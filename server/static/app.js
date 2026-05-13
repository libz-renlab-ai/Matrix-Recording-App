'use strict';

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

const state = {
  recordings: [],
  q: '',
  day: '',
};

function fmtBytes(n) {
  if (!n) return '0 B';
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  if (n < 1024 * 1024 * 1024) return `${(n / 1024 / 1024).toFixed(2)} MB`;
  return `${(n / 1024 / 1024 / 1024).toFixed(2)} GB`;
}

function fmtDuration(ms) {
  if (!ms) return '—';
  const s = Math.round(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  return `${m}:${String(sec).padStart(2, '0')}`;
}

function fmtTime(iso) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    return d.toLocaleString('zh-CN', { hour12: false });
  } catch (_) {
    return iso;
  }
}

async function fetchRecordings() {
  try {
    const res = await fetch('/api/recordings');
    if (!res.ok) throw new Error(`status ${res.status}`);
    state.recordings = await res.json();
    rebuildDayFilter();
    render();
    refreshStats();
  } catch (e) {
    $('#list').innerHTML = `<div class="empty">加载失败：${e}</div>`;
  }
}

function rebuildDayFilter() {
  const days = new Set();
  state.recordings.forEach((r) => {
    if (r.uploaded_at) days.add(r.uploaded_at.slice(0, 10));
  });
  const sel = $('#day');
  const cur = sel.value;
  sel.innerHTML = '<option value="">所有日期</option>';
  Array.from(days).sort().reverse().forEach((d) => {
    const opt = document.createElement('option');
    opt.value = d;
    opt.textContent = d;
    sel.appendChild(opt);
  });
  if (cur && days.has(cur)) sel.value = cur;
}

function refreshStats() {
  const n = state.recordings.length;
  const totalBytes = state.recordings.reduce((s, r) => s + (r.size_bytes || 0), 0);
  const totalDur = state.recordings.reduce((s, r) => s + (r.client_duration_ms || 0), 0);
  $('#count').textContent = `${n} 条录音`;
  $('#size').textContent = `共 ${fmtBytes(totalBytes)}`;
  $('#disk').textContent = `时长 ${fmtDuration(totalDur)}`;
}

function matches(r) {
  if (state.day && (r.uploaded_at || '').slice(0, 10) !== state.day) return false;
  if (!state.q) return true;
  const hay = [
    r.title, r.project, r.participants, r.device, r.filename, r.id,
    r.uploaded_at, r.client_started_at,
  ].filter(Boolean).join(' ').toLowerCase();
  return hay.includes(state.q.toLowerCase());
}

function render() {
  const list = $('#list');
  list.innerHTML = '';
  const tpl = $('#card');
  const filtered = state.recordings.filter(matches);

  if (filtered.length === 0) {
    list.innerHTML = '<div class="empty">还没有录音，去手机端开始录一段吧</div>';
    return;
  }

  filtered.forEach((r) => {
    const node = tpl.content.cloneNode(true);
    const titleText = node.querySelector('.title-text');
    if (r.title) {
      titleText.textContent = r.title;
    } else {
      titleText.textContent = '（无标题）';
      titleText.classList.add('empty');
    }
    node.querySelector('.title-id').textContent = `${r.id} · ${r.filename || ''}`;
    node.querySelector('.meta-time').textContent = fmtTime(r.uploaded_at);
    node.querySelector('.meta-dur').textContent = fmtDuration(r.client_duration_ms);
    node.querySelector('.meta-size').textContent = fmtBytes(r.size_bytes);
    node.querySelector('.meta-device').textContent = r.device || '未知设备';
    node.querySelector('.tag.project').textContent = r.project ? `📂 ${r.project}` : '';
    node.querySelector('.tag.participants').textContent = r.participants ? `👥 ${r.participants}` : '';

    const player = node.querySelector('.player');
    player.src = `/api/audio/${r.id}`;

    const dl = node.querySelector('.download');
    dl.href = `/api/audio/${r.id}`;
    dl.setAttribute('download', r.filename || `${r.id}.m4a`);

    const del = node.querySelector('.delete');
    del.addEventListener('click', async () => {
      if (!confirm(`确定删除：${r.title || r.id}？`)) return;
      const status = node.querySelector('.action-status');
      status.textContent = '删除中…';
      try {
        const res = await fetch(`/api/audio/${r.id}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`status ${res.status}`);
        await fetchRecordings();
      } catch (e) {
        status.textContent = `失败：${e}`;
      }
    });

    list.appendChild(node);
  });
}

// ---- wire up ----

$('#q').addEventListener('input', (e) => {
  state.q = e.target.value;
  render();
});
$('#day').addEventListener('change', (e) => {
  state.day = e.target.value;
  render();
});
$('#refresh').addEventListener('click', fetchRecordings);

// Auto-refresh every 20s in case a phone uploads something.
setInterval(fetchRecordings, 20000);

fetchRecordings();
