function New-ExtensionMetadataItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Value
    )

    if ($Value -is [string]) {
        if ($Value -imatch [io.path]::DirectorySeparatorChar) {
            # Simple syntax referencing a file path to the module
            $extension.Add("Path", $Value)
            # Assume standard directory convention to derive the extension name
            $extension.Add("Name", (Split-Path -Leaf (Split-Path -Parent $Value)))
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

    Write-Verbose "Extension metadata: $($extension | ConvertTo-Json)"
    return $extension
}