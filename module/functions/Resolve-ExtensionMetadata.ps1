# <copyright file="Resolve-ExtensionMetadata.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Resolve-ExtensionMetadata {
    <#
        .SYNOPSIS
        Resolves extension metadata from a string or hashtable configuration.

        .DESCRIPTION
        This function resolves extension metadata from a string or hashtable configuration. The function supports both simple and object-based syntax.

        .PARAMETER Value
        The extension configuration to resolve.

        .INPUTS
        None. You can't pipe objects to Resolve-ExtensionMetadata.

        .OUTPUTS
        Hashtable.  Returns a hashtable containing the extension metadata in canonical form, including any resolved values for its Name.

        .EXAMPLE
        PS:> Resolve-ExtensionMetadata -Value "MyExtension"
        @{
            Name = "MyExtension"
        }

        .EXAMPLE
        PS:> Resolve-ExtensionMetadata -Value "c:\path\to\MyExtension"
        @{
            Name = "MyExtension"
            Path = "c:\path\to\MyExtension"
        }

        .EXAMPLE
        PS:> Resolve-ExtensionMetadata -Value @{Path="c:\path\to\MyExtension"}
        @{
            Name = "MyExtension"
            Path = "c:\path\to\MyExtension"
        }
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Value
    )

    Write-Verbose "Unresolved extension metadata: $($Value | ConvertTo-Json)"

    if ($Value -is [string]) {
        $extension = @{}
        # Check if the value is a path by looking for directory separators
        # NOTE: On Windows we can use either the backslash or forward slash as a directory separator, so 
        #       we need to account for both.
        $regex = "{0}|{1}" -f [System.Text.RegularExpressions.Regex]::Escape([IO.Path]::DirectorySeparatorChar),
                              [IO.Path]::AltDirectorySeparatorChar
        if ($Value -imatch $regex) {
            # Handle the Simple syntax referencing a file path to the module
            $extension.Add("Path", $Value)
        }
        else {
            # Simple syntax referencing a module name
            $extension.Add("Name", $Value)
        }
    }
    elseif ($Value -is [hashtable]) {
        # Assume full object-based syntax
        $extension = $Value
    }
    else {
        throw "Invalid extension configuration syntax. Expected a string or hashtable, but found $($Value.GetType().Name)"
    }

    # Ensure we have the module name, as this is needed to ensure our duplicate extension detection works correctly
    # We can be missing this when the extension is specified as a path using either the simple or object syntax.
    if (!$extension.ContainsKey("Name")) {
        $extension.Add("Name", (_resolveModuleNameFromPath $extension.Path))
    }

    Write-Verbose "Resolved extension metadata: $($extension | ConvertTo-Json)"
    return $extension
}
