# <copyright file="Get-ExtensionFromGitRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionFromGitRepository {
    <#
        .SYNOPSIS
        Retrieves an extension from a Git repository using the git CLI.

        .DESCRIPTION
        If not already available as a locally-installed module, this function installs the extension from the specified git repository.
        It also derives the additional metadata about the extension required by the tooling.

        .PARAMETER Name
        Specifies the name of the extension being retrieved.

        .PARAMETER RepositoryUri
        Specifies the Git repository URI from which to retrieve the extension.

        .PARAMETER RepositoryFolderPath
        Specifies the folder path within the repository where the extension is located.
        Defaults to standard ZF convention of 'module'.

        .PARAMETER TargetPath
        Specifies the path where the extension should be installed.

        .PARAMETER GitRef
        Specifies the version of the extension to retrieve.
        If not specified, the 'main' branch will be retrieved.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git" -GitRef "main"
        Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -GitRef "refs/tags/1.0" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git"
        Retrieves '1.0' tagged version of the "MyExtension" extension from a git repository that uses the default ZF extension folder structure.

        .EXAMPLE
        PS:> Get-ExtensionFromGitRepository -Name "MyExtension" -TargetPath "C:/MyProject/.zf" -RepositoryUri "https://github.com/myorg/MyExtension.git" -RepositoryFolderPath 'modules/MyExtension'
        Retrieves the 'main' branch version of the "MyExtension" extension from a git repository that uses a custom folder structure.
    #>
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