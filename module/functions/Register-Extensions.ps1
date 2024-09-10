function Register-Extensions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]] $ExtensionsConfig,

        [Parameter(Mandatory=$true)]
        [string] $DefaultRepository
    )

    foreach ($extension in $ExtensionsConfig) {
        $extensionName = $extension.Name
        Write-Host "Processing Extension '$(Split-Path -Leaf $extensionName)'" -f Green
        $extensionRepo = $extension.ContainsKey("Repository") ? $extension.Repository : $DefaultRepository
        
        # Decide how the extension is being provided
        if (!$extension.ContainsKey("Path")) {
            Write-Host "  Checking for extension '$extensionName' in repository '$extensionRepo'"
            $extension = Get-ExtensionFromRepository -ExtensionName $extensionName -Repository $extensionRepo
        }
        elseif ((Test-Path $extension.Path)) {
            $extension.Add("Enabled", $true)
            continue
        }
        else {
            Write-Warning "Extension '$extensionName' not found at $($extension.Path) - it has been disabled."
            $extension.Add("Enabled", $false)
            continue
        }
    }

    return $ExtensionsConfig
}