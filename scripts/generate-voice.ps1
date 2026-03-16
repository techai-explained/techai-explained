# TechAI Explained — Voice Generation Script
# Uses edge-tts for free AI voice narration
# Usage: .\generate-voice.ps1 -ScriptFile "path/to/script.md" -OutputFile "voice.mp3"

param(
    [Parameter(Mandatory=$true)]
    [string]$ScriptFile,
    [string]$OutputFile = "output.mp3",
    [string]$Voice = "en-US-GuyNeural",
    [string]$Rate = "+0%",
    [string]$Pitch = "+0Hz"
)

if (-not (Get-Command edge-tts -ErrorAction SilentlyContinue)) {
    Write-Host "Installing edge-tts..." -ForegroundColor Yellow
    pip install edge-tts
}

$scriptContent = Get-Content $ScriptFile -Raw
# Strip markdown formatting
$cleanText = $scriptContent -replace '#.*\n', '' -replace '\*\*', '' -replace '`[^`]*`', '' -replace '\[.*?\]\(.*?\)', ''

$tempFile = [System.IO.Path]::GetTempFileName() + ".txt"
$cleanText | Out-File $tempFile -Encoding utf8

edge-tts --voice $Voice --rate $Rate --pitch $Pitch --text (Get-Content $tempFile -Raw) --write-media $OutputFile

Remove-Item $tempFile -Force
Write-Host "Voice generated: $OutputFile" -ForegroundColor Green
