# <copyright file="Get-InstalledExtensionDetails.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-InstalledExtensionDetails {
    <#
        .SYNOPSIS
        Retrieves the details of an installed extension.

        .DESCRIPTION
        Searches the local system for an installed version of the PowerShell module representing the specified extension, and returns
        the path to the module and the version that was found.

        .PARAMETER Name
        The name of the extension, which is also the name of the PowerShell module.

        .PARAMETER Version
        The version of the extension, if not specified the latest version available, if any, will be returned.

        .PARAMETER PreRelease
        Indicates whether to include pre-release versions in the search.

        .INPUTS
        None. You can't pipe objects to Get-InstalledExtensionDetails.

        .OUTPUTS
        When the extension is found, returns two string values representing the path to the installed extension and the version of the
        extension; otherwise returns $null if the extension is not available.

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -Version "1.0.0"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [switch] $PreRelease
    )

    # NOTE: For some reason using PSBoundParameters with 'Get-PSResource' does not behave as expected,
    # so we have to create a specific splat object rather then just using PSBoundParameters
    # after having removed the 'PreRelease' parameter that Get-PSResource does not use.
    $splat = @{
        Name = $Name
    }
    if ($Version) {
        $splat.Add("Version", $Version)
    }
    
    # Setup a dynamic filter to handle whether we should see any installed pre-release versions
    if ($PreRelease -or $Version) {
        # Return all versions as we're either looking for a specific version (in which case
        # we should only have a single result), or we're interested in pre-release versions
        # so no filtering is required.
        $filter = { $true }
    }
    else {
        # Otherwise we're only intrested in non pre-release versions
        $filter = { $_.PreRelease -eq "" }
    }

    # Use Get-PsResource to query whether the module is already installed, unlike Get-Module it supports
    # filtering the version using a proper SemVer syntax.
    $existing = Get-PSResource @splat -ErrorAction Ignore |
                        Where-Object $filter |
                        Sort-Object Version -Descending |
                        Select-Object -First 1

    if ($existing) {
        # Derive the path to the module from the installed module metadata
        # NOTE: The available 'InstalledLocation' property is different depending on
        #       whether the module has just been installed or was already installed.
        if ($existing.InstalledLocation.EndsWith("Modules")) {
            $modulePath = Join-Path -Resolve $existing.InstalledLocation $existing.Name $existing.Version
        }
        else {
            $modulePath = $existing.InstalledLocation
        }
        $existingVersion = $existing.Prerelease ? "$($existing.Version)-$($existing.Prerelease)" : $existing.Version
        return $modulePath,$existingVersion
    }
    else {
        return $null
    }
}