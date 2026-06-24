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
# Also publish the module(s) above to GitHub Packages, in addition to the PowerShell Gallery.
$GitHubPackagesFeedUrl = "https://nuget.pkg.github.com/zerofailed/index.json"
$SkipGitHubPackagesPublish = $false
$GitHubPackagesApiKey = property ZF_GITHUB_PACKAGES_TOKEN ""
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

# Synopsis: Publishes the configured PowerShell module(s) to GitHub Packages, in addition to the
# PowerShell Gallery publish provided by the ZeroFailed.Build.PowerShell extension. Runs within the
# same Publish flow (-After PublishCore) so it is gated by the same release conditions.
task PublishPowerShellModulesToGitHubPackages `
    -If { !$SkipGitHubPackagesPublish -and ![string]::IsNullOrEmpty($GitHubPackagesApiKey) } `
    -After PublishCore `
    Version,{

    $githubPackagesRepositoryName = "ZeroFailedGitHubPackages"

    # A nominal attempt to make a NuGet-compatible pre-release tag compatible with the additional
    # restrictions enforced by the PowerShell Gallery, kept consistent across both feeds.
    $safePreReleaseTag = $env:GITVERSION_NuGetPreReleaseTag -replace "-",""

    # Register a temporary PSResourceGet repository pointing at the GitHub Packages NuGet feed.
    if (Get-PSResourceRepository -Name $githubPackagesRepositoryName -ErrorAction SilentlyContinue) {
        Unregister-PSResourceRepository -Name $githubPackagesRepositoryName
    }
    Register-PSResourceRepository -Name $githubPackagesRepositoryName -Uri $GitHubPackagesFeedUrl -Trusted

    try {
        foreach ($module in $PowerShellModulesToPublish) {

            Write-Build White "Publishing module to GitHub Packages: $($module.ModulePath)"

            # Ensure the manifest carries the correct version independently of the PowerShell Gallery
            # publish step, so this task also works when that step is skipped.
            Update-ModuleManifest -Path $module.ModulePath `
                                  -ModuleVersion $script:GitVersion.MajorMinorPatch `
                                  -Prerelease $safePreReleaseTag `
                                  -FunctionsToExport $module.FunctionsToExport `
                                  -CmdletsToExport $module.CmdletsToExport `
                                  -AliasesToExport $module.AliasesToExport

            Publish-PSResource -Path (Split-Path -Parent $module.ModulePath) `
                               -Repository $githubPackagesRepositoryName `
                               -ApiKey $GitHubPackagesApiKey `
                               -Verbose
        }
    }
    finally {
        Unregister-PSResourceRepository -Name $githubPackagesRepositoryName -ErrorAction SilentlyContinue
    }
}

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
