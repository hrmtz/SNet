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
- [Anthropic API key](https://console.anthropic.com/)

## Setup

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
vagrant up
```

All VMs (AI trainer, Kali, target), networking, and port forwarding — one command.

Connect to the trainer:

```bash
ssh -p 2222 snet@localhost
```

Default password: `snet`. On first login, enter your Anthropic API key. Claude Code starts automatically.

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

## License

This project is provided for educational purposes only. Use responsibly.
