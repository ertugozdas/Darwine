param(
    [string]$GodotBin = 'C:\Program Files (x86)\Godot Engine\Godot_v4.5-stable_win64_console.exe',
    [int]$Port = 0
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempBase = [System.IO.Path]::GetTempPath()
$tempDir = Join-Path $tempBase ('darwine-online-flow-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir | Out-Null
$hostLog = Join-Path $tempDir 'host.log'
$hostErr = Join-Path $tempDir 'host.err.log'
$clientLog = Join-Path $tempDir 'client.log'
$clientErr = Join-Path $tempDir 'client.err.log'
if ($Port -le 0) {
    $Port = Get-Random -Minimum 41200 -Maximum 41999
}
$hostProcess = $null
$clientProcess = $null

function Wait-Marker {
    param(
        [System.Diagnostics.Process]$Process,
        [string[]]$Paths,
        [string]$Marker,
        [int]$Seconds
    )
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        foreach ($path in $Paths) {
            if ((Test-Path -LiteralPath $path) -and (Select-String -LiteralPath $path -SimpleMatch $Marker -Quiet)) {
                return $true
            }
        }
        $Process.Refresh()
        if ($Process.HasExited) {
            return $false
        }
        Start-Sleep -Milliseconds 100
    }
    return $false
}

try {
    if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
        throw "Godot bulunamadı: $GodotBin"
    }
    $hostArguments = @(
        '--headless', '--path', $projectRoot, '--',
        '--smoke-host', '--smoke-online-flow', '--public-ip', '127.0.0.1',
        '--port', "$Port", '--secret', '24681357', '--ruleset', 'siege',
        '--match-name', 'Steam Full Support Smoke', '--card-pool', 'all_cards',
        '--turn-duration', '60', '--auto-attack', 'false', '--name', 'Host Commander'
    )
    $hostProcess = Start-Process -FilePath $GodotBin -ArgumentList $hostArguments `
        -WorkingDirectory $projectRoot -WindowStyle Hidden `
        -RedirectStandardOutput $hostLog -RedirectStandardError $hostErr -PassThru
    if (-not (Wait-Marker $hostProcess @($hostLog, $hostErr) 'DARWINE_HOST_INVITE_CODE=' 25)) {
        throw 'Host oda kodu üretmedi.'
    }
    $inviteLine = Select-String -LiteralPath $hostLog, $hostErr -Pattern '^DARWINE_HOST_INVITE_CODE=' |
        Select-Object -Last 1
    $inviteCode = ($inviteLine.Line -split '=', 2)[1].Trim()
    if ([string]::IsNullOrWhiteSpace($inviteCode)) {
        throw 'Davet kodu okunamadı.'
    }

    $clientArguments = @(
        '--headless', '--path', $projectRoot, '--',
        '--smoke-client', '--smoke-online-flow', '--invite', $inviteCode,
        '--name', 'Remote Commander'
    )
    $clientProcess = Start-Process -FilePath $GodotBin -ArgumentList $clientArguments `
        -WorkingDirectory $projectRoot -WindowStyle Hidden `
        -RedirectStandardOutput $clientLog -RedirectStandardError $clientErr -PassThru

    $checks = @(
        @($clientProcess, @($clientLog, $clientErr), 'NETWORK_RECONNECT_CLIENT_DROPPED', 50),
        @($hostProcess, @($hostLog, $hostErr), 'ONLINE_FLOW_TURN_HANDOFF_HOST', 8),
        @($clientProcess, @($clientLog, $clientErr), 'ONLINE_FLOW_TURN_HANDOFF_CLIENT', 8),
        @($hostProcess, @($hostLog, $hostErr), 'NETWORK_RECONNECT_SERVER_ACCEPTED player=2', 20),
        @($clientProcess, @($clientLog, $clientErr), 'NETWORK_RECONNECT_CLIENT_READY player=2', 20),
        @($hostProcess, @($hostLog, $hostErr), 'ONLINE_FLOW_REMATCH_SERVER_START generation=2', 20),
        @($clientProcess, @($clientLog, $clientErr), 'ONLINE_FLOW_REMATCH_CLIENT_READY generation=2', 25),
        @($hostProcess, @($hostLog, $hostErr), 'ONLINE_FLOW_REMATCH_HOST_READY generation=2', 12)
    )
    foreach ($check in $checks) {
        if (-not (Wait-Marker $check[0] $check[1] $check[2] $check[3])) {
            throw "İşaret bulunamadı: $($check[2])"
        }
    }
    $allLogs = (Get-Content -LiteralPath $hostLog, $hostErr, $clientLog, $clientErr -ErrorAction SilentlyContinue) -join [Environment]::NewLine
    if ($allLogs -match 'SCRIPT ERROR|Parse Error') {
        throw 'Godot günlüğünde script/parse hatası var.'
    }
    Write-Output "ONLINE_FLOW_POWERSHELL_OK invite=$inviteCode port=$Port"
}
catch {
    Write-Output "ONLINE_FLOW_POWERSHELL_FAILED: $($_.Exception.Message)"
    Get-Content -LiteralPath $hostLog, $hostErr, $clientLog, $clientErr -ErrorAction SilentlyContinue |
        Select-Object -First 500
    exit 1
}
finally {
    foreach ($process in @($clientProcess, $hostProcess)) {
        if ($null -eq $process) {
            continue
        }
        try {
            $process.Refresh()
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
            }
        }
        catch {
        }
    }
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempDir)
    $resolvedBase = [System.IO.Path]::GetFullPath($tempBase)
    if ($resolvedTemp.StartsWith($resolvedBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
