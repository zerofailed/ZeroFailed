# <copyright file="_getNormalizedGitRepositoryUrl.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getNormalizedGitRepositoryUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $RepositoryUrl
    )

    # The same repository can be referenced with a different case, a trailing '/' or a trailing '.git' (e.g.
    # 'https://github.com/org/repo' and 'https://github.com/org/repo.git/'), so remove these differences
    $url = $RepositoryUrl.TrimEnd('/')
    if ($url.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
        $url = $url.Substring(0, $url.Length - 4).TrimEnd('/')
    }

    return $url.ToLowerInvariant()
}
