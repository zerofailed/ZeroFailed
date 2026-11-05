# <copyright file="_getExtensionLockPath.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionLockPath {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $BasePath
    )

    # The lock file is committed and used on other machines, where the repository is in a different folder (e.g. in CI).
    # So a local extension's path is recorded relative to the folder that holds the lock file, with '/' separators
    # whichever platform wrote it. A relative path is resolved from the current location, as when the extension is used.
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $fullBasePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(($BasePath ? $BasePath : '.'))
    $relativePath = [IO.Path]::GetRelativePath($fullBasePath, $fullPath)

    return $relativePath.Replace('\', '/').TrimEnd('/')
}
