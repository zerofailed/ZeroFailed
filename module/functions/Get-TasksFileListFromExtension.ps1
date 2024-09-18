# <copyright file="Get-TasksFileListFromExtension.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-TasksFileListFromExtension {
    <#
        .SYNOPSIS
        Finds all the task definition files from a specified extension.

        .DESCRIPTION
        Finds all the files that define tasks for an extension, using the pattern defined in '-TasksFileGlob'.

        .PARAMETER TasksPath
        The path to the extension tasks.

        .PARAMETER TasksFileGlob
        The glob pattern to use when searching for task files, defaults to '*.tasks.ps1'.

        .INPUTS
        None. You can't pipe objects to Get-TasksFileListFromExtension.

        .OUTPUTS
        System.IO.FileInfo[]

        Returns an array of paths to the files containing the task definitions.

        .EXAMPLE
        PS:> $taskFiles = Get-TasksFileListFromExtension -TasksPath "C:\myExtension\tasks"
        PS:> $taskFiles | % { . $_ }
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $TasksPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $TasksFileGlob = "*.tasks.ps1"
    )

    $tasksToImport = @()
    if (Test-Path $TasksPath) {
        $extensionTaskFiles = Get-ChildItem -Path $TasksPath -Filter $TasksFileGlob -File -Recurse
        $extensionTaskFiles |
            Where-Object { $_ } |
            ForEach-Object {
                $tasksToImport += $_
            }
    }

    return $tasksToImport
}