<#
This example demonstrates how to use the 'ZeroFailed' module to configure a build
process that consumes the Endjin.RecommendedPractices.Build module as an extension.
#>

$zerofailedExtensions = @(
    @{
        # Use latest stable version of existing scripted build module
        Name = "Endjin.RecommendedPractices.Build"
        Process = "tasks/build.process.ps1"
        # Version = "<specific-version>"
        PreRelease = $false
        # Path = "<path-to-local-copy>"  # If Path is not specified, the module will be installed from the repository
        # Repository = "PSGallery"       # Allows the source repository to be overridden on a per extension basis
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

#
# Build process configuration
#
$SolutionToBuild = (Resolve-Path (Join-Path $here "./Solutions/MySolution.sln")).Path


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
