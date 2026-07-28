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

# The machine may be logged into several GitHub accounts, and `gh`'s "active"
# account can be switched out from under us by any other tool. Re-enabling a
# workflow needs admin rights, so resolve a token that actually has them
# instead of trusting whichever account happens to be active.
function Resolve-AdminToken {
    param([string]$Repo)

    $accounts = @(gh auth status 2>&1 |
        Select-String -Pattern 'Logged in to \S+ account (\S+)' |
        ForEach-Object { $_.Matches[0].Groups[1].Value })

    foreach ($account in $accounts) {
        $token = gh auth token -u $account 2>$null
        if (-not $token) { continue }

        $previous = $env:GH_TOKEN
        $env:GH_TOKEN = $token
        $isAdmin = gh api "repos/$Repo" --jq '.permissions.admin' 2>$null
        $env:GH_TOKEN = $previous

        if ($isAdmin -eq 'true') { return $token }
    }

    return $null
}

$originalToken = $env:GH_TOKEN

foreach ($repo in $Repos) {
    Write-Host "Checking scheduled workflows for $repo..." -ForegroundColor Cyan

    $adminToken = Resolve-AdminToken -Repo $repo
    if (-not $adminToken) {
        Write-Host "  No logged-in account has admin rights on $repo - cannot re-enable workflows" -ForegroundColor Red
        continue
    }
    $env:GH_TOKEN = $adminToken

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

$env:GH_TOKEN = $originalToken
