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
5. **Zero setup hassle** — import OVAs, SSH in, and Claude handles the rest

## Requirements

- [VirtualBox](https://www.virtualbox.org/) 7.0+
- Kali Linux VM ([kali.org](https://www.kali.org/get-kali/#kali-virtual-machines))

## Download

Download from [Releases](https://github.com/hrmtz/SNet/releases):

| OVA | Description |
|-----|-------------|
| `SNet1.ova` | Target VM (the server to hack) |

The target VM is all you need to play. Bring your own Kali and go.

### Optional: AI Trainer

An AI trainer (Claude Code) that coaches you through the CTF — explains tools, suggests directions, and adapts to your skill level. Even experienced players find it changes the game.

| | What you need | RAM |
|-|---------------|-----|
| **Sandboxed** (recommended) | [`SNet-Claude.ova`](https://github.com/hrmtz/SNet/releases) + [API key](https://console.anthropic.com/) | 8GB+ |
| **Local** | `git clone` this repo + [Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code) + [API key](https://console.anthropic.com/) | 6GB+ |

## Setup

### Target + Kali only

Import `SNet1.ova` into VirtualBox. Set up networking between Kali and Target. Hack away.

### With AI Trainer (Sandboxed)

The trainer runs in its own VM — nothing is installed on your host.

1. Import `SNet-Claude.ova` and `SNet1.ova` into VirtualBox
2. Create the network (once per setup):

```bash
VBoxManage natnetwork add --netname "SNet-Net" --network "10.0.1.0/24" --enable --dhcp on
VBoxManage natnetwork modify --netname "SNet-Net" --port-forward-4 "claude-ssh:tcp:[]:2222:[10.0.1.5]:22"
VBoxManage natnetwork modify --netname "SNet-Net" --port-forward-4 "kali-ssh:tcp:[]:2223:[10.0.1.10]:22"
```

3. Start all VMs:

```bash
VBoxManage startvm "SNet-Claude" --type headless
VBoxManage startvm "SNet-Kali" --type headless
```

4. Connect to the trainer:

```bash
ssh -p 2222 snet@localhost
```

Default password: `snet`. On first login, enter your Anthropic API key. Claude Code starts automatically.

5. Say "Please set up SNet" — the trainer handles the rest.

### With AI Trainer (Local)

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
npm install -g @anthropic-ai/claude-code
export ANTHROPIC_API_KEY="sk-ant-..."
claude
```

You'll need the Kali and Target VMs running in VirtualBox.

### With Vagrant

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
vagrant up
```

All VMs, networking, and port forwarding — one command. Connect with `vagrant ssh claude` or `ssh -p 2222 snet@localhost`.

### Need help with setup?

If VBoxManage commands or NAT networking feels daunting, you can ask Claude Code on your host machine to do it for you. Just run `claude` in any directory and paste this:

> I downloaded SNet1.ova and SNet-Claude.ova for the SNet CTF. Please import them into VirtualBox, create a NAT network called "SNet-Net" (10.0.1.0/24) with port forwards for SSH (host 2222 → 10.0.1.5:22, host 2223 → 10.0.1.10:22), attach all VMs to it, and start them.

Claude Code on your machine runs with normal permissions — it will ask before running each command. The broad permissions in `CLAUDE.md` exist solely so the trainer can SSH into Kali and run the setup script. Once setup is done, those permissions are no longer needed.

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

## Security Note

Some files in this repository are encrypted to prevent spoilers. If you'd rather not trust encrypted blobs, run everything inside the sandboxed OVA — that's what it's for.

## Files

| File | Description |
|---|---|
| `SNet1.ova` | The target VM |
| `SNet-Claude.ova` | AI Trainer VM (Claude Code) |
| `claude.md.enc` | AI trainer configuration (loaded automatically) |
| `install.sh.enc` | Kali VM setup script (executed automatically) |
| `CLAUDE.md` | Setup instructions for the AI trainer |

## License

This project is provided for educational purposes only. Use responsibly.
