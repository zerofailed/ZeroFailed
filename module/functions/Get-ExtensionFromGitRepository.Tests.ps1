# <copyright file="Get-ExtensionFromGitRepository.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Update-VendirConfig.ps1')

    Set-StrictMode -Version Latest
}

Describe 'Get-ExtensionFromGitRepository' {

    BeforeAll {
        # Setup .zf folder
        $zfPath = Join-Path -Path TestDrive: -ChildPath '.zf'
        New-Item -Path $zfPath -ItemType Directory -Force | Out-Null
        # Use the $TestDrive form instead of TestDrive: to ensure valid physical paths are passed to vendir
        $targetPath = Join-Path -Path $TestDrive -ChildPath '.zf' 'extensions'
        $cachePath = Join-Path -Path $TestDrive -ChildPath '.zf' '.cache'
        
        Mock Write-Host {}

        # Setup extension config
        $name = 'ZeroFailed.Build.Common'
        $repo = 'https://github.com/zerofailed/ZeroFailed.Build.Common.git'
        $splat = @{
            Name = $name
            TargetPath = $targetPath
            RepositoryUri = $repo
            UseEphemeralVendirConfig = $false
        }
    }

    Context "Unit Tests" {
        # Setup TestDrive with sample extension definitions
        BeforeAll {
            # Define a function simulating the vendir cli tool, so we can mock it
            function vendir {}

            # Mock vendir to simulate downloading an extension
            Mock vendir {
                New-Item -Path $installPath -ItemType Directory -Force | Out-Null
                New-Item -Path (Join-Path $installPath "$name.psd1") -ItemType File | Out-Null
            }
        }

        Context 'Basic processing tests (full mock)' {

            Context 'Installing extension from a simple branch reference' {
                BeforeAll {
                    $gitRef = 'main'
                    $installPath = Join-Path $targetPath "$name/$gitRef"

                    # Mock Update-VendirConfig
                    Mock Update-VendirConfig {
                        New-Item -ItemType Directory -Path $cachePath | Out-Null
                        Set-Content -Path $ConfigPath -Value '[]' | Out-Null
                    }

                    $result = Get-ExtensionFromGitRepository @splat -GitRef $gitRef
                }
                AfterAll {
                    Get-ChildItem -Path $zfPath | Remove-Item -Recurse -Force
                }
        
                It "Should generate a vendir configuration file" {
                    Test-Path (Join-Path $cachePath "zf.$name.vendir.yml") | Should -Be $true
                }
                It "Should mark the extension as enabled" {
                    $result.Enabled | Should -Be $true
                }
            }
        
            Context 'Installing extension using the full Git ref syntax' {
                BeforeAll {
                    $gitRef = 'refs/heads/main'
                    $safeGitRef = 'refs-heads-main'
                    $installPath = Join-Path $targetPath "$name/$safeGitRef"

                    # Mock Update-VendirConfig
                    Mock Update-VendirConfig {
                        New-Item -ItemType Directory -Path $cachePath | Out-Null
                        Set-Content -Path $ConfigPath -Value '[]' | Out-Null
                    }

                    $result = Get-ExtensionFromGitRepository @splat -GitRef $gitRef
                }
                AfterAll {
                    Get-ChildItem -Path $zfPath | Remove-Item -Recurse -Force
                }
        
                It "Should generate a vendir configuration file" {
                    Test-Path (Join-Path $cachePath "zf.$name.vendir.yml") | Should -Be $true
                }
                It "Should mark the extension as enabled" {
                    $result.Enabled | Should -Be $true
                }
            }
        }

        Context 'vendir configuration file tests (vendir mocked)' {
            BeforeAll {
                $expectedVendirConfigPath = Join-Path $cachePath "zf.$name.vendir.yml"
            }

            Context 'Installing extension from a simple branch reference' {
                BeforeAll {
                    $gitRef = 'main'
                    $installPath = Join-Path $targetPath "$name/$gitRef"

                    $result = Get-ExtensionFromGitRepository @splat -GitRef $gitRef
                }
                AfterAll {
                    Get-ChildItem -Path $zfPath | Remove-Item -Recurse -Force
                }

                It 'Should generate a vendir configuration file' {
                    Test-Path $expectedVendirConfigPath | Should -Be $true
                }
                It 'Should generate valid YAML' {
                    Get-Content -Path $expectedVendirConfigPath | ConvertFrom-Yaml | Should -BeOfType [hashtable]
                }
                It 'Should generate YAML with relative paths' {
                    Get-Content -Path $expectedVendirConfigPath |
                        ConvertFrom-Yaml |
                        Select-Object -ExpandProperty directories |
                        Select-Object -First 1 |
                        Select-Object -ExpandProperty path |
                        Should -Be ('..{0}extensions{0}ZeroFailed.Build.Common{0}main' -f [IO.Path]::DirectorySeparatorChar)
                }
                It "Should mark the extension as enabled" {
                    $result.Enabled | Should -Be $true
                }
            }
        }
    }

    Context 'vendir integration tests' {
        Context 'Installing extension from a simple branch reference' {
            BeforeAll {
                $gitRef = 'main'
                $installPath = Join-Path $targetPath "$name/$gitRef"

                $result = Get-ExtensionFromGitRepository @splat -GitRef $gitRef
            }
            AfterAll {
                Get-ChildItem -Path $zfPath | Remove-Item -Recurse -Force
            }
    
            It "Should generate a vendir configuration file" {
                Test-Path (Join-Path $cachePath "zf.$name.vendir.yml") | Should -Be $true
            }
            It "Should mark the extension as enabled" {
                $result.Enabled | Should -Be $true
            }
            It "Should download the extension" {
                (Join-Path $installPath 'ZeroFailed.Build.Common.psm1') | Should -Exist
            }
        }
    }
}