# <copyright file="defaultBuild.process.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

# Top-level build process control flags
$SkipInit = $false
$SkipVersion = $false
$SkipBuild = $false
$SkipAnalysis = $false
$SkipTest = $false
$SkipTestReport = $false
$SkipPackage = $false
$SkipPublish = $false

# Define overall build process
task PreInit
task InitCore ApplyEnvironmentVariableOverrides,DetectBuildServer,RunChecks
task PostInit
task Init -If {!$SkipInit} PreInit,InitCore,PostInit

task PreVersion
task VersionCore GitVersion,SetBuildServerBuildNumber
task PostVersion
task Version -If {!$SkipVersion} Init,PreVersion,VersionCore,PostVersion

task PreBuild
task BuildCore
task PostBuild
task Build -If {!$SkipBuild} Init,Version,PreBuild,BuildCore,PostBuild

task PreTest
task TestCore
task PostTest
task Test -If {!$SkipTest} Init,PreTest,TestCore,PostTest

task PreTestReport
task TestReportCore
task PostTestReport
task TestReport -If {!$SkipTest -and !$SkipTestReport} Init,PreTestReport,TestReportCore,PostTestReport

task PreAnalysis
task AnalysisCore
task PostAnalysis
task Analysis -If {!$SkipAnalysis} Init,Version,PreAnalysis,AnalysisCore,PostAnalysis

task PrePackage
task PackageCore
task PostPackage
task Package -If {!$SkipPackage} Init,Version,PrePackage,PackageCore,PostPackage

task PrePublish
task PublishCore
task PostPublish
task Publish -If {!$SkipPublish} Init,Version,PrePublish,PublishCore,PostPublish

task RunFirst
task RunLast


task FullBuild RunFirst,
                Init,
                Version,
                Build,
                Test,
                TestReport,
                Analysis,
                Package,
                RunLast

task FullBuildAndPublish RunFirst,
                            Init,
                            Version,
                            Build,
                            Test,
                            TestReport,
                            Analysis,
                            Package,
                            Publish,
                            RunLast
