# <copyright file="_assertExtensionLockSatisfied.Tests.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

BeforeAll {
    # sut
    . $PSCommandPath.Replace('.Tests.ps1','.ps1')

    # in-module dependencies
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionLockEntries.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_getExtensionContentHash.ps1')
    . (Join-Path (Split-Path -Parent $PSCommandPath) '_testExtensionLockEntryMatch.ps1')

    Set-StrictMode -Version Latest

    # Creates the metadata of a registered extension, as produced by Register-ExtensionAndDependencies
    function newRegisteredExtension([string] $Name, [string] $Type = 'git', [string] $Requested = 'main', [string] $Resolved = 'abc123', [bool] $Enabled = $true) {
        $source = $Type -eq 'path' ? [ordered]@{ type = 'path'; path = "/src/$Name" } : [ordered]@{ type = 'git'; folderPath = 'module'; repository = "https://github.com/org/$Name" }
        @{
            Name = $Name
            Path = Join-Path $TestDrive $Name
            Enabled = $Enabled
            LockEntry = [ordered]@{
                source = $source
                requested = $Requested
                resolved = $Resolved ? $Resolved : $null
                direct = $true
                requiredBy = @()
            }
        }
    }

    # Creates a lock file entry, as read from the lock file
    function newLockedExtension([string] $Name, [string] $Type = 'git', [string] $Requested = 'main', [string] $Resolved = 'abc123', [string] $ContentHash = 'sha256:content') {
        $source = $Type -eq 'path' ? @{ type = 'path'; path = "/src/$Name" } : @{ type = 'git'; folderPath = 'module'; repository = "https://github.com/org/$Name" }
        @{
            source = $source
            requested = $Requested
            resolved = $Resolved ? $Resolved : $null
            contentHash = $ContentHash ? $ContentHash : $null
            direct = $true
            requiredBy = @()
        }
    }
}

Describe '_assertExtensionLockSatisfied' {

    BeforeAll {
        Mock _getExtensionContentHash { 'sha256:content' }
        Mock Write-Warning {}

        $lockFilePath = '/repo/.zf/extensions.lock.json'
    }

    It 'Succeeds when the extensions match the lock file' {
        $extensions = @(
            newRegisteredExtension -Name 'Build'
            newRegisteredExtension -Name 'Local' -Type 'path' -Requested '' -Resolved ''
        )
        $locked = @{
            'Build' = newLockedExtension -Name 'Build'
            'Local' = newLockedExtension -Name 'Local' -Type 'path' -Requested '' -Resolved '' -ContentHash ''
        }

        { _assertExtensionLockSatisfied -Extensions $extensions -LockedExtensions $locked -LockFilePath $lockFilePath } | Should -Not -Throw
        Should -Invoke Write-Warning -Times 0 -Scope It
    }

    It 'Fails when <Description>' -ForEach @(
        @{
            Description = 'an extension is not in the lock file'
            Extension = @{ Name = 'Build' }
            Locked = @{}
            ExpectedProblem = "'Build' is not in the lock file"
        }
        @{
            Description = 'an extension is requested differently'
            Extension = @{ Name = 'Build'; Requested = 'develop' }
            Locked = @{ Name = 'Build'; Requested = 'main' }
            ExpectedProblem = "'Build' is requested as 'develop' from git 'https://github.com/org/Build', but the lock file has 'main' from git 'https://github.com/org/Build'"
        }
        @{
            Description = 'the lock file has no resolved version'
            Extension = @{ Name = 'Build' }
            Locked = @{ Name = 'Build'; Resolved = '' }
            ExpectedProblem = "'Build' has no resolved version in the lock file; delete its installed copy, then run in 'Write' mode*"
        }
        @{
            Description = 'an extension resolved to a different version'
            Extension = @{ Name = 'Build'; Resolved = 'other' }
            Locked = @{ Name = 'Build' }
            ExpectedProblem = "'Build' resolved to 'other', but the lock file has 'abc123'"
        }
        @{
            Description = 'the content of an extension differs'
            Extension = @{ Name = 'Build' }
            Locked = @{ Name = 'Build'; ContentHash = 'sha256:other' }
            ExpectedProblem = "'Build' (abc123) does not have the content recorded in the lock file*"
        }
        @{
            Description = 'an extension could not be installed'
            Extension = @{ Name = 'Build'; Enabled = $false }
            Locked = @{ Name = 'Build' }
            ExpectedProblem = "'Build' could not be installed"
        }
    ) {
        $extensions = @( newRegisteredExtension @Extension )
        $lockedExtensions = $Locked.Count -gt 0 ? @{ $Locked.Name = (newLockedExtension @Locked) } : @{}

        { _assertExtensionLockSatisfied -Extensions $extensions -LockedExtensions $lockedExtensions -LockFilePath $lockFilePath } |
            Should -Throw "*$ExpectedProblem*"
    }

    It 'Reports every problem, with how to update the lock file' {
        $extensions = @(
            newRegisteredExtension -Name 'Build' -Resolved 'other'
            newRegisteredExtension -Name 'Common'
        )
        $locked = @{ 'Build' = newLockedExtension -Name 'Build' }

        $errorMessage = try { _assertExtensionLockSatisfied -Extensions $extensions -LockedExtensions $locked -LockFilePath $lockFilePath } catch { $_.Exception.Message }

        $errorMessage | Should -BeLike "The extensions do not match the lock file '$lockFilePath':*"
        $errorMessage | Should -BeLike "*'Build' resolved to 'other'*"
        $errorMessage | Should -BeLike "*'Common' is not in the lock file*"
        $errorMessage | Should -BeLike "*ZF_EXTENSIONS_LOCK_MODE = 'Write'*"
    }

    It 'Only checks the request of local extensions' {
        $extensions = @( newRegisteredExtension -Name 'Local' -Type 'path' -Requested '' -Resolved '' )
        $locked = @{ 'Local' = newLockedExtension -Name 'Local' -Type 'path' -Requested '' -Resolved '' -ContentHash 'sha256:old' }

        { _assertExtensionLockSatisfied -Extensions $extensions -LockedExtensions $locked -LockFilePath $lockFilePath } | Should -Not -Throw
    }

    It 'Only checks the first extension found with each name' {
        $extensions = @(
            newRegisteredExtension -Name 'Build'
            newRegisteredExtension -Name 'Build' -Requested 'other' -Resolved 'other' -Enabled $false
        )
        $locked = @{ 'Build' = newLockedExtension -Name 'Build' }

        { _assertExtensionLockSatisfied -Extensions $extensions -LockedExtensions $locked -LockFilePath $lockFilePath } | Should -Not -Throw
    }

    It 'Warns about extensions in the lock file that are no longer used' {
        $extensions = @( newRegisteredExtension -Name 'Build' )
        $locked = @{
            'Build' = newLockedExtension -Name 'Build'
            'Removed' = newLockedExtension -Name 'Removed'
        }

        { _assertExtensionLockSatisfied -Extensions $extensions -LockedExtensions $locked -LockFilePath $lockFilePath } | Should -Not -Throw
        Should -Invoke Write-Warning -Times 1 -Scope It -ParameterFilter { $Message -like '*no longer used: Removed' }
    }
}
