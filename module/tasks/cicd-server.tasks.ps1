$IsRunningOnBuildServer = $false
$IsAzureDevOps = $false
$IsGitHubActions = $false
# Controls the format of the version number used as the build server's build number
$GitVersionComponentForBuildNumber = "SemVer"

# Synopsis: Identifies which, if any, CI server/platform is running the current build
task DetectBuildServer {
    if ($env:TF_BUILD) {
        $script:IsRunningOnBuildServer = $true
        $script:IsAzureDevOps = $true
        Write-Build White "Azure Pipelines detected"
    }
    elseif ($env:GITHUB_ACTIONS) {
        $script:IsRunningOnBuildServer = $true
        $script:IsGitHubActions = $true
        Write-Build White "GitHub Actions detected"
    }
}

task SetBuildServerBuildNumber -If {$IsRunningOnBuildServer} {
    if ($IsAzureDevOps) {
        Write-Host "Setting Azure Pipelines build number: $($GitVersion[$GitVersionComponentForBuildNumber])"
        Write-Host "##vso[build.updatebuildnumber]$($GitVersion[$GitVersionComponentForBuildNumber])"
    }
}