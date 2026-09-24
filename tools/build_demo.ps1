## Запрос «собрать демо» всегда выпускает версионный установщик.
[CmdletBinding()]
param(
    [string]$Version,
    [string]$GodotPath = $env:GODOT,
    [string]$IsccPath = $env:ISCC,
    [switch]$Portable
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build_release.ps1') -Edition Demo @PSBoundParameters
