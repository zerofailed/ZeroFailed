# Extensions setup
$zerofailedExtensions = @(
    @{
        Name = "ZeroFailed.Build.PowerShell"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.PowerShell.git"
        GitRef = "main"
    }
    # Currently needed for the report generator tool
    @{
        Name = "ZeroFailed.Build.DotNet"
        GitRepository = "https://github.com/zerofailed/ZeroFailed.Build.DotNet.git"
        GitRef = "main"
    }
)

# Load the tasks and process
. ZeroFailed.tasks -ZfPath $here/.zf

# Set the required build options
$PesterTestsDir = "$here/module"
$PesterVersion = "5.7.1"
$PesterCodeCoveragePaths = @("$here/module/functions")
$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/ZeroFailed.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @("ZeroFailed.tasks")
    }
)
$PSMarkdownDocsFlattenOutputPath = $true
$PSMarkdownDocsOutputPath = './docs/functions'
$PSMarkdownDocsIncludeModulePage = $false
$CreateGitHubRelease = $true
$GitHubReleaseArtefacts = @()
$SkipZeroFailedModuleVersionCheck = $true
$SkipPrAutoflowVersionCheck = $true
$SkipPrAutoflowEnrollmentCheck = $true
$CheckLatestVersion = $true

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
