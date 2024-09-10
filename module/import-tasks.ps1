# Load core task definitions
# TBC: What should constitute a core task?
# NOTE: These are currently overridden when importing the original 'Endjin.RecommendedPractices.Build'
#       module as an extension.
$taskGroups = @(
    # "common"
    # "cicd-server"
)
$taskGroups | ForEach-Object {
    $taskFilename = "$_.tasks.ps1"
    $taskFilePath = Resolve-Path ([IO.Path]::Combine($PSScriptRoot, "tasks", $taskFilename))
    Write-Information "Import '$taskFilePath'"
    . $taskFilePath
}

# Functionality is provided by extensions, for convenience we can provide 1 or more common
# scenarios (e.g. .NET Build, Python Build, Azure Deployment etc.), but a customised set
# of extensions can be specified in 2 ways:
#  1) Defining the '$devopsExtensions' variable early in the calling script (i.e. before calling 'endjin-devops.tasks')
#  2) Via the 'ENDJIN_DEVOPS_EXTENSIONS' environment variables, however note that the former method will take precedence over the environment variable
[hashtable[]]$devopsExtensions ??= $env:ENDJIN_DEVOPS_EXTENSIONS ? ($env:ENDJIN_DEVOPS_EXTENSIONS -split ";" | % {@{"$_" = @{}}}) : @{}

# By default, extensions are loaded from the PowerShell Gallery, but this can be overridden
# in a similar fashion to the 'ENDJIN_DEVOPS_EXTENSIONS' property.
$devopsExtensionsRepository ??= !$env:ENDJIN_DEVOPS_EXTENSIONS_PS_REPO ? "PSGallery" : $env:ENDJIN_DEVOPS_EXTENSIONS_PS_REPO

# Process the extensions configuration, obtaining them where necessary and
# filling-out the addtional metadata required by subsequent steps to load them.
$devopsExtensions = Register-Extensions -Extensions $devopsExtensions `
                                        -DefaultRepository $devopsExtensionsRepository

#
# Load the process definition
#
# The logical process needs to be defined before importing the tasks as they will likely
# reference other tasks that they depend on etc.

# First we decide where the core process is being defined:
# 1) Check whether an extension has been declared as providing it via the 'Process' property
#    NOTE: For the moment, the first one found wins
# 2) If not, fallback to using the core process defined in this module
$processFromExtension = $devopsExtensions |
                            Where-Object { $_.ContainsKey("Process") } |
                            Select-Object -First 1
if ($processFromExtension) {
    $processPath = Join-Path $processFromExtension.Path $processFromExtension.Process
    Write-Host "Importing process from extension '$($processFromExtension.Name)' : $processPath"
}
else {
    $processPath = Join-Path $PSScriptRoot "tasks" "build.process.ps1"
    Write-Host "Importing core process from '$processPath'"
}
. $processPath

#
# Load tasks & functions from extensions
#
foreach ($extension in $devopsExtensions){
    $extensionName = $extension.Name
    Write-Host "Importing functions & tasks from extension: $extensionName" -f Green
    if (!$extension.Enabled) {
        Write-Warning "Skipping disabled extension '$extensionName'"
        continue
    }

    # Import tasks
    Write-Host "Importing tasks"
    $tasksDir = Join-Path $extension.Path "tasks"
    $tasksToImport = Import-TasksFromExtension -TasksPath $tasksDir
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
    Write-Host "Importing functions"
    $functionsDir = Join-Path $extension.Path "functions"
    $functionsToImport = Import-FunctionsFromExtension -FunctionsPath $functionsDir
    $functionsToImport | ForEach-Object {
        Write-Verbose "Importing function '$($_.FullName)'"
        . $_
    }
}
