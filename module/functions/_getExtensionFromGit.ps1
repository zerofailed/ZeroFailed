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

        [Parameter(Mandatory)]
        [string] $GitRef,

        [Parameter()]
        [string] $LockedCommit
    )

    # Records where an installed extension came from, so that later runs know which commit is installed
    $sourceInfoFileName = '.zf-source.json'

    # Check whether module is already installed
    $safeGitRef = $GitRef.Replace('/', '-')
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $safeGitRef

    # Installs made by earlier versions of ZeroFailed have no record of their commit
    $installedCommit = $null
    if ($existingExtensionPath) {
        $sourceInfoPath = Join-Path $existingExtensionPath $sourceInfoFileName
        if (Test-Path $sourceInfoPath) {
            $installedCommit = (Get-Content -Raw -Path $sourceInfoPath | ConvertFrom-Json -AsHashtable)['commit']
        }
    }

    $installRequired = $false
    if (!$existingExtensionPath) {
        Write-Verbose "Extension '$Name' not found locally."
        $installRequired = $true
    }
    elseif ($existingExtensionVersion -ne $safeGitRef) {
        Write-Verbose "Extension '$Name' found locally but version mismatch detected. Found: '$existingExtensionVersion'; Required: '$safeGitRef' [$GitRef]"
        $installRequired = $true
    }
    elseif ($LockedCommit -and $installedCommit -ne $LockedCommit) {
        Write-Verbose "Extension '$Name' found locally but its commit does not match the lock file. Found: '$installedCommit'; Required: '$LockedCommit'"
        $installRequired = $true
    }

    # Handle getting the module from the repository
    if ($installRequired) {
        Write-Host "Installing extension $Name from $RepositoryUri" -f Cyan

        $destinationPath = Join-Path $TargetPath $Name $safeGitRef
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
            $installedCommit = _copyFolderFromGitRepo @copyArgs
        }
        catch {
            throw "Failed to install extension $Name ($GitRef) from $RepositoryUri repository: $($_.Exception.Message)"
        }

        [ordered]@{
            repository = $RepositoryUri.OriginalString
            folderPath = $RepositoryFolderPath
            ref = $GitRef
            commit = $installedCommit
        } | ConvertTo-Json | Set-Content -Path (Join-Path $destinationPath $sourceInfoFileName)

        $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails -Name $Name -TargetPath $TargetPath -GitRefAsFolderName $safeGitRef
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

    return $additionalMetadata
}
