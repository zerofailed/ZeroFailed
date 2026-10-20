# <copyright file="_getCompleteExtensionVersion.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest
}

Describe '_getCompleteExtensionVersion' {

    It 'Returns <Expected> for <Version>' -TestCases @(
        @{ Version = '1'; Expected = '1.0.0' }
        @{ Version = '1.4'; Expected = '1.4.0' }
        @{ Version = '1.4.2'; Expected = '1.4.2' }
        @{ Version = '1.4-beta0001'; Expected = '1.4.0-beta0001' }
        @{ Version = '1.4.2-preview.1'; Expected = '1.4.2-preview.1' }
    ) {
        _getCompleteExtensionVersion -Version $Version | Should -Be $Expected
    }

    It 'Returns nothing for <Version>' -TestCases @(
        @{ Version = '' }
        @{ Version = 'v1.4.2' }
        @{ Version = '1.4.2.1' }
        @{ Version = '[1.0,2.0)' }
    ) {
        _getCompleteExtensionVersion -Version $Version | Should -BeNullOrEmpty
    }
}
