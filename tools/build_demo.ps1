## Экспортирует демоверсию Windows и собирает установщик через Inno Setup.
param([switch]$SkipInstaller)

$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
Set-Location $projectPath

$engine = Get-ChildItem -LiteralPath $projectPath -Filter 'Godot_v*_console.exe' |
	Where-Object { $_.Length -gt 1MB } | Select-Object -First 1
if (-not $engine) {
	$engine = Get-ChildItem -LiteralPath $projectPath -Filter 'Godot_v*.exe' |
		Where-Object { $_.Length -gt 1MB } | Select-Object -First 1
}
if (-not $engine) { throw 'Движок Godot не найден в корне проекта.' }

$demoDir = Join-Path $projectPath 'build/demo'
New-Item -ItemType Directory -Force -Path $demoDir | Out-Null
$logDir = Join-Path $projectPath 'build/demo_logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Invoke-Godot([string[]]$GodotArguments, [string]$LogName) {
	$stdout = Join-Path $logDir ($LogName + '.out.log')
	$stderr = Join-Path $logDir ($LogName + '.err.log')
	$process = Start-Process -FilePath $engine.FullName -ArgumentList $GodotArguments `
		-WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
	if ($process.ExitCode -ne 0) {
		$details = [string](Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
		throw "Godot завершил этап '$LogName' с кодом $($process.ExitCode).`n$details"
	}
}

# После очистки .godot импортированные шрифты, изображения и Theora ещё не
# существуют. Редакторский проход восстанавливает их до начала экспорта.
Invoke-Godot @('--headless', '--editor', '--path', $projectPath, '--quit') 'import'
Invoke-Godot @('--headless', '--path', $projectPath, '--export-release', '"Windows Demo"') 'export'

$demoExe = Join-Path $demoDir 'HeroesOfTheGalaxyDemo.exe'
if (-not (Test-Path -LiteralPath $demoExe)) { throw 'Godot не создал исполняемый файл демоверсии.' }

if ($SkipInstaller) {
	Write-Output "Демоверсия: $demoExe"
	exit 0
}

$compilerCandidates = @(
	(Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'),
	(Join-Path $env:ProgramFiles 'Inno Setup 6/ISCC.exe'),
	(Join-Path $env:LOCALAPPDATA 'Programs/Inno Setup 6/ISCC.exe')
)
$compiler = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) { throw 'Inno Setup 6 не найден. Установите JRSoftware.InnoSetup через winget.' }

& $compiler (Join-Path $projectPath 'installer/HeroesOfTheGalaxyDemo.iss')
if ($LASTEXITCODE -ne 0) { throw "Сборка установщика завершилась с кодом $LASTEXITCODE." }

$setup = Join-Path $projectPath 'build/installer/HeroesOfTheGalaxyDemoSetup.exe'
if (-not (Test-Path -LiteralPath $setup)) { throw 'Inno Setup не создал установщик.' }
Write-Output "Установщик: $setup"
