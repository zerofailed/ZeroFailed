function Register-Extensions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [array] $ExtensionsConfig,

        [Parameter(Mandatory=$true)]
        [string] $DefaultRepository
    )
    
    for ($i=0; $i -lt $ExtensionsConfig.Length; $i++) {
        # Parse the extension configuration item into its canonical form
        $extension = New-ExtensionMetadataItem -Value $ExtensionsConfig[$i] -Verbose:$VerbosePreference

        # Prepare the parameters needed for extension registration
        $splat = $extension.Clone()
        $splat.Remove("Process") | Out-Null
        $splat.Add("Repository", $extension.ContainsKey("Repository") ? $extension.Repository : $DefaultRepository)
        
        # Decide how the extension is being provided
        if (!$extension.ContainsKey("Path")) {
            # Call the helper that will install the extension if it's not already installed and
            # provide the resulting additional metadata that we need to use the extension
            $extension += Get-ExtensionFromRepository @splat
        }
        elseif ((Test-Path $extension.Path)) {
            $extension.Add("Enabled", $true)
            Write-Host "USING PATH: $($extension.Name) ($($extension.Path))" -f Cyan
            continue
        }
        else {
            Write-Warning "Extension '$($extension.Name)' not found at $($extension.Path) - it has been disabled."
            $extension.Add("Enabled", $false)
            continue
        }

        # Persist the fully-populated extension metadata
        $ExtensionsConfig[$i] = $extension
    }

    return $ExtensionsConfig
}