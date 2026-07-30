## Zenn Article Conventions

- 日付はローカル基準、`date`コマンドで調べる
- 記事のslugはYYYYMMDD-xxx（xxxは2語程度の英語）
- slugを考えた後、記事を初期化するには `npx zenn new:article --slug xxx` を実行
- Zenn独自の記法（`:::message`による補足説明など）は @NOTATIONS.md を参照する。標準のMarkdownではないため、他所へ転記すると崩れる。

## 検証コード

- 記事に載せるコードを実際に動かして確認する場合、`check/{slug}/` に置く（画像の `images/{slug}/` と同じ形）
- 掲載コードと同じ内容のファイルと `README.md` を含める。
- 例: `check/20260730-haskell-generator/`
