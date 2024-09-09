$PackagesDir ??= "_packages"
$CoverageDir ??= "_codeCoverage"
$CoverageDir = [IO.Path]::IsPathRooted($CoverageDir) ? $CoverageDir : (Join-Path $here $CoverageDir)


$SkipBuildModuleVersionCheck = $false

# Synopsis: Allows build properties to be overriden by environment variables
task ApplyEnvironmentVariableOverrides {

    # TODO: Review whether we still need this function, or whether we can wholly rely on the 'property' syntax offered by InvokeBuild

    # dot-source the function to load into the same scope as
    # the InvokeBuild process, otherwise as a module function it
    # won't have access to any of the variables it needs to update
    . $PSScriptRoot/../functions/_Set-VariableFromEnvVar.ps1
    
    $buildEnvVars = Get-ChildItem env:BUILDVAR_*
    foreach ($buildEnvVar in $buildEnvVars) {
        # strip the 'BUILDVAR_' prefix to leave the variable name to be overridden
        $varName = $buildEnvVar.Name -replace "^BUILDVAR_",""

        $res = Set-VariableFromEnvVar -VariableName $varName -EnvironmentVariableName $buildEnvVar.Name

        if ($res) {
            Write-Build Yellow "Overriding '$varName' from environment variable [Value=$((Get-Item variable:/$varName).Value)] [Type=$((Get-Item variable:/$varName).Value.GetType().Name)]"
        }
    }
}

task CheckLatestVersion -If { !$SkipBuildModuleVersionCheck } {
    $currentVersion = (get-module endjin-devops).Version
    [version]$latestVersion = (Find-Module endjin-devops -Repository PSGallery).Version
    if ($currentVersion -lt $latestVersion) {
        $msg = @"
A newer endjin-devops version is available: $latestVersion
An overnight CodeOps process should automatically update this, alternatively, you can manually update by changing the default value of the '`$BuildModuleVersion' parameter in this build script to be '$latestVersion'
"@
        Write-Warning $msg
    }
    else {
        Write-Build Green "Build tooling is up-to-date"
    }
}

task EnsureGitHubCli {
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "The GitHub CLI is required - please install as per: https://github.com/cli/cli#installation"
    }

    # Test whether GitHub CLI is logged-in
    & gh repo view endjin/endjin-devops | Out-Null
    if ($LASTEXITCODE -eq 4) {
        throw "You must be logged-in to GitHub CLI to run this build. Please run 'gh auth login' to login and then re-run the build."
    }
}

task EnsurePackagesDir {
    # Ensure we resolve a relative path for $PackagesDir now, rather than letting it be resolved by downstream tooling
    # For example, 'dotnet pack' will resolve it relative to a given project which is not what we want.
    $script:PackagesDir = [IO.Path]::IsPathRooted($PackagesDir) ? $PackagesDir : (Join-Path $here $PackagesDir)

    if (!(Test-Path $PackagesDir)) {
        New-Item -Path $PackagesDir -ItemType Directory | Out-Null
    }
}

task RunChecks -If { !$IsRunningOnBuildServer } `
    -Jobs CheckLatestVersion