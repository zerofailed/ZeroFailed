# <copyright file="Register-ExtensionAndDependencies.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_copyFolderFromGitRepo.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionFromGit.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionFromPSRepository.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionFromPath.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_newExtensionLockEntry.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionLockEntryMatch.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionDependencies.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_resolveModuleNameFromPath.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Resolve-ExtensionMetadata.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionAvailableTasks.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-TasksFileListFromExtension.ps1')
}

Describe 'Register-ExtensionAndDependencies' {
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null

        # Define default PSRepository for PowerShell module-based extensions
        $DefaultPSRepository = 'PSGallery'

        Mock Write-Host {}
        Mock Write-Warning {}
    }

    Context 'Git-Based Extensions' {
        BeforeAll {
            Mock _getExtensionFromGit {
                # Return only the additional properties that Register-ExtensionAndDependencies expects to add
                return @{
                    Path = Join-Path $TargetPath $Name $GitRef
                    Enabled = $true # Ensure Enabled is returned
                    ResolvedVersion = $LockedCommit ? $LockedCommit : "latest-commit-of-$Name"
                }
            }
            Mock Import-PowerShellDataFile {
                param($Path)
                switch ($Path) {
                    { $PSItem.EndsWith('ZeroFailed.DevOps.Common.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.DevOps.Common'
                            PrivateData = @{
                                PSData = @{
                                    ExternalModuleDependencies = @()
                                }
                                ZeroFailed = @{
                                    ExtensionDependencies = @()
                                }
                            }
                        }
                    }
                    { $PSItem.EndsWith('ZeroFailed.Build.Common.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.Build.Common'
                            PrivateData = @{
                                PSData = @{
                                    ExternalModuleDependencies = @()
                                }
                                ZeroFailed = @{
                                    ExtensionDependencies = @(
                                        @{
                                            Name = 'ZeroFailed.DevOps.Common'
                                            GitRepository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'
                                            GitRef = 'main'
                                        }
                                    )
                                }
                            }
                        }
                    }
                    { $PSItem.EndsWith('ZeroFailed.Build.DotNet.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.Build.DotNet'
                            PrivateData = @{
                                PSData = @{
                                    ExternalModuleDependencies = @()
                                }
                                ZeroFailed = @{
                                    ExtensionDependencies = @(
                                        @{
                                            Name = 'ZeroFailed.Build.Common'
                                            GitRepository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'
                                            GitRef = 'main'
                                        }
                                    )
                                }
                            }
                        }
                    }
                    default {
                        throw "Unhandled mock module manifest for '$PSItem'"
                    }
                }
            }
        }
        
        Context 'When processing a single extension with no dependencies (no version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be $null
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with no dependencies  (with version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with 1 dependency (version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 2

                $result[0].Name | Should -Be "ZeroFailed.Build.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true

                $result[1].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[1].Version | Should -Be $null
                $result[1].GitRef | Should -Be "main"
                $result[1].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with multiple dependencies (version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.DotNet"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.DotNet"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 3

                $result[0].Name | Should -Be "ZeroFailed.Build.DotNet"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true

                $result[1].Name | Should -Be "ZeroFailed.Build.Common"
                $result[1].Version | Should -Be $null
                $result[1].GitRef | Should -Be "main"
                $result[1].Enabled | Should -Be $true

                $result[2].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[2].Version | Should -Be $null
                $result[2].GitRef | Should -Be "main"
                $result[2].Enabled | Should -Be $true
            }
        }

        Context 'When the extension is explicitly enabled' {
            It 'Processes the extension' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                    Enabled = $true
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'Lock metadata' {
            BeforeAll {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                    GitRef = "refs/heads/main"
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
            }

            It 'Records how the extension was requested and resolved' {
                $lockEntry = $result[0].LockEntry

                $lockEntry.source.type | Should -Be 'git'
                $lockEntry.source.repository | Should -Be 'https://github.com/zerofailed/ZeroFailed.Build.Common'
                $lockEntry.source.folderPath | Should -Be 'module'
                $lockEntry.requested | Should -Be 'refs/heads/main'
                $lockEntry.resolved | Should -Be 'latest-commit-of-ZeroFailed.Build.Common'
            }

            It 'Records that a configured extension is a direct dependency' {
                $result[0].LockEntry.direct | Should -Be $true
                $result[0].LockEntry.requiredBy | Should -BeNullOrEmpty
            }

            It 'Records which extension requires a dependency' {
                $result[1].Name | Should -Be 'ZeroFailed.DevOps.Common'
                $result[1].LockEntry.direct | Should -Be $false
                $result[1].LockEntry.requiredBy | Should -Be @('ZeroFailed.Build.Common')
                $result[1].LockEntry.requested | Should -Be 'main'
            }

            It 'Does not add the resolved version to the extension metadata' {
                $result[0].ContainsKey('ResolvedVersion') | Should -Be $false
            }
        }

        Context 'Locked extensions' {
            BeforeEach {
                # Registration adds metadata to the configuration it is given, so each test needs a new one
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                }
            }

            It 'Installs the locked commit of the extension and its dependencies when the lock file matches the request' {
                $lockedExtensions = @{
                    'ZeroFailed.Build.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                        requested = 'main'
                        resolved = 'locked-commit-1'
                    }
                    'ZeroFailed.DevOps.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'; folderPath = 'module' }
                        requested = 'main'
                        resolved = 'locked-commit-2'
                    }
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be 'locked-commit-1'
                $result[1].LockEntry.resolved | Should -Be 'locked-commit-2'
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and $LockedCommit -eq 'locked-commit-1' }
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.DevOps.Common' -and $LockedCommit -eq 'locked-commit-2' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Using locked commit for extension ZeroFailed.Build.Common: locked-commit-1' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Using locked commit for extension ZeroFailed.DevOps.Common: locked-commit-2' }
            }

            It 'Does not use the lock file when the extension was requested differently' {
                $lockedExtensions = @{
                    'ZeroFailed.Build.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                        requested = 'feature/other'
                        resolved = 'locked-commit-1'
                    }
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be 'latest-commit-of-ZeroFailed.Build.Common'
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and !$LockedCommit }
                Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like 'Using locked*' }
            }

            It 'Does not use a lock entry that has no resolved commit' {
                $lockedExtensions = @{
                    'ZeroFailed.Build.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                        requested = 'main'
                        resolved = $null
                    }
                }

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and !$LockedCommit }
                Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like 'Using locked*' }
            }
        }
    }

    Context 'PowerShell Module-Based Extensions' {
        BeforeAll {
            $mockModuleName = 'MyZfExtension'
            $mockModuleVersion = '1.2.3'
            $mockPsRepo = "MyPSRepo"
            Mock Get-ExtensionDependencies {
                return @()
            }
            Mock Find-PSResource { 
                # Minimum properties required to fake a PS module being available on a repository
                return New-MockObject -Type 'Microsoft.PowerShell.PSResourceGet.UtilClasses.PSResourceInfo' -Properties @{ Name = $mockModuleName; Repository = $mockPsRepo }
            }
            Mock Save-PSResource {
                # Create the minimum filesystem structure needed to fake the installation of a ZF extension
                New-Item -ItemType Directory -Path (Join-Path $Path $InputObject.Name $mockModuleVersion) -Force | Out-Null
            }
            Mock Import-PowerShellDataFile {
                return @{
                    RootModule = $mockModuleName
                    PrivateData = @{
                        PSData = @{
                            ExternalModuleDependencies = @()
                        }
                        ZeroFailed = @{
                            ExtensionDependencies = @()
                        }
                    }
                }
            }
        }

        Context 'When processing a single PowerShell module extension (no PSRepository specified)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = $mockModuleName
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockModuleName
                $result[0].Version | Should -Be $mockModuleVersion
                $result[0].Enabled | Should -Be $true
                Should -Invoke Find-PSResource -Exactly 1
                Should -Invoke Save-PSResource -Exactly 1
            }
        }

        Context 'When processing a single PowerShell module extension (with PSRepository specified)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = $mockModuleName
                    PSRepository = $mockPsRepo
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockModuleName
                $result[0].Version | Should -Be $mockModuleVersion
                $result[0].PSRepository | Should -Be $mockPsRepo
                $result[0].Enabled | Should -Be $true
                Should -Invoke Find-PSResource -Exactly 1
                Should -Invoke Save-PSResource -Exactly 1
            }
        }

        Context 'Lock metadata' {
            It 'Records how the extension was requested and resolved' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName } -TargetPath $targetPath

                $lockEntry = $result[0].LockEntry
                $lockEntry.source.type | Should -Be 'psrepository'
                $lockEntry.source.repository | Should -Be 'PSGallery'
                $lockEntry.source.preRelease | Should -Be $false
                $lockEntry.requested | Should -BeNullOrEmpty
                $lockEntry.resolved | Should -Be $mockModuleVersion
                $lockEntry.direct | Should -Be $true
            }
        }

        Context 'Locked extensions' {
            BeforeAll {
                Mock _getExtensionFromPSRepository {
                    $path = Join-Path $TargetPath $Name '1.0.0'
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                    return @{
                        Path = $path
                        Enabled = $true
                        ResolvedVersion = $LockedVersion ? $LockedVersion : $mockModuleVersion
                    }
                }
                $lockedExtensions = @{
                    $mockModuleName = @{
                        source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }
                        requested = $null
                        resolved = '1.0.0'
                    }
                }
            }

            It 'Installs the locked version when the lock file matches the request' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName } -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be '1.0.0'
                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $LockedVersion -eq '1.0.0' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq "Using locked version for extension $($mockModuleName): v1.0.0" }
            }

            It 'Does not use the lock file when the extension was requested differently' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName; PreRelease = $true } -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be $mockModuleVersion
                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { !$LockedVersion }
                Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like 'Using locked*' }
            }
        }
    }

    Context 'Local File-System-Based Extensions' {
        BeforeAll {
            Mock Write-Host {} -ParameterFilter { $Object.StartsWith("USING PATH:")}
            $mockExtensionName = 'MyLocalZfExtension'
            $mockExtensionPath = Join-Path -Path TestDrive: -ChildPath $mockExtensionName
            New-Item -Path $mockExtensionPath -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $mockExtensionPath "$mockExtensionName.psd1") -Value @'
@{
    RootModule = 'MyLocalZfExtension.psm1'
    ModuleVersion = '0.0.1'
    PrivateData = @{
        ZFData = @{
            Dependencies = @()
        }
    }
}
'@
        }

        Context 'When processing a single local file-system extension with a valid path' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = $mockExtensionName
                    Path = $mockExtensionPath
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockExtensionName
                $result[0].Path | Should -Be $mockExtensionPath
                $result[0].Enabled | Should -Be $true
                Should -Invoke Write-Host -Exactly 1
            }

            It 'Records the path as the source, with no resolved version' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockExtensionName; Path = $mockExtensionPath } -TargetPath $targetPath

                $result[0].LockEntry.source.type | Should -Be 'path'
                $result[0].LockEntry.source.path | Should -Be $mockExtensionPath
                $result[0].LockEntry.requested | Should -BeNullOrEmpty
                $result[0].LockEntry.resolved | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Disabled Extension Scenarios' {
        BeforeEach {
        }

        Context 'Local extension path does not exist' {
            It 'Should disable the extension and write a warning' {
                $missingExtension = 'missingZfExtension'
                $missingPath = Join-Path $TestDrive $missingExtension
                $extensionConfig = @{
                    Name = $missingExtension
                    Path = $missingPath
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $missingExtension
                $result[0].Enabled | Should -Be $false
                Should -Invoke Write-Warning -Exactly 1 -ParameterFilter {
                    $_.ToString() -like "Extension 'TestmockExtensionName' not found at $invalidPath - it has been disabled.*"
                }
                Should -Not -Invoke Get-ExtensionDependencies
                Should -Not -Invoke Get-ExtensionAvailableTasks
                Should -Not -Invoke Register-ExtensionAndDependencies -ParameterFilter { $ExtensionConfig.Name -ne $missingExtension }
            }
        }

        Context 'Extension explicitly disabled via configuration' {
            It 'Should not process dependencies or tasks' {
                Mock Get-ExtensionDependencies {}
                Mock Get-ExtensionAvailableTasks {}
                Mock Write-Host {}

                $mockExtensionName = 'MyLocalZfExtension'
                $mockExtensionPath = Join-Path -Path TestDrive: -ChildPath $mockExtensionName
                New-Item -Path $mockExtensionPath -ItemType Directory -Force | Out-Null
                Set-Content -Path (Join-Path $mockExtensionPath "$mockExtensionName.psd1") -Value @'
    @{
        RootModule = 'MyLocalZfExtension.psm1'
        ModuleVersion = '0.0.1'
        PrivateData = @{
            ZFData = @{
                Dependencies = @()
            }
        }
    }
'@
                $extensionConfig = @{
                    Name = $mockExtensionName
                    Path = $mockExtensionPath
                    Enabled = $false
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockExtensionName
                $result[0].Enabled | Should -Be $false
                Should -Not -Invoke Get-ExtensionDependencies
                Should -Not -Invoke Get-ExtensionAvailableTasks
                Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Skipping extension - explicitly disabled' }
            }
        }
    }

    

    Context 'Invalid extension path configuration' {
        BeforeAll {
            $invalidExtensionPath = "$PWD/does-not-exist"
        }

        Context 'Simple syntax' {
            It 'Should throw an exception' {
                $mockInvalidSimpleExtensionConfig = $invalidExtensionPath
                {
                    Register-ExtensionAndDependencies $mockInvalidSimpleExtensionConfig $targetPath
                } | Should -Throw "Unable to find the extension's module manifest in '$invalidExtensionPath'"
            }
        }

        Context 'Hashtable syntax' {
            It 'Should throw an exception' {
                $mockInvalidHashtableExtensionConfig = @{
                    Path = $invalidExtensionPath
                }
                {
                    Register-ExtensionAndDependencies $mockInvalidHashtableExtensionConfig $targetPath
                } | Should -Throw "Unable to find the extension's module manifest in '$invalidExtensionPath'"
            }
        }
    }
}
