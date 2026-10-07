param(
    [Parameter(Position = 0)]
    [string]$Version,

    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    @'
Usage:
  pwsh scripts/set-version.ps1 <semver>

Examples:
  pwsh scripts/set-version.ps1 0.2.1
  pwsh scripts/set-version.ps1 0.3.0
  pwsh scripts/set-version.ps1 1.0.0
'@
}

if ($Help -or [string]::IsNullOrWhiteSpace($Version)) {
    Show-Usage

    if ($Help) {
        exit 0
    }

    exit 1
}

$semVerPattern =
    '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)' +
    '(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'

if ($Version -notmatch $semVerPattern) {
    Write-Error "Invalid SemVer: $Version"
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
$versionFile = Join-Path $root 'VERSION'

Set-Content -LiteralPath $versionFile -Value $Version -Encoding utf8NoBOM

Write-Host "MarchJson version set to $Version"
Write-Host 'Next: update CHANGELOG.md, run the version acceptance, then commit/tag the release.'
