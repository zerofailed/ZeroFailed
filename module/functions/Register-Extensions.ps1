# <copyright file="Register-Extensions.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Register-Extensions {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable[]] $ExtensionsConfig,

        [Parameter(Mandatory=$true)]
        [string] $DefaultPSRepository,

        [Parameter(Mandatory=$true)]
        [string] $ZfPath,

        [Parameter()]
        [ValidateSet('Write', 'Frozen', 'Off')]
        [string] $LockMode = 'Write'
    )

    [hashtable[]]$processedExtensionConfig = @()

    # The lock file records the exact version of every extension that was installed, including dependencies:
    #  - Write:  extensions are resolved as normal, then the lock file is updated
    #  - Frozen: the versions in the lock file are installed, and any difference from it is an error
    #  - Off:    the lock file is not used
    $lockFilePath = Join-Path $ZfPath 'extensions.lock.json'
    $lockedExtensions = $null
    if ($LockMode -eq 'Frozen') {
        $lockedExtensions = _readExtensionLockFile -Path $lockFilePath
        if ($null -eq $lockedExtensions) {
            throw "The extensions lock mode is 'Frozen', but there is no lock file at '$lockFilePath'. Run with the lock mode set to 'Write' to create it."
        }
        Write-Host "Using extensions lock file: $lockFilePath"
    }

    # Extensions will be installed under the ZfPath, which by convention
    # is the '.zf' folder in the root of a project.
    $zfExtensionsPath = Join-Path $ZfPath 'extensions'
    if (!(Test-Path $zfExtensionsPath)) {
        New-Item -ItemType Directory $zfExtensionsPath | Out-Null
    }
    Write-Host "ZF Extensions Path: $zfExtensionsPath"

    # Ensure that $zfExtensionsPath is the first place we will look
    # for modules by putting it at the front of $env:PSModulePath
    [string[]]$moduleSearchPaths = $env:PSModulePath -split [IO.Path]::PathSeparator
    if ($zfExtensionsPath -notin $moduleSearchPaths) {
        $moduleSearchPaths = ,$zfExtensionsPath + $moduleSearchPaths
    }
    elseif ($moduleSearchPaths[0] -ne $zfExtensionsPath) {
        $moduleSearchPaths = ,$zfExtensionsPath + $($moduleSearchPaths | Where-Object {$_ -ne $zfExtensionsPath})
    }
    $env:PSModulePath = $moduleSearchPaths -join [IO.Path]::PathSeparator

    # Process each configured extension
    for ($i=0; $i -lt $ExtensionsConfig.Length; $i++) {

        $registeredExtensions = Register-ExtensionAndDependencies -ExtensionConfig $ExtensionsConfig[$i] `
                                                                 -TargetPath $zfExtensionsPath `
                                                                 -LockedExtensions $lockedExtensions

        # Persist the fully-populated extension metadata
        $processedExtensionConfig += $registeredExtensions
    }

    # When several extensions require the same extension with a minimum version, use a version that satisfies all of them
    $processedExtensionConfig = _resolveExtensionVersionRanges -Extensions $processedExtensionConfig

    switch ($LockMode) {
        'Write' {
            _writeExtensionLockFile -Path $lockFilePath -Extensions $processedExtensionConfig
        }
        'Frozen' {
            _assertExtensionLockSatisfied -Extensions $processedExtensionConfig -LockedExtensions $lockedExtensions -LockFilePath $lockFilePath
        }
    }

    return $processedExtensionConfig
}
