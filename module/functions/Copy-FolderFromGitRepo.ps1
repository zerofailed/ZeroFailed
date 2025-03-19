# <copyright file="Copy-FolderFromGitRepo.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

<# 
.SYNOPSIS
    Clones a Git repository and copies a specified folder from the cloned repository to a destination.

.DESCRIPTION
    The function clones the specified Git repository into a temporary directory,
    retrieves the folder indicated by RepoFolderPath, and copies its contents to the specified DestinationPath.
    It validates the existence of Git CLI and cleans up the temporary clone after the operation.

.PARAMETER RepoUrl
    The URL of the Git repository to clone.

.PARAMETER RepoFolderPath
    The relative path within the repository of the folder to be copied.

.PARAMETER DestinationPath
    The path where the folder's contents will be copied.

.PARAMETER GitRef
    The branch or tag to check out from the repository. Defaults to 'main'.

.PARAMETER GitCmd
    The Git command to use. Defaults to expecting 'git' to be in the PATH.

.EXAMPLE
    Copy-FolderFromGitRepo -RepoUrl 'https://github.com/example/repo.git' -RepoFolderPath 'src' -DestinationPath 'C:\target'

.NOTES
    Requires Git CLI to be installed.
#>

function Copy-FolderFromGitRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RepoUrl,
        
        [Parameter(Mandatory)]
        [string] $RepoFolderPath,
        
        [Parameter(Mandatory)]
        [string] $DestinationPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GitRef = 'main',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GitCmd = 'git'
    )
    
    if (!(Get-Command $GitCmd -ErrorAction Ignore)) {
        throw "Git CLI is not installed. Please install Git CLI before trying to retrieve extensions from Git repositories."
    }

    # Create a temporary folder for cloning
    $tempDir = New-TemporaryDirectory

    try {
        Write-Verbose "Cloning repository $RepoUrl to $tempDir..."
        & $GitCmd clone --quiet --single-branch --depth 1 -b $GitRef $RepoUrl $tempDir
        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed. Verify repository URL and network connectivity."
        }

        $sourcePath = [IO.Path]::GetFullPath((Join-Path -Path $tempDir -ChildPath $RepoFolderPath))
        if (!(Test-Path $sourcePath)) {
            throw "The folder '$RepoFolderPath' does not exist in the cloned repository."
        }
        
        Write-Verbose "Copying contents from $sourcePath to $DestinationPath..."
        Copy-Item -Path $sourcePath -Destination $DestinationPath -Recurse -Force   
    }
    finally {
        # Clean up the temporary folder
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}
