# <copyright file="_testExtensionVersionInRange.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')

    Set-StrictMode -Version Latest
}

Describe '_testExtensionVersionInRange' {

    BeforeAll {
        $range = _getExtensionVersionRange -MinimumVersion '1.4.0'
    }

    It 'Returns <Expected> for <Version>' -TestCases @(
        @{ Version = '1.3.9'; Expected = $false }
        @{ Version = '1.4.0'; Expected = $true }
        @{ Version = '1.9.12'; Expected = $true }
        @{ Version = '2.0.0'; Expected = $false }
    ) {
        _testExtensionVersionInRange -Version $Version -Range $range | Should -Be $Expected
    }

    It 'Excludes pre-release versions unless they are requested' {
        _testExtensionVersionInRange -Version '1.5.0-beta.1' -Range $range | Should -Be $false
        _testExtensionVersionInRange -Version '1.5.0-beta.1' -Range $range -PreRelease | Should -Be $true
    }

    It 'Excludes pre-release versions of the next major version' {
        _testExtensionVersionInRange -Version '2.0.0-beta.1' -Range $range -PreRelease | Should -Be $false
    }

    It 'Excludes pre-release versions of the minimum version' {
        _testExtensionVersionInRange -Version '1.4.0-beta.1' -Range $range -PreRelease | Should -Be $false
    }
}
