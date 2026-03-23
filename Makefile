# Remote Work — Claude Code VPS Setup
# Usage:
#   make bootstrap  VPS_HOST=x.x.x.x
#   make provision  VPS_HOST=x.x.x.x [ANTHROPIC_API_KEY=...] [TELEGRAM_BOT_TOKEN=...]
#   make connect    VPS_HOST=x.x.x.x [VPS_USER=vyshnav] [TMUX_SESSION=work]
#   make worktree   VPS_HOST=x.x.x.x name=feature-x

VPS_HOST  ?= $(error Set VPS_HOST, e.g. make connect VPS_HOST=1.2.3.4)
VPS_USER  ?= vyshnav
TMUX_SESSION ?= work

.PHONY: bootstrap provision connect worktree help

help:
	@echo ""
	@echo "  make bootstrap  VPS_HOST=x.x.x.x"
	@echo "      → Create user, harden SSH (run as root, first time only)"
	@echo ""
	@echo "  make provision  VPS_HOST=x.x.x.x [ANTHROPIC_API_KEY=...] [TELEGRAM_BOT_TOKEN=...]"
	@echo "      → Install Tailscale, Mosh, tmux, Node, Claude Code, Bun"
	@echo ""
	@echo "  make connect    VPS_HOST=x.x.x.x"
	@echo "      → Attach to tmux session via Mosh (falls back to SSH)"
	@echo ""
	@echo "  make worktree   VPS_HOST=x.x.x.x name=feature-x"
	@echo "      → Open a new Claude worktree in its own tmux window"
	@echo ""

bootstrap:
	@echo "==> Running bootstrap on root@$(VPS_HOST)"
	VPS_USER=$(VPS_USER) ssh root@$(VPS_HOST) 'bash -s' < scripts/bootstrap.sh

provision:
	@echo "==> Provisioning $(VPS_USER)@$(VPS_HOST)"
	ANTHROPIC_API_KEY="$(ANTHROPIC_API_KEY)" \
	TELEGRAM_BOT_TOKEN="$(TELEGRAM_BOT_TOKEN)" \
	VPS_USER=$(VPS_USER) \
	ssh $(VPS_USER)@$(VPS_HOST) \
	  'ANTHROPIC_API_KEY="$(ANTHROPIC_API_KEY)" TELEGRAM_BOT_TOKEN="$(TELEGRAM_BOT_TOKEN)" bash -s' \
	  < scripts/provision.sh

connect:
	VPS_HOST=$(VPS_HOST) VPS_USER=$(VPS_USER) TMUX_SESSION=$(TMUX_SESSION) \
	  bash scripts/connect.sh

worktree:
	@[ -n "$(name)" ] || (echo "Usage: make worktree VPS_HOST=x.x.x.x name=feature-x" && exit 1)
	ssh -t $(VPS_USER)@$(VPS_HOST) \
	  'cd $$(git rev-parse --show-toplevel 2>/dev/null || echo ~) && claude --worktree $(name) --tmux'
