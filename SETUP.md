# Claude Remote Work Setup

Optimized for unreliable internet. Claude runs on a stable VPS; you connect
with a resilient terminal. Your local bandwidth only carries keystrokes.

---

## Architecture

```
Your device (flaky wifi/cellular)
    │
    │  Mosh (UDP, survives drops/sleep/network switches)
    ▼
VPS / cloud VM  ─── stable connection ──► Anthropic API
    ├── tmux            (session survives disconnects)
    ├── Claude Code     (all API traffic happens here)
    ├── Tailscale       (private mesh, no exposed SSH port)
    └── Claude Channels (Telegram bridge)
```

---

## 1. VPS Setup

Any Ubuntu 22.04+ VPS works (Hetzner CX22 is cheap and fast).

```bash
# As root: create a non-root user
adduser vyshnav
usermod -aG sudo vyshnav
# Copy your SSH public key
mkdir -p /home/vyshnav/.ssh
cat ~/.ssh/authorized_keys >> /home/vyshnav/.ssh/authorized_keys
chown -R vyshnav:vyshnav /home/vyshnav/.ssh

# Harden SSH: disable root login and password auth
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
```

---

## 2. Tailscale (Private Networking)

Eliminates the need to expose port 22 publicly.

```bash
# On the VPS:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Restrict firewall to Tailscale traffic only
sudo ufw allow in on tailscale0
sudo ufw enable
# sudo ufw deny 22   # Do this only after confirming Tailscale works

# On your local machine: install Tailscale app, log in to same account
# Then SSH via: ssh vyshnav@vps-hostname  (uses Tailscale MagicDNS)
```

---

## 3. Mosh (Connection Resilience)

UDP-based shell that survives WiFi → cellular switches, VPN drops, laptop sleep.

```bash
# On the VPS:
sudo apt install mosh -y

# Firewall: allow Mosh UDP ports
sudo ufw allow 60000:61000/udp

# From your local machine (replaces ssh):
mosh vyshnav@vps-hostname
```

---

## 4. tmux (Session Persistence)

Sessions keep running when your connection drops.

```bash
# On the VPS:
sudo apt install tmux -y

# Minimal ~/.tmux.conf — mouse support + persistent history
cat > ~/.tmux.conf << 'EOF'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "screen-256color"

# Better prefix: Ctrl+A instead of Ctrl+B
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Split panes with | and -
bind | split-window -h
bind - split-window -v
EOF
```

**Daily workflow:**
```bash
# Connect (creates or reattaches to session named "work"):
mosh vyshnav@vps-hostname -- tmux new-session -A -s work

# Detach (session keeps running):
Ctrl+A, then D

# Reconnect from anywhere later:
mosh vyshnav@vps-hostname -- tmux attach -t work
```

---

## 5. Claude Code Installation

```bash
# On the VPS:

# Install Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Set API key persistently
echo 'export ANTHROPIC_API_KEY="sk-ant-YOUR_KEY_HERE"' >> ~/.bashrc
source ~/.bashrc

# Authenticate (required once)
claude login

# Verify
claude --version
```

---

## 6. Parallel Worktrees

Each worktree is an independent checkout on its own branch. No conflicts between
parallel agents working on different features simultaneously.

```bash
# Requires a git repo:
cd ~/projects/my-app

# Spawn parallel Claude sessions, each in its own branch + tmux window:
claude --worktree feature-auth --tmux
claude --worktree bugfix-payments --tmux
claude --worktree refactor-api --tmux

# List tmux windows: Ctrl+A, then W
# Switch windows: Ctrl+A, then window number
```

**In custom agent .md files**, declare worktree isolation in frontmatter:
```yaml
---
name: my-agent
isolation: worktree
---
```

Cleanup: if no changes were made, Claude auto-deletes the worktree on exit.
If commits exist, it prompts to keep or remove.

---

## 7. Telegram Integration (Claude Code Channels)

Official first-party feature as of Claude Code v2.1.80+.

**Prerequisites:**
- Claude Code v2.1.80+
- Bun runtime
- claude.ai account login (not just API key)

```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Update Claude Code
npm update -g @anthropic-ai/claude-code

# Create a Telegram bot:
# 1. Open Telegram, search for @BotFather
# 2. Send /newbot, follow prompts
# 3. Copy the bot token (looks like: 7123456789:AAF...)

# In a Claude Code session on the VPS:
# Run: /telegram:configure
# → paste the bot token when prompted
# → scan the pairing QR or enter the code on your phone

# Config is saved to: ~/.claude/channels/telegram/.env
# Or set env var:
echo 'export TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"' >> ~/.bashrc
```

**Usage from Telegram:**
- Send a message to your bot → Claude receives it in the active session
- Claude replies with results through the same chat
- Works while you're on mobile with 2G — only the Telegram messages travel
  over your local connection; Claude's actual work happens on the VPS

**Community alternatives** (if official Channels isn't available):
- [`ccgram`](https://github.com/jsayubi/ccgram) — sends Telegram alerts when Claude needs approval or finishes
- [`claude-code-telegram`](https://github.com/RichardAtCT/claude-code-telegram) — full bot with session management
- [`Claude-Code-Remote`](https://github.com/JessyTsui/Claude-Code-Remote) — Telegram + Discord + email notifications

---

## 8. Webhook / CI Integration (Channels)

Claude Code Channels also supports arbitrary HTTP webhooks — useful for CI/CD events.

```
GitHub Actions failure
    → POST to local webhook port on VPS
    → Claude receives event, reads build logs
    → Claude patches code, commits fix
    → Claude posts status to Telegram
```

See [channels-reference docs](https://code.claude.com/docs/en/channels-reference) for building custom channels as MCP servers.

---

## 9. Notifications Without Telegram

If Channels isn't available yet, `ntfy.sh` is a simple push notification service:

```bash
# On VPS, after Claude finishes a task:
curl -d "Build complete on feature-auth" ntfy.sh/your-unique-topic

# On phone: install ntfy app, subscribe to your-unique-topic
# → get a push notification when Claude finishes
```

Or wrap Claude commands:
```bash
claude "refactor the auth module" && curl -d "done" ntfy.sh/my-topic
```

---

## 10. Cloud-Managed Option (No VPS)

If you don't want to manage infrastructure:

| Option | What it does |
|---|---|
| **Claude Code Remote Sessions** | Runs on Anthropic infra; continues after you close the app |
| **Remote Control** (Feb 2026) | Access a running Desktop session from your phone |
| **GitHub Codespaces** | Cloud dev env; store `ANTHROPIC_API_KEY` as a Codespaces secret |
| **GitHub Actions** | Fully headless; triggered by PR/issue events, no session needed |

GitHub Actions setup:
```yaml
# .github/workflows/claude.yml
- uses: anthropics/claude-code-action@v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    prompt: "Review this PR and suggest improvements"
```

---

## 11. Known Issues to Avoid

| Issue | Fix |
|---|---|
| Claude Code hangs on network loss | Run on VPS (stable), connect via Mosh |
| Cloudflare Warp breaks API calls | Disable Warp before running Claude Code |
| Corporate VPN breaks Claude Code | Use Tailscale instead; it uses WireGuard and plays nice |
| `~/.claude` lost in ephemeral envs | Store `ANTHROPIC_API_KEY` as env var; re-login once in persistent env |
| API key not persisting across sessions | Add `export ANTHROPIC_API_KEY=...` to `~/.bashrc` |

---

## Quick Start Checklist

```
[ ] Provision VPS (Ubuntu 22.04+)
[ ] Create non-root user, disable root/password SSH
[ ] Install Tailscale on VPS + local machine, join same network
[ ] Install Mosh on VPS, open UDP 60000-61000
[ ] Install tmux, configure ~/.tmux.conf
[ ] Install Node.js 20+ and Claude Code
[ ] Set ANTHROPIC_API_KEY in ~/.bashrc
[ ] claude login (once)
[ ] Install Bun for Channels support
[ ] Create Telegram bot via BotFather
[ ] Run /telegram:configure in a Claude session
[ ] Test: mosh vyshnav@vps -- tmux new-session -A -s work
[ ] Test: claude --worktree test-branch --tmux
[ ] Test: send Telegram message to bot, verify Claude responds
```
