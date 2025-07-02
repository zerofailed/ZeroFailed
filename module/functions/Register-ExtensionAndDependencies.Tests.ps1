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
        # Mock Get-ExtensionAvailableTasks {
        #     param ($ExtensionPath)
        #     return @("MockTask1", "MockTask2")
        # }
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
    RootModule = 'ZeroFailed.psm1'
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

    # Context 'Disabled Extension Scenarios' {
    #     BeforeEach {
    #         # Reset mocks for each test in this context
    #         Mock Test-Path {
    #             param ($Path)
    #             return $false # Default to false, override for specific tests
    #         }
    #         Mock Write-Warning {} # Capture Write-Warning output
    #         Mock Get-ExtensionDependencies {
    #             param ($Extension)
    #             return @()
    #         }
    #         Mock Get-ExtensionAvailableTasks {
    #             param ($ExtensionPath)
    #             return @()
    #         }
    #         Mock Register-ExtensionAndDependencies {
    #             param ($ExtensionConfig, $TargetPath)
    #             # Prevent recursive calls from actually executing during these tests
    #             return @($ExtensionConfig)
    #         } -ParameterFilter { $ExtensionConfig.Name -ne "TestDisabledExtension" -and $ExtensionConfig.Name -ne "ExplicitlyDisabledExtension" }
    #     }

    #     Context 'Local extension path does not exist' {
    #         It 'Should disable the extension and write a warning' {
    #             Mock Resolve-ExtensionMetadata {
    #                 param ($Value)
    #                 $mockExtension = $Value.Clone()
    #                 $mockExtension.Enabled = $true # Assume it's enabled initially
    #                 return $mockExtension
    #             }

    #             $invalidPath = "$targetPath/non-existent-local-extension"
    #             $extensionConfig = @{
    #                 Name = "TestDisabledExtension"
    #                 Path = $invalidPath
    #             }

    #             [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

    #             $result.Count | Should -Be 1
    #             $result[0].Name | Should -Be "TestDisabledExtension"
    #             $result[0].Enabled | Should -Be $false
    #             Should -Invoke Write-Warning -Exactly 1 -ParameterFilter {
    #                 $_.ToString() -like "Extension 'TestDisabledExtension' not found at $invalidPath - it has been disabled.*"
    #             }
    #             Should -Not -Invoke Get-ExtensionDependencies
    #             Should -Not -Invoke Get-ExtensionAvailableTasks
    #             Should -Not -Invoke Register-ExtensionAndDependencies -ParameterFilter { $ExtensionConfig.Name -ne "TestDisabledExtension" }
    #         }
    #     }

    #     Context 'Extension explicitly disabled via configuration' {
    #         It 'Should not process dependencies or tasks' {
    #             Mock Resolve-ExtensionMetadata {
    #                 param ($Value)
    #                 $mockExtension = $Value.Clone()
    #                 $mockExtension.Enabled = $false
    #                 return $mockExtension
    #             }

    #             $extensionConfig = @{
    #                 Name = "ExplicitlyDisabledExtension"
    #                 Path = "$targetPath/some-path" # Path doesn't matter as Resolve-ExtensionMetadata is mocked
    #                 Enabled = $false # This will be overridden by mock
    #             }

    #             [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

    #             $result.Count | Should -Be 1
    #             $result[0].Name | Should -Be "ExplicitlyDisabledExtension"
    #             $result[0].Enabled | Should -Be $false
    #             Should -Not -Invoke Get-ExtensionDependencies
    #             Should -Not -Invoke Get-ExtensionAvailableTasks
    #             Should -Not -Invoke Register-ExtensionAndDependencies -ParameterFilter { $ExtensionConfig.Name -ne "ExplicitlyDisabledExtension" }
    #         }
    #     }
    # }

    # Context 'Dependency Resolution Edge Cases' {
    #     BeforeEach {
    #         # Reset mocks for each test in this context
    #         Mock Resolve-ExtensionMetadata {
    #             param ($Value)
    #             if ($Value -is [string]) {
    #                 return @{ Name = $Value; Path = $Value; Enabled = $true }
    #             }
    #             return $Value
    #         }
    #         Mock Get-ExtensionDependencies {
    #             param ($Extension)
    #             return @() # Default to no dependencies, override for specific tests
    #         }
    #         Mock Get-ExtensionFromGitRepository {
    #             param ($Name, $RepositoryUri, $TargetPath)
    #             return @{ Path = Join-Path $TargetPath $Name }
    #         }
    #         Mock Get-ExtensionFromPowerShellRepository {
    #             param ($Name, $PSRepository, $TargetPath)
    #             return @{ Path = Join-Path $TargetPath $Name }
    #         }
    #         Mock Test-Path {
    #             param ($Path)
    #             return $true # Default to path exists
    #         }
    #         Mock Write-Warning {}
    #         Mock Write-Host {}
    #         Mock Register-ExtensionAndDependencies {
    #             param ($ExtensionConfig, $TargetPath)
    #             # Allow recursive calls to be tracked, but return a simple processed config
    #             return @($ExtensionConfig)
    #         } -ParameterFilter { $ExtensionConfig.Name -ne "CircularDependencyB" -and $ExtensionConfig.Name -ne "NonExistentDependency" -and $ExtensionConfig.Name -ne "CommonDependency" }
    #     }

    #     Context 'Extension with no dependencies' {
    #         It 'Should only process the main extension' {
    #             $extensionConfig = @{
    #                 Name = "ExtensionNoDeps"
    #                 GitRepository = "https://github.com/test/nodeps"
    #             }

    #             [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

    #             $result.Count | Should -Be 1
    #             $result[0].Name | Should -Be "ExtensionNoDeps"
    #             Should -Invoke Get-ExtensionDependencies -Exactly 1 -ParameterFilter { $Extension.Name -eq "ExtensionNoDeps" }
    #             Should -Not -Invoke Register-ExtensionAndDependencies -ParameterFilter { $ExtensionConfig.Name -ne "ExtensionNoDeps" }
    #         }
    #     }

    #     # Context 'Circular Dependencies (A -> B -> A)' {
    #     #     It 'Should process each unique extension only once' {
    #     #         Mock Get-ExtensionDependencies {
    #     #             param ($Extension)
    #     #             if ($Extension.Name -eq "CircularDependencyA") {
    #     #                 return @(@{ Name = "CircularDependencyB"; GitRepository = "https://github.com/test/B" })
    #     #             }
    #     #             if ($Extension.Name -eq "CircularDependencyB") {
    #     #                 return @(@{ Name = "CircularDependencyA"; GitRepository = "https://github.com/test/A" })
    #     #             }
    #     #             return @()
    #     #         }

    #     #         # Mock Register-ExtensionAndDependencies to prevent infinite recursion and track calls
    #     #         $processedCalls = [System.Collections.Generic.List[string]]::new()
    #     #         Mock Register-ExtensionAndDependencies {
    #     #             param ($ExtensionConfig, $TargetPath)
    #     #             if (-not ($processedCalls.Contains($ExtensionConfig.Name))) {
    #     #                 $processedCalls.Add($ExtensionConfig.Name)
    #     #                 # Call original function for the first time, then return mock for subsequent calls
    #     #                 if ($ExtensionConfig.Name -eq "CircularDependencyA") {
    #     #                     return (Invoke-MockOriginal -ExtensionConfig $ExtensionConfig -TargetPath $TargetPath)
    #     #                 }
    #     #             }
    #     #             return @($ExtensionConfig) # Return a simple mock for subsequent calls
    #     #         } -MockWith { Invoke-MockOriginal } -ParameterFilter { $ExtensionConfig.Name -eq "CircularDependencyA" }

    #     #         $extensionConfig = @{
    #     #             Name = "CircularDependencyA"
    #     #             GitRepository = "https://github.com/test/A"
    #     #         }

    #     #         [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

    #     #         $result.Count | Should -Be 2 # A and B should be in the final list
    #     #         $result.Name | Should -Contain "CircularDependencyA"
    #     #         $result.Name | Should -Contain "CircularDependencyB"

    #     #         # Verify that Register-ExtensionAndDependencies was called for each unique dependency once
    #     #         $processedCalls.Count | Should -Be 2
    #     #         $processedCalls | Should -Contain "CircularDependencyA"
    #     #         $processedCalls | Should -Contain "CircularDependencyB"
    #     #     }
    #     # }

    #     Context 'Non-existent Dependency' {
    #         It 'Should mark the non-existent dependency as disabled and warn' {
    #             Mock Get-ExtensionDependencies {
    #                 param ($Extension)
    #                 if ($Extension.Name -eq "MainExtension") {
    #                     return @(@{ Name = "NonExistentDependency"; Path = "$targetPath/non-existent-dep" })
    #                 }
    #                 return @()
    #             }
    #             Mock Test-Path {
    #                 param ($Path)
    #                 return $Path -ne "$targetPath/non-existent-dep"
    #             }
    #             Mock Resolve-ExtensionMetadata {
    #                 param ($Value)
    #                 if ($Value.Name -eq "NonExistentDependency") {
    #                     return @{ Name = "NonExistentDependency"; Path = "$targetPath/non-existent-dep"; Enabled = $true } # Assume initially enabled
    #                 }
    #                 return $Value
    #             }

    #             $extensionConfig = @{
    #                 Name = "MainExtension"
    #                 GitRepository = "https://github.com/test/main"
    #             }

    #             [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

    #             $result.Count | Should -Be 2
    #             $result.Name | Should -Contain "MainExtension"
    #             $result.Name | Should -Contain "NonExistentDependency"
    #             ($result | Where-Object Name -eq "NonExistentDependency").Enabled | Should -Be $false

    #             Should -Invoke Write-Warning -Exactly 1 -ParameterFilter {
    #                 $_.ToString() -like "Extension 'NonExistentDependency' not found at $targetPath/non-existent-dep - it has been disabled.*"
    #             }
    #         }
    #     }

    #     Context 'Duplicate Dependencies (A -> B, C -> B)' {
    #         It 'Should process the duplicate dependency only once' {
    #             Mock Get-ExtensionDependencies {
    #                 param ($Extension)
    #                 if ($Extension.Name -eq "ExtensionA") {
    #                     return @(@{ Name = "CommonDependency"; GitRepository = "https://github.com/test/common" })
    #                 }
    #                 if ($Extension.Name -eq "ExtensionC") {
    #                     return @(@{ Name = "CommonDependency"; GitRepository = "https://github.com/test/common" })
    #                 }
    #                 return @()
    #             }

    #             # Mock Register-ExtensionAndDependencies to track calls
    #             $registerCalls = [System.Collections.Generic.List[string]]::new()
    #             Mock Register-ExtensionAndDependencies {
    #                 param ($ExtensionConfig, $TargetPath)
    #                 $registerCalls.Add($ExtensionConfig.Name)
    #                 return (Invoke-MockOriginal -ExtensionConfig $ExtensionConfig -TargetPath $TargetPath)
    #             } -ParameterFilter { $ExtensionConfig.Name -ne "ExtensionA" -and $ExtensionConfig.Name -ne "ExtensionC" }

    #             $extensionConfigA = @{
    #                 Name = "ExtensionA"
    #                 GitRepository = "https://github.com/test/A"
    #             }
    #             $extensionConfigC = @{
    #                 Name = "ExtensionC"
    #                 GitRepository = "https://github.com/test/C"
    #             }

    #             [array]$resultA = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfigA -TargetPath $targetPath
    #             [array]$resultC = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfigC -TargetPath $targetPath

    #             # Combine results and ensure unique entries
    #             $combinedResult = ($resultA + $resultC | Select-Object -Unique Name)

    #             $combinedResult.Count | Should -Be 3
    #             $combinedResult.Name | Should -Contain "ExtensionA"
    #             $combinedResult.Name | Should -Contain "ExtensionC"
    #             $combinedResult.Name | Should -Contain "CommonDependency"

    #             # Verify that CommonDependency was processed only once by Register-ExtensionAndDependencies
    #             ($registerCalls | Where-Object { $_ -eq "CommonDependency" }).Count | Should -Be 1
    #         }
    #     }
    # }

    # Context 'Error Handling of Internal Calls' {
    #     BeforeEach {
    #         # Reset mocks for each test in this context
    #         Mock Resolve-ExtensionMetadata {
    #             param ($Value)
    #             if ($Value -is [string]) {
    #                 return @{ Name = $Value; Path = $Value; Enabled = $true }
    #             }
    #             return $Value
    #         }
    #         Mock Get-ExtensionFromGitRepository {
    #             param ($Name, $RepositoryUri, $TargetPath)
    #             return @{ Path = Join-Path $TargetPath $Name }
    #         }
    #         Mock Get-ExtensionFromPowerShellRepository {
    #             param ($Name, $PSRepository, $TargetPath)
    #             return @{ Path = Join-Path $TargetPath $Name }
    #         }
    #         Mock Get-ExtensionDependencies {
    #             param ($Extension)
    #             return @()
    #         }
    #         Mock Test-Path {
    #             param ($Path)
    #             return $true
    #         }
    #         Mock Write-Warning {}
    #         Mock Write-Host {}
    #     }

    #     Context 'When Get-ExtensionFromGitRepository throws an error' {
    #         It 'Should propagate the exception' {
    #             Mock Get-ExtensionFromGitRepository {
    #                 throw "Mock Git Repository Error"
    #             }

    #             $extensionConfig = @{
    #                 Name = "ErrorGitExtension"
    #                 GitRepository = "https://github.com/error/git"
    #             }

    #             { Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath } | Should -Throw "Mock Git Repository Error"
    #         }
    #     }

    #     Context 'When Get-ExtensionDependencies throws an error' {
    #         It 'Should propagate the exception' {
    #             Mock Get-ExtensionDependencies {
    #                 throw "Mock Dependency Error"
    #             }

    #             $extensionConfig = @{
    #                 Name = "ErrorDepExtension"
    #                 Path = "$targetPath/error-dep"
    #             }

    #             { Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath } | Should -Throw "Mock Dependency Error"
    #         }
    #     }
    # }

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
