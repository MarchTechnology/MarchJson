# MarchJson
# JSON-aware selective wrappers for PowerShell 7.
# Source this file after FNM/Node initialization.

$script:MarchJsonRoot = Split-Path -Parent $PSScriptRoot
$script:MarchJsonVersionFile = Join-Path $script:MarchJsonRoot 'VERSION'

function Get-MarchJsonVersion {
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($env:MARCHJSON_VERSION_OVERRIDE)) {
        return $env:MARCHJSON_VERSION_OVERRIDE.Trim()
    }

    if (Test-Path -LiteralPath $script:MarchJsonVersionFile) {
        $version = (Get-Content -LiteralPath $script:MarchJsonVersionFile -Raw).Trim()

        $semVerPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\z'

        if ($version -match $semVerPattern) {
            return $version
        }
    }

    return '0.0.0-dev'
}
if ([string]::IsNullOrWhiteSpace($env:MARCHJSON_NPM_WHITELIST)) {
    $script:MarchJsonNpmWhitelistFile = "$HOME\.config\powershell\json-npm-whitelist.txt"
}
else {
    $script:MarchJsonNpmWhitelistFile = $env:MARCHJSON_NPM_WHITELIST
}

function Resolve-MarchNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $command = Get-Command $Name -CommandType Application -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -and (Test-Path -LiteralPath $_.Source) } |
        Select-Object -First 1

    if (-not $command) {
        throw "Native command '$Name' was not found."
    }

    return [string]$command.Source
}

function Test-MarchJson {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $trimmed = $Text.Trim()

    $looksLikeJson = (($trimmed.StartsWith('{') -and $trimmed.EndsWith('}')) -or ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')))

    if (-not $looksLikeJson) {
        return $false
    }

    try {
        $null = $trimmed | ConvertFrom-Json -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Format-MarchJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    try {
        $jqExe = Resolve-MarchNativeCommand 'jq.exe'
    }
    catch {
        $jqExe = $null
    }

    if ($jqExe) {
        $Text | & $jqExe -C '.'
        return
    }

    $Text | ConvertFrom-Json -ErrorAction Stop | ConvertTo-Json -Depth 100
}

function Invoke-MarchJsonAwareNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter()]
        [object[]]$ArgumentList = @(),

        [Parameter()]
        [switch]$MergeStdErr
    )

    if ($MergeStdErr) {
        $output = @(& $FilePath @ArgumentList 2>&1)
    }
    else {
        $output = @(& $FilePath @ArgumentList)
    }

    $nativeExitCode = $LASTEXITCODE

    if ($output.Count -eq 0) {
        $global:LASTEXITCODE = $nativeExitCode
        return
    }

    $lines = @($output | ForEach-Object { [string]$_ })
    $wholeOutput = $lines -join [Environment]::NewLine

    if (Test-MarchJson -Text $wholeOutput) {
        Format-MarchJson -Text $wholeOutput
        $global:LASTEXITCODE = $nativeExitCode
        return
    }

    foreach ($line in $lines) {
        if (Test-MarchJson -Text $line) {
            Format-MarchJson -Text $line
        }
        else {
            $line
        }
    }

    $global:LASTEXITCODE = $nativeExitCode
}

function Get-MarchJsonNpmScript {
    if (-not (Test-Path -LiteralPath $script:MarchJsonNpmWhitelistFile)) {
        return
    }

    Get-Content -LiteralPath $script:MarchJsonNpmWhitelistFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') } |
        Sort-Object -Unique
}

function Test-MarchJsonNpmEnabled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $Name -in @(Get-MarchJsonNpmScript)
}

function Add-MarchJsonNpmScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Name = $Name.Trim()

    if ($Name -in @(Get-MarchJsonNpmScript)) {
        Write-Host "Already whitelisted: $Name"
        return
    }

    $directory = Split-Path $script:MarchJsonNpmWhitelistFile -Parent
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Add-Content -LiteralPath $script:MarchJsonNpmWhitelistFile -Value $Name -Encoding utf8

    Write-Host "Added JSON-aware npm script: $Name"
}

function Remove-MarchJsonNpmScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Name = $Name.Trim()

    if ($Name -notin @(Get-MarchJsonNpmScript)) {
        Write-Host "Not whitelisted: $Name"
        return
    }

    $lines = @(Get-Content -LiteralPath $script:MarchJsonNpmWhitelistFile)
    $updated = @($lines | Where-Object { $_.Trim() -ne $Name })
    $updated | Set-Content -LiteralPath $script:MarchJsonNpmWhitelistFile -Encoding utf8

    Write-Host "Removed JSON-aware npm script: $Name"
}

function Edit-MarchJsonNpmWhitelist {
    $directory = Split-Path $script:MarchJsonNpmWhitelistFile -Parent
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $script:MarchJsonNpmWhitelistFile)) {
        New-Item -ItemType File -Path $script:MarchJsonNpmWhitelistFile -Force | Out-Null
    }

    if (Get-Command notepad.exe -ErrorAction SilentlyContinue) {
        & notepad.exe $script:MarchJsonNpmWhitelistFile
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($env:EDITOR)) {
        & $env:EDITOR $script:MarchJsonNpmWhitelistFile
        return
    }

    throw 'No editor was found. Set $env:EDITOR or edit the whitelist file manually.'
}

function global:curl {
    $curlExe = Resolve-MarchNativeCommand 'curl.exe'

    $fileMode = @($args | Where-Object { [string]$_ -match '^(?:-o|-O|-T|--output(?:=|$)|--remote-name$|--upload-file(?:=|$))' }).Count -gt 0

    if ($fileMode) {
        & $curlExe @args
        return
    }

    Invoke-MarchJsonAwareNative -FilePath $curlExe -ArgumentList @($args)
}

function global:node {
    $nodeExe = Resolve-MarchNativeCommand 'node.exe'
    $useJsonWrapper = $args.Count -ge 2 -and $args[0] -in @('-e', '--eval')

    if ($useJsonWrapper) {
        Invoke-MarchJsonAwareNative -FilePath $nodeExe -ArgumentList @($args) -MergeStdErr
        return
    }

    & $nodeExe @args
}

function global:npm {
    $npmCmd = Resolve-MarchNativeCommand 'npm.cmd'
    $useJsonWrapper = $args.Count -ge 2 -and $args[0] -eq 'run' -and (Test-MarchJsonNpmEnabled -Name ([string]$args[1]))

    if ($useJsonWrapper) {
        Invoke-MarchJsonAwareNative -FilePath $npmCmd -ArgumentList @($args) -MergeStdErr
        return
    }

    & $npmCmd @args
}

function global:MarchJson {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command = 'help',

        [Parameter(Position = 1)]
        [string]$Value,

        [Alias('h')]
        [switch]$Help,

        [Alias('v')]
        [switch]$Version
    )

    function Show-MarchJsonHelp {
        @"
MarchJson $(Get-MarchJsonVersion) - JSON-aware wrapper manager

Usage:
  MarchJson -h
  MarchJson h | help | ?
  MarchJson s | status
  MarchJson l | list
  MarchJson a | add <npm-script>
  MarchJson r | remove <npm-script>
  MarchJson e | edit
  MarchJson rl | reload
  MarchJson -v
  MarchJson v | version

Wrappers:
  curl       JSON-aware
  npm        JSON-aware for whitelisted npm scripts
  node -e    JSON-aware

Bypass:
  curl.exe ...
  npm.cmd ...
  node.exe ...

Whitelist:
  $script:MarchJsonNpmWhitelistFile
"@
    }

    if ($Help) {
        Show-MarchJsonHelp
        return
    }

    if ($Version) {
        Write-Host "MarchJson $(Get-MarchJsonVersion)"
        return
    }

    switch ($Command.ToLowerInvariant()) {
        { $_ -in @('h', 'help', '?') } {
            Show-MarchJsonHelp
            return
        }

        { $_ -in @('v', 'version') } {
            Write-Host "MarchJson $(Get-MarchJsonVersion)"
            return
        }

        { $_ -in @('s', 'status') } {
            Write-Host "MarchJson:"
            Write-Host "  Version: $(Get-MarchJsonVersion)"
            Write-Host "  Version file: $script:MarchJsonVersionFile"
            Write-Host ""
            Write-Host "Whitelist file:"
            Write-Host "  $script:MarchJsonNpmWhitelistFile"
            Write-Host ""
            Write-Host "Wrappers:"

            foreach ($name in 'curl', 'npm', 'node') {
                $cmd = Get-Command $name -ErrorAction SilentlyContinue

                if ($cmd) {
                    Write-Host ("  {0,-6} {1}" -f $name, $cmd.CommandType)
                }
                else {
                    Write-Host ("  {0,-6} NOT FOUND" -f $name)
                }
            }

            Write-Host ""
            Write-Host "Native executables:"

            foreach ($name in 'curl.exe', 'npm.cmd', 'node.exe', 'jq.exe') {
                try {
                    $path = Resolve-MarchNativeCommand $name
                    Write-Host ("  {0,-8} {1}" -f $name, $path)
                }
                catch {
                    Write-Host ("  {0,-8} NOT FOUND" -f $name)
                }
            }

            Write-Host ""
            Write-Host "Whitelist:"
            $scripts = @(Get-MarchJsonNpmScript)

            if ($scripts.Count -eq 0) {
                Write-Host "  (empty)"
            }
            else {
                foreach ($scriptName in $scripts) {
                    Write-Host "  $scriptName"
                }
            }

            return
        }

        { $_ -in @('l', 'list') } {
            Get-MarchJsonNpmScript
            return
        }

        { $_ -in @('a', 'add') } {
            if ([string]::IsNullOrWhiteSpace($Value)) {
                Write-Error 'Usage: MarchJson add <npm-script>'
                Write-Host 'Short form: MarchJson a <npm-script>'
                return
            }

            Add-MarchJsonNpmScript $Value
            return
        }

        { $_ -in @('r', 'remove') } {
            if ([string]::IsNullOrWhiteSpace($Value)) {
                Write-Error 'Usage: MarchJson remove <npm-script>'
                Write-Host 'Short form: MarchJson r <npm-script>'
                return
            }

            Remove-MarchJsonNpmScript $Value
            return
        }

        { $_ -in @('e', 'edit') } {
            Edit-MarchJsonNpmWhitelist
            return
        }

        { $_ -in @('rl', 'reload') } {
            Write-Host 'Whitelist is read dynamically; no reload is required.'
            return
        }

        default {
            Write-Error "Unknown command: $Command"
            Write-Host 'Run: MarchJson -h'
            return
        }
    }
}
) {
            return $version
        }
    }

    return '0.0.0-dev'
}

if ([string]::IsNullOrWhiteSpace($env:MARCHJSON_NPM_WHITELIST)) {
    $script:MarchJsonNpmWhitelistFile = "$HOME\.config\powershell\json-npm-whitelist.txt"
}
else {
    $script:MarchJsonNpmWhitelistFile = $env:MARCHJSON_NPM_WHITELIST
}

function Resolve-MarchNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $command = Get-Command $Name -CommandType Application -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -and (Test-Path -LiteralPath $_.Source) } |
        Select-Object -First 1

    if (-not $command) {
        throw "Native command '$Name' was not found."
    }

    return [string]$command.Source
}

function Test-MarchJson {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $trimmed = $Text.Trim()

    $looksLikeJson = (($trimmed.StartsWith('{') -and $trimmed.EndsWith('}')) -or ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']')))

    if (-not $looksLikeJson) {
        return $false
    }

    try {
        $null = $trimmed | ConvertFrom-Json -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Format-MarchJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    try {
        $jqExe = Resolve-MarchNativeCommand 'jq.exe'
    }
    catch {
        $jqExe = $null
    }

    if ($jqExe) {
        $Text | & $jqExe -C '.'
        return
    }

    $Text | ConvertFrom-Json -ErrorAction Stop | ConvertTo-Json -Depth 100
}

function Invoke-MarchJsonAwareNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter()]
        [object[]]$ArgumentList = @(),

        [Parameter()]
        [switch]$MergeStdErr
    )

    if ($MergeStdErr) {
        $output = @(& $FilePath @ArgumentList 2>&1)
    }
    else {
        $output = @(& $FilePath @ArgumentList)
    }

    $nativeExitCode = $LASTEXITCODE

    if ($output.Count -eq 0) {
        $global:LASTEXITCODE = $nativeExitCode
        return
    }

    $lines = @($output | ForEach-Object { [string]$_ })
    $wholeOutput = $lines -join [Environment]::NewLine

    if (Test-MarchJson -Text $wholeOutput) {
        Format-MarchJson -Text $wholeOutput
        $global:LASTEXITCODE = $nativeExitCode
        return
    }

    foreach ($line in $lines) {
        if (Test-MarchJson -Text $line) {
            Format-MarchJson -Text $line
        }
        else {
            $line
        }
    }

    $global:LASTEXITCODE = $nativeExitCode
}

function Get-MarchJsonNpmScript {
    if (-not (Test-Path -LiteralPath $script:MarchJsonNpmWhitelistFile)) {
        return
    }

    Get-Content -LiteralPath $script:MarchJsonNpmWhitelistFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') } |
        Sort-Object -Unique
}

function Test-MarchJsonNpmEnabled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $Name -in @(Get-MarchJsonNpmScript)
}

function Add-MarchJsonNpmScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Name = $Name.Trim()

    if ($Name -in @(Get-MarchJsonNpmScript)) {
        Write-Host "Already whitelisted: $Name"
        return
    }

    $directory = Split-Path $script:MarchJsonNpmWhitelistFile -Parent
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    Add-Content -LiteralPath $script:MarchJsonNpmWhitelistFile -Value $Name -Encoding utf8

    Write-Host "Added JSON-aware npm script: $Name"
}

function Remove-MarchJsonNpmScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Name = $Name.Trim()

    if ($Name -notin @(Get-MarchJsonNpmScript)) {
        Write-Host "Not whitelisted: $Name"
        return
    }

    $lines = @(Get-Content -LiteralPath $script:MarchJsonNpmWhitelistFile)
    $updated = @($lines | Where-Object { $_.Trim() -ne $Name })
    $updated | Set-Content -LiteralPath $script:MarchJsonNpmWhitelistFile -Encoding utf8

    Write-Host "Removed JSON-aware npm script: $Name"
}

function Edit-MarchJsonNpmWhitelist {
    $directory = Split-Path $script:MarchJsonNpmWhitelistFile -Parent
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $script:MarchJsonNpmWhitelistFile)) {
        New-Item -ItemType File -Path $script:MarchJsonNpmWhitelistFile -Force | Out-Null
    }

    if (Get-Command notepad.exe -ErrorAction SilentlyContinue) {
        & notepad.exe $script:MarchJsonNpmWhitelistFile
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($env:EDITOR)) {
        & $env:EDITOR $script:MarchJsonNpmWhitelistFile
        return
    }

    throw 'No editor was found. Set $env:EDITOR or edit the whitelist file manually.'
}

function global:curl {
    $curlExe = Resolve-MarchNativeCommand 'curl.exe'

    $fileMode = @($args | Where-Object { [string]$_ -match '^(?:-o|-O|-T|--output(?:=|$)|--remote-name$|--upload-file(?:=|$))' }).Count -gt 0

    if ($fileMode) {
        & $curlExe @args
        return
    }

    Invoke-MarchJsonAwareNative -FilePath $curlExe -ArgumentList @($args)
}

function global:node {
    $nodeExe = Resolve-MarchNativeCommand 'node.exe'
    $useJsonWrapper = $args.Count -ge 2 -and $args[0] -in @('-e', '--eval')

    if ($useJsonWrapper) {
        Invoke-MarchJsonAwareNative -FilePath $nodeExe -ArgumentList @($args) -MergeStdErr
        return
    }

    & $nodeExe @args
}

function global:npm {
    $npmCmd = Resolve-MarchNativeCommand 'npm.cmd'
    $useJsonWrapper = $args.Count -ge 2 -and $args[0] -eq 'run' -and (Test-MarchJsonNpmEnabled -Name ([string]$args[1]))

    if ($useJsonWrapper) {
        Invoke-MarchJsonAwareNative -FilePath $npmCmd -ArgumentList @($args) -MergeStdErr
        return
    }

    & $npmCmd @args
}

function global:MarchJson {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command = 'help',

        [Parameter(Position = 1)]
        [string]$Value,

        [Alias('h')]
        [switch]$Help
    )

    function Show-MarchJsonHelp {
        @"
MarchJson $script:MarchJsonVersion - JSON-aware wrapper manager

Usage:
  MarchJson -h
  MarchJson h | help | ?
  MarchJson s | status
  MarchJson l | list
  MarchJson a | add <npm-script>
  MarchJson r | remove <npm-script>
  MarchJson e | edit
  MarchJson rl | reload
  MarchJson v | version

Wrappers:
  curl       JSON-aware
  npm        JSON-aware for whitelisted npm scripts
  node -e    JSON-aware

Bypass:
  curl.exe ...
  npm.cmd ...
  node.exe ...

Whitelist:
  $script:MarchJsonNpmWhitelistFile
"@
    }

    if ($Help) {
        Show-MarchJsonHelp
        return
    }

    switch ($Command.ToLowerInvariant()) {
        { $_ -in @('h', 'help', '?') } {
            Show-MarchJsonHelp
            return
        }

        { $_ -in @('v', 'version') } {
            Write-Host "MarchJson $script:MarchJsonVersion"
            return
        }

        { $_ -in @('s', 'status') } {
            Write-Host "MarchJson:"
            Write-Host "  Version: $script:MarchJsonVersion"
            Write-Host ""
            Write-Host "Whitelist file:"
            Write-Host "  $script:MarchJsonNpmWhitelistFile"
            Write-Host ""
            Write-Host "Wrappers:"

            foreach ($name in 'curl', 'npm', 'node') {
                $cmd = Get-Command $name -ErrorAction SilentlyContinue

                if ($cmd) {
                    Write-Host ("  {0,-6} {1}" -f $name, $cmd.CommandType)
                }
                else {
                    Write-Host ("  {0,-6} NOT FOUND" -f $name)
                }
            }

            Write-Host ""
            Write-Host "Native executables:"

            foreach ($name in 'curl.exe', 'npm.cmd', 'node.exe', 'jq.exe') {
                try {
                    $path = Resolve-MarchNativeCommand $name
                    Write-Host ("  {0,-8} {1}" -f $name, $path)
                }
                catch {
                    Write-Host ("  {0,-8} NOT FOUND" -f $name)
                }
            }

            Write-Host ""
            Write-Host "Whitelist:"
            $scripts = @(Get-MarchJsonNpmScript)

            if ($scripts.Count -eq 0) {
                Write-Host "  (empty)"
            }
            else {
                foreach ($scriptName in $scripts) {
                    Write-Host "  $scriptName"
                }
            }

            return
        }

        { $_ -in @('l', 'list') } {
            Get-MarchJsonNpmScript
            return
        }

        { $_ -in @('a', 'add') } {
            if ([string]::IsNullOrWhiteSpace($Value)) {
                Write-Error 'Usage: MarchJson add <npm-script>'
                Write-Host 'Short form: MarchJson a <npm-script>'
                return
            }

            Add-MarchJsonNpmScript $Value
            return
        }

        { $_ -in @('r', 'remove') } {
            if ([string]::IsNullOrWhiteSpace($Value)) {
                Write-Error 'Usage: MarchJson remove <npm-script>'
                Write-Host 'Short form: MarchJson r <npm-script>'
                return
            }

            Remove-MarchJsonNpmScript $Value
            return
        }

        { $_ -in @('e', 'edit') } {
            Edit-MarchJsonNpmWhitelist
            return
        }

        { $_ -in @('rl', 'reload') } {
            Write-Host 'Whitelist is read dynamically; no reload is required.'
            return
        }

        default {
            Write-Error "Unknown command: $Command"
            Write-Host 'Run: MarchJson -h'
            return
        }
    }
}
