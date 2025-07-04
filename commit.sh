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
