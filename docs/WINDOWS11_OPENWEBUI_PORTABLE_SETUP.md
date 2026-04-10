# Open WebUI Windows 11 Portable Setup

この repo は、`python-3.11.9-win64/` に含まれる portable Python を使って、Windows 11 上で `Open WebUI 0.8.12` をオフライン導入できるように構成しています。

## 前提

- OS: Windows 11 x64
- 外部インターネット接続なし
- Python の installer 実行不可
- この repo 一式は社内へ持ち込み済み
- Python 本体の実行そのものは許可されている

補足:

- この構成は「installer 不要」にするものです。
- `Open WebUI` を使うには、最終的に `python.exe` と `.venv\Scripts\open-webui.exe` の実行は必要です。
- 任意の `.exe` 実行そのものが禁止の環境では運用できません。

## 含まれるもの

- portable Python `3.11.9`
- `Open WebUI 0.8.12` の分割済み wheel
- Windows `win_amd64` / `cp311` 向け offline wheelhouse
- オフライン install スクリプト
- 起動スクリプト

## PowerShell での導入

repo ルートで以下を実行します。

```powershell
.\bundle\windows\install-openwebui-offline.cmd
```

この処理で実行される内容:

- 分割された `Open WebUI` wheel を `artifacts/` に再結合
- portable Python を使って `.venv` を作成
- wheelhouse をオフライン install
- `Open WebUI` 本体を install

## 起動

起動確認だけを行う場合:

```powershell
.\bundle\windows\start-openwebui.cmd -DisableOllama -DisableOpenAI
```

Ollama を使う場合:

```powershell
.\bundle\windows\start-openwebui.cmd
```

OpenAI 互換 API を使う場合:

```powershell
.\bundle\windows\start-openwebui.cmd -DisableOllama -OpenAIBaseUrl http://127.0.0.1:8000/v1 -OpenAIApiKey dummy
```

起動後のアクセス先:

- `http://127.0.0.1:8080`

## データ保存先

実行時データは repo ルートの `data/` に保存されます。

## デフォルト設定

起動スクリプトでは以下を設定しています。

- `OFFLINE_MODE=true`
- `HF_HUB_OFFLINE=1`
- `DO_NOT_TRACK=true`
- `SCARF_NO_ANALYTICS=true`
- `ANONYMIZED_TELEMETRY=false`
- `BYPASS_EMBEDDING_AND_RETRIEVAL=true`
- `ENABLE_RAG_HYBRID_SEARCH=false`
- `RAG_EMBEDDING_MODEL=`
- `RAG_RERANKING_MODEL=`

このため、軽量なチャット UI 用の最小構成として使えます。

## 補足

- 依存 wheel は `bundle/windows/vendor/wheelhouse/` に同梱しています。
- `Open WebUI` 本体 wheel は GitHub の 1 ファイル 100MB 制限を避けるため、`bundle/windows/vendor/open-webui/` 配下で分割格納しています。
- 再結合後の wheel は `artifacts/open_webui-0.8.12-py3-none-any.whl` に生成されます。
