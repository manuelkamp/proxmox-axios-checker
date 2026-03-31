# Proxmox LXC & Docker NPM/Axios Scanner

A lightweight bash script designed to run directly on a Proxmox VE host. It audits all running LXC containers and nested Docker containers to detect the presence of `npm` and the popular `axios` HTTP client. 

This helps administrators identify environments potentially exposed to software supply chain attacks (such as malicious packages pushed to npm).

## Features
- **Zero-Agent:** No need to install anything on your LXCs. It leverages Proxmox's `pct exec`.
- **Docker-Aware:** It detects if Docker is running inside the LXC and scans active Docker containers as well.
- **Smart Fallback:** If a Docker image doesn't contain `npm` (common in production), it checks the filesystem directly for Axios module paths.
- **Low I/O Footprint:** Instead of scanning the entire disk, it isolates active Node.js processes and queries their working directories.

## Prerequisites
- A Proxmox VE host.
- Root privileges on the Proxmox host to run `pct`.
- LXCs must be in a `running` state to be scanned.

## Installation
1. Save the script to your Proxmox host:
   ```bash
   nano /usr/local/bin/proxmox-axios-checher.sh
   ```

2. Make it executable:
   ```bash
   chmod +x /usr/local/bin/proxmox-axios-checher.sh
   ```

## Usage
Run the script directly from your Proxmox terminal:
   ```bash
   /usr/local/bin/proxmox-axios-checher.sh
   ```

---

### The Connection to the Axios Supply Chain Incident (March 2026)
The event described by SOCRadar is a classic nightmare for CISOs and sysadmins. Here is a brief summary of why this script might just save your bacon:

1. **What happened?** An attacker hijacked the access credentials (npm tokens) of the main maintainer of the extremely popular JavaScript library Axios (over 100 million downloads per week).
2. **The poisoned packages:** The attacker published two manipulated versions directly to the npm registry system: axios@1.14.1 (current branch) and axios@0.30.4 (legacy branch).
3. **The payload:** These versions contained a hidden phantom dependency called plain-crypto-js@4.2.1. When running npm install, a post-install script (node setup.js) automatically executed, loading a cross-platform Remote Access Trojan (RAT) for Windows, macOS, and Linux alike.
4. **The problem for you:** Since Axios is the absolute foundation for countless web applications, many CI/CD pipelines or automatic updates download these versions without anyone noticing.

**Where does the script come in?**
Standard antivirus scanners on your Proxmox host cannot see what is happening deep inside an LXC or a Docker container running within it. This script reveals exactly where Axios is located and which version is in use.

> ⚠️ **If you see 1.14.1 or 0.30.4 in the output:** Disconnect the container from the network immediately! The system must be considered compromised, and any passwords or API keys stored on it must be rotated.
