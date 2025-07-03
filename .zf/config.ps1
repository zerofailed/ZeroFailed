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

$PowerShellModulesToPublish = @(
    @{
        ModulePath = "$here/module/ZeroFailed.psd1"
        FunctionsToExport = @("*")
        CmdletsToExport = @()
        AliasesToExport = @("ZeroFailed.tasks")
    }
)
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

# Override & customise the default implementation to enable code coverage features
task RunPesterTests `
    -If {!$SkipPesterTests -and $PesterTestsDir} `
    -After TestCore `
    InstallPester,{

    $config = New-PesterConfiguration
    $config.Run.Path = $PesterTestsDir
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Normal'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = $PesterOutputFormat
    $config.TestResult.OutputPath = (Join-Path $here $PesterOutputFilePath)
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.OutputFormat = 'Cobertura'
    $config.CodeCoverage.OutputPath = (Join-Path $CoverageDir 'coverage.pester-cobertura.xml')

    New-Item -ItemType Directory $CoverageDir -Force | Out-Null

    $results = Invoke-Pester -Configuration $config

    # Generate code coverage reports
    _GenerateTestReport `
        -ReportTypes $TestReportTypes `
        -OutputPath $CoverageDir
    
    _GenerateCodeCoverageMarkdownReport `
        -UseGitHubFlavour $IsGitHubActions `
        -OutputPath $CoverageDir

    if ($results.FailedCount -gt 0) {
        throw ("{0} out of {1} tests failed - check previous logging for more details" -f $results.FailedCount, $results.TotalCount)
    }
}