Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot '..\..')).Path
$VendorRoot = Join-Path $ScriptRoot 'vendor'
$WheelPartDir = Join-Path $VendorRoot 'open-webui'
$WheelhouseDir = Join-Path $VendorRoot 'wheelhouse'
$LockFile = Join-Path $ScriptRoot 'requirements-openwebui-offline.lock.txt'
$ArtifactsDir = Join-Path $RepoRoot 'artifacts'
$WheelPath = Join-Path $ArtifactsDir 'open_webui-0.8.12-py3-none-any.whl'
$VenvDir = Join-Path $RepoRoot '.venv'
$PortablePythonExe = Join-Path $RepoRoot 'python-3.11.9-win64\python.exe'
$ExpectedWheelHash = '80475609a3cd9141a66a1d3934ab15195fcf3ca08d9e6df8a937c14565be4065'

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Get-Python311 {
    if (Test-Path $PortablePythonExe) {
        return $PortablePythonExe
    }

    if (Get-Command py -ErrorAction SilentlyContinue) {
        try {
            $path = & py -3.11 -c "import sys; print(sys.executable)"
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($path)) {
                return $path.Trim()
            }
        } catch {
        }
    }

    if (Get-Command python -ErrorAction SilentlyContinue) {
        try {
            $version = & python -c "import sys; print(f'{sys.version_info[0]}.{sys.version_info[1]}')"
            if ($LASTEXITCODE -eq 0 -and $version.Trim() -eq '3.11') {
                $path = & python -c "import sys; print(sys.executable)"
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($path)) {
                    return $path.Trim()
                }
            }
        } catch {
        }
    }

    return $null
}

function Join-WheelParts {
    param(
        [string]$Destination,
        [string]$ExpectedHash
    )

    $parts = Get-ChildItem -Path $WheelPartDir -Filter 'open_webui-0.8.12-py3-none-any.whl.part-*' | Sort-Object Name
    if ($parts.Count -lt 2) {
        throw "Open WebUI wheel parts are missing in '$WheelPartDir'."
    }

    New-Item -ItemType Directory -Force -Path $ArtifactsDir | Out-Null

    if (Test-Path $Destination) {
        Remove-Item $Destination -Force
    }

    $outStream = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        foreach ($part in $parts) {
            $inStream = [System.IO.File]::OpenRead($part.FullName)
            try {
                $inStream.CopyTo($outStream)
            } finally {
                $inStream.Dispose()
            }
        }
    } finally {
        $outStream.Dispose()
    }

    $hash = (Get-FileHash -Path $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $ExpectedHash) {
        throw "Reassembled Open WebUI wheel hash mismatch. Expected '$ExpectedHash' but got '$hash'."
    }
}

function Apply-OpenWebUIOfflinePatch {
    param([string]$VenvDir)

    $MainPy = Join-Path $VenvDir 'Lib\site-packages\open_webui\main.py'
    if (-not (Test-Path $MainPy)) {
        throw "Installed Open WebUI main.py was not found: '$MainPy'"
    }

    $Marker = '# Offline bundle patch: skip retrieval bootstrap when bypass is enabled'
    $Content = [System.IO.File]::ReadAllText($MainPy)
    $Normalized = $Content -replace "`r`n", "`n"

    if ($Normalized.Contains($Marker)) {
        return
    }

    $OldBlock = (@"
try:
    app.state.ef = get_ef(app.state.config.RAG_EMBEDDING_ENGINE, app.state.config.RAG_EMBEDDING_MODEL)
    if app.state.config.ENABLE_RAG_HYBRID_SEARCH and not app.state.config.BYPASS_EMBEDDING_AND_RETRIEVAL:
        app.state.rf = get_rf(
            app.state.config.RAG_RERANKING_ENGINE,
            app.state.config.RAG_RERANKING_MODEL,
            app.state.config.RAG_EXTERNAL_RERANKER_URL,
            app.state.config.RAG_EXTERNAL_RERANKER_API_KEY,
            app.state.config.RAG_EXTERNAL_RERANKER_TIMEOUT,
        )
    else:
        app.state.rf = None
except Exception as e:
    log.error(f'Error updating models: {e}')
    pass
"@) -replace "`r`n", "`n"

    $NewBlock = (@"
try:
    # Offline bundle patch: skip retrieval bootstrap when bypass is enabled
    if app.state.config.BYPASS_EMBEDDING_AND_RETRIEVAL:
        app.state.ef = None
        app.state.rf = None
    else:
        app.state.ef = get_ef(app.state.config.RAG_EMBEDDING_ENGINE, app.state.config.RAG_EMBEDDING_MODEL)
        if app.state.config.ENABLE_RAG_HYBRID_SEARCH:
            app.state.rf = get_rf(
                app.state.config.RAG_RERANKING_ENGINE,
                app.state.config.RAG_RERANKING_MODEL,
                app.state.config.RAG_EXTERNAL_RERANKER_URL,
                app.state.config.RAG_EXTERNAL_RERANKER_API_KEY,
                app.state.config.RAG_EXTERNAL_RERANKER_TIMEOUT,
            )
        else:
            app.state.rf = None
except Exception as e:
    log.error(f'Error updating models: {e}')
    pass
"@) -replace "`r`n", "`n"

    if (-not $Normalized.Contains($OldBlock)) {
        throw "Failed to apply the offline startup patch to '$MainPy'. The expected Open WebUI 0.8.12 code block was not found."
    }

    Write-Step 'Applying offline patch to Open WebUI package'
    $Patched = $Normalized.Replace($OldBlock, $NewBlock)
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($MainPy, $Patched, $Utf8NoBom)
}

$pythonExe = Get-Python311
if (-not $pythonExe) {
    throw "Python 3.11 was not found. Ensure '$PortablePythonExe' exists or make Python 3.11 available, then rerun this script."
}

Write-Step "Using Python 3.11: $pythonExe"

if ((-not (Test-Path $WheelPath)) -or ((Get-FileHash -Path $WheelPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedWheelHash)) {
    Write-Step 'Reassembling Open WebUI wheel from split files'
    Join-WheelParts -Destination $WheelPath -ExpectedHash $ExpectedWheelHash
}

if (-not (Test-Path $WheelhouseDir)) {
    throw "Wheelhouse directory was not found: '$WheelhouseDir'"
}

if (-not (Test-Path $LockFile)) {
    throw "Lock file was not found: '$LockFile'"
}

if (-not (Test-Path $VenvDir)) {
    Write-Step 'Creating virtual environment'
    & $pythonExe -m venv $VenvDir
}

$venvPythonExe = Join-Path $VenvDir 'Scripts\python.exe'
if (-not (Test-Path $venvPythonExe)) {
    throw "Virtual environment Python was not found in '$VenvDir'."
}

Write-Step 'Installing offline dependency wheelhouse'
& $venvPythonExe -m pip install --no-index --find-links $WheelhouseDir -r $LockFile

Write-Step 'Installing Open WebUI wheel'
& $venvPythonExe -m pip install --no-index $WheelPath --no-deps

Apply-OpenWebUIOfflinePatch -VenvDir $VenvDir

Write-Step 'Offline installation completed'
Write-Host "Run '.\bundle\windows\start-openwebui.cmd' to start Open WebUI." -ForegroundColor Green
