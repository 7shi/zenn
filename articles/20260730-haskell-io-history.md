---
title: "Haskell の IO モナドへの道"
emoji: "📜"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "monad"]
published: false
---

Haskell は副作用を IO モナドで扱います。そこに至るまでは「遅延ストリーム → 継続 → `do` 記法」という道のりがありました。当時のコンセプトを現行の GHC で再現しながら、その道をたどります。

:::message
歴史そのものより「なぜ IO モナドがこの形なのか」を掴むための記事です。当時の処理系が手元にないため、実行結果はあくまで動作イメージです。
:::

検証コードは以下に置きました。

* [`check/20260730-haskell-io-history/`](https://github.com/7shi/zenn/tree/main/check/20260730-haskell-io-history)

:::message
本記事の執筆には Claude Code (Opus 5) を利用しました。
:::

# 典拠

以下の論文の 7 節に基づきます。設計に関わった 4 人による回顧録です。

* Paul Hudak, John Hughes, Simon Peyton Jones, Philip Wadler, [*A History of Haskell: Being Lazy with Class*](https://www.microsoft.com/en-us/research/publication/a-history-of-haskell-being-lazy-with-class/) (HOPL III, 2007)

本記事に出て来る `Behaviour` などの型定義とコード（論文中の Figure 3〜6）は、この論文が引用する Haskell 1.0 Report のものです。

# 3 つの候補

Haskell 委員会は言語を純粋に保つと決めていたため、I/O の設計が重要な課題になりました。論文は当時の空気をこう書いています。

> Our greatest fear was that Haskell would be viewed as a toy language because we did a poor job addressing this important capability.  
> （我々が最も恐れたのは、この重要な機能をうまく扱えなかったために Haskell がおもちゃの言語と見なされることだった）

候補は 3 つありました。

|方式|型|採否|
|---|---|---|
|ストリーム|`[Response] -> [Request]`|Haskell 1.0 で採用（primitive）|
|継続|`FailCont -> StrCont -> Behaviour`|Haskell 1.0 で採用（ストリームの上に定義）|
|世界渡し|`World -> (a, World)`|却下|

ストリームと継続はどちらも載りました。両者は相互に定義可能だと分かっていたためです。

# ストリーム I/O

プログラムそのものが「応答の列を受け取って要求の列を返す関数」になります。

```hs
type Behaviour = [Response] -> [Request]
```

要求と応答はデータ型です（一部を抜粋）。

```hs
data Request
    = ReadFile Name
    | ReadChan Name
    | AppendChan Name String
    | ...

data Response
    = Success
    | Str String
    | Failure IOError
    | ...
```

プログラムが要求を出し、OS が応答を返します。遅延評価のおかげで、応答を処理する前に要求を出せるのが前提です。

:::message
要求と応答の列が遅延評価によって少しずつ伸びていくため、この方式は**遅延ストリーム**とも呼ばれます。
:::

## OS の側

Haskell 1.0 Report は付録で、OS を「初期状態と Haskell プログラムを受け取る関数」として仕様化していました。OS そのものが純粋関数として抽象化されているわけです。ここでは最小限のものを用意します。

```hs
os :: [(Name, String)] -> String -> [Request] -> [Response]
os _ _ [] = []
os fs input (r : rs) = case r of
    ReadChan _ -> Str input : os fs input rs
    ReadFile n -> case lookup n fs of
        Just s -> Str s : os fs input rs
        Nothing -> Failure ("no such file: " ++ n) : os fs input rs
    AppendChan _ _ -> Success : os fs input rs
```

ファイルシステムは連想リスト、標準入力は文字列として引数で与えられ、出力の要求にも `Success` を返すだけです。外界を丸ごと引数に押し込んであるので、この `os` は何も副作用を起こしません。当時の処理系では、ここに本物のランタイムが座っていました。

プログラムと OS を互いに参照させて回します。

```hs
run :: [(Name, String)] -> String -> Behaviour -> IO ()
run fs input behaviour = mapM_ emit reqs
  where
    reqs = behaviour resps
    resps = os fs input reqs
    emit (AppendChan _ s) = putStr s
    emit _ = return ()
```

`reqs` が `resps` を必要とし、`resps` が `reqs` を必要とする相互再帰です。遅延評価だけがこれを可能にしています。

実際に画面へ出力しているのは `emit` の `putStr` だけで、それ以外はすべて純粋計算です。現行の GHC で動かすためのアダプタがこの `run` にあたります。

:::message
当時 IO モナドはまだありませんでした。`run` の戻り値が `IO ()` になっているのは、要求の列を現行の GHC で実際に出力するための都合です。当時はこの位置が処理系側の仕事で、プログラマが書くのは `Behaviour` まででした。
:::

## プログラムの側

Report の例です。ファイル名を促し、入力されたファイル名を表示し、その内容を出力します。

```hs
main :: Behaviour
main ~(Success : ~(Str userInput : ~(Success : ~(r4 : _)))) =
    [ AppendChan stdout "enter filename\n"
    , ReadChan stdin
    , AppendChan stdout name
    , ReadFile name
    , AppendChan stdout
        (case r4 of
            Str contents -> contents
            Failure _ -> "can't open file\n")
    ]
  where
    (name : _) = lines userInput
```
```text:実行結果
enter filename
hello.txt
Hello, stream I/O!
```

引数の `~` は**遅延パターン**です。通常のパターンマッチは引数が渡された時点で構造を確かめますが、`~` を付けるとマッチが先送りされ、束縛した変数（`userInput` や `r4`）を実際に使う瞬間まで応答を覗きません。ここでは応答を「見る」前に要求を出す必要があるため、これが欠かせません。

:::message
遅延パターンは当時だけの記法ではなく、現在も Haskell の標準機能です。上のコードは `Behaviour` などの型定義さえ用意すれば、現行の GHC でそのまま通ります。
:::

## ~ を外すと止まる

`~` を外すと、要求を 1 つも出さないうちに応答を見ようとして、自分の出力を待ちます。

```text:実行結果
=== Figure 3: 遅延パターンなし（~ を外す） ===
  → 例外: <<timeout>>
```

要求リストの先頭を評価しようとしただけでタイムアウトしました。順序の正しさが型で守られていません。

n 番目の要求と n 番目の応答が対応しているという前提を、プログラマが遅延パターンで守る必要があります。論文はストリーム版の読みにくさをこう説明しています。

> the pattern matching required by stream-based I/O forces the reader's focus to jump back and forth between the patterns (representing the responses) and the requests.
> （ストリームベースの I/O が要求するパターンマッチは、応答を表すパターンと要求との間で読者の視点を行き来させる）

# 継続 I/O

同じ `Behaviour` 型のままで、要求と応答を直接触らせない書き方が用意されました。要求／応答の対を継続渡しスタイルで包んだ関数を**トランザクション**と呼びます。

```hs
type Behaviour = [Response] -> [Request]
type FailCont = IOError -> Behaviour
type StrCont = String -> Behaviour
```

`ReadFile` という要求（コンストラクタ）に `readFile` というトランザクション（関数）が対応します。この要求は失敗と成功の 2 つの応答を持つので、継続も 2 つ受け取ります。

```hs
readFile :: Name -> FailCont -> StrCont -> Behaviour
readFile name fail succ ~(resp : resps) =
    ReadFile name
        : case resp of
            Str val -> succ val resps
            Failure msg -> fail msg resps
```

要求を出し、応答を見てどちらかの継続を呼ぶ、という形です。`~` はここに閉じ込められて、利用側からは消えます。

先ほどのプログラムはこうなります。

```hs
main :: Behaviour
main =
    appendChan stdout "enter filename\n" abort
        ( readChan stdin abort
            ( \userInput ->
                letE
                    (lines userInput)
                    ( \(name : _) ->
                        appendChan stdout name abort
                            ( readFile name fail
                                (\contents -> appendChan stdout contents abort done)
                            )
                    )
            )
        )
  where
    fail _ = appendChan stdout "can't open file\n" abort done
```

`letE x k = k x` という補助関数が使われているのは、Haskell 1.0 には `let` 式がなかったためです（1.1 で入りました）。

制御の流れが局所的になり、多くのプログラマには継続版が好まれました。一方でラムダが入れ子になるにつれて括弧が積み上がります。

## 括弧を減らす

この書き方が一般的になると見て、委員会は設計の終盤に中置演算子の文脈におけるラムダの優先順位を変更しました。これで次のように書けます。

```hs
main :: Behaviour
main =
    appendChan stdout "enter filename\n"
        >>> readChan stdin
        >>> \userInput ->
            let (name : _) = lines userInput
             in appendChan stdout name
                    >>> readFile name fail
                        (\contents -> appendChan stdout contents abort done)
```

演算子の定義は失敗継続を `abort` に固定するだけです。

```hs
f >>> x = f abort x
```

`>>=` に見えて来ますが、これは IO モナドの 6 年前の話です。

# 継続 I/O は継続モナドだった

ここが本題です。`readFile` の失敗継続を `abort` に固定して部分適用すると、型はこうなります。

```hs
readFile name abort :: StrCont -> Behaviour
                    =  (String -> Behaviour) -> Behaviour
```

`(a -> r) -> r` の形です。つまり継続モナドの中身そのものです。

```hs
newtype Cont r a = Cont {runCont :: (a -> r) -> r}
```

包んでみます。

```hs
readFileC :: Name -> Cont Behaviour String
readFileC name = Cont (readFileT name abort)

appendChanC :: Name -> String -> Cont Behaviour ()
appendChanC name s = Cont $ \k -> appendChanT name s abort (k ())

evalIO :: Cont Behaviour () -> Behaviour
evalIO m = runCont m (\_ -> done)
```

`Monad` インスタンスを与えれば `do` 記法で書けます。

```hs
instance Monad (Cont r) where
    m >>= k = Cont $ \c -> runCont m (\x -> runCont (k x) c)
```

```hs
main :: Behaviour
main = evalIO $ do
    appendChanC stdout "enter filename\n"
    userInput <- readChanC stdin
    let (name : _) = lines userInput
    appendChanC stdout name
    contents <- readFileC name
    appendChanC stdout contents
```

入れ子のラムダ版・`>>>` 版・この `do` 版の 3 つで、実行結果は完全に一致します。

```text:実行結果
=== Figure 4: 継続 I/O（入れ子のラムダ） ===
enter filename
hello.txtHello, continuation I/O!
=== Figure 4: >>> 版 ===
enter filename
hello.txtHello, continuation I/O!
=== Cont で包んで do 記法 ===
enter filename
hello.txtHello, continuation I/O!
```

Haskell 1.0 の継続 I/O は、継続モナドを `newtype` で包まずに素で使っていたものだと言えます。

:::message
継続モナドの答えの型 `r` は抽象的で掴みにくいところですが、ここでは `r` が `Behaviour`、すなわちこれから OS に出す要求の列という具体物になっています。
:::

論文も、IO モナドが継続で実装できることを次の型で示しています。

```hs
type IO a = FailCont -> SuccCont a -> Behaviour
```

## do 記法が効いていた

論文は `>>>` 版について「モナド版のコードと驚くほど似ている」と述べた上で、こう続けます。

> it was really the advent of do-notation—not monads themselves—that made Haskell programs look more like conventional imperative programs
> （Haskell のプログラムを従来の命令型プログラムのように見せたのは、モナドそれ自体ではなく、実は do 記法の登場だった）

そして次の問いを残しています。

> In retrospect it is worth asking whether this same (or similar) syntactic device could have been used to make stream or continuation-based I/O look more natural.
> （振り返ってみると、これと同じ（あるいは似た）構文上の仕掛けを、ストリームや継続ベースの I/O をより自然に見せるために使えたのではないかと問う価値がある）

上で `do` 記法にしてみたものが、まさにその答えに当たります。

# なぜストリームが primitive だったのか

継続の方が使いやすいと考えられていたのに、Haskell 1.0 はストリームを primitive として、継続をその上に定義しました。理由は効率です。

逆向き（継続を primitive としてストリームを定義する）も可能でしたが、要求数に対して線形の空間と二次の時間がかかり、期待される定数空間・線形時間になりませんでした。

# 却下された第 3 の案: 世界渡し

「世界の状態を受け渡して更新する」方式も検討されました。純粋関数型言語で他のデータ構造を扱うのと同じように、世界も引数と戻り値で回すという発想です。

```hs
type IOw a = World -> (a, World)
```

`bind` に相当するものは状態を繋ぐだけです。

```hs
bindW :: IOw a -> (a -> IOw b) -> IOw b
bindW m k w = case m w of (x, w') -> k x w'
```

素直に使えば命令型のように書けます。

```text:実行結果
=== 素直に使えば命令型のように書ける ===
  enter filename / you typed hello.txt
```

却下された理由は、世界への単一スレッドなアクセスを保証する手段がなかったことです。実際に破ってみます。同じ世界を 2 回使うと、世界が分岐します。

```hs
forked w =
    let (_, w1) = putStrLnW "branch A" w
        (_, w2) = putStrLnW "branch B" w  -- ← 同じ w を再利用
    in (w1, w2)
```
```text:実行結果
=== 同じ世界を 2 回使える（単一スレッド性が破れる） ===
  branch1: common / branch A
  branch2: common / branch B
```

古い世界を使い回せば、出力を巻き戻すこともできます。

```hs
rewound =
    let (_, w1) = putStrLnW "first" (World [])
        (_, w2) = putStrLnW "second" w1
        (_, w3) = putStrLnW "third" w1    -- ← w2 を捨てて w1 から再開
    in seq w2 w3
```
```text:実行結果
=== 出力を巻き戻せる（second が消える） ===
  first / third
```

型は何も文句を言いません。現実の世界は巻き戻せないので、これは意味を失っています。

## Clean の一意型

この問題を型システムで解決した言語があります。Haskell とよく似た非正格純粋関数型言語の Clean は、副作用をモナドではなく**一意型**（uniqueness type）で扱います。

型注釈の `*` が一意性の指定で、その値は一度しか使えないという意味です。世界は隠されず、`Start` の引数として表に出ています。

```
Start :: *World -> *World
Start w
    # (f, w) = stdio w
      f      = WriteAB f
      (_, w) = fclose f w
    = w
```

`#` は let-before 式で、同じ名前でシャドウイングしながら値を次々に受け渡します。上の `bindW` を手作業でやっているようなものです。

肝心なのは、先ほどの `forked` に相当するコード――同じ値を 2 か所で使うもの――がコンパイルエラーになることです。

```text:エラー
Uniqueness error: "file" demanded attribute cannot be offered by shared object
```

Haskell が「保証する手段がない」として却下したものを、Clean は型で保証しました。一度受け渡したら元の値には触れられないので、世界が分岐することも巻き戻ることもありません。C++ のムーブセマンティクスに近い発想です。

一方で、受け渡しを手で書き続けるのは面倒です。Clean のドキュメントは関数合成・`seq`・専用演算子といった書き方を次々に紹介した末に、モナドスタイルに行き着きます。ただし Clean には do 記法がないため、そこで止まりました。上で「do 記法が効いていた」と述べたことの裏返しで、分かれ道はここです。

* [Clean 一意型 調査メモ](https://qiita.com/7shi/items/ab3b819871d7b0710949)

## GHC は世界渡しで実装されている

皮肉なことに、却下されたはずの世界渡しは現在の GHC の IO の実装そのものです。`IO` を `newtype` で包んで外から触れなくすることで、単一スレッド性を型システムではなく抽象化によって守っています。剥がすと世界が現れます。

```hs
{-# LANGUAGE UnboxedTuples #-}
import GHC.Base

main = IO $ \world ->
    let (# world1, _  #) = unIO (print "hello") world
        (# world2, _  #) = unIO (print "world") world1
    in  (# world2, () #)
```

`world` を手で受け渡す形は Clean の `#` と同じです（`WorldGHC.hs`）。Haskell は一意型を言語機能として持たない代わりに、一意性をモナドで守ったと言えます。

* [IOモナドを素手で触ってみた](https://qiita.com/7shi/items/0a90d7ba31355e1c73aa)

# IO モナド

1989 年に Moggi が圏論のモナドで言語機能を記述する論文を出し、Wadler がそれをプログラムの構造化に使えると見抜きました。Haskell 1.3（1996 年）で I/O はモナドになり、ストリーム版と継続版の両方を置き換えました。

```hs
main :: IO ()
main = do
    appendChan stdout "enter filename\n"
    userInput <- readChan stdin
    let (name : _) = lines userInput
    appendChan stdout name
    catch
        ( do
            contents <- readFile name
            appendChan stdout contents
        )
        (appendChan stdout "can't open file")
```

`appendChan` と `readChan` は現在の標準ライブラリにはありませんが、`hPutStr` と `hGetContents` に置き換えればそのまま動きます（`Monadic.hs`）。ここまでに出て来た 3 つの方式と実行結果は同じです。

```text:実行結果
enter filename
hello.txtHello, stream I/O!
```

論文が挙げるモナド版の利点は 3 つです。

1. 型が簡潔で情報量が多い。継続版の
   `readFile :: Name -> FailCont -> StrCont -> Behaviour` は成功と失敗の継続で散らかっていて、結果が `String` であることが型に出ていません。
2. 型を多相にできる。`readIORef :: IORef a -> IO a` は、`Request`／`Response` を固定したデータ型で書くことができません。
3. 概念的な利点が大きい。成功／失敗の継続という細部ではなく、計算という抽象で考えられます。細部を後から変更することも容易になります。

3 番目が本質的だと論文は述べています。

# 他言語の類似実装

同じ問題が別の場所で繰り返されています。

## Node.js のコールバック

Node.js の `readFile` はコールバックを取ります。

```js
fs.readFile(path, 'utf8', (err, data) => ...)
```

`(err, data)` は、失敗継続と成功継続を 1 つのコールバックに畳んで先頭引数で見分けているだけです。分けて書くと Haskell 1.0 の `readFile` と同じ形になります。

```js
const readFileT = path => (fail, succ) =>
    fs.readFile(path, 'utf8', (err, data) => (err ? fail(err) : succ(data)));
```

```hs
readFile :: Name -> FailCont -> StrCont -> Behaviour
```

`path` を部分適用すれば `(cb) => void` で、`(a -> r) -> r` の形です。そしてネストすれば括弧が積み上がります。これは「コールバック地獄」として知られていますが、1990 年の Figure 4 で起きていたことと同じです。

解決の方向も同じでした。Promise を経て async/await に至る流れは、継続版から `do` 記法への流れに対応します。

* [非同期APIをPromiseでラップしてasync/awaitで使う](https://qiita.com/7shi/items/a2bb35f27cd4a56f7bac)

## ジェネレーターによる実装

async/await が言語に入る前は、ジェネレーターとドライバーで同じことが実装されていました（`co` ライブラリなど）。ジェネレーターが「やってほしいこと」を `yield` し、ドライバーが実行して結果を `it.next(結果)` で渡して再開します。

`[Response] -> [Request]` という Haskell 1.0 の型は、まさに双方向のコルーチンを 2 本の遅延リストで表したものです。実際、上のプログラムをコルーチンとして書き直すと、型がそのまま `Behaviour` に一致して OS に差せます（`GenBehaviour.hs`）。

このとき、`~` に相当する配慮はドライバー側に移ります。出力を出す前に入力をパターンマッチするドライバーを書くと、`~` を外した Figure 3 と同じくデッドロックしました。

* [call/cc でジェネレーターを実装する](https://qiita.com/7shi/items/a44c5257f04f0c641ef0)
* [限定継続でジェネレーターを実装する](https://qiita.com/7shi/items/6db3e19ddc1f8552d9a0)
* [ジェネレーターでリストモナドを模倣してみた](https://qiita.com/7shi/items/8ec339bcddbb6692b738)

## Python の with

Python の `with` は `@contextmanager` によってジェネレーターで実装できます。`yield` の位置で `with` の本体が走ります。

```python
@contextmanager
def res(name):
    print(f"open  {name}")
    try:
        yield name        # ここで中断し、with の本体が走る
    finally:
        print(f"close {name}")
```

`with` の本体が継続です。Haskell では `ContT` を使うと同じことができます。

# まとめ

* IO モナドの前、Haskell 1.0（1990）はストリームと継続の 2 方式を載せていた。ストリームを primitive とした理由は効率。
* ストリーム版は `[Response] -> [Request]`。遅延評価に依存し、順序の正しさは遅延パターン `~` で守るしかなかった。
* 継続版の `readFile name abort` は `(String -> Behaviour) -> Behaviour` で、継続モナドそのもの。`Cont` で包めば `do` 記法になり、モナド版と同形になる。
* 世界渡しは単一スレッド性を保証できず却下された。Clean は同じ方式を一意型で型付けして成立させ、Haskell はモナドで隠して成立させた。現在の GHC の IO はこの方式を `newtype` で隠したものである。
* 同じ問題と同じ解決が、Node.js のコールバックから async/await への流れとして繰り返された。

「純粋なまま副作用を扱う」という問題に対して、リストで表すか継続で表すかという対立は Haskell が最初に通った道でした。

# 参考

* [A History of Haskell: Being Lazy with Class](https://www.microsoft.com/en-us/research/publication/a-history-of-haskell-being-lazy-with-class/)
  — 本記事の典拠。7 節が I/O の経緯。
* [Tackling the Awkward Squad](https://www.microsoft.com/en-us/research/publication/tackling-awkward-squad-monadic-inputoutput-concurrency-exceptions-foreign-language-calls-haskell/)
  — IO モナドの入門的な解説（Peyton Jones, 2001）。
* [CPS 変換から継続モナドへ](https://qiita.com/7shi/items/27b6f3169961299a6195)
  — JavaScript で CPS 変換から継続モナドまで。
* [継続モナドによるジェネレーターを Haskell で書く](https://zenn.dev/7shi/articles/20260730-haskell-generator)
  — 継続モナドでコルーチンを実装する際に型が循環する問題とその解決。
