# <copyright file="Get-ExtensionAvailableTasks.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>
function Get-ExtensionAvailableTasks {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory=$true)]
        [string] $ExtensionPath
    )

    # Special handling for when this function is called from within an InvokeBuild process (e.g. when this
    # function's Pester tests are run as part of the build process), whereby the 'task' keyword is already
    # defined as an Alias to 'Invoke-BuildTask' and will take precedence over our function override below.
    $aliasBackup = Get-Alias task -ErrorAction Ignore
    if ($aliasBackup) {
        Remove-Alias -Name task
    }

    $availableTasks = @()
    try {
        # Define a private override implementation for the 'task' keyword used in '*.tasks.ps1' files that
        # simply returns the task name as a string.  We will use this as a simple mechanism to discover
        # all of the tasks defined in a given code file.
        function task {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory, Position = 0)]
                [string] $TaskName,
    
                [Parameter(ValueFromRemainingArguments)]
                $Remaining
            )
            return $TaskName
        }

        $tasksDir = Join-Path $ExtensionPath "tasks"
        if (!(Test-Path $tasksDir)) {
            Write-Warning "No tasks directory found at '$tasksDir'"
            return @()
        }

        $tasksToImport = Get-TasksFileListFromExtension -TasksPath $tasksDir
        $tasksToImport |
        # Treat tasks with a '_' prefix as private and exclude them
        Where-Object { !$_.BaseName.StartsWith("_") } |
        ForEach-Object {
            $taskItem = $_.FullName
            Write-Verbose "Importing task '$taskItem'"
            # This is probably a sign that we should have a different approach for enumerating the
            # tasks in each extension, but for now we'll just suppress any errors that might occur
            # when trying to dotsource the file.  For example, since this function is running in a
            # module scope, certain values referenced in the task files may not be available.
            
            # Using our private 'task' implementation, we can simply execute each task file and it
            # will return the name of each task defined in it.
            $availableTasks += try {
                . $taskItem
            }
            catch {}
        }
    }
    finally {
        # Undo our Alias manipulation
        if ($aliasBackup) {
            New-Alias -Name $aliasBackup.Name -Value $aliasBackup.Definition -Scope Script | Out-Null
        }
    }

    return $availableTasks
}