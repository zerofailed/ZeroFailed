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
    return $lockedExtensions
}
