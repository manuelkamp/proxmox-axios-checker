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
