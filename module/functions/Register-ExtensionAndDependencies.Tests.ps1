# <copyright file="Register-ExtensionAndDependencies.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-InstalledExtensionDetails.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_copyFolderFromGitRepo.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionFromGit.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionFromPSRepository.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionFromPath.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_newExtensionLockEntry.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionLockEntryMatch.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionVersionRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionVersionInRange.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getVersionFromGitTag.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionContentHash.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionDependencies.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_resolveModuleNameFromPath.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Resolve-ExtensionMetadata.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-ExtensionAvailableTasks.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) 'Get-TasksFileListFromExtension.ps1')
}

Describe 'Register-ExtensionAndDependencies' {
    BeforeAll {
        # Setup .zf folder
        $targetPath = Join-Path -Path TestDrive: -ChildPath '.zf' 'extensions'
        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null

        # Define default PSRepository for PowerShell module-based extensions
        $DefaultPSRepository = 'PSGallery'

        Mock Write-Host {}
        Mock Write-Warning {}
    }

    Context 'Git-Based Extensions' {
        BeforeAll {
            Mock _getExtensionFromGit {
                # Return only the additional properties that Register-ExtensionAndDependencies expects to add,
                # resolving a minimum version to the release tag of that version
                $ref = $GitRef ? $GitRef : "refs/tags/$MinimumVersion"
                $result = @{
                    Path = Join-Path $TargetPath $Name $ref
                    Enabled = $true # Ensure Enabled is returned
                    ResolvedVersion = $LockedCommit ? $LockedCommit : "latest-commit-of-$Name"
                }
                if ($MinimumVersion) {
                    $result.ResolvedRef = $ref
                }
                return $result
            }
            Mock Import-PowerShellDataFile {
                param($Path)
                switch ($Path) {
                    { $PSItem.EndsWith('ZeroFailed.DevOps.Common.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.DevOps.Common'
                            PrivateData = @{
                                PSData = @{
                                    ExternalModuleDependencies = @()
                                }
                                ZeroFailed = @{
                                    ExtensionDependencies = @()
                                }
                            }
                        }
                    }
                    { $PSItem.EndsWith('ZeroFailed.Build.Common.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.Build.Common'
                            PrivateData = @{
                                PSData = @{
                                    ExternalModuleDependencies = @()
                                }
                                ZeroFailed = @{
                                    ExtensionDependencies = @(
                                        @{
                                            Name = 'ZeroFailed.DevOps.Common'
                                            GitRepository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'
                                            GitRef = 'main'
                                        }
                                    )
                                }
                            }
                        }
                    }
                    { $PSItem.EndsWith('ZeroFailed.Build.DotNet.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.Build.DotNet'
                            PrivateData = @{
                                PSData = @{
                                    ExternalModuleDependencies = @()
                                }
                                ZeroFailed = @{
                                    ExtensionDependencies = @(
                                        @{
                                            Name = 'ZeroFailed.Build.Common'
                                            GitRepository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'
                                            GitRef = 'main'
                                        }
                                    )
                                }
                            }
                        }
                    }
                    default {
                        throw "Unhandled mock module manifest for '$PSItem'"
                    }
                }
            }
        }
        
        Context 'When processing a single extension with no dependencies (no version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be $null
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with no dependencies  (with version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 1
                $result[0].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with 1 dependency (version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 2

                $result[0].Name | Should -Be "ZeroFailed.Build.Common"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true

                $result[1].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[1].Version | Should -Be $null
                $result[1].GitRef | Should -Be "main"
                $result[1].Enabled | Should -Be $true
            }
        }

        Context 'When processing a single extension with multiple dependencies (version constraint)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.DotNet"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.DotNet"
                    GitRef = "refs/heads/main"
                }
    
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
    
                $result.Count | Should -Be 3

                $result[0].Name | Should -Be "ZeroFailed.Build.DotNet"
                $result[0].Version | Should -Be $null
                $result[0].GitRef | Should -Be "refs/heads/main"
                $result[0].Enabled | Should -Be $true

                $result[1].Name | Should -Be "ZeroFailed.Build.Common"
                $result[1].Version | Should -Be $null
                $result[1].GitRef | Should -Be "main"
                $result[1].Enabled | Should -Be $true

                $result[2].Name | Should -Be "ZeroFailed.DevOps.Common"
                $result[2].Version | Should -Be $null
                $result[2].GitRef | Should -Be "main"
                $result[2].Enabled | Should -Be $true
            }
        }

        Context 'When the extension is explicitly enabled' {
            It 'Processes the extension' {
                $extensionConfig = @{
                    Name = "ZeroFailed.DevOps.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.DevOps.Common"
                    Enabled = $true
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Enabled | Should -Be $true
            }
        }

        Context 'Lock metadata' {
            BeforeAll {
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                    GitRef = "refs/heads/main"
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath
            }

            It 'Records how the extension was requested and resolved' {
                $lockEntry = $result[0].LockEntry

                $lockEntry.source.type | Should -Be 'git'
                $lockEntry.source.repository | Should -Be 'https://github.com/zerofailed/ZeroFailed.Build.Common'
                $lockEntry.source.folderPath | Should -Be 'module'
                $lockEntry.requested | Should -Be 'refs/heads/main'
                $lockEntry.resolved | Should -Be 'latest-commit-of-ZeroFailed.Build.Common'
            }

            It 'Records that a configured extension is a direct dependency' {
                $result[0].LockEntry.direct | Should -Be $true
                $result[0].LockEntry.requiredBy | Should -BeNullOrEmpty
            }

            It 'Records which extension requires a dependency' {
                $result[1].Name | Should -Be 'ZeroFailed.DevOps.Common'
                $result[1].LockEntry.direct | Should -Be $false
                $result[1].LockEntry.requiredBy | Should -Be @('ZeroFailed.Build.Common')
                $result[1].LockEntry.requested | Should -Be 'main'
            }

            It 'Does not add the resolved version to the extension metadata' {
                $result[0].ContainsKey('ResolvedVersion') | Should -Be $false
            }
        }

        Context 'Locked extensions' {
            BeforeEach {
                # Registration adds metadata to the configuration it is given, so each test needs a new one
                $extensionConfig = @{
                    Name = "ZeroFailed.Build.Common"
                    GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.Common"
                }
            }

            It 'Installs the locked commit of the extension and its dependencies when the lock file matches the request' {
                $lockedExtensions = @{
                    'ZeroFailed.Build.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                        requested = 'main'
                        resolved = 'locked-commit-1'
                    }
                    'ZeroFailed.DevOps.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'; folderPath = 'module' }
                        requested = 'main'
                        resolved = 'locked-commit-2'
                    }
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be 'locked-commit-1'
                $result[1].LockEntry.resolved | Should -Be 'locked-commit-2'
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and $LockedCommit -eq 'locked-commit-1' }
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.DevOps.Common' -and $LockedCommit -eq 'locked-commit-2' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Using locked commit for extension ZeroFailed.Build.Common: locked-commit-1' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Using locked commit for extension ZeroFailed.DevOps.Common: locked-commit-2' }
            }

            It 'Does not use the lock file when the extension was requested differently' {
                $lockedExtensions = @{
                    'ZeroFailed.Build.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                        requested = 'feature/other'
                        resolved = 'locked-commit-1'
                    }
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be 'latest-commit-of-ZeroFailed.Build.Common'
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and !$LockedCommit }
                Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like 'Using locked*' }
            }

            Context 'Content' {
                BeforeAll {
                    Mock Get-ExtensionAvailableTasks { @('MyTask') }
                    Mock _getExtensionContentHash { 'sha256:installed' }
                }

                BeforeEach {
                    $lockedExtensions = @{
                        'ZeroFailed.Build.Common' = @{
                            source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                            requested = 'main'
                            resolved = 'locked-commit-1'
                            contentHash = 'sha256:installed'
                        }
                    }
                }

                It 'Finds the tasks of a locked extension that has the content in the lock file' {
                    [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions

                    $result[0].availableTasks | Should -Be @('MyTask')
                    Should -Invoke Get-ExtensionAvailableTasks -Times 1 -ParameterFilter { $ExtensionPath -like '*ZeroFailed.Build.Common*' }
                }

                It 'Throws before finding the tasks of a locked extension that does not have the content in the lock file' {
                    $lockedExtensions.'ZeroFailed.Build.Common'.contentHash = 'sha256:locked'

                    { Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions } |
                        Should -Throw "Extension ZeroFailed.Build.Common (locked-commit-1) does not have the content recorded in the lock file. Delete '*' to re-install it."
                    Should -Invoke Get-ExtensionAvailableTasks -Times 0
                }

                It 'Does not find the tasks of an extension that is <Description>' -ForEach @(
                    @{ Description = 'requested differently from the lock file'; Requested = 'feature/other' }
                    @{ Description = 'not in the lock file'; Requested = $null }
                ) {
                    if ($Requested) {
                        $lockedExtensions.'ZeroFailed.Build.Common'.requested = $Requested
                    }
                    else {
                        $lockedExtensions.Remove('ZeroFailed.Build.Common')
                    }

                    [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions

                    $result[0].availableTasks | Should -BeNullOrEmpty
                    Should -Invoke Get-ExtensionAvailableTasks -Times 0
                }

                It 'Finds the tasks of an extension when the lock file is not used' {
                    [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                    $result[0].availableTasks | Should -Be @('MyTask')
                    Should -Invoke _getExtensionContentHash -Times 0
                }
            }

            It 'Does not use a lock entry that has no resolved commit' {
                $lockedExtensions = @{
                    'ZeroFailed.Build.Common' = @{
                        source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                        requested = 'main'
                        resolved = $null
                    }
                }

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and !$LockedCommit }
                Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like 'Using locked*' }
            }
        }

        Context 'Minimum versions' {
            BeforeEach {
                $extensionConfig = @{
                    Name = 'ZeroFailed.DevOps.Common'
                    GitRepository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'
                    MinimumVersion = '1.4.0'
                }
                $lockEntry = @{
                    source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'; folderPath = 'module'; preRelease = $false }
                    requested = '[1.4.0,2.0.0)'
                    resolved = 'locked-commit'
                    resolvedRef = 'refs/tags/1.5.0'
                }
            }

            It 'Records a minimum version as its range, and the release tag that it resolved to' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result[0].LockEntry.requested | Should -Be '[1.4.0,2.0.0)'
                $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/1.4.0'
                $result[0].ContainsKey('ResolvedRef') | Should -Be $false
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $MinimumVersion -eq '1.4.0' -and !$GitRef -and !$LockedCommit }
            }

            It 'Records whether a minimum version includes pre-release tags' {
                $extensionConfig.PreRelease = $true

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result[0].LockEntry.source.preRelease | Should -Be $true
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $PreRelease -and !$LockedCommit }
            }

            It 'Installs the locked release tag when it was locked for a different minimum version that it is in the range of' {
                $lockEntry.requested = '[1.5.0,2.0.0)'

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $GitRef -eq 'refs/tags/1.5.0' -and $LockedCommit -eq 'locked-commit' }
            }

            It 'Installs the locked release tag when it was locked for an exact git reference that is in the range' {
                $lockEntry.requested = 'refs/tags/v1.6.0'
                $lockEntry.Remove('resolvedRef')

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $GitRef -eq 'refs/tags/v1.6.0' -and $LockedCommit -eq 'locked-commit' }
            }

            It 'Installs a locked release tag without a pre-release label when pre-release tags are included' {
                $extensionConfig.PreRelease = $true

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $GitRef -eq 'refs/tags/1.5.0' -and $LockedCommit -eq 'locked-commit' }
            }

            It 'Does not use a locked release tag that is <Description>' -ForEach @(
                @{ Description = 'outside the range'; ResolvedRef = 'refs/tags/2.0.0' }
                @{ Description = 'a pre-release, when pre-release tags are not included'; ResolvedRef = 'refs/tags/1.6.0-beta.1' }
            ) {
                $lockEntry.resolvedRef = $ResolvedRef

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { !$GitRef -and !$LockedCommit }
            }

            Context 'When declared by an extension that is referenced by a git branch' {
                BeforeEach {
                    Mock Import-PowerShellDataFile -ParameterFilter { $Path.EndsWith('ZeroFailed.Build.Common.psd1') } {
                        @{
                            RootModule = 'ZeroFailed.Build.Common'
                            PrivateData = @{
                                ZeroFailed = @{
                                    ExtensionDependencies = @(
                                        @{
                                            Name = 'ZeroFailed.DevOps.Common'
                                            GitRepository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'
                                            MinimumVersion = '1.4.0'
                                        }
                                    )
                                }
                            }
                        }
                    }
                    $parentConfig = @{
                        Name = 'ZeroFailed.Build.Common'
                        GitRepository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'
                        GitRef = 'main'
                    }
                }

                It 'Resolves the dependency to a release tag in its range, rather than to the branch of the extension' {
                    [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $parentConfig -TargetPath $targetPath

                    $result.Count | Should -Be 2
                    $result[1].Name | Should -Be 'ZeroFailed.DevOps.Common'
                    $result[1].LockEntry.requested | Should -Be '[1.4.0,2.0.0)'
                    $result[1].LockEntry.resolvedRef | Should -Be 'refs/tags/1.4.0'
                    $result[1].LockEntry.requiredBy | Should -Be @('ZeroFailed.Build.Common')
                    Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and $GitRef -eq 'main' }
                    Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.DevOps.Common' -and $MinimumVersion -eq '1.4.0' -and !$GitRef }
                }

                It 'Installs the locked commit of the extension and the locked release tag of the dependency' {
                    $lockedExtensions = @{
                        'ZeroFailed.Build.Common' = @{
                            source = @{ type = 'git'; repository = 'https://github.com/zerofailed/ZeroFailed.Build.Common'; folderPath = 'module' }
                            requested = 'main'
                            resolved = 'locked-main-commit'
                        }
                        'ZeroFailed.DevOps.Common' = $lockEntry
                    }

                    Register-ExtensionAndDependencies -ExtensionConfig $parentConfig -TargetPath $targetPath -LockedExtensions $lockedExtensions | Out-Null

                    Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.Build.Common' -and $GitRef -eq 'main' -and $LockedCommit -eq 'locked-main-commit' }
                    Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $Name -eq 'ZeroFailed.DevOps.Common' -and $GitRef -eq 'refs/tags/1.5.0' -and $LockedCommit -eq 'locked-commit' }
                }
            }

            It 'Does not use a locked release tag from a different repository' {
                $lockEntry.source.repository = 'https://github.com/myorg/ZeroFailed.DevOps.Common'

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { !$GitRef -and !$LockedCommit }
            }

            It 'Does not record pre-release tags for a git reference' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{
                    Name = 'ZeroFailed.DevOps.Common'
                    GitRepository = 'https://github.com/zerofailed/ZeroFailed.DevOps.Common'
                } -TargetPath $targetPath

                $result[0].LockEntry.source.Contains('preRelease') | Should -Be $false
            }

            It 'Installs the locked commit of the release tag in the lock file' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry }

                $result[0].LockEntry.resolved | Should -Be 'locked-commit'
                $result[0].LockEntry.resolvedRef | Should -Be 'refs/tags/1.5.0'
                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { $GitRef -eq 'refs/tags/1.5.0' -and $LockedCommit -eq 'locked-commit' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq 'Using locked commit for extension ZeroFailed.DevOps.Common: locked-commit' }
            }

            It 'Does not use a lock entry that has no release tag' {
                $lockEntry.Remove('resolvedRef')

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { !$GitRef -and !$LockedCommit }
            }

            It 'Does not use a lock entry for a git branch' {
                $lockEntry.requested = 'main'
                $lockEntry.Remove('resolvedRef')

                Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath -LockedExtensions @{ 'ZeroFailed.DevOps.Common' = $lockEntry } | Out-Null

                Should -Invoke _getExtensionFromGit -Times 1 -ParameterFilter { !$GitRef -and !$LockedCommit }
            }
        }
    }

    Context 'PowerShell Module-Based Extensions' {
        BeforeAll {
            $mockModuleName = 'MyZfExtension'
            $mockModuleVersion = '1.2.3'
            $mockPsRepo = "MyPSRepo"
            Mock Get-ExtensionDependencies {
                return @()
            }
            Mock Find-PSResource { 
                # Minimum properties required to fake a PS module being available on a repository
                return New-MockObject -Type 'Microsoft.PowerShell.PSResourceGet.UtilClasses.PSResourceInfo' -Properties @{ Name = $mockModuleName; Repository = $mockPsRepo }
            }
            Mock Save-PSResource {
                # Create the minimum filesystem structure needed to fake the installation of a ZF extension
                New-Item -ItemType Directory -Path (Join-Path $Path $InputObject.Name $mockModuleVersion) -Force | Out-Null
            }
            Mock Import-PowerShellDataFile {
                return @{
                    RootModule = $mockModuleName
                    PrivateData = @{
                        PSData = @{
                            ExternalModuleDependencies = @()
                        }
                        ZeroFailed = @{
                            ExtensionDependencies = @()
                        }
                    }
                }
            }
        }

        Context 'When processing a single PowerShell module extension (no PSRepository specified)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = $mockModuleName
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockModuleName
                $result[0].Version | Should -Be $mockModuleVersion
                $result[0].Enabled | Should -Be $true
                Should -Invoke Find-PSResource -Exactly 1
                Should -Invoke Save-PSResource -Exactly 1
            }
        }

        Context 'When processing a single PowerShell module extension (with PSRepository specified)' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = $mockModuleName
                    PSRepository = $mockPsRepo
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockModuleName
                $result[0].Version | Should -Be $mockModuleVersion
                $result[0].PSRepository | Should -Be $mockPsRepo
                $result[0].Enabled | Should -Be $true
                Should -Invoke Find-PSResource -Exactly 1
                Should -Invoke Save-PSResource -Exactly 1
            }
        }

        Context 'Lock metadata' {
            It 'Records how the extension was requested and resolved' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName } -TargetPath $targetPath

                $lockEntry = $result[0].LockEntry
                $lockEntry.source.type | Should -Be 'psrepository'
                $lockEntry.source.repository | Should -Be 'PSGallery'
                $lockEntry.source.preRelease | Should -Be $false
                $lockEntry.requested | Should -BeNullOrEmpty
                $lockEntry.resolved | Should -Be $mockModuleVersion
                $lockEntry.direct | Should -Be $true
            }
        }

        Context 'Locked extensions' {
            BeforeAll {
                Mock _getExtensionFromPSRepository {
                    $path = Join-Path $TargetPath $Name '1.0.0'
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                    return @{
                        Path = $path
                        Enabled = $true
                        ResolvedVersion = $LockedVersion ? $LockedVersion : $mockModuleVersion
                    }
                }
                $lockedExtensions = @{
                    $mockModuleName = @{
                        source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }
                        requested = $null
                        resolved = '1.0.0'
                    }
                }
            }

            It 'Installs the locked version when the lock file matches the request' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName } -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be '1.0.0'
                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $LockedVersion -eq '1.0.0' }
                Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -eq "Using locked version for extension $($mockModuleName): v1.0.0" }
            }

            It 'Does not use the lock file when the extension was requested differently' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName; PreRelease = $true } -TargetPath $targetPath -LockedExtensions $lockedExtensions

                $result[0].LockEntry.resolved | Should -Be $mockModuleVersion
                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { !$LockedVersion }
                Should -Invoke Write-Host -Times 0 -ParameterFilter { $Object -like 'Using locked*' }
            }

            It 'Records a minimum version as its range' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName; MinimumVersion = '1.0' } -TargetPath $targetPath

                $result[0].LockEntry.requested | Should -Be '[1.0.0,2.0.0)'
                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $MinimumVersion -eq '1.0' -and !$LockedVersion }
            }

            It 'Installs the locked version of a minimum version when the lock file matches the request' {
                $rangeLockedExtensions = @{
                    $mockModuleName = @{
                        source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $false }
                        requested = '[1.0.0,2.0.0)'
                        resolved = '1.0.0'
                    }
                }

                Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName; MinimumVersion = '1.0' } -TargetPath $targetPath -LockedExtensions $rangeLockedExtensions | Out-Null

                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $MinimumVersion -eq '1.0' -and $LockedVersion -eq '1.0.0' }
            }

            It 'Installs the locked version of a minimum version when it was locked for a request that it is in the range of' {
                Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName; MinimumVersion = '1.0.0' } -TargetPath $targetPath -LockedExtensions @{
                    $mockModuleName = @{
                        source = @{ type = 'psrepository'; repository = 'PSGallery'; preRelease = $true }
                        requested = '1.0.0'
                        resolved = '1.0.0'
                    }
                } | Out-Null

                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { $LockedVersion -eq '1.0.0' }
            }

            It 'Does not use the locked version of a minimum version when it is <Description>' -ForEach @(
                @{ Description = 'outside the range'; Resolved = '2.0.0'; Repository = 'PSGallery' }
                @{ Description = 'a pre-release, when pre-release versions are not included'; Resolved = '1.1.0-beta1'; Repository = 'PSGallery' }
                @{ Description = 'from a different repository'; Resolved = '1.1.0'; Repository = 'MyRepository' }
            ) {
                Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockModuleName; MinimumVersion = '1.0.0' } -TargetPath $targetPath -LockedExtensions @{
                    $mockModuleName = @{
                        source = @{ type = 'psrepository'; repository = $Repository; preRelease = $true }
                        requested = '[1.0.0,2.0.0)'
                        resolved = $Resolved
                    }
                } | Out-Null

                Should -Invoke _getExtensionFromPSRepository -Times 1 -ParameterFilter { !$LockedVersion }
            }
        }
    }

    Context 'Local File-System-Based Extensions' {
        BeforeAll {
            Mock Write-Host {} -ParameterFilter { $Object.StartsWith("USING PATH:")}
            $mockExtensionName = 'MyLocalZfExtension'
            $mockExtensionPath = Join-Path -Path TestDrive: -ChildPath $mockExtensionName
            New-Item -Path $mockExtensionPath -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $mockExtensionPath "$mockExtensionName.psd1") -Value @'
@{
    RootModule = 'MyLocalZfExtension.psm1'
    ModuleVersion = '0.0.1'
    PrivateData = @{
        ZFData = @{
            Dependencies = @()
        }
    }
}
'@
        }

        Context 'When processing a single local file-system extension with a valid path' {
            It 'Processes the extension and returns the correct metadata' {
                $extensionConfig = @{
                    Name = $mockExtensionName
                    Path = $mockExtensionPath
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockExtensionName
                $result[0].Path | Should -Be $mockExtensionPath
                $result[0].Enabled | Should -Be $true
                Should -Invoke Write-Host -Exactly 1
            }

            It 'Records the path as the source, with no resolved version' {
                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig @{ Name = $mockExtensionName; Path = $mockExtensionPath } -TargetPath $targetPath

                $result[0].LockEntry.source.type | Should -Be 'path'
                $result[0].LockEntry.source.path | Should -Be $mockExtensionPath
                $result[0].LockEntry.requested | Should -BeNullOrEmpty
                $result[0].LockEntry.resolved | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Disabled Extension Scenarios' {
        BeforeEach {
        }

        Context 'Local extension path does not exist' {
            BeforeAll {
                Mock Get-ExtensionDependencies {}
                Mock Get-ExtensionAvailableTasks {}
            }

            It 'Should not register the extension, and write a warning' {
                $missingExtension = 'missingZfExtension'
                $missingPath = Join-Path $TestDrive $missingExtension
                $extensionConfig = @{
                    Name = $missingExtension
                    Path = $missingPath
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 0
                Should -Invoke Write-Warning -Exactly 1 -ParameterFilter {
                    $Message -eq "Extension '$missingExtension' not found at $missingPath - it has been disabled."
                }
                Should -Not -Invoke Get-ExtensionDependencies
                Should -Not -Invoke Get-ExtensionAvailableTasks
            }

            It 'Should return to the caller, rather than ending a loop that the caller is running' {
                $missingPath = Join-Path $TestDrive 'missingZfExtension'

                # 'continue' in the function would skip the rest of this loop's body
                $completedIterations = 0
                foreach ($i in 1..2) {
                    $result = @(Register-ExtensionAndDependencies -ExtensionConfig @{ Name = 'missingZfExtension'; Path = $missingPath } -TargetPath $targetPath)
                    $completedIterations++
                }

                $completedIterations | Should -Be 2
                $result.Count | Should -Be 0
            }
        }

        Context 'Extension explicitly disabled via configuration' {
            It 'Should not process dependencies or tasks' {
                Mock Get-ExtensionDependencies {}
                Mock Get-ExtensionAvailableTasks {}
                Mock Write-Host {}

                $mockExtensionName = 'MyLocalZfExtension'
                $mockExtensionPath = Join-Path -Path TestDrive: -ChildPath $mockExtensionName
                New-Item -Path $mockExtensionPath -ItemType Directory -Force | Out-Null
                Set-Content -Path (Join-Path $mockExtensionPath "$mockExtensionName.psd1") -Value @'
    @{
        RootModule = 'MyLocalZfExtension.psm1'
        ModuleVersion = '0.0.1'
        PrivateData = @{
            ZFData = @{
                Dependencies = @()
            }
        }
    }
'@
                $extensionConfig = @{
                    Name = $mockExtensionName
                    Path = $mockExtensionPath
                    Enabled = $false
                }

                [array]$result = Register-ExtensionAndDependencies -ExtensionConfig $extensionConfig -TargetPath $targetPath

                $result.Count | Should -Be 1
                $result[0].Name | Should -Be $mockExtensionName
                $result[0].Enabled | Should -Be $false
                Should -Not -Invoke Get-ExtensionDependencies
                Should -Not -Invoke Get-ExtensionAvailableTasks
                Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Skipping extension - explicitly disabled' }
            }
        }
    }

    

    Context 'Invalid extension path configuration' {
        BeforeAll {
            $invalidExtensionPath = "$PWD/does-not-exist"
        }

        Context 'Simple syntax' {
            It 'Should throw an exception' {
                $mockInvalidSimpleExtensionConfig = $invalidExtensionPath
                {
                    Register-ExtensionAndDependencies $mockInvalidSimpleExtensionConfig $targetPath
                } | Should -Throw "Unable to find the extension's module manifest in '$invalidExtensionPath'"
            }
        }

        Context 'Hashtable syntax' {
            It 'Should throw an exception' {
                $mockInvalidHashtableExtensionConfig = @{
                    Path = $invalidExtensionPath
                }
                {
                    Register-ExtensionAndDependencies $mockInvalidHashtableExtensionConfig $targetPath
                } | Should -Throw "Unable to find the extension's module manifest in '$invalidExtensionPath'"
            }
        }
    }
}
