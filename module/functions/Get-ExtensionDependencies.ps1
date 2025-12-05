# <copyright file="Get-ExtensionDependencies.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionDependencies {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory=$true)]
        [hashtable] $Extension
    )

    # Constants
    $ZF_PRIVATEDATA_KEY_NAME = "ZeroFailed"
    $ZF_EXTENSION_DEPENDENCIES_KEY_NAME = "ExtensionDependencies"

    $resolvedDeps = @()
    $dependenciesConfig = $null

    # We currently support 2 mechanisms for extensions to declare their dependencies:
    #  1. via a 'dependencies.psd1' (considered legacy due to a structural bug)
    #  2. via configuration stored in the module manifest under the 'PrivateData' key
    #
    # Option 2 is preferred with Option 1 retained as a fallback for backwards-compatibility.

    $extensionModuleManifestPath = Join-Path -Path $Extension.Path -ChildPath "$($Extension.Name).psd1"
    $extensionModuleManifest = Import-PowerShellDataFile -Path $extensionModuleManifestPath
    if ($extensionModuleManifest.ContainsKey("PrivateData") -and `
            $extensionModuleManifest.PrivateData.ContainsKey($ZF_PRIVATEDATA_KEY_NAME)
    ) {
        if ($extensionModuleManifest.PrivateData.$ZF_PRIVATEDATA_KEY_NAME.ContainsKey($ZF_EXTENSION_DEPENDENCIES_KEY_NAME)) {
            Write-Verbose "Reading dependencies from module manifest"
            $dependenciesConfig = $extensionModuleManifest.PrivateData.$ZF_PRIVATEDATA_KEY_NAME.$ZF_EXTENSION_DEPENDENCIES_KEY_NAME
        }
        else {
            if ($extensionModuleManifest.PrivateData.$ZF_PRIVATEDATA_KEY_NAME.Keys.Count -gt 0) {
                Write-Warning "Unknown '$ZF_PRIVATEDATA_KEY_NAME' configuration keys were detected in the extension's module manifest: $($extensionModuleManifest.PrivateData.$ZF_PRIVATEDATA_KEY_NAME.Keys)"
            }
        }
    }
    else {
        # Fallback to legacy mechanism as backwards-compatibility measure
        $legacyDepConfigPath = Join-Path -Path $Extension.Path -ChildPath 'dependencies.psd1'
        if ((Test-Path $legacyDepConfigPath)) {
            Write-Warning "Reading dependencies from 'dependencies.psd1', which is now deprecated. The extension developer should move them to the module manifest under the 'PrivateData.$ZF_PRIVATEDATA_KEY_NAME.$ZF_EXTENSION_DEPENDENCIES_KEY_NAME' key."

            # Log a warning if an array syntax has been used (i.e. potentially multiple dependencies have been specified)
            # Whilst 'Import-PowerShellDataFile' will process such a file without error, it will
            # only return the first item in the array.
            if ((Get-Content $legacyDepConfigPath -Raw).TrimStart().StartsWith("@(")) {
                Write-Warning "Possible multiple dependencies in 'dependencies.psd1'; this is not supported, only the first one will be available. Please migrate to the above method."
            }

            $dependenciesConfig = Import-PowerShellDataFile -Path $legacyDepConfigPath
            if ($dependenciesConfig.Keys.Count -eq 0) {
                # Ensure an empty .psd1 file is treated as no dependencies
                $dependenciesConfig = $null
            }
        }
    }

    # Detect if no dependencies
    foreach ($dependencyConfig in [array]$dependenciesConfig) {
        try {
            # Use existing logic to resolve the supported syntaxes into the canonical form
            $resolvedDeps += Resolve-ExtensionMetadata -Value $dependencyConfig
        }
        catch {
            throw "Failed to resolve extension metadata for dependency due to invalid configuration: $($_.Exception.Message)`ndependencyConfig: $($dependencyConfig | ConvertTo-Json -Depth 3)"
        }
    }

    Write-Verbose "Resolved Dependencies: $($resolvedDeps | ConvertTo-Json -Depth 3)"
    return $resolvedDeps
}
