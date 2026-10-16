# <copyright file="_writeExtensionLockFile.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _writeExtensionLockFile {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    $lock = [ordered]@{
        lockVersion = 1
        extensions = _getExtensionLockEntries -Extensions $Extensions
    }

    # Always use LF line endings, so the file is the same whichever platform wrote it
    $json = ($lock | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"

    $lockFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (Test-Path $lockFilePath) {
        # Avoid touching the file when nothing has changed, ignoring line endings changed by a git checkout
        $existingJson = [IO.File]::ReadAllText($lockFilePath).Replace("`r`n", "`n")
        if ($existingJson -ceq $json) {
            Write-Verbose "Extensions lock file '$lockFilePath' is up to date"
            return
        }
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $lockFilePath) -Force | Out-Null
    [IO.File]::WriteAllText($lockFilePath, $json, [Text.UTF8Encoding]::new($false))
    Write-Host "Updated extensions lock file: $lockFilePath" -f Cyan
}
