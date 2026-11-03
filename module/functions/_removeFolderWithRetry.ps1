# <copyright file="_removeFolderWithRetry.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _removeFolderWithRetry {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter()]
        [int] $TimeoutSeconds = 10,

        [Parameter()]
        [int] $RetryDelayMilliseconds = 200
    )

    # Editors, language services and antivirus scanners often open files soon after they are written, which stops them
    # being deleted on Windows. These locks are short, so try again until the timeout.
    $maxRetryDelayMilliseconds = 1000
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            return
        }
        catch {
            if ($stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw ("Unable to delete '$Path' because a file in it is in use by another process (for example an editor or antivirus scanner): " +
                       $_.Exception.Message)
            }
            Write-Verbose "Unable to delete '$Path', retrying in $($RetryDelayMilliseconds)ms: $($_.Exception.Message)"
            Start-Sleep -Milliseconds $RetryDelayMilliseconds
            $RetryDelayMilliseconds = [Math]::Min($RetryDelayMilliseconds * 2, $maxRetryDelayMilliseconds)
        }
    }
}
