# <copyright file="Get-ExtensionImportOrder.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionImportOrder {
    <#
        .SYNOPSIS
        Returns the extensions in the order that their tasks and functions are imported.

        .DESCRIPTION
        An extension's tasks, functions and properties can override those of the extensions that it requires.
        So every extension is imported after its dependencies, including a dependency that several extensions share.

        The extensions are taken in reverse order, and each one is returned after its own dependencies.
        So when 2 extensions define the same task or property, the one that is earlier in the given order is imported later, and its definition is used.

        A dependency that is not in the given extensions (for example, one that a local extension is used in place of) is ignored.

        .PARAMETER Extensions
        The de-duplicated extensions (as returned by Resolve-ExtensionDuplicates), in the order that they were registered.

        .EXAMPLE
        PS:> $importOrder = Get-ExtensionImportOrder -Extensions $deduplicatedExtensions
        For the extensions 'A', 'Common' and 'B', where 'A' and 'B' both require 'Common', returns 'Common', 'B' and 'A'.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]] $Extensions
    )

    $extensionsByName = @{}
    foreach ($extension in $Extensions) {
        if (!$extensionsByName.ContainsKey($extension.Name)) {
            $extensionsByName[$extension.Name] = $extension
        }
    }

    $ordered = [System.Collections.Generic.List[hashtable]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Adds the dependencies of an extension, then the extension itself. An extension is marked as visited before its
    # dependencies, so that a circular dependency does not repeat forever.
    $visit = {
        param ($extension)
        if (!$visited.Add($extension.Name)) {
            return
        }
        $dependencies = @($extension['dependencies'] | Where-Object { $null -ne $_ })
        for ($i = $dependencies.Count - 1; $i -ge 0; $i--) {
            $dependency = $extensionsByName[$dependencies[$i].Name]
            if ($dependency) {
                & $visit $dependency
            }
        }
        $ordered.Add($extension)
    }

    for ($i = $Extensions.Count - 1; $i -ge 0; $i--) {
        & $visit $Extensions[$i]
    }

    return $ordered.ToArray()
}
