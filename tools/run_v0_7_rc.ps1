[CmdletBinding()]
param(
    [string]$GodotExecutable = "",
    [string]$ManifestPath = "",
    [string]$ReportPath = "",
    [string[]]$GateId = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repositoryRoot "data\release\v0_7_rc_gates.json"
}
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $repositoryRoot "artifacts\v0_7_rc_report.json"
}

function Resolve-GodotExecutable {
    param([string]$RequestedPath)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $candidates.Add($RequestedPath)
    }
    $configuredPath = [Environment]::GetEnvironmentVariable("DARWINE_GODOT_TEST", "Process")
    if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
        $candidates.Add($configuredPath)
    }
    $candidates.Add((Join-Path $env:TEMP "darwine-godot-runtime\GodotTest.exe"))
    foreach ($commandName in @("godot4", "godot")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            $candidates.Add($command.Source)
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Godot test çalıştırıcısı bulunamadı. -GodotExecutable veya DARWINE_GODOT_TEST kullanın."
}

function Get-GateEnvironment {
    param([object]$Gate)

    $values = @{}
    $environmentProperty = $Gate.PSObject.Properties["environment"]
    if ($null -eq $environmentProperty) {
        return $values
    }
    foreach ($property in $environmentProperty.Value.PSObject.Properties) {
        $values[$property.Name] = [string]$property.Value
    }
    return $values
}

function Invoke-GodotGate {
    param(
        [string]$Executable,
        [string]$ProjectPath,
        [object]$Gate,
        [string[]]$ControlledEnvironmentNames,
        [string]$LogDirectory
    )

    $gateId = [string]$Gate.id
    $safeGateId = [regex]::Replace($gateId, "[^a-zA-Z0-9_-]", "_")
    $godotLogPath = Join-Path $LogDirectory "$safeGateId.godot.log"
    foreach ($path in @($godotLogPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    $startTime = [DateTime]::UtcNow
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $Executable
    $processInfo.WorkingDirectory = $ProjectPath
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    foreach ($argument in @(
        "--headless",
        "--path", $ProjectPath,
        "--log-file", $godotLogPath,
        "--script", [string]$Gate.test
    )) {
        [void]$processInfo.ArgumentList.Add($argument)
    }

    foreach ($name in $ControlledEnvironmentNames) {
        [void]$processInfo.Environment.Remove($name)
    }
    $gateEnvironment = Get-GateEnvironment -Gate $Gate
    foreach ($name in $gateEnvironment.Keys) {
        $processInfo.Environment[$name] = $gateEnvironment[$name]
    }

    $stdout = ""
    $stderr = ""
    $exitCode = -1
    $launchError = ""
    try {
        $process = [System.Diagnostics.Process]::Start($processInfo)
        if ($null -eq $process) {
            throw "Godot işlemi başlatılamadı."
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
        $process.Dispose()
    }
    catch {
        $launchError = $_.Exception.Message
    }
    $stopwatch.Stop()

    $godotLog = ""
    if (Test-Path -LiteralPath $godotLogPath) {
        $godotLog = Get-Content -LiteralPath $godotLogPath -Raw
    }
    $combinedOutput = @($stdout, $stderr, $godotLog, $launchError) -join "`n"
    $marker = [string]$Gate.marker
    $failedMarker = $marker -replace "_OK$", "_FAILED"
    $markerFound = $combinedOutput.Contains($marker)
    $failedMarkerFound = $combinedOutput.Contains($failedMarker)
    $passed = $markerFound -and -not $failedMarkerFound -and [string]::IsNullOrWhiteSpace($launchError)

    return [ordered]@{
        id = $gateId
        category = [string]$Gate.category
        test = [string]$Gate.test
        marker = $marker
        status = if ($passed) { "passed" } else { "failed" }
        marker_found = $markerFound
        failed_marker_found = $failedMarkerFound
        process_exit_code = $exitCode
        duration_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        started_at_utc = $startTime.ToString("o")
        log_path = $godotLogPath
        launch_error = $launchError
    }
}

$resolvedGodot = Resolve-GodotExecutable -RequestedPath $GodotExecutable
$resolvedManifest = (Resolve-Path -LiteralPath $ManifestPath).Path
$manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
if ([string]$manifest.execution -ne "sequential") {
    throw "RC manifesti sıralı çalışma sözleşmesini taşımıyor."
}
$selectedGates = @($manifest.gates)
if ($GateId.Count -gt 0) {
    $selectedGates = @($manifest.gates | Where-Object { [string]$_.id -in $GateId })
    $missingGateIds = @($GateId | Where-Object { $_ -notin @($selectedGates | ForEach-Object { [string]$_.id }) })
    if ($missingGateIds.Count -gt 0) {
        throw "Manifestte bulunmayan kapı: $($missingGateIds -join ', ')"
    }
}

$reportDirectory = Split-Path -Parent $ReportPath
$logDirectory = Join-Path $reportDirectory "v0_7_rc_logs"
[void](New-Item -ItemType Directory -Path $logDirectory -Force)

$controlledEnvironment = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($gate in $selectedGates) {
    $environmentProperty = $gate.PSObject.Properties["environment"]
    if ($null -eq $environmentProperty) {
        continue
    }
    foreach ($property in $environmentProperty.Value.PSObject.Properties) {
        [void]$controlledEnvironment.Add($property.Name)
    }
}

$suiteStart = [DateTime]::UtcNow
$results = [System.Collections.Generic.List[object]]::new()
$gateIndex = 0
foreach ($gate in $selectedGates) {
    $gateIndex += 1
    Write-Host ("[{0}/{1}] {2} ({3})" -f $gateIndex, $selectedGates.Count, $gate.id, $gate.category)
    $result = Invoke-GodotGate `
        -Executable $resolvedGodot `
        -ProjectPath $repositoryRoot `
        -Gate $gate `
        -ControlledEnvironmentNames @($controlledEnvironment) `
        -LogDirectory $logDirectory
    $results.Add($result)
    if ($result.status -eq "passed") {
        Write-Host ("  PASS {0}s" -f $result.duration_seconds) -ForegroundColor Green
    }
    else {
        Write-Host ("  FAIL {0}s -> {1}" -f $result.duration_seconds, $result.log_path) -ForegroundColor Red
    }
}

$passedCount = @($results | Where-Object status -eq "passed").Count
$failedCount = $results.Count - $passedCount
$report = [ordered]@{
    schema_version = 1
    release_version = [string]$manifest.release_version
    release_stage = [string]$manifest.release_stage
    execution = "sequential"
    started_at_utc = $suiteStart.ToString("o")
    finished_at_utc = [DateTime]::UtcNow.ToString("o")
    godot_executable = $resolvedGodot
    manifest_path = $resolvedManifest
    gate_count = $results.Count
    passed = $passedCount
    failed = $failedCount
    status = if ($failedCount -eq 0) { "passed" } else { "failed" }
    results = $results
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8

Write-Host ("RC sonucu: {0}/{1} kapı geçti. Rapor: {2}" -f $passedCount, $results.Count, $ReportPath)
if ($failedCount -gt 0) {
    exit 1
}
exit 0
