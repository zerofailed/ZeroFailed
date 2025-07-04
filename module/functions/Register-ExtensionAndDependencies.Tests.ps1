# <copyright file="Register-ExtensionAndDependencies.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionFromGitRepository.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionFromPowerShellRepository.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Copy-FolderFromGitRepo.ps1')
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
            Mock Get-ExtensionFromGitRepository {
                param ($Name, $RepositoryUri, $TargetPath, $GitRef, $RepositoryFolderPath)
                # Return only the additional properties that Register-ExtensionAndDependencies expects to add
                return @{
                    Path = Join-Path $TargetPath $Name $GitRef
                    Enabled = $true # Ensure Enabled is returned
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
