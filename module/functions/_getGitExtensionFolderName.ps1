# <copyright file="_getGitExtensionFolderName.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getGitExtensionFolderName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [uri] $RepositoryUri,

        [Parameter(Mandatory)]
        [string] $RepositoryFolderPath,

        [Parameter(Mandatory)]
        [string] $GitRef
    )

    # The folder is named after the git reference, which is made safe for use as a folder name, followed by a short hash
    # of the source. The source ignores the case of the repository URL, as well as any trailing '/', in the same way as
    # the check of an installed copy's source. Folders in a git repository are case-sensitive (e.g. 'module' and
    # 'Module' can both exist), so the case of the folder is kept.
    $source = '{0}|{1}' -f $RepositoryUri.OriginalString.TrimEnd('/').ToLowerInvariant(), $RepositoryFolderPath
    $sourceHash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($source))
    $shortSourceHash = [Convert]::ToHexString($sourceHash).Substring(0, 8).ToLowerInvariant()

    return '{0}-{1}' -f $GitRef.Replace('/', '-'), $shortSourceHash
}
