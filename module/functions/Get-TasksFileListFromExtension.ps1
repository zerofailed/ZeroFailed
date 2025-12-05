# <copyright file="Get-TasksFileListFromExtension.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-TasksFileListFromExtension {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
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