# <copyright file="_installVendir.ps1" company="Endjin Limited">
# Copyright (c) Endjin Limited. All rights reserved.
# </copyright>

function _installVendir {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string] $InstallDir,

        [Parameter()]
        [string] $ToolName = 'vendir',

        [Parameter()]
        [switch] $NoVerify
    )
    
    # Check if vendir is already available in the system PATH
    if (Get-Command $ToolName -ErrorAction Ignore) {
        return $ToolName
    }

    # Detect OS and architecture
    if ($IsWindows) {
        $cpuArchCode = Get-CimInstance -ClassName Win32_Processor |
                            Select-Object -ExpandProperty Architecture
        if ($cpuArchCode -eq 12) {
            $archSuffix = 'arm64'
        }
        elseif ($cpuArchCode -eq 9) {
            $archSuffix = 'amd64'
        }
        else {
            throw "Unsupported CPU architecture '$cpuArchCode' for vendir installation. Please install vendir manually."
        } 
    }
    else {
        $cpuArch = (uname -m)
        if ($cpuArch -eq 'x86_64') {
            $archSuffix = 'amd64'
        }
        elseif ($cpuArch -eq 'aarch64' -or $cpuArch -eq 'arm64') {
            $archSuffix = 'arm64'
        }
        else {
            throw "Unsupported CPU architecture '$cpuArch' for vendir installation. Please install vendir manually."
        }
    }

    if ($IsWindows) {
        $downloadFile = "vendir-windows-$archSuffix.exe"
        $ToolName = 'vendir.exe'
    }
    elseif ($IsLinux) {
        $downloadFile = "vendir-linux-$archSuffix"
    }
    elseif ($IsMacOS) {
        $downloadFile = "vendir-darwin-$archSuffix"
    }
    else {
        throw "Unsupported OS for vendir installation. Please install vendir manually."
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $installedToolPath = Join-Path $InstallDir $ToolName

    # Check if vendir has already been installed by this function, and if not, download and install it
    if (!(Get-Command $installedToolPath -ErrorAction Ignore)) {
        # Construct the required URL to the relevant release
        $releaseUrl = 'https://github.com/carvel-dev/vendir/releases/download'
        $releaseVersion = 'v0.45.0'

        # Configure expected SHA256 hashes for supported versions
        $vendirHashes = @{
            'vendir-windows-amd64.exe' = '779d4fe4170a472523bb1fcd0a591e460ff417381abd92ba8d2d8b7fa91f5531'
            'vendir-linux-amd64'       = 'd60ad65bbd0658d377f2dcf57b3119f16c5a3a7eeaf80019a3d243a620404d7e'
            'vendir-linux-arm64'       = 'f2b517cfa1a843ffc7b9beb37146ffd8157a5c842138c4f6a5728f708115dbfd'
            'vendir-darwin-amd64'      = '4bce3c5341f1f1566fde617bfabaee16b26e26f6d0e8b4394780a03d57b248a5'
            'vendir-darwin-arm64'      = '6ff67773916bf1587533daf912a24d0fc5c5914e90aa6cd9099b22a480cd0a53'
        }
        if (-not $vendirHashes.ContainsKey($downloadFile)) {
            throw "No known hash for vendir binary $downloadFile. Please update the script with the correct hash."
        }
        $expectedHash = $vendirHashes[$downloadFile]

        Invoke-RestMethod -Uri "$releaseUrl/$releaseVersion/$downloadFile" -OutFile $installedToolPath

        # Verify SHA256 hash
        $actualHash = (Get-FileHash -Path $installedToolPath -Algorithm SHA256).Hash.ToLower()
        if ($NoVerify) {
            Write-Warning "Skipping vendir binary hash verification as requested."
        }
        elseif ($actualHash -ne $expectedHash.ToLower()) {
            Remove-Item $installedToolPath -Force
            throw "Hash verification failed for vendir binary $downloadFile. Expected: $expectedHash, Actual: $actualHash. Aborting execution."
        }
        if (!$IsWindows) {
            # Make executable
            $ErrorActionPreference = 'Stop'
            $PSNativeCommandUseErrorActionPreference = $true
            & chmod +x $installedToolPath
        }
    }

    return $installedToolPath
}