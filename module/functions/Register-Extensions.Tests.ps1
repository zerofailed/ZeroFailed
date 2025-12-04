# <copyright file="Register-Extensions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    $here = Split-Path -Parent $PSCommandPath
    $sut = (Split-Path -Leaf $PSCommandPath) -replace ".Tests"

    . "$here/$sut"

    # Mock Write-Host to keep output clean
    function Write-Host {}

    # Define the dependent function so it can be mocked
    function Register-ExtensionAndDependencies { param($ExtensionConfig, $TargetPath) }

    # Save original env var to restore later
    $script:originalPSModulePath = $env:PSModulePath

    Set-StrictMode -Version Latest
}

AfterAll {
    # Restore env var
    $env:PSModulePath = $script:originalPSModulePath
}

Describe 'Register-Extensions' {

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
            $zfPath = 'TestDrive:\zf_env_path'
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
}
