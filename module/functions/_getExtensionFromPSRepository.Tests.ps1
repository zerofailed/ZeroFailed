# <copyright file="_getExtensionFromPSRepository.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getCompleteExtensionVersion.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionVersionInRange.ps1')

    # Needed to create mock PSResourceInfo objects
    Import-Module Microsoft.PowerShell.PSResourceGet

    Set-StrictMode -Version Latest

    # Creates the minimum folder structure of an installed extension, as Save-PSResource would
    function newInstalledExtension([string] $TargetPath, [string] $Name, [string] $Version) {
        $baseVersion,$preReleaseTag = $Version -split '-', 2
        $path = Join-Path $TargetPath $Name $baseVersion
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content -Path (Join-Path $path "$Name.psd1") -Value @"
@{
    ModuleVersion = '$baseVersion'
    PrivateData = @{ PSData = @{ Prerelease = '$preReleaseTag' } }
}
"@
    }
}

Describe '_getExtensionFromPSRepository' {

    BeforeAll {
        $name = 'ZeroFailed.Build.Test'
        $latestVersion = '2.0.0'

        Mock Write-Host {}
        Mock Write-Warning {}

        # Simulate a repository that has the requested version, or the latest version when none is requested
        Mock Find-PSResource {
            $baseVersion,$preReleaseTag = ($Version ? $Version : $latestVersion) -split '-', 2
            New-MockObject -Type 'Microsoft.PowerShell.PSResourceGet.UtilClasses.PSResourceInfo' -Properties @{
                Name = $Name
                Version = [version]$baseVersion
                Prerelease = $preReleaseTag
                # Bound to Save-PSResource's -Repository parameter when the object is piped to it
                Repository = 'PSGallery'
            }
        }
        Mock Save-PSResource {
            $resource = $InputObject | Select-Object -First 1
            $fullVersion = $resource.Prerelease ? "$($resource.Version)-$($resource.Prerelease)" : "$($resource.Version)"
            newInstalledExtension -TargetPath $Path -Name $resource.Name -Version $fullVersion
        }
    }

    BeforeEach {
        $targetPath = Join-Path $TestDrive "extensions-$(New-Guid)"
    }

    Context 'When no version is locked' {
        It 'Installs the latest version and returns it as the resolved version' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath

            $result.Path | Should -Be (Join-Path $targetPath $name $latestVersion)
            $result.Enabled | Should -Be $true
            $result.Version | Should -Be $latestVersion
            $result.ResolvedVersion | Should -Be $latestVersion
        }

        It 'Only searches the configured repository' {
            _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath | Out-Null

            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Repository -eq 'MyRepository' }
        }

        It 'Uses an installed version without checking the repository' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.5.0'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath

            $result.ResolvedVersion | Should -Be '1.5.0'
            Should -Invoke Find-PSResource -Times 0
        }

        It 'Uses an installed pre-release of the requested version when pre-release versions are allowed' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.0.0-beta1'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -Version '1.0.0' -PreRelease

            $result.Path | Should -Be (Join-Path $targetPath $name '1.0.0')
            $result.ResolvedVersion | Should -Be '1.0.0-beta1'
            Should -Invoke Find-PSResource -Times 0
            Should -Invoke Save-PSResource -Times 0
        }
    }

    Context 'When a version is locked' {
        It 'Installs the locked version even when a newer version is installed' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '2.0.0'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -LockedVersion '1.0.0'

            $result.Path | Should -Be (Join-Path $targetPath $name '1.0.0')
            $result.ResolvedVersion | Should -Be '1.0.0'
            $result.Version | Should -Be '1.0.0'
            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Version -eq '1.0.0' -and !$Prerelease }
        }

        It 'Includes pre-release versions when the locked version is a pre-release' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -LockedVersion '2.1.0-beta0001'

            $result.Path | Should -Be (Join-Path $targetPath $name '2.1.0')
            $result.ResolvedVersion | Should -Be '2.1.0-beta0001'
            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Version -eq '2.1.0-beta0001' -and $Prerelease }
        }

        It 'Uses the installed extension when it is the locked version' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.0.0'
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '2.0.0'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -LockedVersion '1.0.0'

            $result.ResolvedVersion | Should -Be '1.0.0'
            Should -Invoke Find-PSResource -Times 0
            Should -Invoke Save-PSResource -Times 0
        }

        It 'Installs a requested version that has fewer than 3 numeric parts, and uses it once it is installed' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -Version '1.4'

            $result.Path | Should -Be (Join-Path $targetPath $name '1.4.0')
            $result.ResolvedVersion | Should -Be '1.4.0'
            $result.ContainsKey('Version') | Should -Be $false

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -Version '1.4'

            $result.ResolvedVersion | Should -Be '1.4.0'
            Should -Invoke Find-PSResource -Times 1 -Exactly
        }

        It 'Does not overwrite the requested version in the returned metadata' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -Version '1.0.0' -LockedVersion '1.0.0'

            $result.ContainsKey('Version') | Should -Be $false
            $result.ResolvedVersion | Should -Be '1.0.0'
        }
    }

    Context 'When a minimum version is requested' {
        BeforeAll {
            # Simulate a repository with several versions, in no particular order, including some outside the range
            Mock Find-PSResource -ParameterFilter { $Version -and $Version.StartsWith('[') } {
                foreach ($availableVersion in '1.4.0', '1.6.0', '1.5.2', '1.7.0-beta.1', '2.0.0') {
                    $baseVersion,$preReleaseTag = $availableVersion -split '-', 2
                    New-MockObject -Type 'Microsoft.PowerShell.PSResourceGet.UtilClasses.PSResourceInfo' -Properties @{
                        Name = $Name
                        Version = [version]$baseVersion
                        Prerelease = $preReleaseTag
                        Repository = 'PSGallery'
                    }
                }
            }
        }

        It 'Installs the newest version in the range' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.Path | Should -Be (Join-Path $targetPath $name '1.6.0')
            $result.Enabled | Should -Be $true
            $result.ResolvedVersion | Should -Be '1.6.0'
            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Version -eq '[1.4.0,2.0.0)' -and !$Prerelease }
        }

        It 'Only searches the configured repository for versions in the range' {
            _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath -MinimumVersion '1.4.0' | Out-Null

            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Version -eq '[1.4.0,2.0.0)' -and $Repository -eq 'MyRepository' }
        }

        It 'Includes pre-release versions in the range when they are requested' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '1.4.0' -PreRelease

            $result.Path | Should -Be (Join-Path $targetPath $name '1.7.0')
            $result.ResolvedVersion | Should -Be '1.7.0-beta.1'
        }

        It 'Uses an installed version in the range without checking the repository' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.5.0'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.ResolvedVersion | Should -Be '1.5.0'
            Should -Invoke Find-PSResource -Times 0
        }

        It 'Ignores installed versions outside the range' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.3.0'
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '2.0.0'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.ResolvedVersion | Should -Be '1.6.0'
            Should -Invoke Find-PSResource -Times 1
        }

        It 'Disables the extension when no version is in the range' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '3.0.0'

            $result.Enabled | Should -Be $false
            $result.ResolvedVersion | Should -BeNullOrEmpty
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like 'SKIPPED*' }
        }

        It 'Installs the locked version instead of the newest version in the range' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '1.4.0' -LockedVersion '1.4.0'

            $result.Path | Should -Be (Join-Path $targetPath $name '1.4.0')
            $result.ResolvedVersion | Should -Be '1.4.0'
            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Version -eq '1.4.0' }
        }

        It 'Does not overwrite the minimum version in the returned metadata' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.ContainsKey('Version') | Should -Be $false
        }
    }

    Context 'The repository that an extension was installed from' {
        BeforeAll {
            # Records the repository of an installed extension, as an install by ZeroFailed does
            function setInstalledRepository([string] $Path, [string] $Repository) {
                @{ repository = $Repository } | ConvertTo-Json | Set-Content -Path (Join-Path $Path '.zf-source.json')
            }
        }

        It 'Records the repository that the extension was installed from' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath

            $sourceInfo = Get-Content -Raw (Join-Path $result.Path '.zf-source.json') | ConvertFrom-Json -AsHashtable
            $sourceInfo.repository | Should -Be 'MyRepository'
            $sourceInfo.version | Should -Be $latestVersion
        }

        It 'Uses an installed extension from the same repository, ignoring case' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.5.0'
            setInstalledRepository -Path (Join-Path $targetPath $name '1.5.0') -Repository 'myrepository'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath

            $result.ResolvedVersion | Should -Be '1.5.0'
            Should -Invoke Find-PSResource -Times 0
        }

        It 'Uses an installed extension with no record of its repository, as earlier versions of ZeroFailed installed' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.5.0'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath

            $result.ResolvedVersion | Should -Be '1.5.0'
            Should -Invoke Find-PSResource -Times 0
        }

        It 'Installs the extension again when it was installed from a different repository' {
            $installedPath = Join-Path $targetPath $name '1.0.0'
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.0.0'
            setInstalledRepository -Path $installedPath -Repository 'OtherRepository'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath -Version '1.0.0'

            $result.Path | Should -Be $installedPath
            Should -Invoke Find-PSResource -Times 1 -ParameterFilter { $Version -eq '1.0.0' -and $Repository -eq 'MyRepository' }
            (Get-Content -Raw (Join-Path $installedPath '.zf-source.json') | ConvertFrom-Json).repository | Should -Be 'MyRepository'
        }

        It 'Throws, without installing, when an extension from a different repository cannot be removed' {
            $installedPath = Join-Path $targetPath $name '1.0.0'
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.0.0'
            setInstalledRepository -Path $installedPath -Repository 'OtherRepository'
            Mock Remove-Item { Write-Error 'The file is in use' }

            { _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath -Version '1.0.0' } |
                Should -Throw "Extension $name (1.0.0) was installed from another repository, but it could not be removed: The file is in use Delete '$installedPath', then run again."
            Should -Invoke Remove-Item -Times 1 -Exactly
            Should -Invoke Find-PSResource -Times 0
        }

        It 'Uses another installed version from the same repository in place of one from a different repository' {
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.6.0'
            setInstalledRepository -Path (Join-Path $targetPath $name '1.6.0') -Repository 'OtherRepository'
            newInstalledExtension -TargetPath $targetPath -Name $name -Version '1.5.0'
            setInstalledRepository -Path (Join-Path $targetPath $name '1.5.0') -Repository 'MyRepository'

            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'MyRepository' -TargetPath $targetPath -MinimumVersion '1.4.0'

            $result.ResolvedVersion | Should -Be '1.5.0'
            Join-Path $targetPath $name '1.6.0' | Should -Not -Exist
            Should -Invoke Find-PSResource -Times 0
        }
    }

    Context 'When the extension is not available in the repository' {
        BeforeAll {
            Mock Find-PSResource {}
        }

        It 'Disables the extension and returns no resolved version' {
            $result = _getExtensionFromPSRepository -Name $name -PSRepository 'PSGallery' -TargetPath $targetPath

            $result.Enabled | Should -Be $false
            $result.ResolvedVersion | Should -BeNullOrEmpty
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like 'SKIPPED*' }
        }
    }
}
