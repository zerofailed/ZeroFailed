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

        .PARAMETER TargetPath
        The path to the folder where ZeroFailed extensions are installed (typically '.zf/extensions').

        .PARAMETER Version
        The version of the extension, if not specified the latest version available, if any, will be returned. When this contains a
        semantic version with a pre-release tag, then this implies that a pre-release version is acceptable. (i.e. as if the '-PreRelease'
        switch had been specified)

        .PARAMETER PreRelease
        Indicates whether to include pre-release versions in the search.

        .INPUTS
        None. You can't pipe objects to Get-InstalledExtensionDetails.

        .OUTPUTS
        When the extension is found, returns two string values representing the path to the installed extension and the version of the
        extension; otherwise returns $null if the extension is not available.

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension"
        
        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -Version "1.0.0"

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -Version "1.0.0-beta0001"

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -PreRelease
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [switch] $PreRelease
    )

    # New logic to query whether a given extension is already installed, now that we are installing into the 
    # project directory we can't use the Get-*PSResource cmdlets
    $existingVersion = Get-ChildItem -Path (Join-Path $TargetPath $Name) -Directory -ErrorAction Ignore |
                            ForEach-Object {
                                $foundVersion = [semver]$_.BaseName
                                # Check whether we need to include pre-release versions
                                $manifestPath = Join-Path $_ "$Name.psd1"
                                $manifest = Import-PowerShellDataFile $manifestPath
                                $preReleaseTag = try { $manifest.PrivateData.PSData.Prerelease } catch {}
                                if ($preReleaseTag) {
                                    # Re-generate the SemVer object with the prerelease tag
                                    $foundVersion = [semver]"$foundVersion-$preReleaseTag"
                                }

                                if ($PreRelease -or ($Version -and $Version -eq "$foundVersion")) {
                                    # Return all versions as we're either looking for a specific version (in which case
                                    # we should only have a single result), or we're interested in pre-release versions
                                    # so no filtering is required.
                                    $foundVersion
                                }
                                elseif (!$foundVersion.PreReleaseLabel) {
                                    # Otherwise we're only interested in non pre-release versions
                                    $foundVersion
                                }
                            } |
                            Sort-Object -Descending |
                            Select-Object -First 1

    if ($existingVersion) {
        # Reconstruct the required outputs
        $versionFolderName = ("{0}.{1}.{2}" -f $existingVersion.Major, $existingVersion.Minor, $existingVersion.Patch)
        $modulePath = Join-Path $TargetPath $Name $versionFolderName
        return $modulePath,"$existingVersion"
    }
    else {
        return $null
    }
}