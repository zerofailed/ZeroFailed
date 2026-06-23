# <copyright file="Resolve-ExtensionDuplicates.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<#
.SYNOPSIS
Removes duplicate extension references, keeping the first one found.

.DESCRIPTION
It is common for a low-level extension to be referenced by more than one higher-level
extension (e.g. as a shared dependency). When the resolved extension list contains
multiple references to the same extension 'Name', this function removes the duplicates,
keeping the first one found.

A warning is only logged when the duplicate references resolve to genuinely different
versions. The reliable indicator of the resolved version across all extension types
(Git, PowerShell repository and local path) is the 'Path' property, which encodes the
version or git ref as part of the on-disk folder structure. Duplicates that resolve to
the same 'Path' are the same version and are de-duplicated silently.

.PARAMETER Extensions
The array of resolved extensions (as returned by Register-Extensions) to de-duplicate.

.OUTPUTS
[hashtable[]] The de-duplicated array of extensions.
#>
function Resolve-ExtensionDuplicates {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    $groupedByName = $Extensions | Group-Object -Property Name

    # Warn only when the same extension has been resolved to more than one distinct
    # location (i.e. a genuine version conflict), rather than for every shared reference.
    $groupedByName |
        Where-Object { $_.Count -gt 1 -and ($_.Group.Path | Select-Object -Unique).Count -gt 1 } |
        ForEach-Object {
            $winner = $_.Group | Select-Object -First 1
            $ignored = $_.Group | Select-Object -Skip 1
            $conflicts = $_.Group | Select-Object Name, Version, Path
            Write-Warning ("Multiple versions of extension '$($_.Name)' have been resolved - " +
                "using the first one found and ignoring the rest:`n" +
                "Using:   $($winner.Path)`n" +
                "Ignored: $($ignored.Path -join ', ')`n" +
                "$($conflicts | ConvertTo-Json)")
        }

    # De-duplicate by Name, keeping the first one found (preserves the existing
    # depth-first resolution order, so the top-most consumer wins).
    [hashtable[]] $deduplicated = $groupedByName |
        ForEach-Object {
            $_.Group | Select-Object -First 1
        }

    return $deduplicated
}
