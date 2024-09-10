function Import-TasksFromExtension {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $TasksPath
    )

    $tasksToImport = @()
    if (Test-Path $TasksPath) {
        $extensionTaskFiles = Get-ChildItem -Path $TasksPath -Filter "*.tasks.ps1" -File
        $extensionTaskFiles |
            Where-Object { $_ } |
            ForEach-Object {
                $tasksToImport += $_
            }
    }

    return $tasksToImport
}