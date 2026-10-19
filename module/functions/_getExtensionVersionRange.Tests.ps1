# <copyright file="_getExtensionVersionRange.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getExtensionVersionRange' {

    It 'Caps the range below the next major version' {
        $range = _getExtensionVersionRange -MinimumVersion '1.4.2'

        $range.Minimum | Should -Be ([semver]'1.4.2')
        $range.Maximum | Should -Be ([semver]'2.0.0')
        $range.Text | Should -Be '[1.4.2,2.0.0)'
    }

    It 'Caps a 0.x range below the next minor version' {
        (_getExtensionVersionRange -MinimumVersion '0.3.1').Text | Should -Be '[0.3.1,0.4.0)'
    }

    It 'Caps a 0.0.x range below the next patch version' {
        (_getExtensionVersionRange -MinimumVersion '0.0.3').Text | Should -Be '[0.0.3,0.0.4)'
    }

    It 'Accepts <MinimumVersion>, which has fewer than 3 parts' -TestCases @(
        @{ MinimumVersion = '1.4'; Expected = '[1.4.0,2.0.0)' }
        @{ MinimumVersion = '2'; Expected = '[2.0.0,3.0.0)' }
    ) {
        (_getExtensionVersionRange -MinimumVersion $MinimumVersion).Text | Should -Be $Expected
    }

    It 'Keeps a pre-release label' {
        $range = _getExtensionVersionRange -MinimumVersion '1.4.0-beta.1'

        $range.Minimum | Should -Be ([semver]'1.4.0-beta.1')
        $range.Text | Should -Be '[1.4.0-beta.1,2.0.0)'
    }

    It 'Throws for <MinimumVersion>, which is not a semantic version' -TestCases @(
        @{ MinimumVersion = 'main' }
        @{ MinimumVersion = '1.2.3.4' }
        @{ MinimumVersion = 'v1.2.3' }
    ) {
        { _getExtensionVersionRange -MinimumVersion $MinimumVersion } | Should -Throw "Invalid minimum version '$MinimumVersion'*"
    }
}
