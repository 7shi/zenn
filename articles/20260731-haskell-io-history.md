---
title: "Haskell の IO モナドへの道"
emoji: "📜"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "monad"]
published: true
---

Haskell は副作用を IO モナドで扱います。そこに至るまでは**遅延ストリーム**と**継続 I/O**という道のりがありました。当時のコンセプトを現行の GHC で再現しながら、その道をたどります。

:::message
本記事の執筆には Claude Code (Opus 5) を利用しました。
:::

# 典拠

以下の論文の 7 章に基づきます。設計に関わった 4 人による回顧録です。

* Paul Hudak, John Hughes, Simon Peyton Jones, Philip Wadler, [*A History of Haskell: Being Lazy with Class*](https://www.microsoft.com/en-us/research/publication/a-history-of-haskell-being-lazy-with-class/) (HOPL III, 2007)

本記事に出て来る `Behaviour` などの型定義とコード（論文中の Figure 3〜6）は、この論文が引用する当時の実装そのものではなく、現行の GHC で動くように移植したコードです。

* https://github.com/7shi/zenn/tree/main/check/20260731-haskell-io-history

:::message
関数名も Report では各例とも `main` でしたが、`figure3`・`figure4`・`figure4op`・`figureDo`・`figure6` のように改名しています。現行の GHC で `runghc` するには `main :: IO ()` という名前のエントリポイントが別途必要で、Report のコードをそのまま `main` にすると衝突するためです。
:::

# 3 つの候補

Haskell 委員会は言語を純粋に保つと決めていたため、I/O の設計が重要な課題になりました。論文は当時の空気をこう書いています。

> Our greatest fear was that Haskell would be viewed as a toy language because we did a poor job addressing this important capability.
> （我々が最も恐れたのは、この重要な機能をうまく扱えなかったために Haskell がおもちゃの言語と見なされることだった）

候補は 3 つありました。

|方式|型|採否|
|---|---|---|
|ストリーム|`[Response] -> [Request]`|Haskell 1.0 で採用（プリミティブ）|
|継続渡し|`FailCont -> StrCont -> Behaviour`|Haskell 1.0 で採用（ストリームの上に実装）|
|世界渡し|`World -> (a, World)`|却下|

:::message
一般的な「ストリーム」「継続渡し」と区別するため、以降ではこれらの実装方式を「遅延ストリーム」「継続 I/O」と呼びます。
:::

遅延ストリームと継続 I/O はどちらも採用されました。両者は相互に定義可能だと分かっていたためです。

遅延ストリームは n 番目の要求と n 番目の応答が対応しているという前提を型が守ってくれないため、遅延パターン `~` の付け忘れひとつで簡単に壊れる危険な書き方でした。そのため実際に書くには、継続 I/O の方が好まれました。

## なぜ遅延ストリームがプリミティブだったのか

継続 I/O の方が使いやすいと考えられていたのに、Haskell 1.0 は遅延ストリームをプリミティブとして、継続 I/O をその上に実装しました。理由は効率です。

逆向き（継続 I/O をプリミティブとして遅延ストリームを定義する）も可能でしたが、要求数に対して期待される線形時間になりませんでした。

# 遅延ストリーム

プログラムそのものが「応答の列を受け取って要求の列を返す関数」になります。

```hs:Haskell10.hs
type Behaviour = [Response] -> [Request]
```

要求と応答はデータ型です（一部を抜粋）。

```hs:Haskell10.hs
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
要求と応答の列が遅延評価によって少しずつ伸びていくことが、「遅延ストリーム」という名称の由来です。
:::

## OS の側

Haskell 1.0 Report は付録で、OS を「初期状態と Haskell プログラムを受け取る関数」として仕様化していました。

:::message
本物の OS は当然ファイル読み取りやキーボード入力という副作用を起こします。ここで「純粋関数」と言っているのは、実行環境（ファイルシステムの状態や標準入力の内容）を固定してしまえば、「どんな要求列に対してどんな応答列を返すか」が決定的に定まる、という**意味論を与えるための数学的モデル**の話です。副作用そのものが消えるわけではなく、1 回の実行に限れば決定的な関数として説明できる、という捉え方です。
:::

以下はそのモデルをそのまま Haskell コードにしたものです。実行のたびにファイルや標準入力を読み直す代わりに、あらかじめ用意した固定のファイルシステムと入力文字列を引数として与えます。

```hs:Haskell10.hs
os :: [(Name, String)] -> String -> [Request] -> [Response]
os _ _ [] = []
os fs input (r : rs) = case r of
    ReadChan _ -> Str input : os fs input rs
    ReadFile n -> case lookup n fs of
        Just s -> Str s : os fs input rs
        Nothing -> Failure ("no such file: " ++ n) : os fs input rs
    AppendChan _ _ -> Success : os fs input rs
```

ファイルシステムは連想リスト、標準入力は文字列として引数で与えられ、出力の要求にも `Success` を返すだけです。外界を丸ごと引数に押し込んであるので、この `os` 自体は何も副作用を起こしません。当時の処理系では、ここに本物のランタイムが座っていました。

:::message
`ReadChan` は実際に標準入力を読むのではなく、あらかじめ用意した `input` 文字列をそのまま返すだけで、何度要求しても同じ内容が返ります。`ReadFile` も同様に、実際のファイルではなく `fs` に登録された固定の内容を返すだけです。
:::

プログラムと OS を互いに参照させて回します。

```hs:Haskell10.hs
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

```hs:figure3.hs
figure3 :: Behaviour
figure3 ~(Success : ~(Str userInput : ~(Success : ~(r4 : _)))) =
    [ AppendChan stdout "enter filename\n"
    , ReadChan stdin
    , AppendChan stdout (name ++ "\n")
    , ReadFile name
    , AppendChan stdout
        (case r4 of
            Str contents -> contents
            Failure _ -> "can't open file\n")
    ]
  where
    (name : _) = lines userInput

-- 記事用の実行エントリポイント
-- os はモデルなので、ファイルも標準入力も実際には読まず、固定の文字列で与える
main :: IO ()
main = run [("hello.txt", "Hello, stream I/O!\n")] "hello.txt\n" figure3
```
```text:実行結果
enter filename
hello.txt
Hello, stream I/O!
```

`figure3`の引数（応答列）は、戻り値の要求列と同じ順序で並んでいます。`n` 番目の要求に対する応答が、そのまま引数パターンの `n` 番目の要素として返ってきます。

| 位置 | 要求（戻り値の要素） | 応答（引数パターンの要素） |
|---|---|---|
| 1 | `AppendChan stdout "enter filename\n"` | `Success`（読み捨て） |
| 2 | `ReadChan stdin` | `Str userInput` |
| 3 | `AppendChan stdout (name ++ "\n")` | `Success`（読み捨て） |
| 4 | `ReadFile name` | `r4` |

つまり `ReadChan stdin` という要求を出した結果は、`where` 句ではなく、この引数パターン自身の 2 番目の要素 `userInput` として受け取っています。`where` の `(name : _) = lines userInput` は、こうして引数パターンで既に受け取った `userInput` を後から `lines` で分割しているだけです。

この受け取り方が遅延パターンでなければならない理由は、`run` の相互再帰にあります。引数の `~` は**遅延パターン**です。通常のパターンマッチは引数が渡された時点で構造を確かめますが、`~` を付けるとマッチが先送りされ、束縛した変数（`userInput` や `r4`）を実際に使う瞬間まで応答を覗きません。

:::message
遅延パターンは、現在も Haskell の標準機能です。上のコードは `Behaviour` などの型定義さえ用意すれば、現行の GHC でそのまま通ります。
:::

```hs:Haskell10.hs
reqs = behaviour resps
resps = os fs input reqs
```

`reqs` は `figure3`（`behaviour`）の戻り値のリストで、`resps` はその `reqs` を消費して `os` が返す応答のリストです。つまり `reqs` の先頭要素を作るには `figure3` 自身が呼ばれる必要がありますが、`figure3` の引数は他ならぬ `resps` であり、`resps` はまだ `reqs` の先頭要素を消費していないので存在しません。

`~` があると `figure3` は引数の中身を一切見ずに `[AppendChan ..., ReadChan stdin, ...]` というリストの「入れ物」（`:` のコンスセル）だけを即座に組み立てて返します。これで `reqs` の先頭要素が確定し、`os` はそれを消費して最初の応答を返し、`resps` の先頭要素も確定します。以降は要求と応答が1つずつ交互に確定していき、循環が解けます。`userInput` や `r4` の中身を実際に取り出す（`lines userInput` を評価する）のは、対応する応答がすでに届いた後になるので安全です。

## ~ を外すと止まる

`~` がないと、`figure3` は最初の引数（`resps` の先頭）の構造を確かめてからでないと戻り値のコンスセルすら作れません。しかし `resps` の先頭は `reqs` の先頭が要求として消費されて初めて生まれるものです。`reqs` の先頭は `figure3` の戻り値そのものなので、「`figure3` が値を返すには `resps` の先頭が要る」「`resps` の先頭が生まれるには `figure3` が値を返す必要がある」という堂々巡りになり、どちらも先に進めず止まります。

実際に `~` を外して動かすと、この堂々巡りによってタイムアウトとなります。

```hs:figure3.hs
-- 記事用の実行エントリポイント
main :: IO ()
main =
    r <- timeout 1000000 $ try (run fs "hello.txt\n" figure3Strict)
    case r of
        Nothing -> putStrLn "  → タイムアウト（自分の出力を待って止まった）"
        Just (Left e) -> putStrLn ("  → 例外: " ++ show (e :: SomeException))
        Just (Right ()) -> putStrLn "  → 完走した"
```
```text:実行結果
  → 例外: <<timeout>>
```

n 番目の要求と n 番目の応答が対応しているという前提を、プログラマが遅延パターンで守る必要があります。順序の正しさは型では守られておらず、`~` の付け忘れひとつで簡単に壊れます。論文は遅延ストリームの読みにくさをこう説明しています。

> the pattern matching required by stream-based I/O forces the reader's focus to jump back and forth between the patterns (representing the responses) and the requests.
> （遅延ストリームベースの I/O が要求するパターンマッチは、応答を表すパターンと要求との間で読者の視点を行き来させる）

# 継続 I/O

同じ `Behaviour` 型のままで、要求と応答を直接触らせない書き方が用意されました。要求／応答の対を継続渡しスタイルで包んだ関数を**トランザクション**と呼びます。

```hs
type Behaviour = [Response] -> [Request]
type FailCont = IOError -> Behaviour
type StrCont = String -> Behaviour
```

`ReadFile` という要求（コンストラクタ）に `readFileT` というトランザクション（関数）が対応します。この要求は失敗と成功の 2 つの応答を持つので、継続も 2 つ受け取ります。

```hs:Transaction.hs
readFileT :: Name -> FailCont -> StrCont -> Behaviour
readFileT name fail_ succ_ ~(resp : resps) =
    ReadFile name
        : case resp of
            Str val -> succ_ val resps
            Failure msg -> fail_ msg resps
            Success -> fail_ "unexpected" resps
```

要求を出し、応答を見てどちらかの継続を呼ぶ、という形です。`~` はここに閉じ込められて、利用側からは消えます。

先ほどのプログラムはこうなります。

```hs:figure4.hs
figure4 :: Behaviour
figure4 =
    appendChanT stdout "enter filename\n" abort (
    readChanT stdin abort                       (\userInput ->
    letE (lines userInput)                      (\(name : _) ->
    appendChanT stdout (name ++ "\n") abort     (
    readFileT name fail_                        (\contents ->
    appendChanT stdout contents abort done)))))
  where
    fail_ _ = appendChanT stdout "can't open file\n" abort done

-- 記事用の実行エントリポイント
main :: IO ()
main = run [("hello.txt", "Hello, continuation I/O!\n")] "hello.txt\n" figure4
```
```text:実行結果
enter filename
hello.txt
Hello, continuation I/O!
```

`letE x k = k x` という補助関数が使われているのは、Haskell 1.0 には `let` 式がなかったためです（1.1 で入りました）。

制御の流れが局所的になり使いやすくなりましたが、ラムダが入れ子になるにつれて括弧が積み上がります。

## 括弧を減らす

この書き方が一般的になると見て、委員会は設計の終盤に中置演算子の文脈におけるラムダの優先順位を変更しました。これで次のように書けます。

```hs:figure4op.hs
figure4op :: Behaviour
figure4op =
    appendChanT stdout "enter filename\n" >>>
    readChanT stdin                       >>> \userInput ->
    let (name : _) = lines userInput in
    appendChanT stdout (name ++ "\n")     >>>
    readFileT name fail_                     (\contents ->
    appendChanT stdout contents abort done)
  where
    fail_ _ = appendChanT stdout "can't open file\n" abort done

-- 記事用の実行エントリポイント
main :: IO ()
main = run [("hello.txt", "Hello, continuation I/O!\n")] "hello.txt\n" figure4op
```
```text:実行結果
enter filename
hello.txt
Hello, continuation I/O!
```

演算子の定義は失敗継続を `abort` に固定するだけです。

```hs:figure4op.hs
f >>> x = f abort x
```

`>>=` (bind) の手前まで来ているように見えます。

# 継続 I/O と継続モナド

論文は `>>>` について「モナドのコードと驚くほど似ている」と述べた上で、こう続けます。

> it was really the advent of do-notation—not monads themselves—that made Haskell programs look more like conventional imperative programs
> （Haskell のプログラムを従来の命令型プログラムのように見せたのは、モナドそれ自体ではなく、実は do 記法の登場だった）

そして次の問いを残しています。

> In retrospect it is worth asking whether this same (or similar) syntactic device could have been used to make stream or continuation-based I/O look more natural.
> （振り返ってみると、これと同じ（あるいは似た）構文上の仕掛けを、遅延ストリームや継続ベースの I/O をより自然に見せるために使えたのではないかと問う価値がある）

:::message
Haskell 1.0 当時の視点ではなく、2007 年に書かれた論文が振り返って述べている視点です。
:::

## 継続モナドとして見る

まず、継続 I/O がすでに継続モナドの形をしていることを確認します。`readFileT` の失敗継続を `abort` に固定して部分適用すると、型はこうなります。

```hs
readFileT name abort :: StrCont -> Behaviour
--                   =  (String -> Behaviour) -> Behaviour
```

`(a -> r) -> r` の形です。つまり継続モナドの中身そのものです。

```hs:figureDo.hs
newtype Cont r a = Cont {runCont :: (a -> r) -> r}
```

包んでみます。

```hs:figureDo.hs
readFileC :: Name -> Cont Behaviour String
readFileC name = Cont (readFileT name abort)

appendChanC :: Name -> String -> Cont Behaviour ()
appendChanC name s = Cont $ \k -> appendChanT name s abort (k ())

evalIO :: Cont Behaviour () -> Behaviour
evalIO m = runCont m (\_ -> done)
```

## do 記法で書き直す

`Cont` は `newtype` で包んだだけなので、`Monad` インスタンスを与えれば論文の問いにあった「同じ構文上の仕掛け」、つまり `do` 記法がそのまま使えます。

```hs:figureDo.hs
instance Monad (Cont r) where
    m >>= k = Cont $ \c -> runCont m (\x -> runCont (k x) c)

figureDo :: Behaviour
figureDo = evalIO $ do
    appendChanC stdout "enter filename\n"
    userInput <- readChanC stdin
    let (name : _) = lines userInput
    appendChanC stdout (name ++ "\n")
    contents <- readFileC name
    appendChanC stdout contents

-- 記事用の実行エントリポイント
main :: IO ()
main = run [("hello.txt", "Hello, continuation I/O!\n")] "hello.txt\n" figureDo
```
```text:実行結果
enter filename
hello.txt
Hello, continuation I/O!
```

入れ子のラムダ・`>>>`・`do` の 3 つで、実行結果は完全に一致します。

Haskell 1.0 の継続 I/O は、継続モナドを `newtype` で包まずに素で使っていたものだと言えます。論文も、IO モナドが継続で実装できることを次の型で示しています。

```hs
type IO a = FailCont -> SuccCont a -> Behaviour
```

# 却下された世界渡し

「世界の状態を受け渡して更新する」方式も検討されました。純粋関数型言語で他のデータ構造を扱うのと同じように、世界も引数と戻り値で回すという発想です。

```hs:WorldPassing.hs
type IOw a = World -> (a, World)
```

`bind` に相当するものは状態を繋ぐだけです。

```hs:WorldPassing.hs
bindW :: IOw a -> (a -> IOw b) -> IOw b
bindW m k w = case m w of (x, w') -> k x w'
```

素直に使えば命令型のように書けます。

```hs:WorldPassing.hs
greet :: IOw ()
greet =
    putStrLnW "enter filename" `bindW` \_ ->
    getLineW "hello.txt"       `bindW` \name ->
    putStrLnW ("you typed " ++ name)

-- 記事用の実行エントリポイント
main :: IO ()
main = putStrLn ("  " ++ render (snd (runW greet)))
```
```text:実行結果
  enter filename / you typed hello.txt
```

却下された理由は、世界への単一スレッドなアクセスを保証する手段がなかったことです。実際に破ってみます。同じ世界を 2 回使うと、世界が分岐します。

```hs:WorldPassing.hs
forked w =
    let (_, w1) = putStrLnW "branch A" w
        (_, w2) = putStrLnW "branch B" w  -- ← 同じ w を再利用
    in (w1, w2)

-- 記事用の実行エントリポイント
main :: IO ()
main =
    let (a, b) = forked (World ["common"])
    putStrLn ("  branch1: " ++ render a)
    putStrLn ("  branch2: " ++ render b)
```
```text:実行結果
  branch1: common / branch A
  branch2: common / branch B
```

古い世界を使い回せば、出力を巻き戻すこともできます。

```hs:WorldPassing.hs
rewound =
    let (_, w1) = putStrLnW "first" (World [])
        (_, w2) = putStrLnW "second" w1
        (_, w3) = putStrLnW "third" w1    -- ← w2 を捨てて w1 から再開
    in seq w2 w3

-- 記事用の実行エントリポイント
main :: IO ()
main = putStrLn ("  " ++ render rewound)
```
```text:実行結果
  first / third
```

型エラーにはなりませんが、現実の世界は巻き戻せないので、これは意味を失っています。

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

一方で、受け渡しを手で書き続けるのは面倒です。Clean のドキュメントは関数合成・`seq`・専用演算子といった書き方を次々に紹介した末に、モナドスタイルに行き着きます。ただし Clean には do 記法がないため、あまり使い勝手の良いものではなかったと思われます。

https://qiita.com/7shi/items/ab3b819871d7b0710949

# IO モナド

1989 年に Moggi が圏論のモナドで言語機能を記述する論文を出し、Wadler がそれをプログラムの構造化に使えると見抜きました。Haskell 1.3（1996 年）で I/O はモナドになり、遅延ストリームと継続 I/O の両方を置き換えました。

```hs:figure6.hs
figure6 :: IO ()
figure6 = do
    appendChan stdout "enter filename\n"
    userInput <- readChan stdin
    let (name : _) = lines userInput
    appendChan stdout (name ++ "\n")
    catch
        (do
            contents <- readFile name
            appendChan stdout contents
        )
        (\e -> appendChan stdout ("can't open file: " ++ show (e :: IOException) ++ "\n"))

main :: IO ()
main = figure6
```

`appendChan` と `readChan` は現在の標準ライブラリにはありませんが、`hPutStr` と `hGetContents` に置き換えればそのまま動きます（`figure6.hs`）。ここまでに出て来た 3 つの方式と実行結果は同じです。

```text:実行結果
enter filename
hello.txt
Hello, stream I/O!
```

論文が挙げるモナド版の利点は 3 つです。

1. 型が簡潔で情報量が多い。継続 I/O の
   `readFile :: Name -> FailCont -> StrCont -> Behaviour` は成功と失敗の継続で散らかっていて、結果が `String` であることが型に出ていません。
2. 型を多相にできる。`readIORef :: IORef a -> IO a` は、`Request`／`Response` を固定したデータ型で書くことができません。
3. 概念的な利点が大きい。成功／失敗の継続という細部ではなく、計算という抽象で考えられます。細部を後から変更することも容易になります。

3 番目が本質的だと論文は述べています。

## IO モナドと世界渡し

皮肉なことに、却下されたはずの世界渡しは現在の IO モナドの実装そのものです。`IO` を `newtype` で包んで外から触れなくすることで、単一スレッド性を型システムではなく抽象化によって守っています。剥がすと世界が現れます。

```hs:WorldGHC.hs
{-# LANGUAGE UnboxedTuples #-}
import GHC.Base

main = IO $ \world ->
    let (# world1, _  #) = unIO (print "hello") world
        (# world2, _  #) = unIO (print "world") world1
    in  (# world2, () #)
```

`world` を手で受け渡す形は Clean の `#` と同じです（`WorldGHC.hs`）。Haskell は一意型を言語機能として持たない代わりに、一意性をモナドで守ったと言えます。

https://qiita.com/7shi/items/0a90d7ba31355e1c73aa

# 他言語の類似実装

同じ問題が別の場所で繰り返されています。

## Node.js のコールバック

Node.js の `readFile` はコールバックを取ります。

```js
fs.readFile(path, 'utf8', (err, data) => ...)
```

`(err, data)` は、失敗継続と成功継続を 1 つのコールバックに畳んで先頭引数で見分けているだけです。引数を分けて書けば Haskell 1.0 の `readFile` と同じ形になります。

```js
const readFileT = path => fail => succ =>
    fs.readFile(path, 'utf8', (err, data) => (err ? fail(err) : succ(data)));
```

```hs:Haskell 1.0 の型
readFile :: Name -> FailCont -> StrCont -> Behaviour
```

ネストによって括弧が積み上がります。これは「コールバック地獄」として知られていますが、1990 年の Figure 4 で起きていたことと同じです。

解決の方向も同じでした。Promise を経て async/await に至る流れは、継続 I/O から `do` 記法への流れと重なります。

https://qiita.com/7shi/items/a2bb35f27cd4a56f7bac

## ジェネレーターによる実装

async/await が言語に入る前は、ジェネレーターで同じことが実装されていました（`co` ライブラリなど）。

`[Response] -> [Request]` という Haskell 1.0 の型は、まさに双方向のコルーチンを 2 本の遅延リストで表したものです。実際、「遅延ストリーム I/O」の節で見た Figure 3 のプログラムをコルーチンとして書き直すと、型がそのまま `Behaviour` に一致し、そこで定義した `run`（`os`）にそのまま渡せます。

```hs:GenBehaviour.hs
feed :: Gen i o -> [i] -> [o]
feed Done _ = []
feed (Yield v next) is =
    v : case is of
        (i : rest) -> feed (evalCont (next i)) rest
        [] -> []

main :: IO ()
main = run fs "hello.txt\n" (feed prog)
```

# まとめ

* IO モナドの前、Haskell 1.0（1990）は遅延ストリームと継続 I/O の 2 方式を載せていた。遅延ストリームをプリミティブとした理由は効率。
* 遅延ストリームは `[Response] -> [Request]`。遅延評価に依存し、順序の正しさは遅延パターン `~` で守るしかなかった。
* 継続 I/O の `readFile name abort` は `(String -> Behaviour) -> Behaviour` で、継続モナドそのもの。`Cont` で包めば `do` 記法になり、モナド版と同形になる。
* 世界渡しは単一スレッド性を保証できず却下された。Clean は同じ方式を一意型で型付けして成立させ、Haskell はモナドで隠して成立させた。現在の GHC の IO はこの方式を `newtype` で隠したものである。
* 同じ問題と同じ解決が、Node.js のコールバックから async/await への流れとして繰り返された。
