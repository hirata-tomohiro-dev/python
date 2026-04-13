[CmdletBinding()]
param(
    [Alias('Host')]
    [string]$ListenHost = '127.0.0.1',
    [int]$Port = 8080,
    [string]$OpenAIBaseUrl = '',
    [string]$OpenAIApiKey = '',
    [string]$OllamaBaseUrl = 'http://127.0.0.1:11434',
    [switch]$DisableOllama,
    [switch]$DisableOpenAI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot '..\..')).Path
$OpenWebUiExe = Join-Path $RepoRoot '.venv\Scripts\open-webui.exe'
$VenvDir = Join-Path $RepoRoot '.venv'

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Apply-OpenWebUIOfflinePatch {
    param([string]$VenvDir)

    $MainPy = Join-Path $VenvDir 'Lib\site-packages\open_webui\main.py'
    if (-not (Test-Path $MainPy)) {
        return
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

if (-not (Test-Path $OpenWebUiExe)) {
    throw "Open WebUI is not installed. Run '.\bundle\windows\install-openwebui-offline.cmd' first."
}

$env:DATA_DIR = Join-Path $RepoRoot 'data'
$env:OFFLINE_MODE = 'true'
$env:HF_HUB_OFFLINE = '1'
$env:DO_NOT_TRACK = 'true'
$env:SCARF_NO_ANALYTICS = 'true'
$env:ANONYMIZED_TELEMETRY = 'false'
$env:USER_AGENT = 'PythonPortableRepo/OpenWebUIOfflineBundle'
$env:BYPASS_EMBEDDING_AND_RETRIEVAL = 'true'
$env:ENABLE_RAG_HYBRID_SEARCH = 'false'
$env:RAG_EMBEDDING_MODEL = ''
$env:RAG_RERANKING_MODEL = ''
$env:RAG_EMBEDDING_MODEL_AUTO_UPDATE = 'false'
$env:RAG_RERANKING_MODEL_AUTO_UPDATE = 'false'

if ($DisableOllama) {
    $env:ENABLE_OLLAMA_API = 'false'
    Remove-Item Env:OLLAMA_BASE_URL -ErrorAction SilentlyContinue
} else {
    $env:ENABLE_OLLAMA_API = 'true'
    $env:OLLAMA_BASE_URL = $OllamaBaseUrl
}

if ($DisableOpenAI -or [string]::IsNullOrWhiteSpace($OpenAIBaseUrl)) {
    $env:ENABLE_OPENAI_API = 'false'
    Remove-Item Env:OPENAI_API_BASE_URL -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_API_KEY -ErrorAction SilentlyContinue
} else {
    $env:ENABLE_OPENAI_API = 'true'
    $env:OPENAI_API_BASE_URL = $OpenAIBaseUrl
    if ([string]::IsNullOrWhiteSpace($OpenAIApiKey)) {
        $env:OPENAI_API_KEY = 'dummy'
    } else {
        $env:OPENAI_API_KEY = $OpenAIApiKey
    }
}

Apply-OpenWebUIOfflinePatch -VenvDir $VenvDir

Write-Host "Open WebUI will be available at http://$ListenHost`:$Port" -ForegroundColor Green
Push-Location $RepoRoot
try {
    & $OpenWebUiExe serve --host $ListenHost --port $Port
} finally {
    Pop-Location
}
