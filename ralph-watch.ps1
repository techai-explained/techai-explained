# Ralph Watch — TechAI Explained
# Monitors video pipeline and content schedule

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "ERROR: Ralph Watch requires PowerShell 7+" -ForegroundColor Red
    exit 1
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Ralph Watch - techai-explained"

$repoOwner = "tamirdresher"
$repoName = "techai-explained"

function ghp { gh auth switch --user tamirdresher 2>$null | Out-Null; gh @args }

while ($true) {
    $roundStart = Get-Date
    Write-Host "`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') — Ralph Round Start" -ForegroundColor Cyan

    $issues = ghp issue list --repo "$repoOwner/$repoName" --state open --json number,title,labels 2>$null | ConvertFrom-Json
    if ($issues) {
        Write-Host "  Open issues: $($issues.Count)" -ForegroundColor Yellow
        foreach ($issue in $issues) {
            Write-Host "    #$($issue.number): $($issue.title)" -ForegroundColor Gray
        }
    }

    $elapsed = (Get-Date) - $roundStart
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') — Round complete ($([int]$elapsed.TotalSeconds)s)" -ForegroundColor Green

    Start-Sleep -Seconds 300
}
