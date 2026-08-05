# 七誌のZenn

記事を管理するリポジトリです。

Qiita で公開している記事は [7shi/qiita](https://github.com/7shi/qiita) で管理しています。

## Zenn CLI

* [📘 How to use](https://zenn.dev/zenn/articles/zenn-cli-guide)

## ディレクトリ構成

* `articles/` — 記事本体（Markdown、ファイル名がslug）
* `books/` — 本（book）のコンテンツ
* `images/{slug}/` — 記事に掲載する画像
* `check/{slug}/` — 記事に載せたコードの検証用ファイル
* `commit.sh` / `confirm.sh` — `make commit` / `make push` から呼ばれる補助スクリプト
* `NOTATIONS.md` — Zenn独自のMarkdown記法のまとめ

## Makefile

よく使う操作は `make` コマンドにまとめています。

* `make update` — `zenn-cli` を最新版に更新
* `make preview` — プレビューサーバーを起動し、LAN内からアクセスできるURLを表示
* `make new` — 記事作成コマンドの使い方を表示（実際のslug指定は手動で実行）
* `make commit` — `commit.sh` を実行し、Claudeに変更内容からコミットメッセージを生成させ、確認・編集後にコミット
* `make push` — `make commit` を実行後、`confirm.sh` で確認してからpush
