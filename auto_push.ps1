# Auto Git Push Watcher for Company Analysis folder
$watchFolder = "d:\Finance\SelfDashboard\Company Analysis"
$debounceSeconds = 10  # Wait this long after last change before pushing

Write-Host "Watching: $watchFolder" -ForegroundColor Cyan
Write-Host "Auto-push enabled. Press Ctrl+C to stop." -ForegroundColor Cyan

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $watchFolder
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite

$timer = $null
$pendingPush = $false

function Push-Changes {
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Changes detected. Pushing to GitHub..." -ForegroundColor Yellow
    Set-Location $watchFolder

    $status = git status --porcelain
    if (-not $status) {
        Write-Host "No changes to push." -ForegroundColor Gray
        return
    }

    git add .
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    git commit -m "Auto-push: files updated at $timestamp"
    $result = git push 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushed successfully." -ForegroundColor Green
    } else {
        Write-Host "Push failed: $result" -ForegroundColor Red
    }
}

$action = {
    $global:pendingPush = $true
    if ($global:timer) { $global:timer.Stop() }
    $global:timer = New-Object System.Timers.Timer
    $global:timer.Interval = $debounceSeconds * 1000
    $global:timer.AutoReset = $false
    Register-ObjectEvent -InputObject $global:timer -EventName Elapsed -Action {
        Push-Changes
        $global:pendingPush = $false
    } | Out-Null
    $global:timer.Start()
}

Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Renamed" -Action $action | Out-Null

# Keep script running
while ($true) { Start-Sleep -Seconds 1 }
