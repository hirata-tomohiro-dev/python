# Python 3.11.9 Portable for Windows 11

このリポジトリには、Windows 11 x64 向けの `Python 3.11.9` を、インストーラ不要でそのまま配置利用できる形で格納しています。

加えて、同じ portable Python を使って `Open WebUI 0.8.12` をオフライン導入するための Windows 用 bundle も含めています。

実体は、Python Software Foundation が公開している公式 `nuget` パッケージ `python 3.11.9 (64-bit)` を展開したものです。

## この構成で満たしていること

- インターネット接続なしで利用可能
- インストーラ `exe` の実行不要
- GitHub の 1 ファイル 100MB 制限内
- 配置後すぐに `python.exe` を起動可能
- `pip` / `setuptools` / `venv` 同梱

## ディレクトリ構成

- `python-3.11.9-win64/`
  - Windows 11 x64 用の展開済み Python 本体
- `python311.cmd`
  - repo ルートから Python を起動するラッパー
- `pip311.cmd`
  - repo ルートから `python -m pip` を呼ぶラッパー
- `bundle/windows/`
  - Open WebUI オフライン導入用の依存 wheel 群と起動スクリプト

## 使い方

社内 Windows 11 にこのリポジトリを clone またはコピーした後、repo ルートで以下を実行してください。

```bat
python311.cmd -V
python311.cmd
```

`pip` は以下で使えます。

```bat
pip311.cmd --version
pip311.cmd list
```

仮想環境は以下で作成できます。

```bat
python311.cmd -m venv .venv
.venv\Scripts\python.exe -V
```

## Open WebUI の利用

この repo だけで、portable Python を使った `Open WebUI` のオフライン導入と起動ができます。

PowerShell では repo ルートで以下を実行してください。

```powershell
.\bundle\windows\install-openwebui-offline.cmd
.\bundle\windows\start-openwebui.cmd -DisableOllama -DisableOpenAI
```

詳細は以下を参照してください。

- `docs/WINDOWS11_OPENWEBUI_PORTABLE_SETUP.md`

## 重要な注意

- この構成は「インストーラの実行」を不要にするものです。
- Python を実際に使うには、最終的に `python.exe` 自体の起動は必要です。
- もし社内ポリシーが「インストーラ禁止」ではなく「任意の `.exe` 起動そのものを全面禁止」であれば、Windows 上で CPython を運用することはできません。
- Windows 11 で通常含まれている UCRT を前提としています。標準的な Windows 11 では追加導入なしで動作する想定です。
- 社内がオフラインのため、追加パッケージを入れる場合は wheel ファイル等を別途持ち込んで `pip311.cmd install <wheel>` の形で導入してください。

## 参照元

- Source package: official `python` nuget package `3.11.9`
- Package URL: `https://api.nuget.org/v3-flatcontainer/python/3.11.9/python.3.11.9.nupkg`
- SHA256: `9283876d58c017e0e846f95b490da3bca0fc0a6ee1134b2870677cfb7eec3c67`
