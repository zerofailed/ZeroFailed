function Get-ExtensionFromRepository {
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $Repository,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [switch] $PreRelease
    )

    # Setup some objects we'll use for splatting
    $extension = @{
        Name = $Name
        Repository = $Repository
        Enabled = $true
    }
    $psResourceArgs = @{
        Name = $Name
        PreRelease = $PreRelease
    }
    if ($Version) {
        $extension.Add("Version", $Version)
        $psResourceArgs.Add("Version", $Version)
    }

    # Check whether module is already installed
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs

    # Handle getting the module from the repository
    if (!$existingExtensionPath) {
        Write-Verbose "Extension '$Name' not found locally, checking repository"
        if (Find-PSResource @psResourceArgs -ErrorAction Ignore) {
            Write-Host "Installing extension $Name from $Repository" -f Cyan
            $installArgs = $extension.Clone()
            $installArgs.Remove("Enabled") | Out-Null
            $installArgs += @{
                Scope = "CurrentUser"
                TrustRepository = $true
            }
            # When installing pre-release versions we must force reinstall to ensure that an existing pre-release
            # version is updated. This is because PowerShell does not let multiple pre-releases of a given
            # version to be installed side-by-side.
            if ($psResourceArgs.ContainsKey("PreRelease")) {
                $installArgs.Add("Reinstall", $true)
            }
            Install-PSResource @installArgs | Out-Null

            $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs
            if (!$existingExtensionPath) {
                throw "Failed to install extension $Name (v$Version) from $Repository repository"
            }
            Write-Host "INSTALLED MODULE: $Name (v$existingExtensionVersion)" -f Cyan
        }
        else {
            Write-Warning "SKIPPED: Extension $Name not found in $Repository repository"
            $extension.Enabled = $false
        }
    }
    else {
        Write-Host "FOUND MODULE: $Name (v$existingExtensionVersion)" -f Cyan
    }

    # Return the additional extension metadata that this function has populated
    $additionalMetadata = @{
        Path = $existingExtensionPath
        Enabled = $extension.Enabled
    }

    if (!$extension.ContainsKey("Version")) {
        $additionalMetadata += @{ Version = $existingExtensionVersion }
    }

    return $additionalMetadata
}