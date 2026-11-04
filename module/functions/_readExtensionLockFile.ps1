# <copyright file="_readExtensionLockFile.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _readExtensionLockFile {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (!(Test-Path $Path)) {
        Write-Verbose "No extensions lock file found at '$Path'"
        return $null
    }

    try {
        $lock = Get-Content -Raw -Path $Path | ConvertFrom-Json -AsHashtable
    }
    catch {
        throw "The extensions lock file '$Path' is not valid JSON: $($_.Exception.Message)"
    }

    if ($lock -isnot [System.Collections.IDictionary] -or
        $lock['lockVersion'] -ne 1 -or
        ($null -ne $lock['extensions'] -and $lock['extensions'] -isnot [System.Collections.IDictionary])
    ) {
        throw "The extensions lock file '$Path' is not in a supported format (expected 'lockVersion' 1)"
    }

    # Return the locked extensions, keyed by name (which, as elsewhere, is not case-sensitive)
    $lockedExtensions = [ordered]@{}
    if ($null -ne $lock['extensions']) {
        foreach ($name in $lock['extensions'].Keys) {
            $lockedExtensions[$name] = $lock['extensions'][$name]
        }
    }

    # ZeroFailed 2.0.0 recorded the full path of a local extension. Make it relative to the lock file's folder, as it is
    # now recorded, so that a lock file written by that version still matches on the machine that wrote it.
    foreach ($entry in $lockedExtensions.Values) {
        if ($entry -is [System.Collections.IDictionary] -and
            $entry['source'] -is [System.Collections.IDictionary] -and
            $entry['source']['type'] -eq 'path' -and
            $entry['source']['path'] -and
            [IO.Path]::IsPathRooted($entry['source']['path'])
        ) {
            $entry['source']['path'] = _getExtensionLockPath -Path $entry['source']['path'] -BasePath (Split-Path -Parent $Path)
        }
    }

    # The content of an installed extension is checked against its content hash, so an extension from a git or
    # PowerShell repository must have one. Without it, the extension's content would not be checked at all.
    $namesWithoutHash = @($lockedExtensions.Keys | Where-Object {
        $entry = $lockedExtensions[$_]
        $entry -is [System.Collections.IDictionary] -and
            $entry['source'] -is [System.Collections.IDictionary] -and
            $entry['source']['type'] -in 'git', 'psrepository' -and
            !$entry['contentHash']
    })
    if ($namesWithoutHash.Count -gt 0) {
        throw ("The extensions lock file '$Path' has no content hash for: $($namesWithoutHash -join ', '). " +
               "Run with the lock mode set to 'Write' to record it.")
    }

    return $lockedExtensions
}
