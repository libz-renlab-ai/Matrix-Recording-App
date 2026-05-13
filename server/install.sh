#!/usr/bin/env bash
# Matrix Recording — one-shot deploy script.
# Run on the server as the `jushi` user (or another user with sudo).
#
#   curl -fsSL https://raw.githubusercontent.com/libz-renlab-ai/Matrix-Recording-App/main/server/install.sh | bash
#
# Or if files are scp'd:
#   cd /home/jushi/matrix-recording/server && bash install.sh

set -euo pipefail

INSTALL_DIR="/home/jushi/matrix-recording/server"
DATA_DIR="/home/jushi/matrix-recording"
SERVICE_NAME="matrix-recording"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "==> install dir: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$DATA_DIR/uploads"
cd "$INSTALL_DIR"

# 1. Python venv
if [ ! -d venv ]; then
  echo "==> creating venv"
  python3 -m venv venv
fi
# shellcheck disable=SC1091
source venv/bin/activate

echo "==> installing python deps"
pip install --upgrade pip > /dev/null
pip install -r requirements.txt

# 2. Quick smoke (start uvicorn for 2s and curl health)
echo "==> smoke test (port 8000)"
(uvicorn main:app --host 127.0.0.1 --port 8000 --log-level error &) > /tmp/matrix-smoke.log 2>&1
sleep 2
if curl -fsS http://127.0.0.1:8000/api/health > /dev/null; then
  echo "    smoke OK"
else
  echo "    smoke FAIL — see /tmp/matrix-smoke.log"
  pkill -f "uvicorn main:app" || true
  exit 1
fi
pkill -f "uvicorn main:app" || true
sleep 1

# 3. Install systemd unit (requires sudo)
if [ -w /etc/systemd/system ] || sudo -n true 2>/dev/null; then
  echo "==> installing systemd unit"
  if sudo -n cp matrix-recording.service "$SERVICE_FILE" 2>/dev/null; then
    sudo -n systemctl daemon-reload
    sudo -n systemctl enable --now "$SERVICE_NAME"
    sleep 2
    sudo -n systemctl status --no-pager "$SERVICE_NAME" | head -15 || true
  else
    echo "    needs sudo password — run manually:"
    echo "    sudo cp $INSTALL_DIR/matrix-recording.service $SERVICE_FILE"
    echo "    sudo systemctl daemon-reload && sudo systemctl enable --now $SERVICE_NAME"
  fi
else
  echo "==> no sudo; starting via nohup (won't survive reboot)"
  pkill -f "uvicorn main:app" 2>/dev/null || true
  nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --log-level info \
    > "$DATA_DIR/server.log" 2>&1 &
  sleep 2
  if curl -fsS http://127.0.0.1:8000/api/health > /dev/null; then
    echo "    server up via nohup"
  else
    echo "    nohup start failed — check $DATA_DIR/server.log"
    exit 1
  fi
fi

echo ""
echo "==> all done"
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "<server-ip>")
echo "    open in browser: http://$SERVER_IP:8000/"
echo "    health:          http://$SERVER_IP:8000/api/health"
echo "    upload (POST):   http://$SERVER_IP:8000/api/upload"
