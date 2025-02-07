# <copyright file="Get-InstalledExtensionDetails.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
}

Describe 'Get-InstalledExtensionDetails' {
    # Setup TestDrive with sample extension definitions
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        
        # Create a sample extension in TestDrive
        $extension1Ver = "1.0.0"
        $extension1Path = Join-Path -Path $targetPath -ChildPath 'TestExtension1' $extension1Ver
        $extension1Manifest = @"
@{
    ModuleVersion = '$extension1Ver'
    Author = 'TestAuthor1'
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
        New-Item -Path $extension1Path -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $extension1Path -ChildPath 'TestExtension1.psd1') -ItemType File -Value $extension1Manifest -Force | Out-Null


        # Create another sample extension in TestDrive
        $extension2Ver = "2.0.0"
        $extension2Path = Join-Path -Path $targetPath -ChildPath 'TestExtension2' $extension2Ver
        $extension2Manifest = @"
@{
    ModuleVersion = '$extension2Ver'
    Author = 'TestAuthor2'
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
        New-Item -Path $extension2Path -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $extension2Path -ChildPath 'TestExtension2.psd1') -ItemType File -Value $extension2Manifest -Force | Out-Null
        

        # Create a pre-releases sample extension in TestDrive
        $preRelExtensionVer = "1.0.0"
        $preRelExtensionPath = Join-Path -Path $targetPath -ChildPath 'TestPreRelExtension' $preRelExtensionVer
        $preRelTestExtensionManifest = @"
@{
    ModuleVersion = '$preRelExtensionVer'
    Author = 'TestPreRelAuthor'
    PrivateData = @{
        PSData = @{
            Prerelease = 'beta0001'
        }
    }
}
"@
        New-Item -Path $preRelExtensionPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $preRelExtensionPath -ChildPath 'TestPreRelExtension.psd1') -ItemType File -Value $preRelTestExtensionManifest -Force | Out-Null
    }


    It 'Should find an installed extension (without version constraints)' {
        # Arrange
        $expected = @{
            Name = 'TestExtension1'
            Version = '1.0.0'
            Author = 'TestAuthor1'
        }

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name $expected.Name -TargetPath $targetPath

        # Assert
        $path | Should -BeOfType 'String'
        $path | Should -Be (Join-Path $targetPath $expected.Name $expected.Version)
        $version | Should -BeOfType 'String'
        $version | Should -Be $expected.Version
    }

    It 'Should find an installed extension (with version constraint)' {
        # Arrange
        $expected = @{
            Name = 'TestExtension2'
            Version = '2.0.0'
            Author = 'TestAuthor2'
        }

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name $expected.Name -Version $expected.Version -TargetPath $targetPath

        # Assert
        $path | Should -BeOfType 'String'
        $path | Should -Be (Join-Path $targetPath $expected.Name $expected.Version)
        $version | Should -BeOfType 'String'
        $version | Should -Be $expected.Version
    }

    It 'Should find an installed pre-release extension when requested to do so (without version constraints)' {
        # Arrange
        $expected = @{
            Name = 'TestPreRelExtension'
            Version = '1.0.0'
            Author = 'TestPreRelAuthor'
            PreRelease = 'beta0001'
        }

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name $expected.Name -PreRelease -TargetPath $targetPath

        # Assert
        $path | Should -BeOfType 'String'
        $path | Should -Be (Join-Path $targetPath $expected.Name $expected.Version)
        $version | Should -BeOfType 'String'
        $version | Should -Be "$($expected.Version)-$($expected.PreRelease)"
    }

    It 'Should find an installed pre-release extension when requested to do so (with version constraint)' {
        # Arrange
        $expected = @{
            Name = 'TestPreRelExtension'
            Version = '1.0.0'
            Author = 'TestPreRelAuthor'
            PreRelease = 'beta0001'
        }

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name $expected.Name -Version "1.0.0" -PreRelease -TargetPath $targetPath

        # Assert
        $path | Should -BeOfType 'String'
        $path | Should -Be (Join-Path $targetPath $expected.Name $expected.Version)
        $version | Should -BeOfType 'String'
        $version | Should -Be "$($expected.Version)-$($expected.PreRelease)"
    }

    It 'Should find an installed pre-release extension when implied from the version constraint' {
        # Arrange
        $expected = @{
            Name = 'TestPreRelExtension'
            Version = '1.0.0'
            Author = 'TestPreRelAuthor'
            PreRelease = 'beta0001'
        }

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name $expected.Name -Version "1.0.0-beta0001" -PreRelease -TargetPath $targetPath

        # Assert
        $path | Should -BeOfType 'String'
        $path | Should -Be (Join-Path $targetPath $expected.Name $expected.Version)
        $version | Should -BeOfType 'String'
        $version | Should -Be "$($expected.Version)-$($expected.PreRelease)"
    }

    It 'Should return null when no installed extension is found (without version constraints)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'NonExistentModule' -TargetPath $targetPath

        # Assert
        $result | Should -BeNullOrEmpty
    }

    It 'Should return null when no installed extension is found (with version constraint)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'NonExistentModule' -Version "1.0.0" -TargetPath $targetPath

        # Assert
        $result | Should -BeNullOrEmpty
    }

    It 'Should return null when only a pre-release version is installed and a stable version is requested (without version constraints)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestPreRelExtension' -TargetPath $targetPath

        # Assert
        $result | Should -BeNullOrEmpty
    }

    It 'Should return null when only a pre-release version is installed and a stable version is requested (with version constraints)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestPreRelExtension' -Version "1.0.0" -TargetPath $targetPath

        # Assert
        $result | Should -BeNullOrEmpty
    }
}