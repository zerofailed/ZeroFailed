# <copyright file="_getExtensionContentHash.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionContentHash {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    # Files written when an extension is installed, which differ between installs of the same content
    $excludedFiles = @(
        'PSGetModuleInfo.xml'   # Written by Save-PSResource, includes the install date & location
        '.zf-source.json'       # Written by ZeroFailed, records where a git-based extension was installed from
    )

    # Uses .NET APIs rather than cmdlets (e.g. Get-FileHash), since this can run when module auto-loading is disabled
    $rootPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        # Build a manifest of every file's relative path and hash, sorted so the order files are found in does not matter
        $manifestLines = [System.Collections.Generic.List[string]]::new()
        foreach ($file in (Get-ChildItem -LiteralPath $rootPath -File -Recurse -Force)) {
            $relativePath = [IO.Path]::GetRelativePath($rootPath, $file.FullName).Replace('\', '/')
            if ($relativePath -in $excludedFiles) {
                continue
            }

            $bytes = [IO.File]::ReadAllBytes($file.FullName)

            # Treat a file as text when its start contains no NUL bytes (the same heuristic as git), and
            # normalise its line endings, so the hash does not depend on how git was configured to check it out.
            $isText = [Array]::IndexOf($bytes, [byte]0, 0, [Math]::Min($bytes.Length, 8000)) -lt 0
            if ($isText -and [Array]::IndexOf($bytes, [byte]13) -ge 0) {
                # Latin1 maps every byte to a single character, so the round-trip leaves all other bytes unchanged
                $text = [Text.Encoding]::Latin1.GetString($bytes)
                $bytes = [Text.Encoding]::Latin1.GetBytes($text.Replace("`r`n", "`n"))
            }

            $fileHash = [Convert]::ToHexString($sha256.ComputeHash($bytes)).ToLowerInvariant()
            $manifestLines.Add("$relativePath`0$fileHash`n")
        }
        $manifestLines.Sort([StringComparer]::Ordinal)

        $manifestBytes = [Text.Encoding]::UTF8.GetBytes([string]::Concat($manifestLines))
        $contentHash = [Convert]::ToHexString($sha256.ComputeHash($manifestBytes)).ToLowerInvariant()

        return "sha256:$contentHash"
    }
    finally {
        $sha256.Dispose()
    }
}
