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

function Get-GitOutput {
    param([string[]]$Arguments)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required to stamp the build but was not found."
    }
    $ErrorActionPreference="Continue"
    $output=& git -C $projectRoot @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed; package from inside the repository."
    }
    return $output
}

$commit=([string](Get-GitOutput @("rev-parse","--verify","HEAD"))).Trim()
if ($commit -notmatch '^[0-9a-f]{40}$') {
    throw "Could not determine the commit SHA to stamp the build."
}
$dirty=[bool](Get-GitOutput @("status","--porcelain","--untracked-files=no"))

function ConvertTo-LuaString([string]$value) {
    return '"'+($value -replace '\\','\\' -replace '"','\"')+'"'
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
}

$temporaryRoot=Join-Path ([System.IO.Path]::GetTempPath()) ("ShellGame-package-"+[Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
    $variants=@(
        @{ Name="release"; Developer=$false; OverlayLogging=$false },
        @{ Name="dev"; Developer=$true; OverlayLogging=$true }
    )
    foreach ($variant in $variants) {
        $stageDirectory=Join-Path (Join-Path $temporaryRoot $variant.Name) "ShellGame"
        New-Item -ItemType Directory -Force -Path $stageDirectory | Out-Null
        foreach ($file in $packageFiles) {
            Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination (Join-Path $stageDirectory $file)
        }
        $developerValue=$variant.Developer.ToString().ToLowerInvariant()
        $loggingValue=$variant.OverlayLogging.ToString().ToLowerInvariant()
        $dirtyValue=$dirty.ToString().ToLowerInvariant()
        $build="{ commit=$(ConvertTo-LuaString $commit), dirty=$dirtyValue, version=$(ConvertTo-LuaString $manifest.version), variant=$(ConvertTo-LuaString $variant.Name) }"
        [System.IO.File]::WriteAllText((Join-Path $stageDirectory "build_config.lua"),"return { developer_options=$developerValue, default_overlay_runtime_logs=$loggingValue, build=$build }`n")
        $variantOutputDirectory=Join-Path $resolvedOutputDirectory $variant.Name
        New-Item -ItemType Directory -Force -Path $variantOutputDirectory | Out-Null
        $archivePath=Join-Path $variantOutputDirectory "ShellGame.zip"
        if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
        Compress-Archive -LiteralPath $stageDirectory -DestinationPath $archivePath -CompressionLevel Optimal
        Write-Host "Created $archivePath"
    }
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}
