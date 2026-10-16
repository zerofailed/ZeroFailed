# <copyright file="Get-InstalledExtensionDetails.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-InstalledExtensionDetails {
    [CmdletBinding(DefaultParameterSetName='Version')]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter(ParameterSetName='Version')]
        [string] $Version,

        [Parameter(Mandatory=$true, ParameterSetName='GitRef')]
        [string] $GitRefAsFolderName,

        [Parameter()]
        [switch] $PreRelease
    )

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