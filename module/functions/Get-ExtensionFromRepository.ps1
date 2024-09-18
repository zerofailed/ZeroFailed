# <copyright file="Get-ExtensionFromRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromRepository {
    <#
        .SYNOPSIS
        Retrieves an extension from a PowerShell module repository.
        
        .DESCRIPTION
        If not already available as a locally-installed module, this function installs the extension (as PowerShell module) from a specified repository.
        It also derives the additional metadata about the extension required by the tooling.
        
        .PARAMETER Name
        Specifies the module name of the extension to retrieve.
        
        .PARAMETER Repository
        Specifies the PowerShell module repository from which to retrieve the extension.
        
        .PARAMETER Version
        Specifies the version of the extension to retrieve. If not specified, the latest version will be retrieved.
        
        .PARAMETER PreRelease
        Indicates whether to consider pre-release versions of the module when checking for existing and installing new versions.
        
        .INPUTS
        None. You can't pipe objects to Get-ExtensionFromRepository.

        .OUTPUTS
        Hashtable.
        
        Returns a hashtable containing completed set of metadata for the extension. This consists of the originally supplied metadata
        plus these additional propeties:
        - Path: The path to the installed extension.
        - Enabled: Indicates whether the extension is enabled.
        
        .EXAMPLE
        PS:> Get-ExtensionFromRepository -Name "MyExtension" -Version "1.0.0"`
        Retrieves version 1.0 of the "MyExtension" extension from the default repository (e.g. PSGallery).
    #>
    
    [CmdletBinding()]
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
        Verbose = $false
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