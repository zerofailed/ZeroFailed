# <copyright file="Get-ExtensionFromPowerShellRepository.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
}

Describe 'Get-ExtensionFromPowerShellRepository' {
    # Setup TestDrive with sample extension definitions
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
    }

    Context 'When installing an extension without version constraint' {

        BeforeAll {
            $name = 'SamplePsModule'
            $moduleInfo = Find-Module $name
            $result = Get-ExtensionFromPowerShellRepository -Name $name -TargetPath $targetPath -PSRepository PSGallery
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }
        
        It 'Should install the extension into the correct location' {
            Test-Path $result.Path | Should -Be $true
        }
        It "Should install the latest stable version" {
            $result.Version | Should -Be $moduleInfo.Version
        }
        It "Should mark the extension as enabled" {
            $result.Enabled | Should -Be $true
        }
    }

    Context 'When installing an extension without version constraint with pre-release support' {

        BeforeAll {
            $name = 'SamplePsModule'
            $moduleInfo = Find-Module $name -AllowPrerelease
            $result = Get-ExtensionFromPowerShellRepository -Name $name -TargetPath $targetPath -PSRepository PSGallery -PreRelease
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }
        
        It 'Should install the extension into the correct location and return path metadata' {
            $result.Path | Should -Not -BeNullOrEmpty
            Test-Path $result.Path | Should -Be $true
            $result.Path | Should -Be (Join-Path $targetPath $name ($result.Version -split '-')[0])
        }
        It "Should install the latest pre-release version and return version metadata" {
            $result.Version | Should -Be $moduleInfo.Version
            ([semver]$result.Version).PreReleaseLabel | Should -Not -BeNullOrEmpty
        }
        It "Should mark the extension as enabled" {
            $result.Enabled | Should -Be $true
        }
    }

    Context 'When installing an extension not available in the repository' {

        BeforeAll {
            $name = 'NonExistentExtension'
            $result = Get-ExtensionFromPowerShellRepository -Name $name -TargetPath $targetPath -PSRepository PSGallery
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }

        It 'Should not provide path metadata' {
            $result.Path | Should -BeNullOrEmpty
        }
        It "Should not provide version metadata" {
            $result.Version | Should -BeNullOrEmpty
        }
        It "Should mark the extension as disabled" {
            $result.Enabled | Should -Be $false
        }
    }

    Context 'When installing an extension that is already installed' {
        BeforeAll {
            Mock Save-Module {}
            $name = 'AlreadyInstalledExtension'
            $mockExtensionManifest = @"
@{
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
            New-Item -Path (Join-Path $targetPath $name "1.0.0" "AlreadyInstalledExtension.psd1") -ItemType File -Value $mockExtensionManifest -Force | Out-Null
            $result = Get-ExtensionFromPowerShellRepository -Name $name -TargetPath $targetPath -PSRepository PSGallery
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }

        It 'Should not attempt to install from the repository' {
            Should -Invoke -CommandName Save-Module -Times 0
        }
        It 'Should return path metadata' {
            $result.Path | Should -Not -BeNullOrEmpty
            Test-Path $result.Path | Should -Be $true
        }
        It 'Should return version metadata' {
            $result.Version | Should -Be '1.0.0'
        }
        It "Should mark the extension as enabled" {
            $result.Enabled | Should -Be $true
        }
    }

    Context 'When installing an extension that is already installed but not with the specified version' {
        BeforeAll {
            $name = 'SamplePsModule'
            $moduleInfo = Find-Module $name
            $mockExtensionManifest = @"
@{
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
            New-Item -Path (Join-Path $targetPath $name "0.0.9" "SamplePsModule.psd1") -ItemType File -Value $mockExtensionManifest -Force | Out-Null
            $result = Get-ExtensionFromPowerShellRepository -Name $name -Version $moduleInfo.Version -TargetPath $targetPath -PSRepository PSGallery
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }

        It 'Should install the extension into the correct location' {
            Test-Path $result.Path | Should -Be $true
        }
        It 'Should install the correct version' {
            $result.Path | Should -BeLike ("*{0}{1}" -f ([IO.Path]::DirectorySeparatorChar), $moduleInfo.Version)
        }
        It "Should mark the extension as enabled" {
            $result.Enabled | Should -Be $true
        }
    }

    Context 'When installing an extension, without version constraint, that is already installed but is not the latest version' {
        BeforeAll {
            Mock Save-Module {}
            $name = 'SamplePsModule'
            $mockExtensionManifest = @"
@{
    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}
"@
            New-Item -Path (Join-Path $targetPath $name "0.0.9" "SamplePsModule.psd1") -ItemType File -Value $mockExtensionManifest -Force | Out-Null
            $result = Get-ExtensionFromPowerShellRepository -Name $name -TargetPath $targetPath -PSRepository PSGallery
        }
        AfterAll {
            Remove-Item -Path $targetPath/*.* -Recurse -Force
        }

        It 'Should use the existing version' {
            Test-Path $result.Path | Should -Be $true
        }
        It 'Should not upgrade to the latest version' {
            Should -Invoke -CommandName Save-Module -Times 0
            $result.Path | Should -BeLike ("*{0}0.0.9" -f ([IO.Path]::DirectorySeparatorChar), $moduleInfo.Version)
        }
        It "Should mark the extension as enabled" {
            $result.Enabled | Should -Be $true
        }
    }
}