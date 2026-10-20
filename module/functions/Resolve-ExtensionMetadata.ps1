# <copyright file="Resolve-ExtensionMetadata.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Resolve-ExtensionMetadata {
    <#
        .SYNOPSIS
        Resolves extension metadata from a string or hashtable configuration.

        .DESCRIPTION
        This function resolves extension metadata from a string or hashtable configuration.
        The function supports both simple and object-based syntax.

        An error is thrown if 'MinimumVersion' is combined with 'Version', 'GitRef' or 'Path', because a minimum version selects
        from a range of released versions.

        .PARAMETER Value
        The extension configuration to resolve.

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

        .EXAMPLE
        PS:> Resolve-ExtensionMetadata -Value @{Name="MyExtension"; Version="1.0.0"}
        @{
            Name = "MyExtension"
            Version = "1.0.0"
        }

        .EXAMPLE
        PS:> Resolve-ExtensionMetadata -Value @{Name="MyExtension"; MinimumVersion="1.4.0"}
        @{
            Name = "MyExtension"
            MinimumVersion = "1.4.0"
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
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

    # Ensure we have the module name, as this is needed to ensure our duplicate extension detection works correctly
    # We can be missing this when the extension is specified as a path using either the simple or object syntax.
    if (!$extension.ContainsKey("Name") -and $extension.ContainsKey("Path")) {
        $extension.Add("Name", (_resolveModuleNameFromPath $extension.Path))
    }
    elseif (!$extension.ContainsKey("Name")) {
        throw "Invalid extension configuration syntax."
    }

    # A minimum version selects from a range of released versions, so it cannot be combined with a specific version
    if ($extension.ContainsKey("MinimumVersion")) {
        foreach ($key in "Version", "GitRef", "Path") {
            if ($extension.ContainsKey($key)) {
                throw "Invalid extension configuration for '$($extension.Name)': 'MinimumVersion' cannot be used with '$key'."
            }
        }
    }

    Write-Verbose "Resolved extension metadata: $($extension | ConvertTo-Json)"
    return $extension
}
