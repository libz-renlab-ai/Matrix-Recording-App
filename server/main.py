"""Matrix Recording — minimal upload + browse server.

Endpoints:
  POST /api/upload      multipart upload of audio file + form metadata
  GET  /api/recordings  list all uploaded recordings as JSON
  GET  /api/audio/<id>  stream audio file by id
  DELETE /api/audio/<id>  delete recording
  GET  /                serve static frontend
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import logging
import os
import shutil
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

# --------------------------------------------------------------------------- config

BASE_DIR = Path(__file__).resolve().parent
# Where uploaded audio + metadata live. Override with MATRIX_DATA_DIR env var.
# Default: /home/jushi/matrix-recording on Linux server, ~/matrix-recording-data on local dev.
_DEFAULT_DATA_DIR = (
    "/home/jushi/matrix-recording"
    if os.name == "posix" and Path("/home/jushi").exists()
    else str(Path.home() / "matrix-recording-data")
)
DATA_DIR = Path(os.getenv("MATRIX_DATA_DIR", _DEFAULT_DATA_DIR))
UPLOADS_DIR = DATA_DIR / "uploads"
META_FILE = DATA_DIR / "metadata.jsonl"
STATIC_DIR = BASE_DIR / "static"

for p in (UPLOADS_DIR, DATA_DIR):
    p.mkdir(parents=True, exist_ok=True)
META_FILE.touch(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("matrix-recording")

# --------------------------------------------------------------------------- app

app = FastAPI(
    title="Matrix Recording Server",
    description="Receive meeting recordings from the Matrix mobile app.",
    version="0.0.2",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# --------------------------------------------------------------------------- helpers

def _today_dir() -> Path:
    d = UPLOADS_DIR / dt.date.today().isoformat()
    d.mkdir(parents=True, exist_ok=True)
    return d


def _load_meta() -> list[dict]:
    if not META_FILE.exists():
        return []
    rows = []
    with META_FILE.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                log.warning("skip malformed meta line: %s", line[:120])
    rows.sort(key=lambda r: r.get("uploaded_at", ""), reverse=True)
    return rows


def _append_meta(row: dict) -> None:
    with META_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def _rewrite_meta(rows: list[dict]) -> None:
    with META_FILE.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


# --------------------------------------------------------------------------- API


@app.post("/api/upload")
async def upload_recording(
    file: UploadFile = File(...),
    title: Optional[str] = Form(default=None),
    project: Optional[str] = Form(default=None),
    participants: Optional[str] = Form(default=None),
    client_started_at: Optional[str] = Form(default=None),
    client_duration_ms: Optional[int] = Form(default=None),
    device: Optional[str] = Form(default=None),
):
    """Receive an audio file. Saves to UPLOADS/<date>/<rec_id>.<ext>."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="filename missing")

    rec_id = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%S") + "_" + hashlib.md5(
        (file.filename + str(dt.datetime.utcnow().timestamp())).encode()
    ).hexdigest()[:8]

    suffix = Path(file.filename).suffix or ".m4a"
    target_dir = _today_dir()
    target = target_dir / f"{rec_id}{suffix}"

    # stream copy
    size = 0
    with target.open("wb") as fout:
        while True:
            chunk = await file.read(1 << 20)  # 1 MB
            if not chunk:
                break
            fout.write(chunk)
            size += len(chunk)
    log.info("uploaded %s (%d bytes)", target, size)

    row = {
        "id": rec_id,
        "filename": file.filename,
        "stored_path": str(target.relative_to(DATA_DIR)),
        "size_bytes": size,
        "content_type": file.content_type,
        "uploaded_at": dt.datetime.utcnow().isoformat() + "Z",
        "client_started_at": client_started_at,
        "client_duration_ms": client_duration_ms,
        "title": title,
        "project": project,
        "participants": participants,
        "device": device,
    }
    _append_meta(row)
    return JSONResponse(row, status_code=201)


@app.get("/api/recordings")
async def list_recordings():
    return _load_meta()


@app.get("/api/audio/{rec_id}")
async def stream_audio(rec_id: str):
    for r in _load_meta():
        if r["id"] == rec_id:
            p = DATA_DIR / r["stored_path"]
            if not p.exists():
                raise HTTPException(status_code=410, detail="file gone from disk")
            return FileResponse(
                p,
                media_type=r.get("content_type") or "audio/mp4",
                filename=r["filename"],
            )
    raise HTTPException(status_code=404, detail="not found")


@app.delete("/api/audio/{rec_id}")
async def delete_audio(rec_id: str):
    rows = _load_meta()
    keep, removed = [], None
    for r in rows:
        if r["id"] == rec_id:
            removed = r
        else:
            keep.append(r)
    if removed is None:
        raise HTTPException(status_code=404, detail="not found")
    p = DATA_DIR / removed["stored_path"]
    p.unlink(missing_ok=True)
    _rewrite_meta(keep)
    log.info("deleted %s (%s)", rec_id, p)
    return {"deleted": rec_id}


@app.get("/api/health")
async def health():
    return {
        "ok": True,
        "ts": dt.datetime.utcnow().isoformat() + "Z",
        "upload_dir": str(UPLOADS_DIR),
        "recordings_count": len(_load_meta()),
        "disk_free_bytes": shutil.disk_usage(str(DATA_DIR)).free,
    }


# --------------------------------------------------------------------------- static


# Serve frontend at /
if STATIC_DIR.exists():
    app.mount("/", StaticFiles(directory=str(STATIC_DIR), html=True), name="static")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info",
    )
