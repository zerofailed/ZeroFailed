# <copyright file="Resolve-ExtensionDuplicates.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Resolve-ExtensionDuplicates {
    <#
        .SYNOPSIS
        Removes duplicate extension references, keeping the first one found.

        .DESCRIPTION
        It is common for a low-level extension to be referenced by more than one higher-level
        extension (e.g. as a shared dependency). When the resolved extension list contains
        multiple references to the same extension 'Name', this function removes the duplicates,
        keeping the first one found.

        The extensions are returned in the order that they were given, so that the depth-first
        resolution order is preserved.
        This order decides which extension's process definition is used, and the order in which
        the tasks and functions of the extensions are imported.

        When the reference that is kept does not declare a 'Process', but a removed reference to
        the same extension does, the kept reference uses that 'Process'.
        A warning is logged when the references declare different processes.

        A warning is only logged when the duplicate references resolve to genuinely different
        versions. The reliable indicator of the resolved version across all extension types
        (Git, PowerShell repository and local path) is the 'Path' property, which encodes the
        version or git ref as part of the on-disk folder structure. Duplicates that resolve to
        the same 'Path' are the same version and are de-duplicated silently.

        .PARAMETER Extensions
        The array of resolved extensions (as returned by Register-Extensions) to de-duplicate.

        .EXAMPLE
        PS:> $deduplicated = Resolve-ExtensionDuplicates -Extensions $resolvedExtensions
        Removes duplicate references from the resolved extension list (keeping the first one found),
        warning only where the duplicates resolve to genuinely different versions.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    # Group the references by name, in the order that each name is first found. 'Group-Object' is not used, as it
    # sorts the groups by name.
    $groupedByName = [ordered]@{}
    foreach ($extension in $Extensions) {
        if (!$groupedByName.Contains($extension.Name)) {
            $groupedByName[$extension.Name] = [System.Collections.Generic.List[hashtable]]::new()
        }
        $groupedByName[$extension.Name].Add($extension)
    }

    [hashtable[]] $deduplicated = foreach ($name in $groupedByName.Keys) {
        $group = $groupedByName[$name]
        $winner = $group[0]

        if ($group.Count -gt 1) {
            # Warn only when the same extension has been resolved to more than one distinct
            # location (i.e. a genuine version conflict), rather than for every shared reference.
            if (@($group.Path | Select-Object -Unique).Count -gt 1) {
                $ignored = $group | Select-Object -Skip 1
                $conflicts = $group | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Version = $_['Version']; Path = $_.Path } }
                Write-Warning ("Multiple versions of extension '$name' have been resolved - " +
                    "using the first one found and ignoring the rest:`n" +
                    "Using:   $($winner.Path)`n" +
                    "Ignored: $($ignored.Path -join ', ')`n" +
                    "$($conflicts | ConvertTo-Json)")
            }

            foreach ($duplicate in ($group | Select-Object -Skip 1)) {
                _mergeExtensionProcess -Extension $winner -Duplicate $duplicate
            }
        }

        $winner
    }

    return $deduplicated
}
