---
title: "Claude CodeでAI署名の設定"
emoji: "🤖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["claudecode"]
published: True
---

Claude Codeはデフォルトで、gitコミットとプルリクエストに署名を自動で追加します。

```text
🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

これを無効化する設定について説明します。

この記事は以下のドキュメントに基づいています。

https://docs.anthropic.com/ja/docs/claude-code/settings

## 署名を無効にする方法

設定ファイルを書き換えます。どの範囲で設定するかによって設定ファイルは変わります。

1. ローカルプロジェクト設定: `.claude/settings.local.json`（git管理対象外）
2. 共有プロジェクト設定: `.claude/settings.json`（git管理対象）
3. ユーザー設定: `~/.claude/settings.json`

:::message
複数の設定があるときに優先される順番で並べています（推奨順ではありません）。通常はユーザー設定にだけ書いて、必要に応じてより上位の設定で上書きする運用となります。
:::

JSON内に以下の設定を追加します。

```json
{
  （...既存の設定...,）
  "includeCoAuthoredBy": false
}
```

### 注意点

- デフォルト値（省略時）は `true` です
- `includeCoAuthoredBy` は `claude config` コマンドでは設定できません。

## 謝辞

以下のコメントでご教示いただきました。

- https://zenn.dev/link/comments/841382ea128b75

## 関連記事

フック機能でコミットメッセージにAI署名が入らないように監視します。（設定で回避可能なためフック機能を使う必要はありませんが、この手法自体は他の設定にも応用可能です）

https://zenn.dev/7shi/articles/20250702-hooks-commit

Claude Codeでコミットメッセージを自動生成するシェルスクリプトを段階的に作成します。

https://zenn.dev/7shi/articles/20250704-auto-commit
