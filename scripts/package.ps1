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
    "duat_adapter.lua",
    "sparrow_adapter.lua",
    "check_lifecycle.lua",
    "runtime_state.lua",
    "run_report.lua",
    "logger.lua",
    "build_config.lua",
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

$temporaryRoot=Join-Path ([System.IO.Path]::GetTempPath()) ("ShellGame-package-"+[Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
    $variants=@(
        @{ Suffix=""; Developer=$false; OverlayLogging=$false },
        @{ Suffix="-dev"; Developer=$true; OverlayLogging=$true }
    )
    foreach ($variant in $variants) {
        $stageDirectory=Join-Path (Join-Path $temporaryRoot ("stage"+$variant.Suffix)) "ShellGame"
        New-Item -ItemType Directory -Force -Path $stageDirectory | Out-Null
        foreach ($file in $packageFiles) {
            Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $stageDirectory $file)
        }
        $developerValue=$variant.Developer.ToString().ToLowerInvariant()
        $loggingValue=$variant.OverlayLogging.ToString().ToLowerInvariant()
        [System.IO.File]::WriteAllText((Join-Path $stageDirectory "build_config.lua"),"return { developer_options=$developerValue, default_overlay_runtime_logs=$loggingValue }`n")
        $archiveName="Spelunky2-ShellGame-v$($manifest.version)$($variant.Suffix).zip"
        $archivePath=Join-Path $resolvedOutputDirectory $archiveName
        if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
        Compress-Archive -LiteralPath $stageDirectory -DestinationPath $archivePath -CompressionLevel Optimal
        Write-Host "Created $archivePath"
    }
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}
