## Версионный дистрибутив Windows: отдельный PCK, проверка игры, Inno Setup и SHA256.
[CmdletBinding()]
param(
    [ValidateSet('Demo', 'Full')][string]$Edition = 'Demo',
    [string]$Version,
    [string]$GodotPath = $env:GODOT,
    [string]$IsccPath = $env:ISCC,
    [switch]$Portable
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$projectText = Get-Content (Join-Path $projectPath 'project.godot') -Raw -Encoding UTF8
if (-not $Version) {
    $Version = [regex]::Match($projectText, '(?m)^config/version="([^"]+)"').Groups[1].Value
}
if ($Version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
    throw 'Версия должна иметь вид 0.1.0 (три целых числа без суффиксов).'
}
foreach ($part in $Version.Split('.')) {
    if ([decimal]$part -gt 65535) { throw 'Компоненты версии Windows не могут превышать 65535.' }
}
if (-not $GodotPath) {
    $candidate = Get-ChildItem -LiteralPath $projectPath -Filter 'Godot_v*_console.exe' | Sort-Object Name -Descending | Select-Object -First 1
    if ($candidate) { $GodotPath = $candidate.FullName }
    else {
        $candidate = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { $GodotPath = $candidate.Source }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Укажите -GodotPath или переменную GODOT.' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
# Консольная обёртка порождает второй процесс. Headless запускаем напрямую,
# чтобы таймаут останавливал сам движок, а не оставлял его дочерний процесс.
if ($GodotPath.EndsWith('_console.exe', [StringComparison]::OrdinalIgnoreCase)) {
    $directEngine = $GodotPath.Substring(0, $GodotPath.Length - '_console.exe'.Length) + '.exe'
    if (Test-Path -LiteralPath $directEngine) { $GodotPath = $directEngine }
}
if (-not $IsccPath) {
    $candidates = @(
        (Join-Path $projectPath 'build/toolchain/inno/ISCC.exe'),
        "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe",
        "$env:LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe"
    )
    $compilerCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($compilerCommand) { $candidates += $compilerCommand.Source }
    $IsccPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $IsccPath -or -not (Test-Path -LiteralPath $IsccPath)) {
    throw 'Нужен Inno Setup 6. Установите с https://jrsoftware.org/isdl.php и укажите -IsccPath или ISCC.'
}
$IsccPath = (Resolve-Path -LiteralPath $IsccPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'video/intro.ogv'))) { throw 'В дистрибутиве обязателен video/intro.ogv.' }
$productId = if ($Edition -eq 'Demo') { 'HeroesOfTheGalaxyDemo' } else { 'HeroesOfTheGalaxy' }
$presetName = "Windows $Edition"
$releaseRoot = Join-Path $projectPath "build/releases/$($Edition.ToLowerInvariant())"
$releasePath = Join-Path $releaseRoot $Version
if (Test-Path -LiteralPath $releasePath) { throw "Версия уже собрана: $releasePath. Выберите новый номер или перенесите предыдущий дистрибутив." }

# Сборка идёт в отдельной копии: исходники и открытый редактор не меняются.
$workRoot = Join-Path $projectPath 'build/release-work'
$workPath = Join-Path $workRoot ([guid]::NewGuid().ToString('N'))
$stagePath = Join-Path $workPath 'project'
$resultPath = Join-Path $workPath 'result'
$payloadPath = Join-Path $resultPath 'game'
$logsPath = Join-Path $resultPath 'logs'
New-Item -ItemType Directory -Force -Path $stagePath, $payloadPath, $logsPath | Out-Null
# Редактор исходного проекта не должен импортировать временные копии и снимки.
New-Item -ItemType File -Force -Path (Join-Path $projectPath 'build/.gdignore') | Out-Null

function Invoke-CheckedProcess([string]$File, [string[]]$Arguments, [string]$LogName, [string]$WorkingDirectory = $stagePath, [int]$TimeoutSeconds = 1200) {
    $logPath = Join-Path $logsPath "$LogName.log"
    $errorPath = Join-Path $logsPath "$LogName.stderr.log"
    # Каждый аргумент экранируется отдельно по правилам командной строки Windows.
    $quoted = foreach ($argument in $Arguments) {
        '"' + [regex]::Replace([regex]::Replace($argument, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
    }
    Write-Host "Шаг: $LogName"
    $process = Start-Process -FilePath $File -ArgumentList ($quoted -join ' ') -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force
        throw "Шаг $LogName превысил $TimeoutSeconds секунд. Логи: $logsPath"
    }
    $process.Refresh()
    $output = (Get-Content $logPath, $errorPath -Raw -ErrorAction SilentlyContinue) -join "`n"
    if ($process.ExitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR:|ERROR:)') {
        throw "Ошибка шага $LogName (код $($process.ExitCode)). Логи: $logsPath`n$output"
    }
}

try {
    Write-Host "Сборка $Edition $Version"
    foreach ($directory in @('assets', 'data', 'music', 'scenes', 'scripts', 'shaders', 'video')) {
        Copy-Item -LiteralPath (Join-Path $projectPath $directory) -Destination $stagePath -Recurse
    }
    # Кэш ускоряет повторный импорт, но движок всё равно проверяет актуальность ресурсов.
    $sourceCache = Join-Path $projectPath '.godot'
    if (Test-Path -LiteralPath $sourceCache) {
        $stageCache = Join-Path $stagePath '.godot'
        New-Item -ItemType Directory -Path $stageCache | Out-Null
        foreach ($entry in @('imported', 'global_script_class_cache.cfg', 'uid_cache.bin')) {
            $cacheEntry = Join-Path $sourceCache $entry
            if (Test-Path -LiteralPath $cacheEntry) { Copy-Item -LiteralPath $cacheEntry -Destination $stageCache -Recurse }
        }
    }
    # Крупный арт в дистрибутиве использует WebP 90%; исходники и пиксельный UI не меняются.
    $textureProfile = Get-Content (Join-Path $PSScriptRoot 'installer/texture_profile.json') -Raw | ConvertFrom-Json
    $textureCount = 0
    foreach ($directory in $textureProfile.directories) {
        foreach ($import in Get-ChildItem -LiteralPath (Join-Path $stagePath $directory) -Filter '*.png.import' -Recurse) {
            $settings = [IO.File]::ReadAllText($import.FullName)
            # Специальные VRAM/несжатые режимы автора сохраняются.
            if ($settings -notmatch '(?m)^compress/mode=[01]\r?$') { continue }
            $settings = [regex]::Replace($settings, '(?m)^compress/mode=[01]', 'compress/mode=1')
            $quality = ([double]$textureProfile.quality).ToString([Globalization.CultureInfo]::InvariantCulture)
            $settings = [regex]::Replace($settings, '(?m)^compress/lossy_quality=[0-9.]+', ('compress/lossy_quality=' + $quality))
            [IO.File]::WriteAllText($import.FullName, $settings)
            # Без кэша редактора Godot не видит прежние параметры импорта.
            # Убираем только готовые текстуры из копии кэша, чтобы новый профиль применился.
            $importedRoot = [IO.Path]::GetFullPath((Join-Path $stagePath '.godot/imported')) + [IO.Path]::DirectorySeparatorChar
            foreach ($match in [regex]::Matches($settings, '"res://\.godot/imported/([^"]+)"')) {
                $cachedFile = [IO.Path]::GetFullPath((Join-Path $importedRoot $match.Groups[1].Value))
                if (-not $cachedFile.StartsWith($importedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Путь текстуры вышел за пределы кэша сборки.' }
                if (Test-Path -LiteralPath $cachedFile) { Remove-Item -LiteralPath $cachedFile -Force }
            }
            $textureCount++
        }
    }
    Write-Host "Компактный профиль арта: $textureCount текстур, качество $($textureProfile.quality)."
    $projectText = [regex]::Replace($projectText, '(?m)^config/version="[^"]*"', ('config/version="' + $Version + '"'))
    [IO.File]::WriteAllText((Join-Path $stagePath 'project.godot'), $projectText)
    $presets = Get-Content (Join-Path $projectPath 'export_presets.cfg') -Raw -Encoding UTF8
    # Поля PE меняются только в копии проекта; версия в меню берётся из project.godot.
    $presets = $presets.Replace('binary_format/embed_pck=false', "binary_format/embed_pck=false`napplication/file_version=`"$Version.0`"`napplication/product_version=`"$Version`"")
    [IO.File]::WriteAllText((Join-Path $stagePath 'export_presets.cfg'), $presets)
    Invoke-CheckedProcess $GodotPath @('--headless', '--path', $stagePath, '--import') 'import'
    $exePath = Join-Path $payloadPath "$productId.exe"
    $pckPath = Join-Path $payloadPath "$productId.pck"
    Invoke-CheckedProcess $GodotPath @('--headless', '--path', $stagePath, '--export-release', $presetName, $exePath) 'export'
    if (-not (Test-Path -LiteralPath $pckPath) -or (Get-Item $pckPath).Length -lt 1MB) { throw 'Экспорт не создал отдельный пакет ресурсов.' }
    if ((Get-Item $exePath).Length -gt 150MB) { throw 'Игровой exe больше 150 МиБ: проверьте встраивание PCK и шаблон экспорта.' }
    if ((Get-Item $exePath).VersionInfo.FileVersion.Trim() -ne "$Version.0") { throw 'Версия игрового exe не совпала с запрошенной.' }

    # Проверяем именно экспорт, из его каталога и в отдельном профиле сохранений.
    $savedAppData = $env:APPDATA
    $savedCheckProfile = $env:HOTG_DISTRIBUTION_CHECK_PROFILE
    try {
        $env:APPDATA = Join-Path $workPath 'test-profile'
        $env:HOTG_DISTRIBUTION_CHECK_PROFILE = $env:APPDATA
        New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
        Invoke-CheckedProcess $exePath @('--headless', '--', '--verify-distribution', $Version, $Edition) 'game-check' $payloadPath 180
        if (-not (Select-String -LiteralPath (Join-Path $logsPath 'game-check.log') -SimpleMatch 'Проверка дистрибутива: ошибок — 0' -Quiet)) { throw 'Игра не подтвердила завершение проверки.' }
    } finally {
        $env:APPDATA = $savedAppData
        $env:HOTG_DISTRIBUTION_CHECK_PROFILE = $savedCheckProfile
    }
    if ($Edition -eq 'Demo') {
        Copy-Item -LiteralPath (Join-Path $projectPath 'docs/demo_readme.txt') -Destination (Join-Path $payloadPath 'ПРОЧТИ МЕНЯ.txt')
    }
    $revision = (& git -C $projectPath rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Не удалось определить коммит сборки.' }
    $changes = @(& git -C $projectPath status --porcelain)
    $engineVersion = (& $GodotPath --version | Out-String).Trim()
    $compilerArguments = @("/DAppVersion=$Version", "/DEdition=$Edition", "/DPayloadDir=$payloadPath", "/DOutputDir=$resultPath", (Join-Path $PSScriptRoot 'installer/game.iss'))
    # PE-версия ISCC бывает 0.0.0.0; настоящая версия движка компилятора — в его логе.
    Invoke-CheckedProcess $IsccPath (@('/O-') + $compilerArguments) 'installer-preflight'
    $compilerLog = Get-Content (Join-Path $logsPath 'installer-preflight.log') -Raw
    $compilerVersion = [regex]::Match($compilerLog, 'Compiler engine version: Inno Setup ([0-9.]+)').Groups[1].Value
    if (-not $compilerVersion) { throw 'Не удалось определить версию Inno Setup.' }
    $info = [ordered]@{
        version = $Version; edition = $Edition; commit = $revision; dirty = ($changes.Count -gt 0)
        built_at_utc = [DateTime]::UtcNow.ToString('o'); godot = $engineVersion
        inno_setup = $compilerVersion
        textures = [ordered]@{ compression = 'WebP lossy'; quality = $textureProfile.quality; count = $textureCount; resized = $false }
        files = @(Get-ChildItem -LiteralPath $payloadPath -File | ForEach-Object {
            [ordered]@{ name = $_.Name; bytes = $_.Length; sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
        })
    }
    $info | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payloadPath 'build-info.json') -Encoding UTF8
    Invoke-CheckedProcess $IsccPath $compilerArguments 'installer'
    $setupPath = Join-Path $resultPath "$productId-$Version-windows-x64-setup.exe"
    if (-not (Test-Path -LiteralPath $setupPath)) { throw 'Компилятор не создал установщик.' }
    if ((Get-Item $setupPath).Length -gt 300MB) { throw 'Установщик больше 300 МиБ: проверьте состав ресурсов перед выпуском.' }
    if ((Get-Item $setupPath).VersionInfo.FileVersion.Trim() -ne "$Version.0") { throw 'Версия установщика не совпала с запрошенной.' }
    if ($Portable) {
        Compress-Archive -Path (Join-Path $payloadPath '*') -DestinationPath (Join-Path $resultPath "$productId-$Version-windows-x64-portable.zip") -CompressionLevel Optimal
    }
    Get-ChildItem -LiteralPath $resultPath -File | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | ForEach-Object {
        '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
    } | Set-Content -LiteralPath (Join-Path $resultPath 'SHA256SUMS.txt') -Encoding ASCII
    New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
    # Обе операции ограничены build/: проверяем абсолютные пути до переноса и очистки.
    $buildRoot = [IO.Path]::GetFullPath((Join-Path $projectPath 'build')) + [IO.Path]::DirectorySeparatorChar
    foreach ($target in @($resultPath, $releasePath, $workPath)) {
        if (-not [IO.Path]::GetFullPath($target).StartsWith($buildRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Путь сборки вышел за пределы build/.' }
    }
    # Directory.Move отказывает при существующем назначении, включая параллельный выпуск.
    [IO.Directory]::Move($resultPath, $releasePath)
    Remove-Item -LiteralPath $workPath -Recurse -Force
    Write-Host "Готов дистрибутив: $releasePath"
    Get-ChildItem -LiteralPath $releasePath -File | Select-Object Name, @{Name = 'МиБ'; Expression = { [math]::Round($_.Length / 1MB, 2) }}
} catch {
    Write-Host "Незавершённая сборка сохранена для диагностики: $workPath"
    throw
}
