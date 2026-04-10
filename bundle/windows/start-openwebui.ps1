[CmdletBinding()]
param(
    [string]$Host = '127.0.0.1',
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

Write-Host "Open WebUI will be available at http://$Host`:$Port" -ForegroundColor Green
Push-Location $RepoRoot
try {
    & $OpenWebUiExe serve --host $Host --port $Port
} finally {
    Pop-Location
}
