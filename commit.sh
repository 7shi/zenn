#!/bin/bash
# コミット支援スクリプト

set -e  # エラー時に停止

echo "=== Git Status ==="
git status

echo -e "\n=== Changes ==="
if ! git diff --cached --quiet || ! git diff --quiet; then
    echo "変更内容を確認中..."
    msg=$(claude -p "git diff を確認して、日本語1行コミットメッセージ(AI署名なし)だけを出力してください。")
    
    if [ -z "$msg" ]; then
        echo "エラー: コミットメッセージが生成されませんでした"
        exit 1
    fi
    
    echo -e "\n提案されたコミットメッセージ:"
    echo "「$msg」"
    
    echo -e "\nこれでcommitしますか? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "$msg"
        echo "コミットが完了しました"
    else
        echo "コミットをキャンセルしました"
    fi
else
    echo "コミットする変更がありません"
fi
