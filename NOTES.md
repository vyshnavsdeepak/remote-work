# Research Notes
> Sourced via Playwright browser — prices verified March 2026

---

## Hetzner Cloud — VPS Pricing (excl. VAT)

Source: hetzner.com/cloud/regular-performance

### Shared / Regular Performance (AMD) — Recommended tier

| Model | vCPU | RAM | SSD | Price/mo | Price/hr |
|---|---|---|---|---|---|
| **CPX11** | 2 | 2 GB | 40 GB | **€ 4.49** | € 0.0072 |
| **CPX21** | 3 | 4 GB | 80 GB | € 8.99 | € 0.0145 |
| CPX31 | 4 | 8 GB | 160 GB | € 15.99 | € 0.0257 |
| CPX41 | 8 | 16 GB | 240 GB | € 29.99 | € 0.0481 |
| CPX51 | 16 | 32 GB | 360 GB | € 59.99 | € 0.0962 |

### Shared / Regular Performance (ARM64 / Ampere) — Cheaper option

| Model | vCPU | RAM | SSD | Price/mo |
|---|---|---|---|---|
| CPX12 | 1 | 2 GB | 40 GB | € 5.99 |
| **CPX22** | 2 | 4 GB | 80 GB | **€ 5.99** |
| CPX32 | 4 | 8 GB | 160 GB | € 10.49 |
| CPX42 | 8 | 16 GB | 320 GB | € 19.49 |

### Shared / Cost Optimized — Starting from € 2.99/mo
Older hardware. Good for very light workloads or testing.

### Dedicated / General Purpose — Starting from € 11.99/mo
For consistently high CPU loads. Not needed for this use case.

### Add-ons
| Add-on | Cost |
|---|---|
| Snapshots | € 0.011/GB/month |
| Backups | from € 0.598/mo |
| Floating IPv6 | € 1.00/mo |
| Extra traffic | € 1.00/TB (after 20 TB inclusive) |

### Locations
- EU: Falkenstein (FSN), Nuremberg (NBG), Helsinki (HEL)
- US East: Ashburn, Virginia (ASH)
- US West: Hillsboro, Oregon (HIL)
- Asia: Singapore (SIN)

### Recommendation
**CPX11** (2 vCPU / 2 GB RAM / 40 GB SSD) at **€ 4.49/mo** is sufficient for running
Claude Code + tmux + Tailscale. Upgrade to **CPX21** (4 GB RAM) if you run
multiple heavy worktrees simultaneously.

---

## Claude Plans — Pricing (verified March 2026)

Source: claude.com/pricing

| Plan | Price | Notes |
|---|---|---|
| **Free** | $0 | Limited usage |
| **Pro** | **$17/mo** (annual) / **$20/mo** (monthly) | Includes Claude Code + Cowork |
| **Max 5x** | from $100/mo | 5× more usage than Pro |
| **Max 20x** | higher | 20× more usage than Pro |
| **Team / Enterprise** | custom | Shared projects, admin controls |

**For remote work setup: Pro ($20/mo) is the minimum.**
Required for:
- claude.ai login (needed for Claude Code Channels / Telegram)
- Claude Code access
- Projects with persistent context

---

## Tailscale — Pricing

Source: tailscale.com/pricing

| Plan | Price | Devices | Users |
|---|---|---|---|
| **Personal (Free)** | **$0** | 100 | 3 |
| Starter | $5/user/mo | 100+ | 3+ |
| Premium | $18/user/mo | unlimited | unlimited |

**Personal (free) is sufficient** for a solo remote work setup (your laptop, phone, VPS).

---

## Other Tools — All Free

| Tool | Cost | Notes |
|---|---|---|
| Mosh | Free / open source | UDP shell, `sudo apt install mosh` |
| tmux | Free / open source | `sudo apt install tmux` |
| Bun | Free / open source | Required for Claude Code Channels |
| ntfy.sh | Free (cloud tier) | Push notifications |
| Telegram | Free | Bot via @BotFather |
| GitHub Codespaces | Free tier: 60 hrs/mo | Alternative to VPS |

---

## Total Monthly Cost Summary

| Item | Cost |
|---|---|
| Hetzner CPX11 VPS | € 4.49/mo (~$5) |
| Claude Pro | $20/mo |
| Tailscale Personal | $0 |
| Everything else | $0 |
| **Total** | **~$25/mo** |

Upgrade path: CPX21 (4 GB RAM) at € 8.99/mo if running 3+ parallel worktrees.

---

## Notes on Claude Code Channels (Telegram)

- Requires Claude Code **v2.1.80+**
- Requires **Bun** runtime
- Requires **claude.ai login** (Pro plan) — API key alone is not supported
- Team/Enterprise orgs must enable it in org settings
- Config stored at: `~/.claude/channels/telegram/.env`
- Official docs: https://code.claude.com/docs/en/channels

## Notes on Worktrees

- CLI flags: `--worktree [name]` and `--tmux`
- Worktrees created at `.claude/worktrees/[name]/`
- Agent frontmatter: `isolation: worktree`
- Auto-cleaned if no changes; prompts to keep if commits exist
- Available on: CLI, Desktop, IDE extensions, Web, Mobile

## Notes on Remote Control (Feb 2026)

- Access a running Desktop session from another device (phone)
- Session continues even if originating device closes the app
- Research preview — requires claude.ai login
- Docs: https://code.claude.com/docs/en/remote-control
