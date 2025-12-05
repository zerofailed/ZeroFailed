# <copyright file="Get-ExtensionFromPowerShellRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromPowerShellRepository {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $PSRepository,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [switch] $PreRelease
    )

    # Setup some objects we'll use for splatting
    $extension = @{
        Name = $Name
        Repository = $PSRepository
        Enabled = $true
    }
    $psResourceArgs = @{
        Name = $Name
        PreRelease = $PreRelease
        Verbose = $false
    }
    if ($Version) {
        $extension.Add("Version", $Version)
        $psResourceArgs.Add("Version", $Version)
    }

    # Check whether module is already installed
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs -TargetPath $TargetPath

    # Handle getting the module from the repository
    if (!$existingExtensionPath -or ($Version -and $existingExtensionVersion -ne $Version)) {
        if (!$existingExtensionPath) {
            Write-Verbose "Extension '$Name' not found locally, checking repository"
        }
        elseif ($Version -and $existingExtensionVersion -ne $Version) {
            Write-Verbose "Extension '$Name' found locally but version mismatch detected. Found: v$existingExtensionVersion; Required: v$Version"
        }
        
        $availableModule = Find-PSResource @psResourceArgs -ErrorAction Ignore
        if ($availableModule) {
            Write-Host "Installing extension $Name from $PSRepository" -f Cyan
            $availableModule | Save-PSResource -Path $TargetPath -TrustRepository

            $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs -TargetPath $TargetPath
            if (!$existingExtensionPath) {
                throw "Failed to install extension $Name (v$Version) from $PSRepository repository"
            }
            Write-Host "INSTALLED MODULE: $Name (v$existingExtensionVersion)" -f Cyan
        }
        else {
            Write-Warning "SKIPPED: Extension $Name not found in $PSRepository repository"
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