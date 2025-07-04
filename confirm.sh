#!/bin/bash
# 確認プロンプト共通スクリプト
# 使用方法: bash confirm.sh "メッセージ"

if [ $# -eq 0 ]; then
    echo "使用方法: bash confirm.sh \"メッセージ\""
    exit 1
fi

echo "$1 (y/N)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    exit 0  # 成功
else
    exit 1  # キャンセル
fi