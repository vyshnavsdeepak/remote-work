#!/usr/bin/env bash
# provision.sh — run as your user on the VPS after bootstrap.sh
# Usage: ssh <VPS_USER>@<VPS_HOST> 'bash -s' < scripts/provision.sh
# Env:   ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN (optional, written to ~/.bashrc)
set -euo pipefail

echo "==> Updating apt"
sudo apt-get update -qq

# ── Tailscale ────────────────────────────────────────────────────────────────
echo "==> Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sudo sh
echo "    Run 'sudo tailscale up' and authenticate in a browser, then re-run this script."
echo "    Press Enter when done (or Ctrl+C to skip and do it later)."
read -r _

# ── Mosh ─────────────────────────────────────────────────────────────────────
echo "==> Installing Mosh"
sudo apt-get install -y -qq mosh

# ── tmux ─────────────────────────────────────────────────────────────────────
echo "==> Installing tmux"
sudo apt-get install -y -qq tmux

cat > ~/.tmux.conf << 'EOF'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "screen-256color"

# Prefix: Ctrl+A
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Intuitive splits
bind | split-window -h
bind - split-window -v

# Window navigation
bind -n M-Left  previous-window
bind -n M-Right next-window
EOF

# ── Node.js ──────────────────────────────────────────────────────────────────
echo "==> Installing Node.js 20"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - -qq
  sudo apt-get install -y -qq nodejs
fi
echo "    Node $(node --version)"

# ── Claude Code ───────────────────────────────────────────────────────────────
echo "==> Installing Claude Code"
sudo npm install -g @anthropic-ai/claude-code --silent
echo "    Claude Code $(claude --version)"

# ── Bun (required for Channels/Telegram) ────────────────────────────────────
echo "==> Installing Bun"
if ! command -v bun &>/dev/null; then
  curl -fsSL https://bun.sh/install | bash
fi
# shellcheck disable=SC1091
[ -f "$HOME/.bashrc" ] && grep -q 'bun' "$HOME/.bashrc" || \
  echo 'export BUN_INSTALL="$HOME/.bun"; export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc

# ── Firewall ─────────────────────────────────────────────────────────────────
echo "==> Configuring UFW"
sudo ufw allow in on tailscale0
sudo ufw allow 60000:61000/udp   # Mosh
sudo ufw allow 22/tcp            # SSH (keep open until Tailscale is confirmed)
sudo ufw --force enable
sudo ufw status

# ── Environment variables ────────────────────────────────────────────────────
echo "==> Writing env vars to ~/.bashrc"
BASHRC="$HOME/.bashrc"

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  grep -q 'ANTHROPIC_API_KEY' "$BASHRC" || \
    echo "export ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY\"" >> "$BASHRC"
  echo "    ANTHROPIC_API_KEY set."
else
  echo "    ANTHROPIC_API_KEY not provided. Set it manually:"
  echo "    echo 'export ANTHROPIC_API_KEY=\"sk-ant-...\"' >> ~/.bashrc"
fi

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  grep -q 'TELEGRAM_BOT_TOKEN' "$BASHRC" || \
    echo "export TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" >> "$BASHRC"
  echo "    TELEGRAM_BOT_TOKEN set."
fi

# ── Git ───────────────────────────────────────────────────────────────────────
echo "==> Installing git"
sudo apt-get install -y -qq git

echo ""
echo "======================================================"
echo " Provisioning complete. Next steps:"
echo "======================================================"
echo ""
echo "  1. source ~/.bashrc"
echo "  2. claude login          (authenticate once)"
echo "  3. cd ~/your-project"
echo "  4. claude --worktree feature-x --tmux"
echo ""
echo "  For Telegram:"
echo "  5. Open Telegram → @BotFather → /newbot → copy token"
echo "  6. Inside Claude Code: /telegram:configure"
echo ""
