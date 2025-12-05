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