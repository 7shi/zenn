---
title: "Claude Code HooksでAI署名を含むコミットを拒否"
emoji: "🤖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["claudecode"]
published: True
---

Claude Codeのフック機能は強力ですが、その設定にはコマンドラインツールを駆使したワンライナーの構築が求められることがあります。本記事では、AIによる署名付きコミットを自動で拒否するためのワンライナーを構築します。

:::message
本記事はClaude CodeとGemini CLIの生成結果をベースに編集しました。
:::

## 概要

Claude Codeはデフォルトで以下の署名をコミットメッセージに挿入します。

```
🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

`CLAUDE.md` などで署名を付けないように指示しても、守られないことが多いです。この署名を含むコミットを自動的に拒否するために、Claude Code Hooks を利用する方法を説明します。

## Claude Code Hooksとは

Claude Code Hooks（フック）とは、Claude Codeの実行ライフサイクルにおける特定のタイミングでコマンドを呼び出す機能です。このフック機能を利用することで、Claude Codeの標準的な動作をカスタマイズできます。

公式ドキュメント：

https://docs.anthropic.com/en/docs/claude-code/hooks

Claude Codeでは、フックを呼び出すタイミングが数種類提供されています。今回はツールが呼び出される直前に実行される`PreToolUse`を対象とします。

## JSON入力の構造

フックが実行される際、Claude Codeは以下の形式のJSONデータを標準入力（stdin）経由でフックコマンドに渡します。

```json
{
  "session_id": "session_abc123",
  "tool_name": "Bash",
  "tool_input": {
    "command": "実行するコマンド",
    "description": "コマンドの説明"
  }
}
```

- `session_id`: Claude Codeセッションの一意な識別子
- `tool_name`: 実行されるツール名（この例では "Bash"）
- `tool_input`: ツールに渡される入力データ
  - `command`: 実行対象のコマンド文字列
  - `description`: コマンドの簡単な説明

今回の目的であるコミットメッセージの検証では、この中の `.tool_input.command` フィールドに含まれるコマンド文字列が分析の対象となります。

## 設定方法

Claude Codeの `/hooks` コマンドを使い、対話形式で設定を進めます。

1.  **hooks設定画面を開く**
    ```
    /hooks
    ```

2.  **PreToolUseを選択**
    ```
    1. PreToolUse - Before tool execution
    ```

3.  **新しいマッチャー（Matcher）を追加**
    ```
    1. + Add new matcher…
    ```

4.  **Tool Matcherを設定**
    `Bash` と入力してEnterキーを押します。
    ```
    Tool matcher: Bash
    ```

5.  **新しいフックを追加**
    ```
    1. + Add new hook…
    ```

6.  **フックコマンドを入力**
    ```bash
    if jq -r '.tool_input.command' | grep -q '🤖 Generated with'; then echo 'Error: Commit message contains AI signature. Please remove it before committing.' 1>&2; exit 2; fi
    ```

7.  **フックの適用範囲を選択**
    今回はユーザーレベルで有効化します。
    ```
    3. User settings
    ```

8.  **設定完了**
    `[Esc]`キーを数回押して設定画面を終了します。

### 設定ファイル

生成された設定ファイルは `~/.claude/settings.json` に保存されます。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if jq -r '.tool_input.command' | grep -q '🤖 Generated with'; then echo 'Error: Commit message contains AI signature. Please remove it before committing.' 1>&2; exit 2; fi"
          }
        ]
      }
    ]
  }
}
```

これを直接編集することも可能です。

### 動作結果

上記の設定を完了すると、Claude CodeがAI署名を含む `git commit` コマンドを実行しようとした際に、次のようなエラーメッセージが表示され、コミット処理が中止されます。

```text
● Bash(git commit -m "Add Ollama integration with thinking process support…)
  ⎿  Error: Bash operation blocked by hook:
     - [if jq -r '.tool_input.command' | grep -q '🤖 Generated with'; then echo 'Error: Commit message contains
     AI signature. Please remove it before committing.' 1>&2; exit 2; fi]: Error: Commit message contains AI
     signature. Please remove it before committing.
```

## フックコマンドの動作解説

コマンドの構造を説明するため改行を入れます。

```bash
if jq -r '.tool_input.command' | grep -q '🤖 Generated with'; then
  echo 'Error: Commit message contains AI signature. Please remove it before committing.' 1>&2;
  exit 2;
fi
```

このコマンドは、以下の図のように、パイプライン（`|`）を通じて複数の処理を連携させています。

```
[JSON入力] → jqで抽出 → grepで検索 → if文で判定 → [処理実行 or 中止]
```

各ステップの動作は以下の通りです。

1. **`jq`による抽出**  
   フックがトリガーされると、Claude Codeから渡されたJSONデータが標準入力経由で `jq` コマンドに渡されます。`jq -r '.tool_input.command'` は、そのJSONデータからコミットコマンド全体（例: `git commit -m "..."`）を抽出し、生の文字列として出力します。

2. **`grep`による検索**  
   次に、その出力がパイプを通じて `grep` コマンドに渡されます。`grep -q '🤖 Generated with'` は、受け取った文字列内にAI署名が含まれているかを検索しますが、`-q` で出力を抑制します。文字列が見つかれば終了コード `0`（成功）を、見つからなければ `1`（失敗）を返します。

3. **`if`文による判定と処理**  
   `if` 文で `grep` の終了コードを評価します。終了コードが `0` であれば、`then` 以降の処理が実行されます。`echo` コマンドがエラーメッセージを標準エラー出力（stderr）に表示し、`exit 2` によってスクリプトが終了します。この終了コード `2` はClaude Codeに「ブロッキングエラー」として解釈され、`git commit` コマンドの実行を中止させます。

:::message
C言語やPythonなど他のプログラミング言語では `if` の条件式が `0` であれば偽となります。シェルスクリプトとは仕様が異なることに注意が必要です。一般にコマンドでは `0` 以外の終了コードによってエラーの種類などを表すため、`if` 文の条件は `0` が成功を表します。
:::

### 終了コードの詳細

Claude Codeのフックは、スクリプトの終了コード（Exit Code）に応じて挙動を制御します。終了コードが `0` の場合は成功とみなされ、フックの標準出力（stdout）に何か出力があれば、それがユーザーに表示されます。一方で、終了コードが `2` の場合は「ブロッキングエラー」として扱われ、後続の処理を中止させます。例えば、`PreToolUse` フックで `exit 2` を使用すると、ツールの実行そのものが中止されます。その他の終了コード（`1` など）は「非ブロッキングエラー」と見なされ、標準エラー出力（stderr）の内容がユーザーに表示されるものの、処理は継続されます。今回の目的であるコミットの実行を確実に中止させるためには、必ず `exit 2` を使用することが重要です。

### 動作確認

Claude Codeのフックは、JSONデータを標準入力経由でコマンドに渡します。この動作をローカル環境で再現するためには、テスト用のJSONファイルを作成し、`cat`コマンドとパイプ（`|`）を使って標準入力に流し込む方法が有効です。

1. テスト用のJSONファイルを作成

```json:git-commit.json
{
  "session_id": "session_abc123",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m \"fix bug 🤖 Generated with Claude Code\"",
    "description": "Creates git commit with auto-generated marker"
  }
}
```

2. `jq` の動作を確認

```bash
# JSONファイルからコマンドを抽出
$ cat git-commit.json | jq -r '.tool_input.command'
git commit -m "fix bug 🤖 Generated with Claude Code"

# AI署名が含まれているか確認
$ cat git-commit.json | jq -r '.tool_input.command' | grep -q '🤖 Generated with'

# grepの終了コードを確認
$ echo $?
0
```

:::message
`cat ... |` の部分は標準入力からの入力を再現するためのもので、実際のフックではClaude Codeが自動的にこの形式でデータを渡すため、指定するコマンドには現れません。
:::

### 正常なコミットメッセージのテスト

AI署名が含まれない場合のテストも行い、意図せずブロックされないことを確認します。

```json:git-commit-no-sign.json
{
  "session_id": "session_abc123",
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m \"fix bug\"",
    "description": "Creates clean git commit"
  }
}
```

```bash
$ cat git-commit-no-sign.json | jq -r '.tool_input.command' | grep -q '🤖 Generated with'
$ echo $?
1
```

### ワンライナーとPythonスクリプトの比較

今回はワンライナーでフックを実装しましたが、より複雑なロジックを記述する場合は、処理を外部のスクリプトファイルに切り出す方法が有効です。例えば、以下のようなPythonスクリプトを作成し、フックから呼び出すことができます。

```python:Pythonで実装した例
import sys
import json

# 標準入力からJSONデータを読み込む
hook_data = json.load(sys.stdin)

# コマンド文字列を抽出
command = hook_data.get("tool_input", {}).get("command", "")

# AI署名が含まれているかチェック
if "🤖 Generated with" in command:
    # 標準エラー出力にメッセージを書き込む
    print("Error: Commit message contains AI signature. Please remove it before committing.", file=sys.stderr)
    # 終了コード2で終了し、実行をブロック
    sys.exit(2)
```

このスクリプトをフックから呼び出すには、`settings.json`を以下のように設定します。スクリプトのパスは、環境に応じた絶対パスを指定してください。

```json
// settings.json の例
"command": "python /path/to/your/script.py"
```

単純な検証であればワンライナーが手軽ですが、条件が複雑であればPythonスクリプトの利用も視野に入れると良いでしょう。

## 注意事項

フックは現在のユーザー権限で実行されるため、意図しないコマンドが実行されないよう、スクリプトの内容は慎重に検証してください。また、セキュリティを維持するため、フックの設定は定期的に見直すことを推奨します。

## まとめ

本記事では、AI署名付きコミットの自動拒否を例として、Claude Code Hooksで利用される一見複雑なワンライナーコマンドの構造を解説しました。`jq`によるJSONの解析、`grep`での条件判定、`if`文による処理分岐といった個々の要素に分解することで、その動作原理は理解しやすくなります。

ここで解説した段階的な構築手法やローカルでのテスト方法は、他のフックを自作する際にも応用できます。この知識を活用し、コミットメッセージのフォーマット強制など、独自の自動化ルールを作成してみてください。
