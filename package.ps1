param(
    [string]$Version = "",
    [string]$ProjectName = "RotationTracker"
)

$AddonRoot = Split-Path -Parent $PSCommandPath
$OutDir = Join-Path $AddonRoot "dist"
$StagingDir = Join-Path $AddonRoot ".release_staging"

if (!(Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}
if (Test-Path $StagingDir) {
    Remove-Item $StagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $StagingDir | Out-Null

function Read-TocValue {
    param([string]$Key)
    $pattern = "^\s*##\s*${Key}:\s*(?<value>.+)$"
    $tocPath = Join-Path $AddonRoot "RotationTracker.toc"
    if (!(Test-Path $tocPath)) {
        return $null
    }
    foreach ($line in Get-Content $tocPath) {
        if ($line -match $pattern) {
            return $matches["value"].Trim()
        }
    }
    return $null
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Read-TocValue -Key "Version"
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    Write-Error "Could not determine version. Add '## Version: X.Y.Z' to RotationTracker.toc or pass -Version."
    exit 1
}

$packageFiles = @(
    "RotationTracker.toc",
    "RotationTracker.lua",
    "README.md",
    "CHANGELOG.md"
)

$packageDirs = @(
    "Assets",
    "assets",
    "media",
    "lib"
)

foreach ($file in $packageFiles) {
    $source = Join-Path $AddonRoot $file
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $StagingDir -Force
    }
}

foreach ($dir in $packageDirs) {
    $source = Join-Path $AddonRoot $dir
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $StagingDir -Recurse -Force
    }
}

$ZipPath = Join-Path $OutDir "$ProjectName-$Version.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $StagingDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Host "Created: $ZipPath"
Write-Host "Version: $Version"
