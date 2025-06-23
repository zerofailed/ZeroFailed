# <copyright file="Get-ExtensionDependencies.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Resolve-ExtensionMetadata.ps1')
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
    }

    Context 'Single dependency' {
        BeforeAll {
            $extensionDependencies = @'
@{
    Name = "an-extension"
    Version = "1.0.0"
}
'@
            Set-Content -Path (Join-Path $extensionPath 'dependencies.psd1') -Value $extensionDependencies
            [array]$deps = Get-ExtensionDependencies $extensionConfig
        }
        AfterAll {}

        It 'Should resolve the dependency' {
            $deps.Count | Should -Be 1
        }
        It 'Should return the dependency metadata' {
            $deps[0].Version | Should -Be '1.0.0'
        }
    }

    Context 'Multiple dependencies' {
        BeforeAll {
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
)
'@
            Set-Content -Path (Join-Path $extensionPath 'dependencies.psd1') -Value $extensionDependencies
            [array]$deps = Get-ExtensionDependencies $extensionConfig
        }
        AfterAll {}

        It 'Should resolve all the dependencies' {
            $deps.Count | Should -Be 2
        }
        It 'Should return the dependency metadata' {
            $deps[0].Version | Should -Be '1.0.0'
            $deps[1].Version | Should -Be '2.0.0'
        }
    }
}