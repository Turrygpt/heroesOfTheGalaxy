## Отдельный Windows-exe демо с роликом и встроенными ресурсами.
param([switch]$SkipImport)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
Set-Location $projectPath
$engine = Get-ChildItem -LiteralPath $projectPath -Filter 'Godot_v*_console.exe' | Select-Object -First 1
if (-not $engine) { $engine = Get-ChildItem -LiteralPath $projectPath -Filter 'Godot_v*.exe' | Select-Object -First 1 }
if (-not $engine) { throw 'Движок Godot не найден.' }
if (-not (Test-Path -LiteralPath 'video/intro.ogv')) { throw 'Для демо нужен вступительный ролик video/intro.ogv.' }
$outputPath = Join-Path $projectPath 'build/demo'
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
if (-not $SkipImport) {
    & $engine.FullName --headless --path $projectPath --import
    if ($LASTEXITCODE -ne 0) { throw 'Ошибка импорта ресурсов.' }
}
$exePath = Join-Path $outputPath 'HeroesOfTheGalaxyDemo.exe'
& $engine.FullName --headless --path $projectPath --export-release 'Windows Demo' $exePath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) { throw 'Ошибка экспорта демо.' }
Copy-Item -LiteralPath (Join-Path $projectPath 'docs/demo_readme.txt') -Destination (Join-Path $outputPath 'ПРОЧТИ МЕНЯ.txt') -Force
$hash = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash
$revision = git rev-parse HEAD
@("Коммит: $revision", "SHA256: $hash", "Файл: HeroesOfTheGalaxyDemo.exe") | Set-Content -LiteralPath (Join-Path $outputPath 'build-info.txt') -Encoding utf8
Write-Output "Готово: $exePath"
