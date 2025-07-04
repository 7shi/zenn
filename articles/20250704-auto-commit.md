---
title: "Claude Codeによるコミットメッセージ生成"
emoji: "🤖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["claudecode", "git"]
published: true
---

リポジトリの変更内容から自動でコミットメッセージを生成するツールは既に色々あります。Claude Codeを常用しているので、それで済ませてみました。

本記事では、コミットメッセージを自動生成するスクリプトを、簡単なものから段階的に作り上げていく過程を紹介します。なお、同様のことはGemini CLIでも可能です。

:::message
本記事はClaude CodeとGemini CLIの生成結果をベースに編集しました。
:::

## Step 1: コア機能 - AIによるメッセージ生成

Claude Codeは `-p` オプションを使うことで、プロンプトを渡してAIに処理を依頼できます。これを利用すれば簡単にコミットメッセージが生成できます。

```bash
claude -p "git diff を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。"
```

結果を取得してコミットするシェルスクリプトを作成します。

```bash
msg=$(claude -p "git diff を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。")
git commit -a -m "$msg"
```

:::message
Gemini CLI では、`git` を許可するために `gemini -y` としてYOLOモード（コマンド自動承認）を指定する必要があります。
:::

確認なしにコミットされるのは危険なので、生成されたメッセージを確認する必要があります。

## Step 2: 対話的なコミット機能の追加

変更があるかを確認して、コミットの前に確認を兼ねて編集できるようにします。

```bash
if [ -n "$(git diff --name-only)" ]; then
    echo "変更を確認中..."
    msg=$(claude -p "git diff を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。")
    echo -e "\nコミットメッセージを編集してください (Enterで確定、Ctrl+Cで中止):"
    read -r -e -p "> " -i "$msg" edited_msg
    git commit -a -m "$edited_msg"
fi
```

これで、AIが生成したメッセージを確認・編集してからコミットできるようになりました。

## Step 3: ステージングの確認

基本的な機能はできましたが、このままでは少し不便です。

- コミットする変更がない場合でも実行されてしまう。
- `git add`でステージングしたファイルだけをコミットしたい場合に対応できない。

ステージングされているかを確認して、コミット対象を変更するようにします。

```bash
set -e  # エラー時に停止

# コミットメッセージの共通部分
COMMIT_MSG_SUFFIX="日本語1行コミットメッセージ(AI署名なし)だけを出力してください。"

git status
if [ -n "$(git diff --cached --name-only)" ]; then
    echo "ステージングされている変更を確認中..."
    CLAUDE_MSG="git diff --cached を確認して、ステージングされたファイルに対する"
    ADD_OPTION=""
    COMMIT_OPTION=""
elif [ -n "$(git diff --name-only)" ]; then
    echo "未ステージングの変更を確認中..."
    CLAUDE_MSG="git diff を確認して、"
    ADD_OPTION=""
    COMMIT_OPTION="-a"
elif [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "未追跡ファイルを確認中..."
    CLAUDE_MSG="git status を確認して、未追跡ファイルに対する"
    ADD_OPTION="."
    COMMIT_OPTION=""
else
    echo "コミットする変更がありません。"
    exit 0
fi

msg=$(claude -p "${CLAUDE_MSG}${COMMIT_MSG_SUFFIX}")

echo -e "\nコミットメッセージを編集してください (Enterで確定、Ctrl+Cで中止):"
read -r -e -p "> " -i "$msg" edited_msg
if [ -z "$edited_msg" ]; then
    echo "コミットをキャンセルしました"
    exit 1
fi

if [ -n "$ADD_OPTION" ]; then
    git add $ADD_OPTION
fi
git commit $COMMIT_OPTION -m "$edited_msg"
echo "コミットが完了しました"
```

以下の3つの状態で動作を切り替えるようになりました。

1. **ステージングされている変更がある場合**  
   ステージングされたファイルに対するコミットメッセージを生成
2. **ステージングされていない変更がある場合**  
   変更されたファイルに対するコミットメッセージを生成
3. **未追跡ファイルがある場合**  
   未追跡ファイルに対するコミットメッセージを生成

## まとめ

本記事では、`claude -p "..."` を利用したシンプルなコア機能から始めて、対話機能や実用的な条件分岐を「肉付け」していくことで、機能を拡張するプロセスを示しました。

シェルスクリプトの条件分岐は文法が独特なためある程度の慣れが必要ですが、Claude Codeを使うことで文法的な面はクリアしてアルゴリズムに集中できました。ぜひ、皆さんの開発フローにもAIを取り入れてみてください。
