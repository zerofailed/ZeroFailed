# <copyright file="_newExtensionLockEntry.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _newExtensionLockEntry {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('git', 'psrepository', 'path')]
        [string] $SourceType,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Source,

        [Parameter()]
        [AllowNull()]
        [string] $Requested,

        [Parameter()]
        [AllowNull()]
        [string] $RequiredBy
    )

    # Use a consistent key order, so the lock file is stable when it is serialized
    $entrySource = [ordered]@{ type = $SourceType }
    foreach ($key in ($Source.Keys | Sort-Object)) {
        $entrySource[$key] = $Source[$key]
    }

    $entry = [ordered]@{
        source = $entrySource
        requested = [string]::IsNullOrEmpty($Requested) ? $null : $Requested
        resolved = $null
        direct = [string]::IsNullOrEmpty($RequiredBy)
        requiredBy = [string]::IsNullOrEmpty($RequiredBy) ? @() : @($RequiredBy)
    }

    return $entry
}
