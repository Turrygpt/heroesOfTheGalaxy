## Настраивает Android SDK для текущего пользователя Godot и собирает тестовый APK.
param(
	[string]$SdkPath = "",
	[string]$JavaPath = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$godot = Join-Path $projectRoot "Godot_v4.7.1-stable_win64_console.exe"
if (-not (Test-Path -LiteralPath $godot)) {
	throw "Не найден Godot: $godot"
}

$sdkCandidates = @(
	$SdkPath,
	$env:ANDROID_HOME,
	$env:ANDROID_SDK_ROOT,
	(Join-Path $projectRoot "build\android-sdk"),
	(Join-Path $env:LOCALAPPDATA "Android\Sdk")
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$sdk = $null
foreach ($candidate in $sdkCandidates) {
	$resolved = [System.IO.Path]::GetFullPath($candidate)
	if ((Test-Path -LiteralPath (Join-Path $resolved "platform-tools\adb.exe")) -and
		(Test-Path -LiteralPath (Join-Path $resolved "build-tools"))) {
		$sdk = $resolved
		break
	}
}
if ($null -eq $sdk) {
	throw "Android SDK не найден. Проверьте build\android-sdk (platform-tools и build-tools) или передайте -SdkPath."
}
Write-Output "Android SDK: $sdk"
$buildTools = Get-ChildItem -LiteralPath (Join-Path $sdk "build-tools") -Directory |
	Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "apksigner.bat") } |
	Sort-Object Name -Descending | Select-Object -First 1
if ($null -eq $buildTools) {
	throw "В Android SDK отсутствует apksigner: $sdk"
}

if ([string]::IsNullOrWhiteSpace($JavaPath)) {
	$JavaPath = $env:JAVA_HOME
}
if (-not [string]::IsNullOrWhiteSpace($JavaPath)) {
	$JavaPath = [System.IO.Path]::GetFullPath($JavaPath)
	if (-not (Test-Path -LiteralPath (Join-Path $JavaPath "bin\java.exe"))) {
		throw "Не найден JDK по пути $JavaPath"
	}
}

$sharedTemplates = Join-Path $projectRoot "build\android-export-templates\4.7.1.stable"
$userTemplates = Join-Path $env:APPDATA "Godot\export_templates\4.7.1.stable"
if (-not (Test-Path -LiteralPath (Join-Path $userTemplates "android_debug.apk"))) {
	if (-not (Test-Path -LiteralPath (Join-Path $sharedTemplates "android_debug.apk"))) {
		throw "Не найдены шаблоны экспорта Android для Godot 4.7.1."
	}
	New-Item -ItemType Directory -Force -Path $userTemplates | Out-Null
	foreach ($name in @("android_debug.apk", "android_release.apk")) {
		$source = Join-Path $sharedTemplates $name
		if ((Test-Path -LiteralPath $source) -and
			-not (Test-Path -LiteralPath (Join-Path $userTemplates $name))) {
			Copy-Item -LiteralPath $source -Destination (Join-Path $userTemplates $name)
		}
	}
	Write-Output "Шаблоны экспорта установлены: $userTemplates"
}

$settingsPath = Join-Path $env:APPDATA "Godot\editor_settings-4.7.tres"
if (-not (Test-Path -LiteralPath $settingsPath)) {
	Push-Location $projectRoot
	try {
		& $godot --headless --path . --editor --quit | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "Godot не создал настройки редактора." }
	} finally {
		Pop-Location
	}
}
if (-not (Test-Path -LiteralPath $settingsPath)) {
	throw "Не найден файл настроек редактора: $settingsPath"
}

$lines = @(Get-Content -LiteralPath $settingsPath -Encoding UTF8)
$changed = $false
$entries = @{ "export/android/android_sdk_path" = $sdk }
if (-not [string]::IsNullOrWhiteSpace($JavaPath)) {
	$entries["export/android/java_sdk_path"] = $JavaPath
}
foreach ($key in $entries.Keys) {
	$value = $entries[$key].Replace("\", "/")
	$entry = "$key = `"$value`""
	$found = $false
	for ($index = 0; $index -lt $lines.Count; $index++) {
		if ($lines[$index] -match ("^" + [regex]::Escape($key) + "\s*=")) {
			$found = $true
			if ($lines[$index] -ne $entry) {
				$lines[$index] = $entry
				$changed = $true
			}
			break
		}
	}
	if (-not $found) {
		$lines += $entry
		$changed = $true
	}
}
if ($changed) {
	$backupPath = "$settingsPath.hotg-backup"
	if (-not (Test-Path -LiteralPath $backupPath)) {
		Copy-Item -LiteralPath $settingsPath -Destination $backupPath
	}
	[System.IO.File]::WriteAllLines($settingsPath, [string[]]$lines,
		[System.Text.UTF8Encoding]::new($false))
	Write-Output "Путь SDK в настройках Godot обновлён: $sdk"
}

$apk = Join-Path $projectRoot "build\android\HeroesOfTheGalaxy-0.12.0-debug.apk"
$debugKeystore = Join-Path $projectRoot "build\android-sdk\debug.keystore"
if (Test-Path -LiteralPath $debugKeystore) {
	$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $debugKeystore
	$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = "androiddebugkey"
	$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = "android"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $apk) | Out-Null
Push-Location $projectRoot
try {
	& $godot --headless --path . --export-debug Android $apk
	if ($LASTEXITCODE -ne 0) { throw "Экспорт Android завершился с ошибкой." }
} finally {
	Pop-Location
}
& (Join-Path $buildTools.FullName "apksigner.bat") verify $apk
if ($LASTEXITCODE -ne 0) { throw "Подпись APK не прошла проверку." }
Write-Output "Готово: $apk"
