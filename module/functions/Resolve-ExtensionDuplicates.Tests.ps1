# <copyright file="Resolve-ExtensionDuplicates.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    . $PSScriptRoot/_mergeExtensionProcess.ps1
}

Describe 'Resolve-ExtensionDuplicates' {
    BeforeAll {
        Mock Write-Warning {}
    }

    Context 'When there are no duplicate extensions' {
        It 'Returns all extensions and does not warn' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.PowerShell'; Path = '/zf/ZeroFailed.Build.PowerShell/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $result.Count | Should -Be 2
            Should -Invoke Write-Warning -Times 0 -Exactly
        }
    }

    Context 'When the same extension is referenced more than once at the same version' {
        It 'De-duplicates without warning (the issue scenario)' {
            # Two top-level extensions both depend on the same version of a shared extension,
            # which therefore resolves to the same Path.
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.PowerShell'; Path = '/zf/ZeroFailed.Build.PowerShell/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main' }
                @{ Name = 'ZeroFailed.Build.GitHub'; Path = '/zf/ZeroFailed.Build.GitHub/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $result.Count | Should -Be 3
            @($result | Where-Object { $_.Name -eq 'ZeroFailed.Build.Common' }).Count | Should -Be 1
            Should -Invoke Write-Warning -Times 0 -Exactly
        }
    }

    Context 'When the same extension is resolved to different versions' {
        It 'Keeps the first one found' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Version = '1.0.0'; Path = '/zf/ZeroFailed.Build.Common/1.0.0' }
                @{ Name = 'ZeroFailed.Build.GitHub'; Path = '/zf/ZeroFailed.Build.GitHub/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Version = '2.0.0'; Path = '/zf/ZeroFailed.Build.Common/2.0.0' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $common = @($result | Where-Object { $_.Name -eq 'ZeroFailed.Build.Common' })
            $common.Count | Should -Be 1
            $common[0].Path | Should -Be '/zf/ZeroFailed.Build.Common/1.0.0'
        }

        It 'Warns exactly once, naming the extension' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Version = '1.0.0'; Path = '/zf/ZeroFailed.Build.Common/1.0.0' }
                @{ Name = 'ZeroFailed.Build.GitHub'; Path = '/zf/ZeroFailed.Build.GitHub/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Version = '2.0.0'; Path = '/zf/ZeroFailed.Build.Common/2.0.0' }
            )

            Resolve-ExtensionDuplicates -Extensions $extensions | Out-Null

            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*ZeroFailed.Build.Common*'
            }
        }

        It 'Lists both the winning and the ignored paths in the warning' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Version = '1.0.0'; Path = '/zf/ZeroFailed.Build.Common/1.0.0' }
                @{ Name = 'ZeroFailed.Build.GitHub'; Path = '/zf/ZeroFailed.Build.GitHub/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Version = '2.0.0'; Path = '/zf/ZeroFailed.Build.Common/2.0.0' }
            )

            Resolve-ExtensionDuplicates -Extensions $extensions | Out-Null

            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*ZeroFailed.Build.Common/1.0.0*' -and $Message -like '*ZeroFailed.Build.Common/2.0.0*'
            }
        }

        It 'Warns under strict mode when the references have no version' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/local/ZeroFailed.Build.Common' }
                @{ Name = 'ZeroFailed.Build.Common'; MinimumVersion = '1.0'; Path = '/zf/ZeroFailed.Build.Common/1.2.0' }
            )

            & {
                Set-StrictMode -Version Latest
                [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions
                $result.Count | Should -Be 1
            }

            Should -Invoke Write-Warning -Times 1 -Exactly
        }
    }

    Context 'When there is a mix of conflicting and non-conflicting duplicates' {
        BeforeAll {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main' }    # shared, same version
                @{ Name = 'ZeroFailed.DevOps.Common'; Version = '1.0.0'; Path = '/zf/ZeroFailed.DevOps.Common/1.0.0' }  # conflict
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main' }    # shared, same version
                @{ Name = 'ZeroFailed.DevOps.Common'; Version = '2.0.0'; Path = '/zf/ZeroFailed.DevOps.Common/2.0.0' }  # conflict
            )
        }

        It 'De-duplicates every extension by name' {
            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions
            $result.Count | Should -Be 2
        }

        It 'Warns only for the genuinely conflicting extension' {
            Resolve-ExtensionDuplicates -Extensions $extensions | Out-Null

            Should -Invoke Write-Warning -Times 1 -Exactly
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*ZeroFailed.DevOps.Common*'
            }
        }
    }

    Context 'When the extensions are not in alphabetical order' {
        It 'Returns them in the order that they were given' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Deploy.Azure'; Path = '/zf/ZeroFailed.Deploy.Azure/main' }
                @{ Name = 'ZeroFailed.Deploy.Common'; Path = '/zf/ZeroFailed.Deploy.Common/main'; Process = 'tasks/deploy.process.ps1' }
                @{ Name = 'ZeroFailed.DevOps.Common'; Path = '/zf/ZeroFailed.DevOps.Common/main' }
                @{ Name = 'ZeroFailed.Build.Python'; Path = '/zf/ZeroFailed.Build.Python/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main'; Process = 'tasks/build.process.ps1' }
                @{ Name = 'ZeroFailed.DevOps.Common'; Path = '/zf/ZeroFailed.DevOps.Common/main' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $result.Name | Should -Be @(
                'ZeroFailed.Deploy.Azure'
                'ZeroFailed.Deploy.Common'
                'ZeroFailed.DevOps.Common'
                'ZeroFailed.Build.Python'
                'ZeroFailed.Build.Common'
            )
        }

        It 'Keeps the first extension that declares a process ahead of the others' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Deploy.Common'; Path = '/zf/ZeroFailed.Deploy.Common/main'; Process = 'tasks/deploy.process.ps1' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main'; Process = 'tasks/build.process.ps1' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            ($result | Where-Object { $_.ContainsKey('Process') } | Select-Object -First 1).Name | Should -Be 'ZeroFailed.Deploy.Common'
        }
    }

    Context 'When only a later reference to an extension declares a process' {
        It 'Uses that process for the reference that is kept' {
            # e.g. the configuration overrides a dependency with a local copy, without repeating its 'Process'
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/src/ZeroFailed.Build.Common/module' }
                @{ Name = 'ZeroFailed.Build.PowerShell'; Path = '/zf/ZeroFailed.Build.PowerShell/main' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main'; Process = 'tasks/build.process.ps1' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $common = @($result | Where-Object { $_.Name -eq 'ZeroFailed.Build.Common' })
            $common.Count | Should -Be 1
            $common[0].Path | Should -Be '/src/ZeroFailed.Build.Common/module'
            $common[0].Process | Should -Be 'tasks/build.process.ps1'
        }
    }

    Context 'When the references to an extension declare different processes' {
        It 'Keeps the process of the first one found, and warns' {
            $extensions = @(
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main'; Process = 'tasks/build.process.ps1' }
                @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main'; Process = 'tasks/other.process.ps1' }
            )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $result[0].Process | Should -Be 'tasks/build.process.ps1'
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*different process definitions*'
            }
        }
    }

    Context 'When given a single extension' {
        It 'Returns it unchanged without warning' {
            $extensions = @( @{ Name = 'ZeroFailed.Build.Common'; Path = '/zf/ZeroFailed.Build.Common/main' } )

            [array]$result = Resolve-ExtensionDuplicates -Extensions $extensions

            $result.Count | Should -Be 1
            Should -Invoke Write-Warning -Times 0 -Exactly
        }
    }

    Context 'When given an empty collection' {
        It 'Returns nothing without warning' {
            [array]$result = Resolve-ExtensionDuplicates -Extensions @()

            $result.Count | Should -Be 0
            Should -Invoke Write-Warning -Times 0 -Exactly
        }
    }
}
