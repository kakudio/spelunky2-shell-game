[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot "dist"
}
$manifestPath = Join-Path $projectRoot "mod.json"
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json

# Keep this explicit: only files needed by Playlunky belong in a release archive.
$packageFiles = @(
    "main.lua",
    "logic.lua",
    "checks.lua",
    "placements.lua",
    "replacement_policy.lua",
    "adapters.lua",
    "check_lifecycle.lua",
    "runtime_state.lua",
    "tests.lua",
    "mod.json"
)

foreach ($file in $packageFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $file) -PathType Leaf)) {
        throw "Required package file is missing: $file"
    }
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
}
New-Item -ItemType Directory -Force -Path $resolvedOutputDirectory | Out-Null

$archiveName = "KeyItemRandomizer-v$($manifest.version).zip"
$archivePath = Join-Path $resolvedOutputDirectory $archiveName
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

$sourcePaths = $packageFiles | ForEach-Object { Join-Path $projectRoot $_ }
Compress-Archive -LiteralPath $sourcePaths -DestinationPath $archivePath -CompressionLevel Optimal
Write-Host "Created $archivePath"
