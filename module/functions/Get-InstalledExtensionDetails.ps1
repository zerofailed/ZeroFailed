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
        The version of the extension, if not specified the latest version available, if any, will be returned.
        When specified, only that exact version is returned, even if a later version is installed.
        When this contains a semantic version with a pre-release tag, then this implies that a pre-release version is acceptable, as if the '-PreRelease' switch had been specified.
        When the '-PreRelease' switch is specified, a version without a pre-release tag (for example, '1.0.0') also matches its pre-release versions (for example, '1.0.0-beta0001').

        .PARAMETER MinimumVersion
        The lowest version of the extension to return.
        The newest installed version from this version up to, but not including, the next major version is returned: for example, '1.4.0' matches '1.9.2', but not '2.0.0'.
        Before version 1.0.0, the limit is the next change to the first part that is not zero: for example, '0.3.1' matches versions below '0.4.0'.
        Pre-release versions only match when the '-PreRelease' switch is specified.
        When '-Version' is also specified, this parameter is ignored.

        .PARAMETER GitRefAsFolderName
        The extension version as represented by the GitRef, modified to be safe for use as a filesystem directory name.

        .PARAMETER PreRelease
        Indicates whether to include pre-release versions in the search.

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf"

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -Version "1.0.0"

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -Version "1.0.0-beta0001" -PreRelease

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -PreRelease

        .EXAMPLE
        PS:> $path,$version = Get-InstalledExtensionDetails -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -MinimumVersion "1.4.0"
    #>
    [CmdletBinding(DefaultParameterSetName='Version')]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter(ParameterSetName='Version')]
        [string] $Version,

        [Parameter(ParameterSetName='Version')]
        [string] $MinimumVersion,

        [Parameter(Mandatory=$true, ParameterSetName='GitRef')]
        [string] $GitRefAsFolderName,

        [Parameter()]
        [switch] $PreRelease
    )

    # A minimum version accepts any installed version in its range, up to the next major version
    if ($MinimumVersion -and !$Version) {
        $range = _getExtensionVersionRange -MinimumVersion $MinimumVersion
    }

    # New logic to query whether a given extension is already installed, now that we are installing into the
    # project directory we can't use the Get-*PSResource cmdlets
    $existingVersion = Get-ChildItem -Path (Join-Path $TargetPath $Name) -Directory -ErrorAction Ignore |
                            ForEach-Object {
                                if ($PSCmdlet.ParameterSetName -eq 'Version') {
                                    $foundVersion = [semver]$_.BaseName
                                    # Check whether we need to include pre-release versions
                                    $manifestPath = Join-Path $_ "$Name.psd1"
                                    $manifest = Import-PowerShellDataFile $manifestPath
                                    $preReleaseTag = try { $manifest.PrivateData.PSData.Prerelease } catch {}
                                    if ($preReleaseTag) {
                                        # Re-generate the SemVer object with the prerelease tag
                                        $foundVersion = [semver]"$foundVersion-$preReleaseTag"
                                    }
    
                                    if ($Version) {
                                        # A specific version has been requested, so only exact matches are of interest. When
                                        # pre-release versions are allowed, a version without a pre-release tag (e.g. '1.0.0')
                                        # also matches its pre-release variants (e.g. '1.0.0-beta0001').
                                        $baseVersion = "{0}.{1}.{2}" -f $foundVersion.Major, $foundVersion.Minor, $foundVersion.Patch
                                        if ($Version -eq "$foundVersion" -or ($PreRelease -and $Version -eq $baseVersion)) {
                                            $foundVersion
                                        }
                                    }
                                    elseif ($MinimumVersion) {
                                        if (_testExtensionVersionInRange -Version $foundVersion -Range $range -PreRelease:$PreRelease) {
                                            $foundVersion
                                        }
                                    }
                                    elseif ($PreRelease -or !$foundVersion.PreReleaseLabel) {
                                        # Without a version constraint we're only interested in pre-release versions
                                        # when they have been explicitly requested
                                        $foundVersion
                                    }
                                }
                                else {
                                    $foundGitRef = $_.BaseName
                                    if ($GitRefAsFolderName -eq $foundGitRef) {
                                        $foundGitRef
                                    }
                                }

                            } |
                            Sort-Object -Descending |
                            Select-Object -First 1

    if ($existingVersion) {
        # Reconstruct the required outputs
        if ($PSCmdlet.ParameterSetName -eq 'Version') {
            $versionFolderName = ("{0}.{1}.{2}" -f $existingVersion.Major, $existingVersion.Minor, $existingVersion.Patch)
        }
        else {
            $versionFolderName = $GitRefAsFolderName
        }
        $modulePath = Join-Path $TargetPath $Name $versionFolderName
        return $modulePath,"$existingVersion"
    }
    else {
        return $null
    }
}