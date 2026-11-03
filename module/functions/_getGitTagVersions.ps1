# <copyright file="_getGitTagVersions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getGitTagVersions {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory)]
        [string] $RepoUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $GitCmd = 'git'
    )

    if (!(Get-Command $GitCmd -ErrorAction Ignore)) {
        throw "Git CLI is not installed. Please install Git CLI before trying to retrieve extensions from Git repositories."
    }

    # Only the names of the tags are needed, so their peeled commits ('^{}') are not listed
    $PSNativeCommandUseErrorActionPreference = $false
    $output = & $GitCmd ls-remote --tags --refs $RepoUrl 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Verbose "git: $_" }
    if ($exitCode -ne 0) {
        throw "git ls-remote --tags --refs $RepoUrl failed with exit code $exitCode`n$($output -join "`n")"
    }

    # Each line is '<object id><tab><ref>', and only tags named after a semantic version are releases
    foreach ($line in ($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })) {
        $ref = ("$line" -split "`t")[-1].Trim()
        $version = _getVersionFromGitTag -Ref $ref
        if ($version) {
            @{ Ref = $ref; Version = $version }
        }
    }
}
