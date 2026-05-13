import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Default server endpoint (overridable in app settings).
const String _kDefaultUploadEndpoint = 'http://192.168.22.88:8000/api/upload';
const String _kPrefsEndpointKey = 'upload_endpoint';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MatrixRecordingApp());
}

class MatrixRecordingApp extends StatelessWidget {
  const MatrixRecordingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matrix Recording',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF818CF8),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const RecordingHomePage(),
    );
  }
}

enum UploadStatus { idle, queued, uploading, uploaded, failed }

class _Recording {
  _Recording({
    required this.path,
    required this.startedAt,
    required this.durationMs,
  });

  final String path;
  final DateTime startedAt;
  final int durationMs;

  UploadStatus uploadStatus = UploadStatus.idle;
  String? uploadError;
  double uploadProgress = 0.0;
  String? serverId;

  String get filename => path.split(Platform.pathSeparator).last;

  int get sizeBytes {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }
}

class RecordingHomePage extends StatefulWidget {
  const RecordingHomePage({super.key});

  @override
  State<RecordingHomePage> createState() => _RecordingHomePageState();
}

class _RecordingHomePageState extends State<RecordingHomePage> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  final List<_Recording> _history = [];
  String? _errorMessage;
  String _endpoint = _kDefaultUploadEndpoint;

  @override
  void initState() {
    super.initState();
    _loadEndpoint();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _endpoint = prefs.getString(_kPrefsEndpointKey) ?? _kDefaultUploadEndpoint;
    });
  }

  Future<void> _saveEndpoint(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsEndpointKey, value);
    setState(() => _endpoint = value);
  }

  Future<void> _toggle() async {
    setState(() => _errorMessage = null);
    try {
      if (_isRecording) {
        await _stop();
      } else {
        await _start();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isRecording = false;
      });
      _ticker?.cancel();
    }
  }

  Future<void> _start() async {
    final granted = await _ensurePermission();
    if (!granted) {
      setState(() => _errorMessage = '麦克风权限未授予');
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now();
    final path =
        '${dir.path}${Platform.pathSeparator}rec_${ts.millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _startedAt = ts;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecording || _startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final endedAt = DateTime.now();
    final path = await _recorder.stop();
    final started = _startedAt;
    setState(() {
      _isRecording = false;
      _startedAt = null;
    });
    if (path != null && started != null) {
      final rec = _Recording(
        path: path,
        startedAt: started,
        durationMs: endedAt.difference(started).inMilliseconds,
      );
      setState(() => _history.insert(0, rec));
      // Auto-queue upload.
      unawaited(_upload(rec));
    }
  }

  Future<bool> _ensurePermission() async {
    final ok = await _recorder.hasPermission();
    if (ok) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _upload(_Recording rec) async {
    setState(() {
      rec.uploadStatus = UploadStatus.queued;
      rec.uploadError = null;
      rec.uploadProgress = 0.0;
    });
    try {
      final file = File(rec.path);
      if (!file.existsSync()) {
        throw Exception('文件丢失：${rec.path}');
      }
      setState(() => rec.uploadStatus = UploadStatus.uploading);

      final uri = Uri.parse(_endpoint);
      final request = http.MultipartRequest('POST', uri);
      request.fields.addAll({
        'client_started_at': rec.startedAt.toUtc().toIso8601String(),
        'client_duration_ms': rec.durationMs.toString(),
        'device': await _deviceTag(),
      });
      request.files.add(
        await http.MultipartFile.fromPath('file', rec.path),
      );

      final response = await request.send().timeout(
            const Duration(minutes: 5),
            onTimeout: () =>
                throw TimeoutException('上传超时（>5min），网络太慢或服务器没响应'),
          );
      final body = await response.stream.bytesToString();
      if (response.statusCode == 201 || response.statusCode == 200) {
        setState(() {
          rec.uploadStatus = UploadStatus.uploaded;
          rec.uploadProgress = 1.0;
          // Try to capture server-assigned id (best effort, ignore parsing).
          final match = RegExp(r'"id"\s*:\s*"([^"]+)"').firstMatch(body);
          if (match != null) rec.serverId = match.group(1);
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
    } on TimeoutException catch (e) {
      setState(() {
        rec.uploadStatus = UploadStatus.failed;
        rec.uploadError = e.message;
      });
    } catch (e) {
      setState(() {
        rec.uploadStatus = UploadStatus.failed;
        rec.uploadError = e.toString();
      });
    }
  }

  Future<String> _deviceTag() async {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  String _fmtElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  Future<void> _openEndpointDialog() async {
    final controller = TextEditingController(text: _endpoint);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上传地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Endpoint URL',
                hintText: 'http://<server>:8000/api/upload',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '改完点保存。改成空 → 恢复默认。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _saveEndpoint(result.isEmpty ? _kDefaultUploadEndpoint : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix Recording'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '设置上传地址',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: _openEndpointDialog,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'v0.0.2',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _RecorderHero(
              isRecording: _isRecording,
              elapsed: _fmtElapsed(_elapsed),
              onToggle: _toggle,
              color: cs.primary,
              errorColor: cs.error,
            ),
            const SizedBox(height: 8),
            Text(
              '上传到 $_endpoint',
              style: TextStyle(fontSize: 11, color: cs.outline),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '本机录音 (${_history.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _history.isEmpty
                  ? _EmptyState(color: cs.outline)
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _history[i];
                        return _RecordingTile(
                          rec: r,
                          fmtElapsed: _fmtElapsed,
                          fmtSize: _fmtSize,
                          onRetry: () => _upload(r),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'v0.0.2 · 自动上传到服务器 + 失败可重试',
              style: TextStyle(fontSize: 11, color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecorderHero extends StatelessWidget {
  const _RecorderHero({
    required this.isRecording,
    required this.elapsed,
    required this.onToggle,
    required this.color,
    required this.errorColor,
  });

  final bool isRecording;
  final String elapsed;
  final VoidCallback onToggle;
  final Color color;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: isRecording
            ? errorColor.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecording
              ? errorColor.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isRecording ? Icons.mic : Icons.mic_none,
            size: 80,
            color: isRecording ? errorColor : color,
          ),
          const SizedBox(height: 12),
          Text(
            elapsed,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: isRecording ? errorColor : color,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor: isRecording ? errorColor : color,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: Icon(
              isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: Colors.white,
            ),
            label: Text(
              isRecording ? '停止录音' : '开始录音',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({
    required this.rec,
    required this.fmtElapsed,
    required this.fmtSize,
    required this.onRetry,
  });

  final _Recording rec;
  final String Function(Duration) fmtElapsed;
  final String Function(int) fmtSize;
  final VoidCallback onRetry;

  Color _statusColor(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (rec.uploadStatus) {
      case UploadStatus.uploaded:
        return Colors.green;
      case UploadStatus.failed:
        return cs.error;
      case UploadStatus.uploading:
      case UploadStatus.queued:
        return cs.primary;
      case UploadStatus.idle:
        return cs.outline;
    }
  }

  String _statusLabel() {
    switch (rec.uploadStatus) {
      case UploadStatus.uploaded:
        return '✓ 已上传';
      case UploadStatus.failed:
        return '✗ 上传失败';
      case UploadStatus.uploading:
        return '↑ 上传中…';
      case UploadStatus.queued:
        return '… 排队中';
      case UploadStatus.idle:
        return '本地';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(
          Icons.audiotrack,
          color: cs.onPrimaryContainer,
        ),
      ),
      title: Text(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(rec.startedAt),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${fmtElapsed(Duration(milliseconds: rec.durationMs))} · ${fmtSize(rec.sizeBytes)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            rec.filename,
            style: TextStyle(fontSize: 11, color: cs.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (rec.uploadError != null) ...[
            const SizedBox(height: 4),
            Text(
              rec.uploadError!,
              style: TextStyle(fontSize: 11, color: cs.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(),
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (rec.uploadStatus == UploadStatus.failed) ...[
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onRetry,
              child: const Text('重试', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_off_outlined, size: 56, color: color),
          const SizedBox(height: 12),
          Text(
            '还没有录音\n点击上面的开始录音试试',
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
