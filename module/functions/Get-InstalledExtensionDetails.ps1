function Get-InstalledExtensionDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Name,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [switch] $PreRelease
    )

    # NOTE: For some reason using   with 'Get-PSResource' does not behave as expected,
    # so we have to create a specific splat object rather then just using PSBoundParameters
    # after having removed the 'PreRelease' parameter that Get-PSResource does not use.
    $splat = @{
        Name = $Name
    }
    if ($Version) {
        $splat.Add("Version", $Version)
    }
    
    # Setup a dynamic filter to handle whether we should see any installed pre-release versions
    if ($PreRelease -or $Version) {
        # Return all versions as we're either looking for a specific version (in which case
        # we should only have a single result), or we're interested in pre-release versions
        # so no filtering is required.
        $filter = { $true }
    }
    else {
        # Otherwise we're only intrested in non pre-release versions
        $filter = { $_.PreRelease -eq "" }
    }

    # Use Get-PsResource to query whether the module is already installed, unlike Get-Module it supports
    # filtering the version using a proper SemVer syntax.
    $existing = Get-PSResource @splat -ErrorAction Ignore |
                        Where-Object $filter |
                        Sort-Object Version -Descending |
                        Select-Object -First 1

    if ($existing) {
        # Derive the path to the module from the installed module metadata
        # NOTE: The available 'InstalledLocation' property is different depending on
        #       whether the module has just been installed or was already installed.
        if ($existing.InstalledLocation.EndsWith("Modules")) {
            $modulePath = Join-Path -Resolve $existing.InstalledLocation $existing.Name $existing.Version
        }
        else {
            $modulePath = $existing.InstalledLocation
        }
        $existingVersion = $existing.Prerelease ? "$($existing.Version)-$($existing.Prerelease)" : $existing.Version
        return $modulePath,$existingVersion
    }
    else {
        return $null
    }
}