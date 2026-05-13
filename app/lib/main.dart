import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

void main() {
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

class _Recording {
  _Recording({
    required this.path,
    required this.startedAt,
    required this.durationMs,
  });

  final String path;
  final DateTime startedAt;
  final int durationMs;

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

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
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
    }
  }

  Future<bool> _ensurePermission() async {
    final ok = await _recorder.hasPermission();
    if (ok) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix Recording'),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'v0.0.1',
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
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _history[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Icon(
                              Icons.audiotrack,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            DateFormat('yyyy-MM-dd HH:mm:ss')
                                .format(r.startedAt),
                          ),
                          subtitle: Text(
                            '${_fmtElapsed(Duration(milliseconds: r.durationMs))} · ${_fmtSize(r.sizeBytes)}\n${r.filename}',
                          ),
                          isThreeLine: true,
                          trailing: const Chip(
                            label: Text('本地'),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            const Text(
              'v0.0.1 · 录音本地保存，上传服务器功能待 sprint 1',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
