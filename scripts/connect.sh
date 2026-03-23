#!/usr/bin/env bash
# connect.sh — connect to the VPS via Mosh+tmux (falls back to SSH)
# Usage: VPS_HOST=x.x.x.x VPS_USER=vyshnav ./scripts/connect.sh
#        Or: make connect
set -euo pipefail

VPS_HOST="${VPS_HOST:?Set VPS_HOST or run: VPS_HOST=x.x.x.x make connect}"
VPS_USER="${VPS_USER:-vyshnav}"
SESSION="${TMUX_SESSION:-work}"

echo "==> Connecting to $VPS_USER@$VPS_HOST (session: $SESSION)"

if command -v mosh &>/dev/null; then
  exec mosh "$VPS_USER@$VPS_HOST" -- tmux new-session -A -s "$SESSION"
else
  echo "    mosh not found locally — falling back to SSH"
  echo "    Install mosh locally for resilient connections: brew install mosh"
  exec ssh -t "$VPS_USER@$VPS_HOST" "tmux new-session -A -s $SESSION"
fi
