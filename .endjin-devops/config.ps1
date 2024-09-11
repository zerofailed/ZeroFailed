# Extensions setup
#
# Override default extension repository (defaults to PSGallery)
# $devopsExtensionsRepository = ""

# Declare required extensions

# Simple syntax where version constraints and/or custom process definition is not required
# $devopsExtensions = @(
#     "Endjin.RecommendedPractices.Build"
#     "../../Endjin.RecommendedPractices.Build/module"
# )

# Full syntax
$devopsExtensions = @(
    @{
        # Use latest stable version of exisiting scripted build module
        Name = "Endjin.RecommendedPractices.Build"
        Process = "tasks/build.process.ps1"
        Version = "1.5.10-beta0004"
        PreRelease = $true
        # Path = "<path-to-local-copy>"  # If Path is not specified, the module will be installed from the repository
        # Repository = ""  # Allows the source repository to be overridden on a per extension basis
    }
    # TODO: Add support for obtaining extensions via Git?
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

#
# Build Process Extensibility Points - uncomment and implement as required
#

# task RunFirst {}
# task PreInit {}
# task PostInit {}
# task PreVersion {}
# task PostVersion {}
# task PreBuild {}
# task PostBuild {}
# task PreTest {}
# task PostTest {}
# task PreTestReport {}
# task PostTestReport {}
# task PreAnalysis {}
# task PostAnalysis {}
# task PrePackage {}
# task PostPackage {}
# task PrePublish {}
# task PostPublish {}
# task RunLast {}
