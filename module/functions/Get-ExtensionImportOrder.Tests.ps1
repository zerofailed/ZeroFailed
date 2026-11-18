# <copyright file="Get-ExtensionImportOrder.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    Set-StrictMode -Version Latest

    # An extension, with the names of the extensions that it requires
    function newExtension([string] $Name, [string[]] $Dependencies = @()) {
        @{ Name = $Name; Path = "/zf/$Name"; Enabled = $true; dependencies = @($Dependencies | ForEach-Object { @{ Name = $_ } }) }
    }
}

Describe 'Get-ExtensionImportOrder' {

    Context 'When each extension has its own dependency' {
        It 'Returns the reverse of the given order, with each dependency before the extension that requires it' {
            $extensions = @(
                newExtension 'A' 'CommonA'
                newExtension 'CommonA'
                newExtension 'B' 'CommonB'
                newExtension 'CommonB'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('CommonB', 'B', 'CommonA', 'A')
        }
    }

    Context 'When several extensions share a dependency' {
        It 'Returns the shared dependency before every extension that requires it' {
            # As registered and de-duplicated: 'Common' follows the first extension that requires it
            $extensions = @(
                newExtension 'A' 'Common'
                newExtension 'Common' 'DevOps'
                newExtension 'DevOps'
                newExtension 'B' 'Common'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('DevOps', 'Common', 'B', 'A')
        }
    }

    Context 'When an extension has several dependencies' {
        It 'Returns the later dependency first, so that the earlier one takes precedence' {
            $extensions = @(
                newExtension 'A' 'First', 'Second'
                newExtension 'First'
                newExtension 'Second'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('Second', 'First', 'A')
        }
    }

    Context 'When a dependency is not in the given extensions' {
        It 'Ignores it' {
            $extensions = @(
                newExtension 'A' 'Missing'
                newExtension 'B'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('B', 'A')
        }
    }

    Context 'When a later extension requires an earlier one' {
        It 'Returns the earlier one after the extensions that it does not depend on, so that its definitions take precedence' {
            $extensions = @(
                newExtension 'A'
                newExtension 'B'
                newExtension 'C' 'A'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('B', 'A', 'C')
        }
    }

    Context 'When the dependencies are circular' {
        It 'Returns each extension once, the latest first' {
            $extensions = @(
                newExtension 'A' 'B'
                newExtension 'B' 'A'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('B', 'A')
        }
    }

    Context 'When an extension is given more than once' {
        It 'Returns its first reference once' {
            $first = newExtension 'A'
            $extensions = @(
                $first
                newExtension 'B'
                newExtension 'A'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('B', 'A')
            [object]::ReferenceEquals($result[1], $first) | Should -BeTrue
        }
    }

    Context 'When an extension has no dependencies key' {
        It 'Returns it' {
            $extensions = @(
                @{ Name = 'Disabled'; Path = '/zf/Disabled'; Enabled = $false }
                newExtension 'A'
            )

            $result = Get-ExtensionImportOrder -Extensions $extensions

            $result.Name | Should -Be @('A', 'Disabled')
        }
    }

    Context 'When given an empty collection' {
        It 'Returns nothing' {
            $result = @(Get-ExtensionImportOrder -Extensions @())

            $result.Count | Should -Be 0
        }
    }
}
