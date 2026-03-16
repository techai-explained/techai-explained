# TechAI Explained — Video Production Pipeline

## Overview

This pipeline automates the production of faceless YouTube videos from script to upload.

## Pipeline Stages

```
1. Topic Research  →  pipeline/scripts/{nn}-topic-brief.md
2. Script Writing  →  pipeline/scripts/{nn}-{title}.md
3. Voice Generation →  pipeline/voice/{nn}-{title}.mp3
4. Visual Creation  →  pipeline/visuals/{nn}/
5. Video Editing    →  pipeline/output/{nn}-{title}.mp4
6. SEO & Metadata   →  (YouTube metadata in script frontmatter)
7. Upload & Publish →  YouTube via API
```

## Directory Structure

```
pipeline/
├── scripts/     # Video scripts in markdown (timestamped)
├── voice/       # Generated audio files (MP3)
├── visuals/     # Diagrams, screen recordings, B-roll
└── output/      # Final rendered videos (MP4)
```

## Naming Convention

Files use a two-digit prefix matching the video number:
- `01-what-is-ai-agent.md`
- `01-what-is-ai-agent.mp3`
- `01-what-is-ai-agent.mp4`

## Automation Scripts

- `scripts/generate-voice.ps1` — Generate AI narration from a script file
- `scripts/upload-youtube.ps1` — Upload final video to YouTube via API

## Quick Start

```powershell
# Generate voice for a script
.\scripts\generate-voice.ps1 -ScriptFile "pipeline\scripts\01-what-is-ai-agent.md" -OutputFile "pipeline\voice\01-what-is-ai-agent.mp3"
```
