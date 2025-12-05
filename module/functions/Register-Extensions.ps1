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
        [string] $ZfPath
    )
    
    [hashtable[]]$processedExtensionConfig = @()

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

        $registeredExtensions = Register-ExtensionAndDependencies -ExtensionConfig $ExtensionsConfig[$i] -TargetPath $zfExtensionsPath
        
        # Persist the fully-populated extension metadata
        $processedExtensionConfig += $registeredExtensions
    }

    return $processedExtensionConfig
}
