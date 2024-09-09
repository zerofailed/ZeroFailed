# Load core task definitions
$taskGroups = @(
    "common"
    "cicd-server"
)
$taskGroups | ForEach-Object {
    $taskFilename = "$_.tasks.ps1"
    $taskFilePath = Resolve-Path ([IO.Path]::Combine($PSScriptRoot, "tasks", $taskFilename))
    Write-Information "Import '$taskFilePath'"
    . $taskFilePath
}

# Functionality is provided by extensions, for convenience we can provide 1 or more common scenarios (e.g. .NET Build, Python Build, Azure Deployment etc.),
# but a customised set of extensions can be specified in 2 ways:
#  1) Defining the '$devopsExtensions' variable early in the calling script (i.e. before calling 'endjin-devops.tasks')
#  2) Via the 'ENDJIN_DEVOPS_EXTENSIONS' environment variables, however note that the former method will take precedence over the environment variable
$devopsExtensions ??= $env:ENDJIN_DEVOPS_EXTENSIONS ? $env:ENDJIN_DEVOPS_EXTENSIONS -split ";" : @()

# By default, extensions are loaded from the PowerShell Gallery, but this can be overridden in a similar fashion to the 'ENDJIN_DEVOPS_EXTENSIONS' property.
# TODO: Add support for specifying a custom repository for a given extension.
$devopsExtensionsRepository ??= !$env:ENDJIN_DEVOPS_EXTENSIONS_PS_REPO ? "PSGallery" : $env:ENDJIN_DEVOPS_EXTENSIONS_PS_REPO

# Support loading tasks from local folders or published modules
foreach ($extension in ($devopsExtensions -split ";")) {
    Write-Host "Processing Extension '$(Split-Path -Leaf $extension)'" -f Green
    if (!(Test-Path $extension)) {
        Write-Host "  Checking for extension '$extension' on $devopsExtensionsRepository"
        if (Find-Module $extension -ErrorAction Ignore) {
            Write-Host "  Installing extension '$extension' from $devopsExtensionsRepository"
            $extensionModule = Install-PSResource $extension -Scope CurrentUser -Repository $devopsExtensionsRepository -PassThru
            $extension = $extensionModule.InstalledLocation
            Write-Host "  Extension installed: $extension"
        }
        else {
            Write-Warning "Extension '$extension' not found locally or on $devopsExtensionsRepository"
            continue
        }
    }

    $tasksDir = Join-Path $extension "tasks"
    if (Test-Path $tasksDir) {
        Write-Host "  Importing tasks from '$extension'"
        $extensionTaskFiles = Get-ChildItem -Path $tasksDir -Filter "*.tasks.ps1" -File
        $extensionTaskFiles | ? { $_ } | % {
            Write-Host "  Import '$($_.FullName)'"
            . $_
        }
    }
    else {
        Write-Warning "  No tasks found in '$extension'"
    }
}

# Import the build process that orchestrates the above tasks
# TODO: Add support for specifying a custom process (e.g. to support different scenarios, like build & deployment)
. (Join-Path $PSScriptRoot "tasks/build.process.ps1")