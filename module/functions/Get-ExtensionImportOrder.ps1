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

        Otherwise, an extension that is earlier in the given order is imported later, so when 2 extensions define the same task or property, the earlier one's definition is used.
        Each time, the latest extension whose dependencies have all been imported is imported next.
        A dependency can still override an extension that is earlier than it in the given order, when an extension that requires it is earlier still.
        For example, for 'A', 'B' and 'C', where 'C' requires 'A', the order is 'B', 'A' and 'C', so 'C' overrides 'B'.
        When extensions require each other in a circle, the latest of them is imported first.
        An extension that requires one of the extensions in a circle is still imported after all of them.

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

    # The first reference to each extension, in the given order, which is its priority: a later extension is imported
    # earlier, so that the definitions of an earlier one take precedence
    $remaining = [System.Collections.Generic.List[hashtable]]::new()
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in $Extensions) {
        if ($names.Add($extension.Name)) {
            $remaining.Add($extension)
        }
    }

    # The names of the given extensions that each extension requires
    $dependencyNames = @{}
    foreach ($extension in $remaining) {
        $dependencyNames[$extension.Name] = @($extension['dependencies'] |
                                                Where-Object { $null -ne $_ -and $names.Contains($_.Name) -and $_.Name -ne $extension.Name } |
                                                ForEach-Object { $_.Name })
    }

    $ordered = [System.Collections.Generic.List[hashtable]]::new()
    $imported = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Whether an extension requires another, directly or through extensions that have not been imported
    $requires = {
        param ([string] $name, [string] $required)
        $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $pending = [System.Collections.Generic.Stack[string]]::new()
        $pending.Push($name)
        while ($pending.Count -gt 0) {
            foreach ($dependencyName in $dependencyNames[$pending.Pop()]) {
                if ($dependencyName -eq $required) {
                    return $true
                }
                if (!$imported.Contains($dependencyName) -and $visited.Add($dependencyName)) {
                    $pending.Push($dependencyName)
                }
            }
        }
        return $false
    }
    while ($remaining.Count -gt 0) {
        # An extension is ready once every extension that it requires has been imported
        $next = $null
        for ($i = $remaining.Count - 1; $i -ge 0; $i--) {
            $candidate = $remaining[$i]
            if (!($dependencyNames[$candidate.Name] | Where-Object { !$imported.Contains($_) })) {
                $next = $candidate
                break
            }
        }

        # When none is ready, some of the remaining extensions require each other. The latest extension whose remaining
        # dependencies all require it in turn is imported to break the circle, so that an extension outside the circle
        # that requires one of them is still imported after them. There is always one, as the extensions in a circle
        # that does not require any other remaining extension are all such extensions.
        for ($i = $remaining.Count - 1; !$next -and $i -ge 0; $i--) {
            $candidate = $remaining[$i]
            $isInCircle = $true
            foreach ($dependencyName in ($dependencyNames[$candidate.Name] | Where-Object { !$imported.Contains($_) })) {
                if (!(& $requires $dependencyName $candidate.Name)) {
                    $isInCircle = $false
                    break
                }
            }
            if ($isInCircle) {
                $next = $candidate
            }
        }
        $next ??= $remaining[$remaining.Count - 1]

        $ordered.Add($next)
        $imported.Add($next.Name) | Out-Null
        $remaining.Remove($next) | Out-Null
    }

    return $ordered.ToArray()
}
