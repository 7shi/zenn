#!/bin/bash
# コミット支援スクリプト

set -e  # エラー時に停止

echo "=== Git Status ==="
git status

echo -e "\n=== Changes ==="
# 変更状態をチェック
has_staged=$(! git diff --cached --quiet && echo "yes" || echo "no")
has_unstaged=$(! git diff --quiet && echo "yes" || echo "no")

if [ "$has_staged" = "no" ] && [ "$has_unstaged" = "no" ]; then
    echo "コミットする変更がありません"
    exit 1
fi

if [ "$has_staged" = "yes" ]; then
    echo "変更内容を確認中... (staging)"
    msg=$(claude -p "stagingされているファイルだけを対象とします。git diff --cached を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。")
    commit_options=""
else
    echo "変更内容を確認中..."
    msg=$(claude -p "git diff を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。")
    commit_options="-a"
fi

if [ -z "$msg" ]; then
    echo "エラー: コミットメッセージが生成されませんでした"
    exit 1
fi

echo -e "\n提案されたコミットメッセージ:"
echo "「$msg」"

echo -e "\nこれでcommitしますか? (y/N)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    git commit $commit_options -m "$msg"
    echo "コミットが完了しました"
else
    echo "コミットをキャンセルしました"
    exit 1
fi
