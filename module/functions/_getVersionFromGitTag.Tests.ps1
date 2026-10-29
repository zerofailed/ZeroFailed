# <copyright file="_getVersionFromGitTag.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getVersionFromGitTag' {

    It 'Returns <Expected> for <Ref>' -TestCases @(
        @{ Ref = 'refs/tags/1.4.2'; Expected = '1.4.2' }
        @{ Ref = 'refs/tags/v1.4.2'; Expected = '1.4.2' }
        @{ Ref = 'refs/tags/1.1.0-preview.1'; Expected = '1.1.0-preview.1' }
        @{ Ref = 'refs/tags/1.0.0+build.5'; Expected = '1.0.0+build.5' }
    ) {
        $result = _getVersionFromGitTag -Ref $Ref

        $result | Should -BeOfType [semver]
        "$result" | Should -Be $Expected
    }

    It 'Returns null for <Ref>, which is not a release tag' -TestCases @(
        @{ Ref = 'refs/tags/v1' }
        @{ Ref = 'refs/tags/1.4' }
        @{ Ref = 'refs/tags/1.0.0.0' }
        @{ Ref = 'refs/tags/release-1.0.0' }
        @{ Ref = 'refs/heads/1.0.0' }
        @{ Ref = '1.0.0' }
        @{ Ref = 'main' }
        @{ Ref = '' }
    ) {
        _getVersionFromGitTag -Ref $Ref | Should -BeNullOrEmpty
    }
}
