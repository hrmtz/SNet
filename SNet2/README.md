# SNet2 - Evade the Watchers

[Japanese version / 日本語版はこちら](README_ja.md)

> You broke in. Now stay hidden.

**SNet2** is the second installment of the [SNet CTF series](https://github.com/hrmtz/SNet). While SNet1 taught you how to break into a poorly managed server, SNet2 challenges you to **operate under active surveillance** — a Zabbix monitoring system watches every file change, every process, every login. Your mission: maintain persistent access without triggering a single alert.

Then flip sides and build the defenses yourself.

## The Challenge

The target server is monitored 24/7. Checksums are verified every 30 seconds. Logs are analyzed in real-time. And yet, every monitoring system has blind spots — if you know where to look.

This CTF is based on a real server. The vulnerabilities are not hypothetical.

## Structure

| Round | Phase | Goal |
|-------|-------|------|
| 1-3 | **Attack** | Evade monitoring while maintaining persistence |
| 4-6 | **Defense** | Build detection systems that catch the attacks you just performed |

Attack like an intruder. Defend like a sysadmin. Understand both sides of the wire.

## Requirements

- PC with 12GB+ RAM (4 VMs running simultaneously)
- [VirtualBox](https://www.virtualbox.org/) 7.0+
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [Anthropic API key](https://console.anthropic.com/)

## Setup

```bash
git clone https://github.com/hrmtz/SNet.git
cd SNet
SNET=2 vagrant up
```

All VMs (AI trainer, Kali, target, Zabbix), networking, and port forwarding — one command.

Connect to the trainer:

```bash
ssh -p 2222 snet@localhost
```

On first login, enter your Anthropic API key. Claude Code starts automatically.

Follow your trainer — Claude handles Kali setup, network config, and game progression.

## What You'll Learn

### Attack Phase
- How agent-based monitoring works — and where it breaks
- Timing attacks against periodic integrity checks
- Selective log manipulation
- The difference between "alive" and "watching"

### Defense Phase
- Remote syslog forwarding (tamper-proof logging)
- File integrity monitoring (AIDE/Tripwire)
- Kernel-level auditing with auditd
- Agentless monitoring — when you can't trust the agent

## Key Lesson

> "Don't trust the agent. Trust the kernel."
>
> When an attacker has root, application-level monitoring is compromised.
> Only kernel-level controls and external logging survive.

## Series

```
SNet1 = Breaking into an unlocked house     (Beginner)
SNet2 = Staying hidden from the guards      (Intermediate)
```

Completing SNet1 first is recommended but not required. SNet1 veterans may discover things that others won't.

## Credits

Created by [@hrmtz](https://github.com/hrmtz) | Built with [Claude Code](https://claude.ai/claude-code)
