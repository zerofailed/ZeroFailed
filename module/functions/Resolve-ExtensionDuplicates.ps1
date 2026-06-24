# <copyright file="Resolve-ExtensionDuplicates.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
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
