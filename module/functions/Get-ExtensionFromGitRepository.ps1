# <copyright file="Get-ExtensionFromGitRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromGitRepository {
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
        [string] $GitRef
    )

    # Retained for backwards-compatibility, the implementation now lives in a private function
    # that also returns the resolved commit.
    $result = _getExtensionFromGit @PSBoundParameters

    # Return the additional extension metadata that this function has always populated
    $additionalMetadata = @{
        Path = $result.Path
        Enabled = $result.Enabled
    }

    return $additionalMetadata
}