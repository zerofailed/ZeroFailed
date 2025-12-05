# <copyright file="Get-ExtensionDependencies.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Resolve-ExtensionMetadata.ps1')

    Set-StrictMode -Version Latest
}

Describe 'Get-ExtensionDependencies' {
    # Setup TestDrive with sample extension
    BeforeAll {
        # Setup .zf folder
        $extensionPath = Join-Path -Path TestDrive: -ChildPath 'fake-extension'
        New-Item -Path $extensionPath -ItemType Directory -Force | Out-Null
        $extensionConfig = @{
            Name = "fake-extension"
            Path = $extensionPath
        }
        $mockLegacyModuleManifest = @{
            RootModule = "an-extension"
            PrivateData = @{
                PSData = @{
                    ExternalModuleDependencies = @()
                }
            }
        }
        Mock Write-Warning {}
        Mock Write-Host {}
    }

    Context 'No dependencies' {

        Context 'Legacy definition' {

            BeforeAll {
                $mockDependenciesPsd1FilePath = Join-Path $extensionPath 'dependencies.psd1'
                $extensionDependencies = @'
@{}
'@
                Set-Content -Path $mockDependenciesPsd1FilePath -Value $extensionDependencies

                Mock Import-PowerShellDataFile -ParameterFilter { $Path -ne $mockDependenciesPsd1FilePath } { $mockLegacyModuleManifest }

                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {}
    
            It 'Should resolve no dependencies' {
                $deps | Should -BeNullOrEmpty
            }
            It 'Should log a deprecation warning' {
                Should -Invoke Write-Warning -Times 1 -Exactly -Scope Context
            }
        }

        Context 'Module manifest private data definition' {
            BeforeAll {
                $mockModuleManifest = @{
                    RootModule = "an-extension"
                    PrivateData = @{
                        PSData = @{
                            ExternalModuleDependencies = @()
                        }
                        ZeroFailed = @{
                            ExtensionDependencies = @()
                        }
                    }
                }
                Mock Import-PowerShellDataFile { $mockModuleManifest }
                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {}
    
            It 'Should resolve no dependencies' {
                $deps | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Single dependency' {

        Context 'Legacy definition' {

            BeforeAll {
                $mockDependenciesPsd1FilePath = Join-Path $extensionPath 'dependencies.psd1'
                $extensionDependencies = @'
@{
    Name = "an-extension"
    Version = "1.0.0"
}
'@
                Set-Content -Path $mockDependenciesPsd1FilePath -Value $extensionDependencies

                Mock Import-PowerShellDataFile -ParameterFilter { $Path -ne $mockDependenciesPsd1FilePath } { $mockLegacyModuleManifest }

                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {}
    
            It 'Should resolve the dependency' {
                $deps.Count | Should -Be 1
            }
            It 'Should return the correct dependency metadata' {
                $deps[0].Name | Should -Be 'an-extension'
                $deps[0].Version | Should -Be '1.0.0'
            }
            It 'Should log a deprecation warning' {
                Should -Invoke Write-Warning -Times 1 -Exactly -Scope Context
            }
        }

        Context 'Module manifest private data definition' {
            BeforeAll {
                $mockModuleManifest = @{
                    RootModule = "an-extension"
                    PrivateData = @{
                        PSData = @{
                            ExternalModuleDependencies = @()
                        }
                        ZeroFailed = @{
                            ExtensionDependencies = @(
                                @{
                                    Name = "an-extension"
                                    Version = "1.0.0"
                                }
                            )
                        }
                    }
                }
                Mock Import-PowerShellDataFile { $mockModuleManifest }
                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {}
    
            It 'Should resolve the dependency' {
                $deps.Count | Should -Be 1
            }
            It 'Should return the correct dependency metadata' {
                $deps[0].Name | Should -Be 'an-extension'
                $deps[0].Version | Should -Be '1.0.0'
            }
        }
    }

    Context 'Multiple dependencies' {

        Context 'Legacy definition' {
            BeforeAll {
                $mockDependenciesPsd1FilePath = Join-Path $extensionPath 'dependencies.psd1'
                $extensionDependencies = @'
@(
    @{
        Name = "an-extension"
        Version = "1.0.0"
    }
    @{
        Name = "another-extension"
        Version = "2.0.0"
    }
    @{
        Name = "an-extension-from-git"
        GitRepository = "https://github.com/myOrg/myExtension"
        GitRef = "main"
    }
)
'@
                Set-Content -Path $mockDependenciesPsd1FilePath -Value $extensionDependencies
                
                Mock Import-PowerShellDataFile -ParameterFilter { $Path -ne $mockDependenciesPsd1FilePath } { $mockLegacyModuleManifest }
                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {
                Remove-Item $mockDependenciesPsd1FilePath
            }

            It 'Should only resolve a single dependency' {
                $deps.Count | Should -Be 1
            }
            It 'Should return the correct dependency metadata' {
                $deps[0].Name | Should -Be 'an-extension'
                $deps[0].Version | Should -Be '1.0.0'
            }
            It 'Should log an unsupported warning' {
                Should -Invoke Write-Warning -Times 2 -Exactly -Scope Context
            }
        }

        Context 'Module manifest private data definition' {
            BeforeAll {
                $mockModuleManifest = @{
                    RootModule = "an-extension"
                    PrivateData = @{
                        PSData = @{
                            ExternalModuleDependencies = @()
                        }
                        ZeroFailed = @{
                            ExtensionDependencies = @(
                                @{
                                    Name = "an-extension"
                                    Version = "1.0.0"
                                }
                                @{
                                    Name = "another-extension"
                                    Version = "2.0.0"
                                }
                                @{
                                    Name = "an-extension-from-git"
                                    GitRepository = "https://github.com/myOrg/myExtension"
                                    GitRef = "main"
                                }
                            )
                        }
                    }
                }
                Mock Import-PowerShellDataFile { $mockModuleManifest }
                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {}

            It 'Should resolve all the dependencies' {
                $deps.Count | Should -Be 3
            }
            It 'Should return the correct dependency metadata' {
                $deps[0].Name | Should -Be 'an-extension'
                $deps[0].Version | Should -Be '1.0.0'
                $deps[1].Name | Should -Be 'another-extension'
                $deps[1].Version | Should -Be '2.0.0'
                $deps[2].Name | Should -Be 'an-extension-from-git'
                $deps[2].GitRepository | Should -Be 'https://github.com/myOrg/myExtension'
                $deps[2].GitRef | Should -Be 'main'
            }
        }

        Context 'Module manifest private data definition - mixed syntax' {
            BeforeAll {
                $mockModuleManifest = @{
                    RootModule = "an-extension"
                    PrivateData = @{
                        PSData = @{
                            ExternalModuleDependencies = @()
                        }
                        ZeroFailed = @{
                            ExtensionDependencies = @(
                                "an-extension"
                                @{
                                    Name = "another-extension"
                                    Version = "2.0.0"
                                }
                            )
                        }
                    }
                }
                Mock Import-PowerShellDataFile { $mockModuleManifest }
                [array]$deps = Get-ExtensionDependencies $extensionConfig
            }
            AfterAll {}

            It 'Should resolve all the dependencies' {
                $deps.Count | Should -Be 2
            }
            It 'Should return the correct dependency metadata' {
                $deps[0].Name | Should -Be 'an-extension'
                $deps[1].Name | Should -Be 'another-extension'
                $deps[1].Version | Should -Be '2.0.0'
            }
        }
    }

    Context 'Invalid dependency configuration' {
        BeforeAll {
            $mockModuleManifest = @{
                RootModule = "an-extension"
                PrivateData = @{
                    PSData = @{
                        ExternalModuleDependencies = @()
                    }
                    ZeroFailed = @{
                        ExtensionDependencies = @(
                            @{
                                InvalidKey = "InvalidValue"
                            }
                        )
                    }
                }
            }
            Mock Import-PowerShellDataFile { $mockModuleManifest }
        }
        AfterAll {}

        It 'Should throw an exception with the correct message' {
            {
                Get-ExtensionDependencies $extensionConfig
            } | Should -Throw "Failed to resolve extension metadata for dependency due to invalid configuration: Invalid extension configuration syntax*"
        }
    }
    Context 'Unknown ZF configuration' {
        BeforeAll {
            $mockModuleManifest = @{
                RootModule = "an-extension"
                PrivateData = @{
                    PSData = @{
                        ExternalModuleDependencies = @()
                    }
                    ZeroFailed = @{
                        RandomKey = 'foo'
                    }
                }
            }
            Mock Import-PowerShellDataFile { $mockModuleManifest }
            Mock Write-Warning {}
        }
        AfterAll {}

        It 'Should log a warning about unknown configuration settings' {
            Get-ExtensionDependencies $extensionConfig

            Should -Invoke Write-Warning -ParameterFilter {
                $Message -eq "Unknown 'ZeroFailed' configuration keys were detected in the extension's module manifest: RandomKey"
            }
        }
    }
}