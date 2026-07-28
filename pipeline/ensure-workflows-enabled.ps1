# Ensures the repo's scheduled GitHub Actions workflows are enabled.
#
# GitHub disables scheduled workflows after 60 days of repository inactivity.
# Commits pushed by GITHUB_TOKEN (i.e. the pipeline's own bot commits) do NOT
# reset that timer, and a scheduled keepalive workflow gets disabled alongside
# everything else - so it cannot heal itself. This check therefore has to run
# from outside Actions. It is invoked by bootstrap.ps1 / startup-catchup.ps1.

param(
    [string[]]$Repos = @(
        'techai-explained/techai-explained'
    )
)

$ErrorActionPreference = 'Continue'

foreach ($repo in $Repos) {
    Write-Host "Checking scheduled workflows for $repo..." -ForegroundColor Cyan

    $raw = gh api "repos/$repo/actions/workflows" --paginate 2>$null
    if (-not $raw) {
        Write-Host "  Could not query workflows for $repo (auth or network issue)" -ForegroundColor Red
        continue
    }

    $workflows = ($raw | ConvertFrom-Json).workflows
    $disabled = @($workflows | Where-Object { $_.state -eq 'disabled_inactivity' })

    if ($disabled.Count -eq 0) {
        Write-Host "  All workflows active" -ForegroundColor DarkGray
        continue
    }

    foreach ($wf in $disabled) {
        Write-Host "  Re-enabling '$($wf.name)' (was disabled_inactivity)" -ForegroundColor Yellow
        gh api -X PUT "repos/$repo/actions/workflows/$($wf.id)/enable" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Enabled" -ForegroundColor Green
        } else {
            Write-Host "    Failed - needs admin rights on $repo" -ForegroundColor Red
        }
    }
}
