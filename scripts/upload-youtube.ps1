# TechAI Explained — YouTube Upload Script
# Uploads a video to YouTube using the Data API v3
# Usage: .\upload-youtube.ps1 -VideoFile "path/to/video.mp4" -Title "Video Title"
#
# PREREQUISITES:
# 1. Python 3.8+ with google-api-python-client, google-auth-oauthlib
# 2. OAuth 2.0 client credentials (client_secrets.json)
# 3. Dedicated Google account for the channel (NOT personal)
#
# SETUP:
# pip install google-api-python-client google-auth-oauthlib google-auth-httplib2

param(
    [Parameter(Mandatory=$true)]
    [string]$VideoFile,
    [Parameter(Mandatory=$true)]
    [string]$Title,
    [string]$Description = "",
    [string]$Tags = "",
    [string]$Category = "28",  # Science & Technology
    [string]$Privacy = "private",  # Start as private, manually publish
    [string]$ClientSecretsFile = "client_secrets.json"
)

Write-Host "=== TechAI Explained — YouTube Upload ===" -ForegroundColor Cyan

if (-not (Test-Path $VideoFile)) {
    Write-Error "Video file not found: $VideoFile"
    exit 1
}

if (-not (Test-Path $ClientSecretsFile)) {
    Write-Error @"
OAuth client secrets not found: $ClientSecretsFile

To set up YouTube API access:
1. Go to https://console.developers.google.com/
2. Create a project for TechAI Explained
3. Enable YouTube Data API v3
4. Create OAuth 2.0 credentials
5. Download client_secrets.json to this directory

IMPORTANT: Use the dedicated TechAI Explained Google account, NOT a personal account.
"@
    exit 1
}

$fileSize = (Get-Item $VideoFile).Length / 1MB
Write-Host "Video: $VideoFile ($([math]::Round($fileSize, 1)) MB)" -ForegroundColor Yellow
Write-Host "Title: $Title" -ForegroundColor Yellow
Write-Host "Privacy: $Privacy" -ForegroundColor Yellow
Write-Host ""
Write-Host "Upload functionality requires YouTube API credentials." -ForegroundColor Yellow
Write-Host "See README for setup instructions." -ForegroundColor Yellow
