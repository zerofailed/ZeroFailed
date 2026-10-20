# <copyright file="_getExtensionFromPSRepository.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _getExtensionFromPSRepository {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter(Mandatory=$true)]
        [string] $PSRepository,

        [Parameter(Mandatory=$true)]
        [string] $TargetPath,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [string] $MinimumVersion,

        [Parameter()]
        [switch] $PreRelease,

        [Parameter()]
        [string] $LockedVersion
    )

    # Setup some objects we'll use for splatting
    $extension = @{
        Name = $Name
        Repository = $PSRepository
        Enabled = $true
    }
    if ($Version) {
        $extension.Add("Version", $Version)
    }
    if ($MinimumVersion) {
        $extension.Add("MinimumVersion", $MinimumVersion)
    }

    # The lock file records the exact version to install, which takes precedence over the requested version
    if ($LockedVersion) {
        $Version = $LockedVersion
        $MinimumVersion = $null
        if ($LockedVersion.Contains('-')) {
            $PreRelease = $true
        }
    }

    # Compare a version with fewer than 3 numeric parts (e.g. '1.4') as its full version (e.g. '1.4.0'), which is the
    # version that is installed. The requested version is still returned unchanged.
    if ($Version) {
        $completeVersion = _getCompleteExtensionVersion -Version $Version
        if ($completeVersion) {
            $Version = $completeVersion
        }
    }

    $psResourceArgs = @{
        Name = $Name
        PreRelease = $PreRelease
        Verbose = $false
    }
    if ($Version) {
        $psResourceArgs.Add("Version", $Version)
    }

    # A minimum version accepts any version in its range, up to the next major version
    $installedArgs = @{}
    if ($MinimumVersion) {
        $range = _getExtensionVersionRange -MinimumVersion $MinimumVersion
        $installedArgs.Add("MinimumVersion", $MinimumVersion)
    }
    $requestedVersion = $MinimumVersion ? $range.Text : "v$Version"

    # Records which repository an installed extension came from
    $sourceInfoFileName = '.zf-source.json'

    # Whether an installed copy came from another repository. Copies installed by earlier versions of ZeroFailed have no
    # record of their repository, so they are used as they are.
    $isFromOtherRepository = {
        param ($path)
        $sourceInfoPath = Join-Path $path $sourceInfoFileName
        if (Test-Path $sourceInfoPath) {
            $installedRepository = (Get-Content -Raw -Path $sourceInfoPath | ConvertFrom-Json -AsHashtable)['repository']
            if ($installedRepository -and $installedRepository -ne $PSRepository) {
                Write-Verbose "Extension '$Name' found locally but it was installed from a different repository. Found: '$installedRepository'; Required: '$PSRepository'"
                return $true
            }
        }
        return $false
    }

    # Check whether module is already installed. Remove a copy from another repository, as a module with the same name
    # and version can have different content there, then check for another installed version that can be used.
    $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs @installedArgs -TargetPath $TargetPath
    while ($existingExtensionPath -and (& $isFromOtherRepository $existingExtensionPath)) {
        # Stop if the copy cannot be removed (e.g. a file is in use), as it would be found again, or a partly removed
        # copy could be used
        try {
            Remove-Item -Path $existingExtensionPath -Recurse -Force -ErrorAction Stop
        }
        catch {
            throw ("Extension $Name ($existingExtensionVersion) was installed from another repository, but it could not be removed: " +
                   "$($_.Exception.Message) Delete '$existingExtensionPath', then run again.")
        }
        $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs @installedArgs -TargetPath $TargetPath
    }

    # Handle getting the module from the repository
    if (!$existingExtensionPath -or ($Version -and $existingExtensionVersion -ne $Version)) {
        if (!$existingExtensionPath) {
            Write-Verbose "Extension '$Name' not found locally, checking repository"
        }
        elseif ($Version -and $existingExtensionVersion -ne $Version) {
            Write-Verbose "Extension '$Name' found locally but version mismatch detected. Found: v$existingExtensionVersion; Required: v$Version"
        }

        # Only search the configured repository, as the lock file records it as the extension's source
        if ($MinimumVersion) {
            # The repository returns every version in the range, so install the newest one
            $availableModule = Find-PSResource @psResourceArgs -Repository $PSRepository -Version $range.Text -ErrorAction Ignore |
                                    ForEach-Object {
                                        $resourceVersion = [semver]::new($_.Version.Major, $_.Version.Minor, [Math]::Max($_.Version.Build, 0), $_.Prerelease)
                                        if (_testExtensionVersionInRange -Version $resourceVersion -Range $range -PreRelease:$PreRelease) {
                                            [pscustomobject]@{ Version = $resourceVersion; Resource = $_ }
                                        }
                                    } |
                                    Sort-Object -Property Version -Descending |
                                    Select-Object -First 1 -ExpandProperty Resource
        }
        else {
            $availableModule = Find-PSResource @psResourceArgs -Repository $PSRepository -ErrorAction Ignore
        }
        if ($availableModule) {
            Write-Host "Installing extension $Name from $PSRepository" -f Cyan
            $availableModule | Save-PSResource -Path $TargetPath -TrustRepository

            $existingExtensionPath,$existingExtensionVersion = Get-InstalledExtensionDetails @psResourceArgs @installedArgs -TargetPath $TargetPath
            if (!$existingExtensionPath) {
                throw "Failed to install extension $Name ($requestedVersion) from $PSRepository repository"
            }
            [ordered]@{
                repository = $PSRepository
                version = $existingExtensionVersion
            } | ConvertTo-Json | Set-Content -Path (Join-Path $existingExtensionPath $sourceInfoFileName)
            Write-Host "INSTALLED MODULE: $Name (v$existingExtensionVersion)" -f Cyan
        }
        else {
            Write-Warning "SKIPPED: Extension $Name not found in $PSRepository repository"
            $extension.Enabled = $false
        }
    }
    else {
        Write-Host "FOUND MODULE: $Name (v$existingExtensionVersion)" -f Cyan
    }

    # Return the additional extension metadata that this function has populated
    $additionalMetadata = @{
        Path = $existingExtensionPath
        Enabled = $extension.Enabled
        ResolvedVersion = $extension.Enabled ? $existingExtensionVersion : $null
    }

    # Only report the installed version when no version was requested, so the requested version is not overwritten
    if (!$extension.ContainsKey("Version") -and !$extension.ContainsKey("MinimumVersion")) {
        $additionalMetadata += @{ Version = $existingExtensionVersion }
    }

    return $additionalMetadata
}
