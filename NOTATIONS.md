このページでは Zenn のmarkdown記法のうち、標準的なMarkdownにはない独自・拡張記法を紹介します。

## 画像

### 画像の横幅を指定する

画像の表示が大きすぎる場合は、URL の後に半角スペースを空けて`=○○x`と記述すると、画像の幅を px 単位で指定できます。

```
![](https://画像のURL =250x)
```

### キャプションをつける

画像のすぐ下の行に`*`で挟んだテキストを配置すると、キャプションのような見た目で表示されます。

```
![](https://画像のURL)
*キャプション*
```

## コードブロック

シンタックスハイライトには Shiki を使用しています。
[📄 対応言語の一覧 →](https://shiki.style/languages)

### ファイル名を表示する

`言語:ファイル名`と`:`区切りで記載することで、ファイル名がコードブロックの上部に表示されるようになります。

> ```js:ファイル名
> 
> ```

### diff のシンタックスハイライト

`diff`と言語のハイライトを同時に適用するには、以下のように`diff`と`言語名`を半角スペース区切りで指定します。

> ```diff js
> 
> ```

なお、`diff`の使用時には、先頭に`+`、`-`、`>`、`<`、`半角スペース`のいずれが入っていない行はハイライトされません。

同時にファイル名を指定することも可能です。

> ```diff js:ファイル名
> 
> ```

## 数式

Zenn では**KaTeX**による数式表示に対応しています。
KaTeXのバージョンは常に最新バージョンを使用します。

[📄 KaTeXがサポートする記法の一覧 →](https://katex.org/docs/support_table.html)

### 数式のブロックを挿入する

`$$`で記述を挟むことで、数式のブロックが挿入されます。

```
$$
e^{i\theta} = \cos\theta + i\sin\theta
$$
```

:::message
`$$`の前後は空の行でないと正しく埋め込まれないことがあります。
:::

### インラインで数式を挿入する

`$a\ne0$`というように`$`ひとつで挟むことで、インラインで数式を含めることができます。

## 脚注

脚注を指定するとページ下部にその内容が表示されます。

```
脚注の例[^1]です。インライン^[脚注の内容その2]で書くこともできます。

[^1]: 脚注の内容その1
```

## Zenn 独自の記法

### メッセージ

```
:::message
メッセージをここに
:::
```

```
:::message alert
警告メッセージをここに
:::
```

### アコーディオン（トグル）

```
:::details タイトル
表示したい内容
:::
```

#### 要素をネストさせるには

外側の要素の開始/終了に `:` を追加します。

```
::::details タイトル
:::message
ネストされた要素
:::
::::
```

## コンテンツの埋め込み

### リンクカード

```
# URLだけの行
https://zenn.dev/zenn/articles/markdown-guide
```

URL だけが貼り付けられた行があると、その部分がカードとして表示されます。

また`@[card](URL)`という書き方でカード型のリンクを貼ることもできます。

アンダースコア `_` を含むURLが正しく認識されない場合は、[こちら](https://zenn.dev/catnose99/scraps/e94c8e789f846a)を参照してください。

### X（Twitter）のポスト（ツイート）

```
# ポストのURLだけの行（前後に改行が必要です）
https://twitter.com/jack/status/20

# x.comドメインの場合
https://x.com/jack/status/20
```

以前は`@[tweet](ポストのURL)`の記法を採用していましたが、現在はポストのURLを貼り付けるだけで埋め込みが表示されます。

#### リプライ元のポストを非表示にする

リプライを埋め込んだ場合、デフォルトでリプライ元のポスト含まれて表示されます。`ポストのURL?conversation=none`のようにクエリパラメータに`conversation=none`を指定すると、リプライ元のポストが含まれなくなります。

### YouTube

```
# YouTubeのURLだけの行（前後に改行が必要です）
https://www.youtube.com/watch?v=WRVsOCh907o
```

以前は`@[youtube](YouTubeの動画ID)`という記法を採用していましたが、現在は動画URLを貼り付けるだけで動画を埋め込むことができます。

### GitHub

GitHub上のファイルへのURLまたはパーマリンクだけの行を作成すると、その部分にGitHubの埋め込みが表示されます。

```
# GitHubのファイルURLまたはパーマリンクだけの行（前後に改行が必要です）
https://github.com/octocat/Hello-World/blob/master/README
```

#### 行の指定

GitHubと同じように、リンクの末尾に`#L00-L00`のような形で表示するファイルの開始行と終了行を指定することができます。

```
# コードの開始行と終了行を指定
https://github.com/octocat/Spoon-Knife/blob/main/README.md#L1-L3
```

また、開始行のみ指定することもできます。

```
# コードの開始行のみ指定
https://github.com/octocat/Spoon-Knife/blob/main/README.md#L3
```

#### テキストファイル以外は埋め込めません

埋め込めるファイルは、ソースコードなどのテキストファイルのみとなっています。

### GitHub Gist

```
@[gist](GistのページURL)
```

GistのページURLを指定します。

特定のファイルだけ埋め込みたい場合は`@[gist](https://gist.github.com/foo/bar?file=example.json)`のようにクエリ文字列で`?file=ファイル名`という形で指定します。

### CodePen

```
@[codepen](ページのURL)
```

デフォルトの表示タブは`ページのURL?default-tab=html,css`のようにクエリを指定することで変更できます。

### SlideShare

```
@[slideshare](スライドのkey)
```

SlideShare の埋め込み iframe に含まれる`...embed_code/key/○○...`の`◯◯`の部分を入力します。

### SpeakerDeck

```
@[speakerdeck](スライドのID)

例:
@[speakerdeck](4f926da9cb4cd0001f00a1ff)
@[speakerdeck](4f926da9cb4cd0001f00a1ff?slide=24)
```

SpeakerDeck で取得した埋め込みコードに含まれる`data-id`の値を入力します。スライド番号も指定できます。

### Docswell

```
@[docswell](スライドのURL)
# もしくは
@[docswell](埋め込み用のURL)

例:
@[docswell](https://www.docswell.com/s/ku-suke/LK7J5V-hello-docswell)
@[docswell](https://www.docswell.com/s/ku-suke/LK7J5V-hello-docswell#p13)
@[docswell](https://www.docswell.com/s/ku-suke/LK7J5V-hello-docswell/13)
@[docswell](https://www.docswell.com/slide/LK7J5V/embed)
```

スライドのURL（ `https://www.docswell.com/s/{UserId}/{SlideId}-xxx-xxx` ）、もしくは埋め込み用のURL( `https://www.docswell.com/slide/{SlideId}/embed` )を入力します。スライド番号も指定できます。

### JSFiddle

```
@[jsfiddle](ページのURL)
```

[埋め込みオプション](https://docs.jsfiddle.net/embedding-fiddles)を指定する場合、iframe用の埋め込みURL（ `ページのURL + /embedded/{Tabs}/{Visual}/` ）を入力します。

### CodeSandbox

```
@[codesandbox](embed用のURL)
```

CodeSandbox では、各ページから埋め込み用の`<iframe>`を取得できます。この`<iframe>`に含まれる`src`の URL を括弧の中に入力します。

### StackBlitz

```
@[stackblitz](embed用のURL)
```

StackBlitz では、各ページから「Embed URL」を取得できます。取得した URL をそのまま括弧の中に入力します。

### Figma

```
@[figma](共有リンクのURL)
```

Figma では、デザインページで共有リンクを取得できます。取得したURLをそのまま括弧の中に入力します。

### その他の埋め込み可能なコンテンツ

オンラインエディターの埋め込みの選択肢としては表示されませんが、以下の埋め込み記法もサポートしています。

#### blueprintUE

```
@[blueprintue](ページのURL)

例：
@[blueprintue](https://blueprintue.com/render/0ovgynk-/)
```

[blueprintUE](https://blueprintue.com/) を埋め込むには、公開されているページのURLをそのまま括弧の中に入力します。

## ダイアグラム

[mermaid.js](https://mermaid-js.github.io/mermaid/#/) によるダイアグラム表示に対応しています。コードブロックの言語名を`mermaid`とすることで自動的にレンダリングされます。

````
```mermaid
graph TB
    A[Hard edge] -->|Link text| B(Round edge)
    B --> C{Decision}
    C -->|One| D[Result one]
    C -->|Two| E[Result two]
```
````

他にもシーケンス図やクラス図が表示できます。文法は mermaid.js に従っていますので、どのように書けばよいかは[公式サイトの文法](https://mermaid-js.github.io/mermaid/#/flowchart)を参照してください。

### 制限事項

#### クリックイベントの無効化

[Interaction機能](https://mermaid-js.github.io/mermaid/#/classDiagram?id=interaction)として図の要素にクリックイベントなどが設定できますが、セキュリティの観点でZennでは無効にさせていただきます。

#### ブロックあたりの文字数制限 - 2000文字以内

ブロックあたりの文字数を**2000**文字に制限させていただいています。これを超えた場合、ダイアグラムが表示される代わりにエラーメッセージが表示されます。

#### ブロックあたりのChain数制限 - 10以下

フローチャートにおいて、ノードをひとまとまりで表現する記述として`&`が利用できます。以下のようなイメージです。

````
```mermaid
graph LR
   a --> b & c--> d
```
````

`&`の数を**10**に制限させていただきます。こちらも超えた場合はダイアグラムの代わりにエラーメッセージが表示されます。
