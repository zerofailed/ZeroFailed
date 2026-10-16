# <copyright file="Copy-FolderFromGitRepo.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function Copy-FolderFromGitRepo {
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
