# <copyright file="import-tasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $ZfPath
)

# Functionality is provided by extensions that are specified in 2 ways:
#  1) Defining the '$zerofailedExtensions' variable early in the calling script (i.e. before calling 'ZeroFailed.tasks')
#  2) Via the 'ZF_EXTENSIONS' environment variable containing a JSON string with the same structure as #1. Note that this method will take precedence over #1.
if ($env:ZF_EXTENSIONS) {
    if ($zerofailedExtensions) {
        Write-Host "Overriding extensions configuration with environment variable 'ZF_EXTENSIONS'" -f Green
    }
    else {
        Write-Host "Loading extensions configuration from environment variable 'ZF_EXTENSIONS'" -f Green
    }

    try {
        [hashtable[]]$zerofailedExtensions = $env:ZF_EXTENSIONS | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Warning "Failed to parse environment variable 'ZF_EXTENSIONS' as JSON: $($_.Exception.Message)"
        Write-Verbose "ZF_EXTENSIONS: $env:ZF_EXTENSIONS"
        [hashtable[]]$zerofailedExtensions = @()
    }
}

# By default, extensions are loaded from the PowerShell Gallery, but this can be overridden
# in a similar fashion to the 'ZF_EXTENSIONS' property.
$zerofailedExtensionsRepository ??= !$env:ZF_EXTENSIONS_PS_REPO ? "PSGallery" : $env:ZF_EXTENSIONS_PS_REPO

# Process the extensions configuration, obtaining them where necessary and
# filling-out the addtional metadata required by subsequent steps to load them.
if ($zerofailedExtensions.Count -gt 0) {
    Write-Host "*** Registering Extensions..." -f Green
    [array]$registeredExtensions = Register-Extensions -Extensions $zerofailedExtensions `
                                                -DefaultPSRepository $zerofailedExtensionsRepository `
                                                -ZfPath $ZfPath `
                                                -Verbose:$VerbosePreference
}
else {
    Write-Host "No extensions specified" -f Yellow
}

# Validate whether extension dependencies are non-conflicting
# For the moment we'll just log a warning and remove duplicate references, with no regard for versioning - first one wins
($registeredExtensions | Group-Object -Property Name) |
    Where-Object { $_.Count -gt 1 } |
    ForEach-Object {
        Write-Warning "Multiple versions of extension '$($_.Name)' have been resolved - removing duplicates, will use the first one found: $($_.Group[0] | Select-Object Name,Version,Path | ConvertTo-Json)"
    }
$registeredExtensions = $registeredExtensions |
                            Group-Object -Property Name |
                                ForEach-Object {
                                    $_.Group |
                                    Select-Object -First 1
                                }

#
# Load the process definition
#
# The logical process needs to be defined before importing the tasks as they will likely
# reference other tasks that they depend on etc.

# First we decide where the core process is being defined:
# 1) Check whether an extension has been declared as providing it via the 'Process' property
#    NOTE: For the moment, the first one found wins
# 2) If not, assume the calling process is defining their own process
[array]$processesFromExtension = $registeredExtensions |
                            Where-Object { $_.ContainsKey("Process") }
if ($processesFromExtension.Count -gt 1) {
    Write-Warning "Multiple extensions have declared a process definition, will use the first one found: $($processesFromExtension[0] | Select-Object Name,Version,Path,Process | ConvertTo-Json)"
}

$processFromExtension = $processesFromExtension | Select-Object -First 1
if ($processFromExtension) {
    $processPath = Join-Path $processFromExtension.Path $processFromExtension.Process
    Write-Host "Using process from extension '$($processFromExtension.Name)'" -f Green
    
    # Dot-source the file that defines the tasks representing the top-level process
    if (!(Test-Path $processPath)) {
        throw "Process definition not found: $processPath"
    }
    Write-Verbose "Importing process definition: $processPath"
    . $processPath
}
else {
    $localProcessDefinition = Get-ChildItem $ZfPath\*.process.ps1 | Select-Object -First 1
    if ($localProcessDefinition) {
        Write-Host "Found local process definition '$($localProcessDefinition.Name)'" -f Green
        . $localProcessDefinition.FullName
    }
    else {
        Write-Host "No process definition has been specified from an extension or found locally, assuming an in-line definition" -f Green
    }
}

#
# Load tasks & functions from extensions
#
if ($registeredExtensions.Count -gt 0) {
    Write-Host "Loading functions & tasks from extensions..." -f Green
    # We do this processing in reverse order (i.e. starting from the bottom of the dependency tree),
    # so that any overriding values that are set in the dependent extension(s) can take precedence.
    for ($i=$registeredExtensions.Count-1; $i -ge 0; $i--) {
        
        $extension = $registeredExtensions[$i]
        Write-Host $extension.Name -f Cyan
        $extensionName = $extension.Name
        if (!$extension.Enabled) {
            Write-Warning "Skipping disabled extension '$extensionName'"
            continue
        }
    
        # Import tasks
        Write-Host "- Importing tasks"
        $tasksDir = Join-Path $extension.Path "tasks"
        $tasksToImport = Get-TasksFileListFromExtension -TasksPath $tasksDir
        if (!($tasksToImport)) {
            Write-Warning "No tasks found in '$extensionName'"
        }
        else {
            $tasksToImport | ForEach-Object {
                Write-Verbose "Importing task '$($_.FullName)'"
                . $_
            }
        }
    
        # Import functions
        Write-Host "- Importing functions"
        $functionsDir = Join-Path $extension.Path "functions"
        $functionsToImport = Get-FunctionsFileListFromExtension -FunctionsPath $functionsDir
        $functionsToImport | ForEach-Object {
            Write-Verbose "Importing function '$($_.FullName)'"
            . $_
        }
    
    }
}
Write-Host "*** Extensions registration complete`n" -f Green
