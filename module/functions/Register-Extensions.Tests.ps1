# <copyright file="Register-Extensions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"

    . "$here/$sut"

    # Mock Write-Host to keep output clean
    function Write-Host {}

    # Define the dependent functions so they can be mocked
    function Register-ExtensionAndDependencies { param($ExtensionConfig, $TargetPath, $RequiredBy, $LockedExtensions) }
    function _readExtensionLockFile { param($Path) }
    function _writeExtensionLockFile { param($Path, $Extensions) }
    function _assertExtensionLockSatisfied { param($Extensions, $LockedExtensions, $LockFilePath) }

    # Save original env var to restore later
    $script:originalPSModulePath = $env:PSModulePath

    Set-StrictMode -Version Latest
}

AfterAll {
    # Restore env var
    $env:PSModulePath = $script:originalPSModulePath
}

Describe 'Register-Extensions' {

    BeforeAll {
        Mock _readExtensionLockFile {}
        Mock _writeExtensionLockFile {}
        Mock _assertExtensionLockSatisfied {}
    }

    Context 'Directory and Environment Setup' {
        It 'Should create the extensions directory if it does not exist' {
            # Arrange
            $zfPath = 'TestDrive:\zf_create_dir'
            $extensionsConfig = @(@{ Name = 'Dummy' })
            $defaultRepo = 'PSGallery'

            Mock 'Register-ExtensionAndDependencies' { return @{} }

            # Act
            Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath

            # Assert
            Test-Path (Join-Path $zfPath 'extensions') | Should -Be $true
        }

        It 'Should add the extensions directory to the front of PSModulePath' {
            # Arrange
            $zfPath = Join-Path $TestDrive 'zf_env_path'
            $extensionsConfig = @(@{ Name = 'Dummy' })
            $defaultRepo = 'PSGallery'
            $expectedPath = Join-Path $zfPath 'extensions'

            Mock 'Register-ExtensionAndDependencies' { return @{} }

            # Act
            Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath

            # Assert
            $paths = $env:PSModulePath -split [IO.Path]::PathSeparator
            $paths[0] | Should -Be $expectedPath
        }
    }

    Context 'Extension Registration' {
        It 'Should call Register-ExtensionAndDependencies for each extension in the config' {
            # Arrange
            $zfPath = 'TestDrive:\zf_registration'
            $extensionsConfig = @(
                @{ Name = 'Extension1'; Version = '1.0.0' }
                @{ Name = 'Extension2'; Version = '2.0.0' }
            )
            $defaultRepo = 'PSGallery'

            Mock 'Register-ExtensionAndDependencies' { 
                param($ExtensionConfig, $TargetPath)
                return @{ Name = $ExtensionConfig.Name; Status = 'Installed' } 
            }

            # Act
            $result = Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath

            # Assert
            Assert-MockCalled 'Register-ExtensionAndDependencies' -Times 2
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'Extension1'
            $result[1].Name | Should -Be 'Extension2'
        }

        It 'Should pass the correct arguments to Register-ExtensionAndDependencies' {
            # Arrange
            $zfPath = 'TestDrive:\zf_args'
            $extensionsConfig = @(
                @{ Name = 'Extension1' }
            )
            $defaultRepo = 'PSGallery'
            $expectedTargetPath = Join-Path $zfPath 'extensions'

            Mock 'Register-ExtensionAndDependencies' { return @{} }

            # Act
            Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath

            # Assert
            Assert-MockCalled 'Register-ExtensionAndDependencies' -ParameterFilter {
                $ExtensionConfig.Name -eq 'Extension1' -and
                $TargetPath -eq $expectedTargetPath
            }
        }
    }

    Context 'Lock file' {
        BeforeAll {
            $zfPath = Join-Path $TestDrive 'zf_lock'
            $expectedLockFilePath = Join-Path $zfPath 'extensions.lock.json'
            $extensionsConfig = @(
                @{ Name = 'Extension1' }
                @{ Name = 'Extension2' }
            )
            $defaultRepo = 'PSGallery'

            Mock 'Register-ExtensionAndDependencies' {
                return @{ Name = $ExtensionConfig.Name; Enabled = $true }
            }
        }

        Context 'When the lock mode is not specified' {
            BeforeAll {
                $result = Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath
            }

            It 'Resolves extensions without using the lock file' {
                Should -Invoke _readExtensionLockFile -Times 0 -Scope Context
                Should -Invoke 'Register-ExtensionAndDependencies' -Times 2 -Scope Context -ParameterFilter { $null -eq $LockedExtensions }
            }

            It 'Writes the lock file with every registered extension' {
                Should -Invoke _writeExtensionLockFile -Times 1 -Scope Context -ParameterFilter {
                    $Path -eq $expectedLockFilePath -and
                    $Extensions.Count -eq 2 -and
                    $Extensions[0].Name -eq 'Extension1' -and
                    $Extensions[1].Name -eq 'Extension2'
                }
            }

            It 'Returns the registered extensions' {
                $result.Count | Should -Be 2
            }
        }

        Context 'When the lock mode is Off' {
            BeforeAll {
                $result = Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath -LockMode 'Off'
            }

            It 'Does not read, write or check the lock file' {
                Should -Invoke _readExtensionLockFile -Times 0 -Scope Context
                Should -Invoke _writeExtensionLockFile -Times 0 -Scope Context
                Should -Invoke _assertExtensionLockSatisfied -Times 0 -Scope Context
            }

            It 'Returns the registered extensions' {
                $result.Count | Should -Be 2
            }
        }

        Context 'When the lock mode is Frozen' {
            BeforeAll {
                # Named so the mock does not see a variable of the same name in Register-Extensions
                $mockLockedExtensions = @{ Extension1 = @{ resolved = '1.0.0' } }
                Mock _readExtensionLockFile { $mockLockedExtensions }

                $result = Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath -LockMode 'Frozen'
            }

            It 'Reads the lock file' {
                Should -Invoke _readExtensionLockFile -Times 1 -Scope Context -ParameterFilter { $Path -eq $expectedLockFilePath }
            }

            It 'Resolves extensions using the lock file' {
                Should -Invoke 'Register-ExtensionAndDependencies' -Times 2 -Scope Context -ParameterFilter { $LockedExtensions.Extension1.resolved -eq '1.0.0' }
            }

            It 'Checks the registered extensions against the lock file' {
                Should -Invoke _assertExtensionLockSatisfied -Times 1 -Scope Context -ParameterFilter {
                    $Extensions.Count -eq 2 -and
                    $LockedExtensions.Extension1.resolved -eq '1.0.0' -and
                    $LockFilePath -eq $expectedLockFilePath
                }
            }

            It 'Does not write the lock file' {
                Should -Invoke _writeExtensionLockFile -Times 0 -Scope Context
            }
        }

        Context 'When the lock mode is Frozen and there is no lock file' {
            It 'Throws an error before resolving any extensions' {
                Mock _readExtensionLockFile { $null }

                { Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath -LockMode 'Frozen' } |
                    Should -Throw "*lock mode is 'Frozen', but there is no lock file at '$expectedLockFilePath'*"
                Should -Invoke 'Register-ExtensionAndDependencies' -Times 0 -Scope It
            }
        }

        Context 'When the lock mode is not valid' {
            It 'Throws an error' {
                { Register-Extensions -ExtensionsConfig $extensionsConfig -DefaultPSRepository $defaultRepo -ZfPath $zfPath -LockMode 'Sometimes' } |
                    Should -Throw
            }
        }
    }
}
