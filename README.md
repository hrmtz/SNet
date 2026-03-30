# SNet

[日本語版はこちら / Japanese version](README_ja.md)

**A CTF where you use AI to capture the flag.**

No pentesting experience? No problem. Claude Code acts as your personal trainer — it sets up the environment, teaches you the tools, and guides you through real attack techniques step by step. You type every command yourself.

## What is SNet?

SNet is a vulnerable virtual machine built from a real server that was actually in production. This isn't a textbook exercise — you'll find the kind of mess that real sysadmins leave behind: config files, leftover scripts, forgotten credentials, and bad decisions layered on top of each other.

There are **10 attack routes** to discover. Each playthrough, you take a different path and get fewer hints. By the time you've found them all, you'll think like both an attacker and a defender.

If you can open a terminal, you can play SNet.

## How It Works

1. **You hack, AI coaches** — Claude Code explains concepts and suggests directions, but your hands are on the keyboard
2. **Real-world scenarios** — based on actual server misconfigurations, not contrived puzzles
3. **10 attack routes** — from beginner-friendly to advanced, with decreasing guidance each round
4. **Attack, then defend** — after every exploit, switch roles: fix the vulnerability as a sysadmin
5. **Zero setup hassle** — one command, and Claude handles the rest

## Requirements

- [VirtualBox](https://www.virtualbox.org/) 7.0+
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [Anthropic API key](https://console.anthropic.com/) or a [Claude Max/Pro plan](https://claude.ai)

## Setup

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
vagrant up
```

All VMs (AI trainer, Kali, target), networking, and port forwarding — one command.

> **WSL2 users:** Install the Linux version of Vagrant inside WSL, not the Windows version. Make sure these environment variables are set (add them to your `~/.bashrc` or `~/.zshrc`):
>
> ```bash
> export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
> export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"
> ```

> **Note:** The target VM will show an SSH authentication timeout during `vagrant up` — this is expected. The target is a CTF machine and does not allow Vagrant SSH access. As long as `vagrant status` shows it as `running`, you're good.

## Connecting

| VM | Command | Notes |
|---|---|---|
| AI Trainer | `vagrant ssh claude` or `ssh -p 2222 snet@localhost` | |
| Kali | `vagrant ssh kali` | |
| Target | No SSH from host — attack it from Kali (`10.0.1.20`) | |

On first login, Claude Code starts automatically and asks you to choose an authentication method:

- **API key** — paste your Anthropic API key
- **Max/Pro plan** — select "Subscription" and open the displayed URL in your browser to complete OAuth login

Say "Please set up SNet" — the trainer handles the rest.

## The Cycle

```
 Recon → Exploit → Capture the flag
   ↑                      ↓
   ← Fix it as a sysadmin ←
         (repeat × 10)
```

1. **Find user.txt** — gain initial access
2. **Find root.txt** — escalate to root
3. **Write a report** — document what you did and why it worked
4. **Fix the holes** — patch the vulnerabilities you just exploited
5. **Reset and go again** — different route, fewer hints

## Scenarios

This repository supports multiple CTF scenarios. By default, `vagrant up` starts **SNet1** (beginner).

| Scenario | Command | Description |
|---|---|---|
| SNet1 | `vagrant up` | Breaking into an unlocked house (Beginner) |
| [SNet2](SNet2/README.md) | `SNET=2 vagrant up` | Staying hidden from the guards (Intermediate) |

SNet2 adds a Zabbix monitoring server — you must operate under active surveillance. See [SNet2 README](SNet2/README.md) for details.

To start a specific scenario when VMs are already running:

```bash
SNET=2 vagrant up snet2-target snet2-zabbix   # add SNet2 VMs
SNET=2 vagrant provision claude                # configure trainer for SNet2
```

## Tips: Reverse Shell Usability

The Kali VM comes with `rlwrap` and `tmux` pre-installed to make reverse shells more comfortable.

**Recommended workflow:**

```bash
# 1. Start a tmux session
tmux new-session -s attack

# 2. Use rlwrap with nc for line editing and history
rlwrap nc -lvnp 4444

# 3. Scroll up/down in tmux: Ctrl+B, then [
#    Exit scroll mode: q
```

**Why?** Raw reverse shells lack arrow keys, tab completion, and scrollback. `rlwrap` adds readline support (history, editing), and `tmux` adds scrollback and window management.

## Updating Scenarios

New scenarios are fetched automatically during provisioning. To get the latest:

```bash
vagrant provision claude
```

This pulls the newest versions of all available scenarios without re-downloading the entire VM.

## License

This project is provided for educational purposes only. Use responsibly.
