# Define required extensions
$devopsExtensionsRepository = ""
$devopsExtensions = @(
    "endjin-devops-build-powershell"
)

# Load the tasks and process
. endjin-devops.tasks

# Set the required build options
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/endjin-devops.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @("endjin-devops.tasks")
    }
)

# Customise the build process
task . FullBuild

# build extensibility tasks
task RunFirst {}
task PreInit {}
task PostInit {}
task PreVersion {}
task PostVersion {}
task PreBuild {}
task PostBuild {}
task PreTest {}
task PostTest {}
task PreTestReport {}
task PostTestReport {}
task PreAnalysis {}
task PostAnalysis {}
task PrePackage {}
task PostPackage {}
task PrePublish {}
task PostPublish {}
task RunLast {}
