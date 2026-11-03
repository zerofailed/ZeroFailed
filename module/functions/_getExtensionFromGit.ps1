# <copyright file="_getExtensionFromGit.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionFromGit {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [uri] $RepositoryUri,

        [Parameter()]
        [string] $RepositoryFolderPath = 'module',

        [Parameter(Mandatory)]
        [string] $TargetPath,

        [Parameter()]
        [string] $GitRef,

        [Parameter()]
        [string] $MinimumVersion,

        [Parameter()]
        [switch] $PreRelease,

        [Parameter()]
        [string] $LockedCommit
    )

    # Records where an installed extension came from, so that later runs know which commit is installed
    $sourceInfoFileName = '.zf-source.json'

    # Whether an installed copy came from the requested repository and folder. Ignore the case of the repository URL,
    # as well as any trailing '/' or '.git', as the lock file does. Folders in a git repository are case-sensitive.
    $isSameSource = {
        param ($sourceInfo)
        (_getNormalizedGitRepositoryUrl -RepositoryUrl "$($sourceInfo['repository'])") -eq (_getNormalizedGitRepositoryUrl -RepositoryUrl $RepositoryUri.OriginalString) -and
            "$($sourceInfo['folderPath'])" -ceq $RepositoryFolderPath
    }

    # A minimum version installs the newest release tag in its range, up to the next major version. An installed
    # release in the range is used as it is, so the tags are only listed when none is installed.
    if ($MinimumVersion -and !$GitRef) {
        $range = _getExtensionVersionRange -MinimumVersion $MinimumVersion

        $installedRelease = Get-ChildItem -Path (Join-Path $TargetPath $Name) -Directory -ErrorAction Ignore |
                                ForEach-Object {
                                    $sourceInfoPath = Join-Path $_.FullName $sourceInfoFileName
                                    if (Test-Path $sourceInfoPath) {
                                        $sourceInfo = Get-Content -Raw -Path $sourceInfoPath | ConvertFrom-Json -AsHashtable
                                        $version = _getVersionFromGitTag -Ref "$($sourceInfo['ref'])"
                                        if ((& $isSameSource $sourceInfo) -and $version -and (_testExtensionVersionInRange -Version $version -Range $range -PreRelease:$PreRelease)) {
                                            @{ Ref = $sourceInfo['ref']; Version = $version }
                                        }
                                    }
                                } |
                                Sort-Object -Property { $_.Version } -Descending |
                                Select-Object -First 1

        if ($installedRelease) {
            $GitRef = $installedRelease.Ref
        }
        else {
            try {
                $availableReleases = @(_getGitTagVersions -RepoUrl $RepositoryUri.OriginalString)
            }
            catch {
                throw "Failed to list the release tags of extension $Name from $RepositoryUri repository: $($_.Exception.Message)"
            }

            $availableRelease = $availableReleases |
                                    Where-Object { _testExtensionVersionInRange -Version $_.Version -Range $range -PreRelease:$PreRelease } |
                                    Sort-Object -Property { $_.Version } -Descending |
                                    Select-Object -First 1
            if (!$availableRelease) {
                throw ("No release of extension $Name in $RepositoryUri repository matches $($range.Text). " +
                       "Releases are git tags named after a semantic version, e.g. '$($range.Minimum)' or 'v$($range.Minimum)'. GitHub Releases are not used.")
            }
            $GitRef = $availableRelease.Ref
        }
        Write-Verbose "Extension '$Name' $($range.Text) resolved to '$GitRef'"
    }
    elseif (!$GitRef) {
        throw "A 'GitRef' or 'MinimumVersion' is required to install extension $Name from $RepositoryUri repository"
    }

    # Check whether module is already installed. Copies from different repositories (e.g. a fork and its upstream) or
    # folders are installed in different folders, so they never overwrite each other's files.
    $installFolderName = _getGitExtensionFolderName -RepositoryUri $RepositoryUri -RepositoryFolderPath $RepositoryFolderPath -GitRef $GitRef
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $installFolderName

    # Every install records its source once all of its files are in place, so a folder without this record is an
    # install that did not complete. Earlier versions of ZeroFailed did not use this folder name.
    $installedCommit = $null
    $installedSourceInfo = $null
    if ($existingExtensionPath) {
        $sourceInfoPath = Join-Path $existingExtensionPath $sourceInfoFileName
        if (Test-Path $sourceInfoPath) {
            $installedSourceInfo = Get-Content -Raw -Path $sourceInfoPath | ConvertFrom-Json -AsHashtable
            $installedCommit = $installedSourceInfo['commit']
        }
    }

    $installRequired = $false
    if (!$existingExtensionPath) {
        Write-Verbose "Extension '$Name' not found locally."
        $installRequired = $true
    }
    elseif ($existingExtensionVersion -ne $installFolderName) {
        Write-Verbose "Extension '$Name' found locally but version mismatch detected. Found: '$existingExtensionVersion'; Required: '$installFolderName' [$GitRef]"
        $installRequired = $true
    }
    elseif (!$installedSourceInfo) {
        Write-Verbose "Extension '$Name' found locally but its install did not complete, as it has no '$sourceInfoFileName' file"
        $installRequired = $true
    }
    elseif ($installedSourceInfo.ContainsKey('repository') -and !(& $isSameSource $installedSourceInfo)) {
        # The folder name includes a short hash of the source, so this only happens if two sources' hashes collide or
        # the folder was changed by hand
        Write-Verbose ("Extension '$Name' found locally but it was installed from a different source. " +
                       "Found: '$($installedSourceInfo['repository'])' ($($installedSourceInfo['folderPath'])); Required: '$RepositoryUri' ($RepositoryFolderPath)")
        $installRequired = $true
    }
    elseif ($LockedCommit -and $installedCommit -ne $LockedCommit) {
        Write-Verbose "Extension '$Name' found locally but its commit does not match the lock file. Found: '$installedCommit'; Required: '$LockedCommit'"
        $installRequired = $true
    }

    # Handle getting the module from the repository
    if ($installRequired) {
        Write-Host "Installing extension $Name from $RepositoryUri" -f Cyan

        # The source record is written last, so an install that stops part way (e.g. with Ctrl+C) leaves a folder without
        # it, which is installed again on the next run. The files are copied straight into the install folder rather than
        # renaming a staging folder, as editors and antivirus scanners often have newly written files open, which stops
        # their folder being renamed on Windows.
        $destinationPath = Join-Path $TargetPath $Name $installFolderName
        $copyArgs = @{
            RepoUrl = $RepositoryUri
            DestinationPath = $destinationPath
            RepoFolderPath = $RepositoryFolderPath
            GitRef = $GitRef
        }
        if ($LockedCommit) {
            $copyArgs.Commit = $LockedCommit
        }

        try {
            # Mark an existing install as incomplete before deleting it, in case it can only be partly deleted
            if (Test-Path $destinationPath) {
                $existingSourceInfoPath = Join-Path $destinationPath $sourceInfoFileName
                if (Test-Path $existingSourceInfoPath) {
                    Remove-Item -Path $existingSourceInfoPath -Force -ErrorAction Stop
                }
                _removeFolderWithRetry -Path $destinationPath
            }

            $installedCommit = _copyFolderFromGitRepo @copyArgs

            [ordered]@{
                repository = $RepositoryUri.OriginalString
                folderPath = $RepositoryFolderPath
                ref = $GitRef
                commit = $installedCommit
            } | ConvertTo-Json | Set-Content -Path (Join-Path $destinationPath $sourceInfoFileName) -ErrorAction Stop
        }
        catch {
            throw "Failed to install extension $Name ($GitRef) from $RepositoryUri repository: $($_.Exception.Message)"
        }

        $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $installFolderName
        if (!$existingExtensionPath) {
            throw "Failed to install extension $Name ($GitRef) from $RepositoryUri repository"
        }
        Write-Host "INSTALLED MODULE: $Name ($existingExtensionVersion)" -f Cyan
    }
    else {
        Write-Host "FOUND MODULE: $Name ($existingExtensionVersion)" -f Cyan
    }

    # Return the additional extension metadata that this function has populated
    $additionalMetadata = @{
        Path = $existingExtensionPath
        Enabled = $true
        ResolvedVersion = $installedCommit
    }

    # Record which release tag a minimum version resolved to, so that the lock file can install it again
    if ($MinimumVersion) {
        $additionalMetadata.ResolvedRef = $GitRef
    }

    return $additionalMetadata
}
