# <copyright file="_waitForExtensionsLock.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _waitForExtensionsLock {
    [CmdletBinding()]
    [OutputType([System.Threading.Mutex])]
    param (
        [Parameter(Mandatory)]
        [string] $ZfPath,

        [Parameter()]
        [timespan] $Timeout = [timespan]::FromMinutes(10)
    )

    # Runs that share a '.zf' folder (e.g. parallel builds of the same repository) would otherwise install extensions
    # into the same folders, and write the same lock file, at the same time. A named mutex works across processes on
    # every platform. The name is a hash of the full path, as a path can contain characters that a name cannot.
    $fullPath = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ZfPath)).TrimEnd('/', '\')
    $pathHash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($fullPath.ToLowerInvariant()))
    $mutexName = 'ZeroFailed-{0}' -f [Convert]::ToHexString($pathHash).Substring(0, 16).ToLowerInvariant()

    $mutex = [System.Threading.Mutex]::new($false, $mutexName)
    try {
        # A mutex that another run did not release (e.g. because it was stopped) is acquired by the next run
        $acquired = $false
        try {
            $acquired = $mutex.WaitOne(0)
        }
        catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
        }

        if (!$acquired) {
            Write-Host "Waiting for another run that uses '$fullPath' to finish..." -f Cyan
            try {
                $acquired = $mutex.WaitOne($Timeout)
            }
            catch [System.Threading.AbandonedMutexException] {
                $acquired = $true
            }
            if (!$acquired) {
                throw "Timed out after $Timeout waiting for another run that uses '$fullPath' to finish."
            }
        }
    }
    catch {
        $mutex.Dispose()
        throw
    }

    return $mutex
}
