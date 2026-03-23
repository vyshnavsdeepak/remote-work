# Claude Code — Remote Work Setup

> Run Claude Code on a stable VPS. Access it from anywhere, on any connection.
> Your local bandwidth only carries keystrokes — all API traffic stays on the server.

---

## Table of Contents

- [Architecture](#architecture)
- [Setup](#setup)
  - [1. VPS Provisioning](#1-vps-provisioning)
  - [2. Tailscale — Private Networking](#2-tailscale--private-networking)
  - [3. Mosh — Connection Resilience](#3-mosh--connection-resilience)
  - [4. tmux — Session Persistence](#4-tmux--session-persistence)
  - [5. Claude Code](#5-claude-code)
- [Features](#features)
  - [Parallel Worktrees](#parallel-worktrees)
  - [Telegram Integration](#telegram-integration)
  - [Webhook / CI Integration](#webhook--ci-integration)
  - [Lightweight Notifications (ntfy)](#lightweight-notifications-ntfy)
- [Cloud-Managed Alternative](#cloud-managed-alternative)
- [Known Issues](#known-issues)
- [Quick Start Checklist](#quick-start-checklist)

---

## Architecture

```
Your device  (flaky wifi / cellular)
     │
     │  Mosh  (UDP — survives drops, sleep, network switches)
     ▼
VPS / cloud VM  ──── stable connection ────► Anthropic API
     ├── Claude Code     (all API traffic happens here)
     ├── tmux            (sessions survive disconnects)
     ├── Tailscale       (private mesh — no exposed SSH port)
     └── Claude Channels (Telegram / Discord / webhook bridge)
```

---

## Setup

### 1. VPS Provisioning

Any Ubuntu 22.04+ VPS works. [Hetzner CX22](https://www.hetzner.com/cloud) (~€4/mo) is a good default.

```bash
# As root — create a non-root user
adduser <your-username>
usermod -aG sudo <your-username>

# Copy your SSH public key
mkdir -p /home/<your-username>/.ssh
cat ~/.ssh/authorized_keys >> /home/<your-username>/.ssh/authorized_keys
chown -R <your-username>:<your-username> /home/<your-username>/.ssh

# Harden SSH: disable root login and password auth
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
```

---

### 2. Tailscale — Private Networking

Connects your devices in a private mesh. No need to expose port 22 to the public internet.

```bash
# On the VPS
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Lock the firewall to Tailscale traffic only
sudo ufw allow in on tailscale0
sudo ufw enable
# Only run the next line after confirming Tailscale is working:
# sudo ufw deny 22
```

On your local machine: install the [Tailscale app](https://tailscale.com/download), log in to the same account.
Connect via: `ssh <your-username>@<vps-hostname>` — Tailscale MagicDNS handles routing.

---

### 3. Mosh — Connection Resilience

UDP-based shell. Survives WiFi → cellular switches, VPN drops, and laptop sleep.

```bash
# On the VPS
sudo apt install mosh -y
sudo ufw allow 60000:61000/udp

# From your local machine — replaces ssh
mosh <your-username>@<vps-hostname>
```

---

### 4. tmux — Session Persistence

Sessions keep running when your connection drops. Reconnect and pick up exactly where you left off.

```bash
# On the VPS
sudo apt install tmux -y
```

**Recommended `~/.tmux.conf`:**

```bash
cat > ~/.tmux.conf << 'EOF'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "screen-256color"

# Use Ctrl+A as prefix (easier than Ctrl+B)
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Intuitive pane splits
bind | split-window -h
bind - split-window -v
EOF
```

**Daily workflow:**

```bash
# Connect — creates or reattaches to a session named "work"
mosh <your-username>@<vps-hostname> -- tmux new-session -A -s work

# Detach (session keeps running in background)
Ctrl+A, then D

# Reattach from anywhere
mosh <your-username>@<vps-hostname> -- tmux attach -t work
```

---

### 5. Claude Code

```bash
# Install Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Persist the API key
echo 'export ANTHROPIC_API_KEY="sk-ant-YOUR_KEY_HERE"' >> ~/.bashrc
source ~/.bashrc

# Authenticate (one-time)
claude login

# Verify
claude --version
```

---

## Features

### Parallel Worktrees

Each worktree is an independent checkout on its own branch. Multiple Claude agents work on different tasks simultaneously — no conflicts.

```bash
cd ~/projects/my-app

# Spawn parallel Claude sessions, each isolated in its own branch + tmux window
claude --worktree feature-auth --tmux
claude --worktree bugfix-payments --tmux
claude --worktree refactor-api --tmux

# Navigate tmux windows: Ctrl+A then W  (list) / number (jump)
```

To declare isolation in a custom agent file:

```yaml
---
name: my-agent
isolation: worktree
---
```

> **Cleanup:** worktree is auto-deleted on exit if no changes were made. If commits exist, Claude prompts to keep or remove.

---

### Telegram Integration

Official first-party feature in Claude Code v2.1.80+ via **Claude Code Channels**.

**Prerequisites:** Claude Code v2.1.80+, [Bun](https://bun.sh) runtime, claude.ai login (not just API key).

```bash
# 1. Install Bun
curl -fsSL https://bun.sh/install | bash

# 2. Update Claude Code
npm update -g @anthropic-ai/claude-code

# 3. Create a Telegram bot
#    → Open Telegram → search @BotFather → /newbot → copy the token

# 4. Inside a running Claude Code session:
/telegram:configure
# → paste the bot token → pair your phone via QR or code

# Token is saved to ~/.claude/channels/telegram/.env
# Or set it as an env var:
echo 'export TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"' >> ~/.bashrc
```

**How it works:**
Send a message from your phone → Claude receives it in the active session → does the work on the VPS → replies back through Telegram. Your local connection only carries the chat messages.

**Community alternatives** (if official Channels isn't available):

| Project | What it does |
|---|---|
| [`ccgram`](https://github.com/jsayubi/ccgram) | Push alerts when Claude needs approval or finishes a task |
| [`claude-code-telegram`](https://github.com/RichardAtCT/claude-code-telegram) | Full bot with persistent session management |
| [`Claude-Code-Remote`](https://github.com/JessyTsui/Claude-Code-Remote) | Telegram + Discord + email notifications |

---

### Webhook / CI Integration

Channels also accepts arbitrary HTTP webhooks, enabling fully autonomous CI/CD loops:

```
GitHub Actions failure
  → POST to webhook port on VPS
  → Claude reads the build logs
  → Claude patches the code, commits the fix, triggers re-run
  → Claude posts a status update to Telegram
```

See the [Channels reference docs](https://code.claude.com/docs/en/channels-reference) for building custom MCP-based channels.

---

### Lightweight Notifications (ntfy)

No Telegram? `ntfy.sh` delivers push notifications with a single `curl` call.

```bash
# Send a notification from the VPS
curl -d "feature-auth complete" ntfy.sh/your-unique-topic

# Wrap any Claude task
claude "refactor the auth module" && curl -d "done" ntfy.sh/your-unique-topic
```

On your phone: install the [ntfy app](https://ntfy.sh) and subscribe to your topic.

---

## Cloud-Managed Alternative

No VPS? These options run Claude on someone else's infra.

| Option | Notes |
|---|---|
| **Claude Code Remote Sessions** | Runs on Anthropic infra; continues after you close the app |
| **Remote Control** _(Feb 2026)_ | Access a running Desktop session from your phone |
| **GitHub Codespaces** | Store `ANTHROPIC_API_KEY` as a Codespaces secret; ephemeral but easy |
| **GitHub Actions** | Fully headless; triggered by PR/issue events |

**GitHub Actions example:**

```yaml
# .github/workflows/claude.yml
- uses: anthropics/claude-code-action@v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    prompt: "Review this PR and suggest improvements"
```

---

## Known Issues

| Symptom | Fix |
|---|---|
| Claude Code hangs on network loss | Run on VPS; connect via Mosh — your local drop doesn't affect the session |
| `Unable to connect to API` errors | Disable Cloudflare Warp before running Claude Code |
| Corporate VPN breaks Claude Code | Replace with Tailscale (WireGuard-based, plays nice with API traffic) |
| `~/.claude` lost in ephemeral environments | Use `ANTHROPIC_API_KEY` env var; keep auth in a persistent home directory |

---

## Quick Start Checklist

```
[ ] Provision VPS (Ubuntu 22.04+, ≥2 GB RAM)
[ ] Create non-root user, disable root/password SSH
[ ] Install Tailscale on VPS + local machine, join same network
[ ] Install Mosh on VPS, open UDP 60000–61000 in firewall
[ ] Install tmux, write ~/.tmux.conf
[ ] Install Node.js 20+ and Claude Code
[ ] Add ANTHROPIC_API_KEY to ~/.bashrc
[ ] Run: claude login
[ ] Install Bun (required for Channels)
[ ] Create Telegram bot via @BotFather
[ ] Run /telegram:configure inside a Claude session
[ ] Smoke test: mosh <host> -- tmux new-session -A -s work
[ ] Smoke test: claude --worktree test-branch --tmux
[ ] Smoke test: send Telegram message → verify Claude responds
```
