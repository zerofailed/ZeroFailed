# <copyright file="Resolve-ExtensionMetadata.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_resolveModuleNameFromPath.ps1')
}

Describe 'Resolve-ExtensionMetadata' {
    BeforeAll {
        # Setup mock extension on filesystem
        $extensionPath = Join-Path TestDrive: "MyExtension" "MyExtension.psd1"
        New-Item -Path $extensionPath -ItemType File -Force | Out-Null
    }

    Context 'Resolving from string-formatted configuration' {
        Context 'Valid specification by name' {
            BeforeAll {
                $config = "MyExtension"
                $result = Resolve-ExtensionMetadata $config
            }

            It 'Should return name metadata' {
                $result.Name | Should -Be $config
            }
            It 'Should not return path metadata' {
                $result.Keys | Should -Not -Contain 'Path'
            }
        }
        Context 'Valid specification by path' {
            BeforeAll {
                $config = "$extensionPath"
                $result = Resolve-ExtensionMetadata $config
            }
    
            It 'Should return path metadata' {
                $result.Path | Should -Be $config
            }
            It 'Should return name metadata' {
                $result.Name | Should -Be 'MyExtension'
            }
        }
    }

    Context 'Resolving from hashtable-formatted configuration' {
        Context 'Minimal valid specification by name' {
            BeforeAll {
                $config = @{
                    Name = "MyExtension"
                }
                $result = Resolve-ExtensionMetadata $config
            }

            It 'Should return name metadata' {
                $result.Name | Should -Be $config.Name
            }
            It 'Should not return path metadata' {
                $result.Keys | Should -Not -Contain 'Path'
            }
        }
        Context 'Minimal valid specification by path' {
            BeforeAll {
                $config = @{
                    Path = "$extensionPath"
                }
                $result = Resolve-ExtensionMetadata $config
            }
    
            It 'Should return path metadata' {
                $result.Path | Should -Be $config.Path
            }
            It 'Should return name metadata' {
                $result.Name | Should -Be 'MyExtension'
            }
        }
        Context 'Valid specification by name & version' {
            BeforeAll {
                $config = @{
                    Name = "MyExtension"
                    Version = "1.0.0"
                }
                $result = Resolve-ExtensionMetadata $config
            }

            It 'Should return name metadata' {
                $result.Name | Should -Be $config.Name
            }
            It 'Should return version metadata' {
                $result.Version | Should -Be $config.Version
            }
            It 'Should not return path metadata' {
                $result.Keys | Should -Not -Contain 'Path'
            }
        }
    }
}