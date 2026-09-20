## Headless-проверки Windows в отдельном профиле; игровые сохранения не трогаются.
param([string[]]$Filters = @(), [int]$TimeoutSeconds = 180)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
Set-Location $projectPath
$engine = Get-ChildItem -LiteralPath $projectPath -Filter 'Godot_v*.exe' | Select-Object -First 1
if (-not $engine) { throw 'Движок Godot не найден в корне проекта.' }
$logPath = Join-Path $projectPath ('build/test_runs/' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $logPath | Out-Null
$previousAppData = $env:APPDATA
$results = @()
try {
    foreach ($script in Get-ChildItem tools/test_*.gd,tools/*_regression.gd) {
        $name = $script.BaseName
        if ($Filters.Count -gt 0 -and -not ($Filters | Where-Object { $name.Contains($_) })) { continue }
        $env:APPDATA = Join-Path $logPath ('test_profile/' + $name)
        New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
        $outPath = Join-Path $logPath ($name + '.out')
        $errPath = Join-Path $logPath ($name + '.err')
        $engineArgs = @('--headless', '--path', '.', '--script', ('res://tools/' + $script.Name))
        if ($name -eq 'test_planet_turn_persistence') { $engineArgs = @('--headless', '--path', '.', 'res://tools/PlanetTurnPersistence.tscn') }
        $process = Start-Process -FilePath $engine.FullName -ArgumentList $engineArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        $timedOut = $false
        while (-not $process.WaitForExit(1000)) {
            $errors = [string](Get-Content -LiteralPath $errPath -Raw)
            $timedOut = (Get-Date) -gt $deadline
            if ($timedOut -or $errors -match 'SCRIPT ERROR:') {
                $process.Kill()
                $process.WaitForExit()
                break
            }
        }
        $process.WaitForExit()
        $process.Refresh()
        $exitCode = $process.ExitCode
        $errors = [string](Get-Content -LiteralPath $errPath -Raw)
        # push_error сам по себе не меняет код выхода Godot: читаем также журнал.
        $passed = $exitCode -eq 0 -and -not $timedOut -and $errors -notmatch 'SCRIPT ERROR:|(?m)^ERROR:'
        $results += [pscustomobject]@{ Test = $name; Passed = $passed; ExitCode = $exitCode; Timeout = $timedOut }
        Write-Output ("{0}: {1}" -f $name, $(if ($passed) { 'OK' } else { 'ОШИБКА' }))
        $results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logPath 'results.json') -Encoding utf8
    }
} finally {
    $env:APPDATA = $previousAppData
    if ($process -and -not $process.HasExited) { $process.Kill() }
}
$failed = @($results | Where-Object { -not $_.Passed })
Write-Output ("Проверок: {0}; ошибок: {1}. Журналы: {2}" -f $results.Count, $failed.Count, $logPath)
if ($failed.Count -gt 0) { exit 1 }
