# TechAI Explained — Copilot Instructions

## Machine Setup
When starting a new session, check if this machine is registered:
1. Read pipeline/machines/registry.json
2. If this machine ($env:COMPUTERNAME) is not listed, run: pipeline/bootstrap.ps1 -Install
3. If it IS listed, check setup_pending — fix any incomplete items
4. Read STATUS.md for full project context

## Project Overview
This is the TechAI Content Empire — an automated pipeline for generating daily tech brief videos.
- **pipeline/machine-manifest.json** — central config for repos, tasks, and machine setup
- **pipeline/machines/registry.json** — tracks which machines are registered and their setup status
- **pipeline/bootstrap.ps1** — runs on every boot; auto-detects new machines and runs full setup
- **STATUS.md** — current project state, priorities, and context
