# <copyright file="Copy-FolderFromGitRepo.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Copy-FolderFromGitRepo {
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
        The branch or tag to check out from the repository.
        Defaults to 'main'.

        .PARAMETER GitCmd
        The Git command to use.
        Defaults to expecting 'git' to be in the PATH.

        .EXAMPLE
        PS:> Copy-FolderFromGitRepo -RepoUrl 'https://github.com/example/repo.git' -RepoFolderPath 'src' -DestinationPath 'C:\target'
    #>
    [CmdletBinding()]
    [OutputType([void])]
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

    # Retained for backwards-compatibility, the implementation now lives in a private function
    # that also returns the resolved commit.
    _copyFolderFromGitRepo @PSBoundParameters | Out-Null
}
