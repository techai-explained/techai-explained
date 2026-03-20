# TechAI Content Empire — Machine Bootstrap
# Install ONCE per machine. It self-updates from the repo.
# 
# One-time install:
#   1. Clone the repos
#   2. Run: powershell -File bootstrap.ps1 -Install
#   3. Done. Every future boot auto-syncs.

param(
    [switch]$Install  # First-time install flag
)

$ErrorActionPreference = "Continue"
$manifestRepo = "C:\Users\tamirdresher\source\repos\techai-explained"
$manifestPath = "$manifestRepo\pipeline\machine-manifest.json"
$logFile = "$env:TEMP\bootstrap-$(Get-Date -Format 'yyyy-MM-dd').log"

function Log($msg) {
    $ts = Get-Date -Format 'HH:mm:ss'
    "$ts  $msg" | Tee-Object -FilePath $logFile -Append
}

Log "=== Bootstrap starting ==="

# Step 1: Git pull all repos
Log "Pulling latest from all repos..."
$token = gh auth token --user tamirdresher 2>$null

$repos = @(
    "C:\Users\tamirdresher\source\repos\techai-explained",
    "C:\Users\tamirdresher\source\repos\content-empire",
    "C:\Users\tamirdresher\source\repos\jellybolt-games"
)

foreach ($repo in $repos) {
    if (Test-Path $repo) {
        Push-Location $repo
        git pull --quiet 2>$null
        $repoName = Split-Path $repo -Leaf
        Log "  Pulled: $repoName"
        Pop-Location
    }
}

# Step 2: Read manifest
if (-not (Test-Path $manifestPath)) {
    Log "ERROR: Manifest not found at $manifestPath"
    exit 1
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
Log "Manifest version: $($manifest.version), last updated: $($manifest.last_updated)"

# Step 3: Sync scheduled tasks
foreach ($task in $manifest.scheduled_tasks) {
    $existing = Get-ScheduledTask -TaskName $task.name -ErrorAction SilentlyContinue
    if (-not $existing) {
        Log "  Registering new task: $($task.name)"
        $repoPath = ($manifest.repos | Where-Object { $_.name -eq $task.repo }).path
        $scriptPath = Join-Path $repoPath $task.script
        
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        
        if ($task.trigger -eq "daily") {
            $trigger = New-ScheduledTaskTrigger -Daily -At $task.time
        } else {
            $trigger = New-ScheduledTaskTrigger -AtLogOn
        }
        
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $task.name -Action $action -Trigger $trigger `
            -Settings $settings -Description $task.description -ErrorAction SilentlyContinue
        Log "  Registered: $($task.name)"
    } else {
        Log "  Task exists: $($task.name) ($($existing.State))"
    }
}

# Step 4: Sync startup scripts
foreach ($startup in $manifest.startup_scripts) {
    $taskName = $startup.name
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if (-not $existing) {
        Log "  Registering startup task: $taskName"
        $repoPath = ($manifest.repos | Where-Object { $_.name -eq $startup.repo }).path
        $scriptPath = Join-Path $repoPath $startup.script
        
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Settings $settings -Description $startup.description -ErrorAction SilentlyContinue
        Log "  Registered: $taskName"
    }
}

# Step 5: Install Python deps
Log "Checking Python dependencies..."
foreach ($dep in $manifest.python_deps) {
    $installed = python -c "import $dep" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Log "  Installing: $dep"
        pip install $dep --quiet 2>$null
    }
}

# Step 6: Run catch-up (generate missed briefs)
$catchupScript = ($manifest.startup_scripts | Where-Object { $_.name -eq "TechAI-StartupCatchUp" })
if ($catchupScript) {
    $repoPath = ($manifest.repos | Where-Object { $_.name -eq $catchupScript.repo }).path
    $scriptPath = Join-Path $repoPath $catchupScript.script
    if (Test-Path $scriptPath) {
        Log "Running catch-up script..."
        & $scriptPath
    }
}

# Step 7: Launch Ralphs (read STATUS.md for context)
Log "Launching Ralphs..."
foreach ($ralph in $manifest.ralphs) {
    $repoPath = ($manifest.repos | Where-Object { $_.name -eq $ralph.repo }).path
    if (Test-Path $repoPath) {
        # Check if Ralph is already running for this repo
        $existing = Get-Process -Name "copilot" -ErrorAction SilentlyContinue | 
            Where-Object { $_.MainWindowTitle -eq $ralph.name }
        if (-not $existing) {
            Start-Process powershell -ArgumentList @(
                "-NoExit", "-Command", 
                "cd '$repoPath'; `$host.UI.RawUI.WindowTitle = '$($ralph.name)'; copilot -p '$($ralph.prompt)'"
            ) -WindowStyle Minimized
            Log "  Launched: $($ralph.name)"
        } else {
            Log "  Already running: $($ralph.name)"
        }
    }
}

# Step 8: First-time install — add bootstrap to Windows Startup folder
if ($Install) {
    Log "First-time install: Adding bootstrap to Startup folder..."
    $startupPath = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startupPath "ContentEmpire-Bootstrap.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$manifestRepo\pipeline\bootstrap.ps1`""
    $shortcut.WindowStyle = 7
    $shortcut.Save()
    Log "  Shortcut created: $shortcutPath"
    Log "Bootstrap installed! Will run automatically on every logon."
}

Log "=== Bootstrap complete ==="
