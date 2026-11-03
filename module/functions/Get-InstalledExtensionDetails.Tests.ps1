# <copyright file="Get-InstalledExtensionDetails.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getCompleteExtensionVersion.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionVersionInRange.ps1')
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
        $extension2aVer = "2.0.0"
        $extension2aPath = Join-Path -Path $targetPath -ChildPath 'TestExtension2' $extension2aVer
        $extension2aManifest = @"
@{
    ModuleVersion = '$extension2aVer'
    Author = 'TestAuthor2'
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
        New-Item -Path $extension2aPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $extension2aPath -ChildPath 'TestExtension2.psd1') -ItemType File -Value $extension2aManifest -Force | Out-Null

        # Create a later pre-release version of the same sample extension in TestDrive
        $extension2bVer = "2.1.0"
        $extension2bPath = Join-Path -Path $targetPath -ChildPath 'TestExtension2' $extension2bVer
        $extension2bManifest = @"
@{
    ModuleVersion = '$extension2bVer'
    Author = 'TestAuthor2'
    PrivateData = @{
        PSData = @{
            Prerelease = 'rc0001'
        }
    }
}
"@
        New-Item -Path $extension2bPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $extension2bPath -ChildPath 'TestExtension2.psd1') -ItemType File -Value $extension2bManifest -Force | Out-Null

        # Create an older stable version of the same sample extension in TestDrive
        $extension2cVer = "1.9.0"
        $extension2cPath = Join-Path -Path $targetPath -ChildPath 'TestExtension2' $extension2cVer
        $extension2cManifest = @"
@{
    ModuleVersion = '$extension2cVer'
    Author = 'TestAuthor2'
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
        New-Item -Path $extension2cPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $extension2cPath -ChildPath 'TestExtension2.psd1') -ItemType File -Value $extension2cManifest -Force | Out-Null
        

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

    It 'Should prefer the latest stable version over a newer pre-release version when no versioning constraints are specified' {
        # Arrange
        $expected = @{
            Name = 'TestExtension2'
            Version = '2.0.0'
            Author = 'TestAuthor2'
        }

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -TargetPath $targetPath

        # Assert
        $path | Should -BeOfType 'String'
        $path | Should -Be (Join-Path $targetPath $expected.Name $expected.Version)
        $version | Should -BeOfType 'String'
        $version | Should -Be $expected.Version
    }

    It 'Should find an older installed version when it is explicitly requested and a newer stable version is also installed' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -Version '1.9.0' -TargetPath $targetPath

        # Assert
        $path | Should -Be (Join-Path $targetPath 'TestExtension2' '1.9.0')
        $version | Should -Be '1.9.0'
    }

    It 'Should find a requested version that has fewer than 3 numeric parts (<Requested>)' -ForEach @(
        @{ Requested = '1.9' }
        @{ Requested = '2' }
    ) {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -Version $Requested -TargetPath $targetPath

        # Assert
        $expected = _getCompleteExtensionVersion -Version $Requested
        $path | Should -Be (Join-Path $targetPath 'TestExtension2' $expected)
        $version | Should -Be $expected
    }

    It 'Should find the requested stable version when pre-release versions are allowed and a newer pre-release version is installed' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -Version '2.0.0' -PreRelease -TargetPath $targetPath

        # Assert
        $path | Should -Be (Join-Path $targetPath 'TestExtension2' '2.0.0')
        $version | Should -Be '2.0.0'
    }

    It 'Should find the requested pre-release version when a stable version is also installed' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -Version '2.1.0-rc0001' -PreRelease -TargetPath $targetPath

        # Assert
        $path | Should -Be (Join-Path $targetPath 'TestExtension2' '2.1.0')
        $version | Should -Be '2.1.0-rc0001'
    }

    It 'Should return null when the requested version is not installed but other versions are' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -Version '3.0.0' -TargetPath $targetPath

        # Assert
        $path | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty
    }

    It 'Should return null when no installed extension is found (without version constraints)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'NonExistentModule' -TargetPath $targetPath

        # Assert
        $path | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty
    }

    It 'Should return null when no installed extension is found (with version constraint)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'NonExistentModule' -Version "1.0.0" -TargetPath $targetPath

        # Assert
        $path | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty
    }

    It 'Should return null when only a pre-release version is installed and a stable version is requested (without version constraints)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestPreRelExtension' -TargetPath $targetPath

        # Assert
        $path | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty
    }

    It 'Should return null when only a pre-release version is installed and a stable version is requested (with version constraints)' {
        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TestPreRelExtension' -Version "1.0.0" -TargetPath $targetPath

        # Assert
        $path | Should -BeNullOrEmpty
        $version | Should -BeNullOrEmpty
    }

    It 'Should ignore folders that are not named after a version, such as a copy from a git repository' {
        # Arrange
        $gitTargetPath = Join-Path -Path TestDrive: -ChildPath 'git-and-psrepository'
        New-Item -Path (Join-Path $gitTargetPath 'MixedExtension' 'main-1f0c8a2e') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $gitTargetPath 'MixedExtension' '.staging-00000000-0000-0000-0000-000000000000') -ItemType Directory -Force | Out-Null
        $stablePath = Join-Path $gitTargetPath 'MixedExtension' '1.0.0'
        New-Item -Path $stablePath -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $stablePath 'MixedExtension.psd1') -Value "@{ ModuleVersion = '1.0.0' }"

        # Act
        $ErrorActionPreference = 'Stop'
        $path,$version = Get-InstalledExtensionDetails -Name 'MixedExtension' -TargetPath $gitTargetPath

        # Assert
        $path | Should -Be $stablePath
        $version | Should -Be '1.0.0'
    }

    It 'Should ignore a copy from a git repository whose tag is a version, when pre-release versions are allowed (<Description>)' -ForEach @(
        @{ Description = 'without a version'; Arguments = @{} ; ExpectedVersion = '1.0.0' }
        @{ Description = 'with the version of the tag'; Arguments = @{ Version = '1.1.0' }; ExpectedVersion = $null }
    ) {
        # Arrange: a git reference such as '1.1.0' is installed in a folder that is named after it and a hash of its
        # source, which is also a valid semantic version with a pre-release label
        $gitTargetPath = Join-Path -Path TestDrive: -ChildPath "git-version-tag-$($Arguments.Count)"
        $gitPath = Join-Path $gitTargetPath 'TagExtension' '1.1.0-1f0c8a2e'
        New-Item -Path $gitPath -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $gitPath 'TagExtension.psd1') -Value "@{ ModuleVersion = '1.1.0' }"
        $stablePath = Join-Path $gitTargetPath 'TagExtension' '1.0.0'
        New-Item -Path $stablePath -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $stablePath 'TagExtension.psd1') -Value "@{ ModuleVersion = '1.0.0' }"

        # Act
        $path,$version = Get-InstalledExtensionDetails -Name 'TagExtension' -TargetPath $gitTargetPath -PreRelease @Arguments

        # Assert
        if ($ExpectedVersion) {
            $path | Should -Be $stablePath
            $version | Should -Be $ExpectedVersion
        }
        else {
            $path | Should -BeNullOrEmpty
            $version | Should -BeNullOrEmpty
        }
    }

    Context 'With a minimum version' {
        It 'Should find the newest installed version below the next major version' {
            # Act
            $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -MinimumVersion '1.5' -TargetPath $targetPath

            # Assert
            $path | Should -Be (Join-Path $targetPath 'TestExtension2' '1.9.0')
            $version | Should -Be '1.9.0'
        }

        It 'Should ignore a newer pre-release version unless pre-release versions are allowed' {
            # Act
            $stablePath,$stableVersion = Get-InstalledExtensionDetails -Name 'TestExtension2' -MinimumVersion '2.0.0' -TargetPath $targetPath
            $preReleasePath,$preReleaseVersion = Get-InstalledExtensionDetails -Name 'TestExtension2' -MinimumVersion '2.0.0' -PreRelease -TargetPath $targetPath

            # Assert
            $stablePath | Should -Be (Join-Path $targetPath 'TestExtension2' '2.0.0')
            $stableVersion | Should -Be '2.0.0'
            $preReleasePath | Should -Be (Join-Path $targetPath 'TestExtension2' '2.1.0')
            $preReleaseVersion | Should -Be '2.1.0-rc0001'
        }

        It 'Should return null when no installed version is in the range' {
            # Act
            $path,$version = Get-InstalledExtensionDetails -Name 'TestExtension2' -MinimumVersion '3.0.0' -TargetPath $targetPath

            # Assert
            $path | Should -BeNullOrEmpty
            $version | Should -BeNullOrEmpty
        }
    }
}