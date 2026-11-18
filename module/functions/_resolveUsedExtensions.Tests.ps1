# <copyright file="_resolveUsedExtensions.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_mergeExtensionProcess.ps1')

    Set-StrictMode -Version Latest

    # Creates the metadata of a registered extension, as produced by Register-ExtensionAndDependencies. A dependency
    # is registered as the same object as its declaration, so 'Declarations' are the occurrences of the extension's
    # dependencies, or the declarations of dependencies that are not registered.
    function newExtension {
        param (
            [string] $Name,
            [string] $Version = '1.0.0',
            [string] $RequiredBy,
            [hashtable[]] $Declarations = @(),
            [string] $Process
        )
        $extension = @{
            Name = $Name
            Enabled = $true
            Path = "$Name-$Version"
            LockEntry = [ordered]@{
                source = [ordered]@{ type = 'psrepository' }
                requested = $Version
                resolved = $Version
                direct = !$RequiredBy
                requiredBy = $RequiredBy ? @($RequiredBy) : @()
            }
            dependencies = $Declarations
        }
        if ($Process) {
            $extension.Process = $Process
        }
        $extension
    }

    # The declaration of a dependency that is not registered (for example, one that a local extension is used in place of)
    function newDeclaration([string] $Name, [string] $Process) {
        $declaration = @{ Name = $Name }
        if ($Process) {
            $declaration.Process = $Process
        }
        $declaration
    }

    # Calls the sut. Unless they are given, the configured occurrences are those that no extension requires: those
    # created without 'RequiredBy', and explicitly disabled ones, which have no lock entry.
    function resolveUsed([hashtable[]] $Extensions, [hashtable[]] $Configured) {
        if (!$PSBoundParameters.ContainsKey('Configured')) {
            $Configured = @($Extensions | Where-Object { !$_.ContainsKey('LockEntry') -or $_.LockEntry.direct })
        }
        _resolveUsedExtensions -Extensions $Extensions -ConfiguredExtensions $Configured
    }
}

Describe '_resolveUsedExtensions' {

    BeforeAll {
        Mock Write-Warning {}
    }

    Context 'When every extension is used' {
        It 'Returns every occurrence, in the same order' {
            $commonForA = newExtension 'Common' -RequiredBy 'A'
            $commonForB = newExtension 'Common' -RequiredBy 'B'
            $extensions = @(
                newExtension 'A' -Declarations $commonForA
                $commonForA
                newExtension 'B' -Declarations $commonForB
                $commonForB
            )

            $result = @(resolveUsed -Extensions $extensions)

            $result.Count | Should -Be 4
            for ($i = 0; $i -lt 4; $i++) {
                [object]::ReferenceEquals($result[$i], $extensions[$i]) | Should -BeTrue
            }
            $commonForA.LockEntry.requiredBy | Should -Be @('A', 'B')
        }
    }

    Context 'When an extension is referenced at 2 exact versions' {
        BeforeAll {
            # 'A' 1.0.0 is in the configuration, and 'X' requires 'A' 2.0.0, which requires 'Common' and declares its process
            $commonForA2 = newExtension 'Common' -RequiredBy 'A' -Process 'tasks/old.process.ps1'
            $a2 = newExtension 'A' -Version '2.0.0' -RequiredBy 'X' -Declarations $commonForA2
            $script:extensions = @(
                newExtension 'A'
                newExtension 'X' -Declarations $a2
                $a2
                $commonForA2
            )
            $script:result = @(resolveUsed -Extensions $script:extensions)
        }

        It 'Keeps the version that is not used, so that it can be reported as a duplicate' {
            @($result | Where-Object { $_.Name -eq 'A' }).Path | Should -Be @('A-1.0.0', 'A-2.0.0')
        }

        It 'Removes the dependencies that only the version that is not used requires' {
            @($result | Where-Object { $_.Name -eq 'Common' }).Count | Should -Be 0
        }
    }

    Context 'When a local extension is used in place of a dependency' {
        It 'Uses the process, and records the extension that requires it, only from an extension that is used' {
            $local = newExtension 'Common' -Process $null
            $local.LockEntry.source.type = 'path'
            $a2 = newExtension 'A' -Version '2.0.0' -RequiredBy 'X' -Declarations (newDeclaration 'Common' 'tasks/old.process.ps1')
            $extensions = @(
                newExtension 'A'
                newExtension 'X' -Declarations $a2
                $a2
                newExtension 'B' -Declarations (newDeclaration 'Common')
                $local
            )

            resolveUsed -Extensions $extensions | Out-Null

            $local.ContainsKey('Process') | Should -BeFalse
            $local.LockEntry.requiredBy | Should -Be @('B')
        }

        It 'Uses the process that an extension that is used declares' {
            $local = newExtension 'Common'
            $local.LockEntry.source.type = 'path'
            $extensions = @(
                $local
                newExtension 'A' -Declarations (newDeclaration 'Common' 'tasks/build.process.ps1')
            )

            resolveUsed -Extensions $extensions | Out-Null

            $local.Process | Should -Be 'tasks/build.process.ps1'
            $local.LockEntry.requiredBy | Should -Be @('A')
        }
    }

    Context 'When a declaration does not match the lock file' {
        It 'Uses its process, which the extension that requires it declares' {
            # In a Frozen run, the version that 'A' requires is not installed, as the lock file has the configured one
            $commonForA = newExtension 'Common' -Version '2.0.0' -RequiredBy 'A' -Process 'tasks/build.process.ps1'
            $commonForA.Enabled = $false
            $commonForA.LockMismatch = $true
            $configured = newExtension 'Common'
            $extensions = @(
                $configured
                newExtension 'A' -Declarations $commonForA
                $commonForA
            )

            resolveUsed -Extensions $extensions | Out-Null

            $configured.Process | Should -Be 'tasks/build.process.ps1'
        }

        It 'Does not use the process of an explicitly disabled declaration' {
            $configured = newExtension 'Common'
            $extensions = @(
                $configured
                newExtension 'A' -Declarations @{ Name = 'Common'; Enabled = $false; Process = 'tasks/build.process.ps1' }
            )

            resolveUsed -Extensions $extensions | Out-Null

            $configured.ContainsKey('Process') | Should -BeFalse
        }
    }

    Context 'When the references to an extension declare different processes' {
        It 'Uses the process in the configuration before the one that a dependency declares, and warns once' {
            # The configuration lists the local extension twice, and only the second declares its process
            $local = newExtension 'Common'
            $local.LockEntry.source.type = 'path'
            $localWithProcess = newExtension 'Common' -Process 'tasks/configured.process.ps1'
            $localWithProcess.LockEntry.source.type = 'path'
            $extensions = @(
                $local
                $localWithProcess
                newExtension 'A' -Declarations (newDeclaration 'Common' 'tasks/dependency.process.ps1')
            )

            resolveUsed -Extensions $extensions | Out-Null

            $local.Process | Should -Be 'tasks/configured.process.ps1'
            $localWithProcess.ContainsKey('Process') | Should -BeFalse
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like "*'tasks/configured.process.ps1'*'tasks/dependency.process.ps1'*"
            }
        }

        It 'Uses the process in the configuration when a dependency that declares another is registered first' {
            $commonForA = newExtension 'Common' -RequiredBy 'A' -Process 'tasks/dependency.process.ps1'
            $configured = newExtension 'Common' -Process 'tasks/configured.process.ps1'
            $extensions = @(
                newExtension 'A' -Declarations $commonForA
                $commonForA
                $configured
            )

            resolveUsed -Extensions $extensions | Out-Null

            $commonForA.Process | Should -Be 'tasks/configured.process.ps1'
            $configured.ContainsKey('Process') | Should -BeFalse
        }

        It 'Uses the process that the first extension to be registered declares, when the configuration has none' {
            $commonForA = newExtension 'Common' -RequiredBy 'A' -Process 'tasks/first.process.ps1'
            $commonForB = newExtension 'Common' -RequiredBy 'B' -Process 'tasks/second.process.ps1'
            $extensions = @(
                newExtension 'A' -Declarations $commonForA
                $commonForA
                newExtension 'B' -Declarations $commonForB
                $commonForB
            )

            resolveUsed -Extensions $extensions | Out-Null

            $commonForA.Process | Should -Be 'tasks/first.process.ps1'
            $commonForB.ContainsKey('Process') | Should -BeFalse
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like "*'tasks/first.process.ps1'*'tasks/second.process.ps1'*"
            }
        }
    }

    Context 'When an occurrence that was discarded when reconciling minimum versions declares a process' {
        It 'Uses the process when an extension that is used declares it' {
            # The discarded occurrence is no longer in the extensions, but is still declared by 'A'
            $discarded = newExtension 'Common' -Version '1.3.0' -RequiredBy 'A' -Process 'tasks/build.process.ps1'
            $common = newExtension 'Common' -Version '1.6.0'
            $extensions = @(
                newExtension 'A' -Declarations $discarded
                $common
            )

            resolveUsed -Extensions $extensions | Out-Null

            $common.Process | Should -Be 'tasks/build.process.ps1'
            $common.LockEntry.requiredBy | Should -Be @('A')
        }

        It 'Ignores the process when only an extension that is not used declares it' {
            # 'A' 1.6.0 is in the configuration. 'X' requires 'A' 1.3.0, which was discarded with its dependencies
            # but is still declared by 'X'.
            $commonForA13 = newExtension 'Common' -Version '1.3.0' -RequiredBy 'A' -Process 'tasks/old.process.ps1'
            $a13 = newExtension 'A' -Version '1.3.0' -RequiredBy 'X' -Declarations $commonForA13
            $common = newExtension 'Common' -Version '1.4.0'
            $extensions = @(
                newExtension 'A' -Version '1.6.0'
                $common
                newExtension 'X' -Declarations $a13
            )

            resolveUsed -Extensions $extensions | Out-Null

            $common.ContainsKey('Process') | Should -BeFalse
            $common.LockEntry.requiredBy | Should -BeNullOrEmpty
        }
    }

    Context 'When the occurrence that is used was registered by an extension that is not used' {
        It 'Removes the process that only that extension declares' {
            # 'A' 2.0.0 is not used, but registered 'Common' first; 'B' also requires 'Common', without a process
            $commonForA2 = newExtension 'Common' -RequiredBy 'A' -Process 'tasks/old.process.ps1'
            $a2 = newExtension 'A' -Version '2.0.0' -RequiredBy 'X' -Declarations $commonForA2
            $commonForB = newExtension 'Common' -RequiredBy 'B'
            $extensions = @(
                newExtension 'A'
                newExtension 'X' -Declarations $a2
                $a2
                $commonForA2
                newExtension 'B' -Declarations $commonForB
                $commonForB
            )

            $result = @(resolveUsed -Extensions $extensions)

            @($result | Where-Object { $_.Name -eq 'Common' }).Count | Should -Be 2
            $commonForA2.ContainsKey('Process') | Should -BeFalse
            $commonForA2.LockEntry.requiredBy | Should -Be @('B')
        }
    }

    Context 'When an extension is disabled' {
        It 'Keeps it, and does not use the extensions that only it requires' {
            $common = newExtension 'Common' -RequiredBy 'A'
            $a = newExtension 'A' -Declarations $common
            $a.Enabled = $false
            $extensions = @($a, $common)

            $result = @(resolveUsed -Extensions $extensions)

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'A'
        }

        It 'Keeps an explicitly disabled extension, which has no lock entry' {
            $extensions = @(@{ Name = 'A'; Enabled = $false })

            $result = @(resolveUsed -Extensions $extensions)

            $result.Count | Should -Be 1
        }

        It 'Does not treat an explicitly disabled dependency of an unused version, which has no lock entry, as configured' {
            # The configuration has 'A' 1.0.0 and 'X'. 'X' requires 'A' 2.0.0, which is not used. 'A' 2.0.0 requires 'E',
            # which requires 'D', and also declares 'D' as disabled.
            $dForE = newExtension 'D' -RequiredBy 'E'
            $e = newExtension 'E' -RequiredBy 'A' -Declarations $dForE
            $dDisabled = @{ Name = 'D'; Enabled = $false }
            $a2 = newExtension 'A' -Version '2.0.0' -RequiredBy 'X' -Declarations $e, $dDisabled
            $a1 = newExtension 'A'
            $x = newExtension 'X' -Declarations $a2
            $extensions = @($a1, $x, $a2, $e, $dForE, $dDisabled)

            $result = @(resolveUsed -Extensions $extensions -Configured $a1, $x)

            $result.Name | Should -Be @('A', 'X', 'A')
        }
    }

    Context 'When an occurrence in the configuration was discarded when reconciling minimum versions' {
        It 'Uses its process' {
            $configured = newExtension 'Common'
            $discarded = newExtension 'Common' -Process 'tasks/build.process.ps1'

            resolveUsed -Extensions $configured -Configured $configured, $discarded | Out-Null

            $configured.Process | Should -Be 'tasks/build.process.ps1'
        }
    }

    Context 'When given an empty collection' {
        It 'Returns nothing' {
            @(resolveUsed -Extensions @()).Count | Should -Be 0
        }
    }
}
