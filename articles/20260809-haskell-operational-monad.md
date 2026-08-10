---
title: "Haskell Operationalモナド 超入門"
emoji: "⚙️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "モナド"]
published: true
---

Operational モナド（Freer モナドとも）は、Free モナドと同じく命令をデータとしてつなぐモナドですが、継続を命令の型ではなく bind の側が持つ形にすることで、`Functor` インスタンスなしで手順書を組み立てられるようにしたものです。Free モナドとの違いを追いながら説明します。

:::message
本記事の執筆には GitHub Copilot CLI (Kimi K3) と Claude Code (Opus 5) を利用しました。
:::

シリーズの記事です。

1. [Haskell 超入門](http://qiita.com/7shi/items/145f1234f8ec2af923ef)
1. [Haskell 代数的データ型 超入門](http://qiita.com/7shi/items/1ce76bde464b4a55c143)
1. [Haskell アクション 超入門](http://qiita.com/7shi/items/85afd7bbd5d6c4115ad6)
1. [Haskell ラムダ 超入門](http://qiita.com/7shi/items/1345bf32003faff435cb)
1. [Haskell アクションとラムダ 超入門](http://qiita.com/7shi/items/4a8a2807bb5186576c61)
1. [Haskell IOモナド 超入門](http://qiita.com/7shi/items/d3d3492ddd90d47160f2)
1. [Haskell リストモナド 超入門](http://qiita.com/7shi/items/deb19c4cba933590ffbf)
1. [Haskell Maybeモナド 超入門](http://qiita.com/7shi/items/c7d7eec066af0fe0688d)
1. [Haskell 状態系モナド 超入門](http://qiita.com/7shi/items/2e9bff5d88302de1a9e9)
1. [Haskell モナド変換子 超入門](http://qiita.com/7shi/items/4408b76624067c17e933)
1. [Haskell 例外処理 超入門](http://qiita.com/7shi/items/73e534c47bbebc71b37e)
1. [Haskell 構文解析 超入門](http://qiita.com/7shi/items/b8c741e78a96ea2c10fe)
1. [Haskell 継続モナド 超入門](https://zenn.dev/7shi/articles/20260803-haskell-continuation-monad)
1. [Haskell 型クラス 超入門](https://zenn.dev/7shi/articles/20260805-haskell-type-classes)
1. [Haskell モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends)
1. [Haskell Freeモナド 超入門](https://zenn.dev/7shi/articles/20260808-haskell-free-monad)
1. **Haskell Operationalモナド 超入門** ← この記事
1. [Haskell Effモナド 超入門](https://zenn.dev/7shi/articles/20260811-haskell-eff-monad)
1. 【予定】Haskell アロー 超入門

# Free モナドから Operational モナドへ

前回は、命令を並べた手順書をデータとして組み立て、後からインタープリターで解釈するという枠組みを、Free モナドで実現しました。👉[Freeモナド](https://zenn.dev/7shi/articles/20260808-haskell-free-monad)

Free モナドは葉と枝からなる木構造において、枝の形を型引数にくくり出したものに相当します。

```hs
data Free f a = Pure a | Free (f (Free f a))
```

命令の型は、継続を `next` という型引数で受け取ります。ジェネレーターの命令なら次の 1 行です。

```hs
data GenF o next = Yield o next deriving Functor
```

`Yield` は出力する値と継続を持ちます。`>>=` が枝の中の継続を `fmap` で辿るので、命令の型に `Functor` インスタンスが必要でした。

```hs
instance Functor f => Monad (Free f) where
    Pure a >>= k = k a
    Free g >>= k = Free (fmap (>>= k) g)
```

入出力を伴う命令では、継続が関数になりました。👉[Freeモナド](https://zenn.dev/7shi/articles/20260808-haskell-free-monad#テレタイプ)

```hs
data TeletypeF next
    = PutLine String next
    | GetLine (String -> next)

instance Functor TeletypeF where
    fmap f (PutLine s next) = PutLine s (f next)
    fmap f (GetLine k)      = GetLine (f . k)
```

`GetLine` は読み込んだ文字列が決まらないと継続が決まらないので、継続が `String -> next` という関数です。`fmap` も関数合成 `f . k` になり、少し込み入っていました。

## 継続を命令の型から外す

命令の型を作るたびに `Functor` インスタンスが要ること、継続が関数になる命令ではその捌き方まで考えないといけないことが、Free モナドの手間でした。今回はこの 2 つを同時に解消します。

発想は単純です。継続を命令の型から外してしまいます。

継続がどこにも書かれていない命令は、それだけでは手順書になりません。そこで「命令と、その結果を受け取って継続を返す関数」の組を、手順書の型の側に持たせます。この形を **Operational モナド**と呼びます。

:::message
名前は、操作的意味論（operational semantics）に由来します。計算の意味を、実行する操作（命令）の並びとして記述する手法を指し、今回の方式はまさにこの発想に基づいています。

なお、同等の方式は **Freer モナド**とも呼ばれます。Free が「モナド則だけを満たす自由な構造」だったのに対し、Freer は `Functor` インスタンスすら要求しない、より自由な構造（比較級）、という命名です。
:::

```hs
data Program instr a where
    Return :: a -> Program instr a
    (:>>=) :: instr b -> (b -> Program instr a) -> Program instr a
```

見慣れない書き方ですが、各コンストラクターが自分の戻り値の型を宣言しているだけです。この宣言方法を **GADT**（Generalized Algebraic Data Type、一般化代数的データ型）と呼びます。

- `Return` は結果の値を受け取って手順書を終えます。`Pure` に相当します。
- `:>>=` は命令 `instr b` と、命令の結果 `b` を受け取って継続の手順書 `Program instr a` を返す関数の組です。

演算子をコンストラクターの名前にするときは、`:` で始める決まりがあります。`>>=` に似せた `:>>=` にしたのは、この組が bind そのものを表しているからです。以降、`:` の有無でコンストラクターの `:>>=` とメソッドの `>>=` を見分けてください。

命令の型 `instr` は `* -> *` の種を持つ型引数で、前回の `Free` の `f` と同じ位置づけです。👉[Freeモナド](https://zenn.dev/7shi/articles/20260808-haskell-free-monad#種)

命令の結果の型 `b` は、手順書全体の型 `a` には現れません。途中の命令が何を返すかは、外からは見えないようになっています。このように型全体からは見えない型変数を含む型を**存在型**（existential type）と呼びます。この `b` が、GADT で書く理由です。普通の `data` では宣言の先頭に置いた型引数しか使えないので、戻り値の型に現れない `b` を持つコンストラクターは書けません。

GADT は拡張構文なので、このままではコンパイルが通りません。言語拡張を有効にするプラグマを、ファイルの先頭に書きます。概念としての GADT に対して、拡張の名前は複数形の `GADTs` です。`FlexibleInstances`・`UnboxedTuples` のように、言語拡張の名前は複数形で綴るものが多くあります。

```hs
{-# LANGUAGE GADTs #-}
```

:::message
これまでのコードは GHC2021 という既定の拡張セットだけで動いていましたが、GADTs はそこに含まれていません。前回の `DeriveFunctor` は「手書きでも書けるものを楽にする」便利のための拡張でしたが、GADTs は「それがないと表現できない型」を可能にする拡張です。書かなくて済むものではないので、明示が要ります。
:::

この型に 3 段を揃えます。`Functor`・`Applicative` は定型です。👉[モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends#3-段まとめて書く定型)

```hs
import Control.Monad (liftM, ap)

instance Functor (Program instr) where
    fmap = liftM

instance Applicative (Program instr) where
    pure  = Return
    (<*>) = ap
```

前回と違って、`instance` に `Functor instr =>` という制約が付いていません。要点は `Monad` の方です。

```hs
instance Monad (Program instr) where
    Return a   >>= k = k a
    (i :>>= j) >>= k = i :>>= (\b -> j b >>= k)
```

`Return` の行は Free と同じです。`:>>=` の行を読み解きます。「命令 `i` の結果を `j` に渡して得られた手順書に、さらに `k` を続ける」のを、「命令 `i` の結果を、『`j` に渡してさらに `k` を続ける関数』に渡す」に書き換えています。継続の関数を合成しているだけです。

:::message
この書き換えは、モナド則の結合法則と同じ形です。👉[モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends#モナド則)

```hs
(m  >>= f) >>= g == m  >>= (\x -> f x >>= g)  -- モナド則の結合法則
(i :>>= j) >>= k =  i :>>= (\b -> j b >>= k)  -- Program の定義
```

コンストラクターの `:>>=` をメソッドの `>>=` と読み替えると、左辺どうし・右辺どうしが重なります。左に積み上がった `>>=` を右に倒す、という結合法則の書き換えを、そのまま定義として採用した形です。
:::

Free の `>>=` と並べます。

```hs
Free g     >>= k = Free (fmap (>>= k) g)      -- Free
(i :>>= j) >>= k = i :>>= (\b -> j b >>= k)   -- Program
```

Free は枝の中に継続があるので `fmap` で辿る必要がありました。Program は継続が最初から関数の中にあるので、辿る対象がありません。`fmap` が消え、命令の型への `Functor` 要求がなくなりました。

「結果を受け取って継続を返す関数」を持ち回るのは、継続渡しスタイルと同じ形です。👉[継続モナド](https://zenn.dev/7shi/articles/20260803-haskell-continuation-monad#bind-と-cps)

命令 1 つだけの手順書を作る関数も用意します。Free の `liftF` に相当します。

```hs
singleton :: instr a -> Program instr a
singleton i = i :>>= Return
```

「命令を実行して、その結果をそのまま手順書の結果として終わる」という形です。`liftF` のように `fmap` で継続を書き換える必要がない分、素直な定義になっています。

:::message
`singleton` という名前は「要素が 1 つだけの構造を作る」という意味で、`Data.Map.singleton`（キーと値が 1 組だけのマップ）などと同じ用法です。ここでは命令 1 つだけの手順書を指します。オブジェクト指向のデザインパターンでいうシングルトン（インスタンスを 1 つに限る）とは関係ありません。
:::

## 命令の型を GADT で並べる

命令の型を作ります。テレタイプを例にします。今度は継続を持たないので、命令が何を受け取って何を返すかだけを書きます。

```hs
data TeletypeI a where
    PutLine :: String -> TeletypeI ()
    GetLine :: TeletypeI String
```

`Program` を宣言したときと同じ、コンストラクターごとに戻り値の型を書く構文（GADT）です。ただし `Program` では `Return` も `:>>=` も戻り値が `Program instr a` で揃っていたのに対し、こちらは `TeletypeI ()`・`TeletypeI String` とコンストラクターごとに違います。`PutLine` の結果が `()` で `GetLine` の結果が `String` だということが、型に直接書けました。

この `()` と `String` が、`:>>=` の `b`（命令の結果の型）に入ります。`Program` の側では外から見えない型でしたが、命令の型の側では命令ごとに具体的に決まっている、という関係です。

:::message
GADT の「一般化」は、普通の `data` では `TeletypeI a` に揃うしかなかった戻り値の型を、コンストラクターごとに決められることを指します。`Program` では `b` を隠すために GADT を使いましたが、こちらは名前どおりの使い方です。同じ拡張が 2 通りに効いています。
:::

前回は「継続が値の命令では置いた値が結果になり、継続が関数の命令では置いた関数の戻り値が結果になる」という対応を、スマートコンストラクターの中で自分で作っていました。今度はその対応が、命令の型の宣言そのものになっています。👉[Freeモナド](https://zenn.dev/7shi/articles/20260808-haskell-free-monad#スマートコンストラクター)

スマートコンストラクターは `singleton` を使って書きます。

```hs
type Teletype = Program TeletypeI

putLine :: String -> Teletype ()
putLine s = singleton (PutLine s)

getLine' :: Teletype String
getLine' = singleton GetLine
```

前回の `getLine'` は `liftF (GetLine id)` と、継続の位置に関数 `id` を置く必要がありました。命令の結果の型が宣言されている今度は、単に `singleton GetLine` で `Teletype String` になります。

これで `do` が使えます。前回と同じ手順書です。

```hs
greet :: Teletype ()
greet = do
    putLine "name?"
    name <- getLine'
    putLine ("Hello, " ++ name ++ "!")
```

`<-` で受け取る値が `b` です。`name` が `String` になるのは `GetLine :: TeletypeI String` だからで、`putLine` は `b` が `()` なので受け取るものがありません。一方 `greet` 全体の型は `Teletype ()` で、途中で `String` を受け取ったことは残っていません。

## インタープリター

組み立てた手順書を 1 段ずつ剥がして辿ります。まずは入力をリストで与えて出力をリストで集めるもので、入力が尽きたら空文字列を返します。前回と同じ形です。👉[Freeモナド](https://zenn.dev/7shi/articles/20260808-haskell-free-monad#インタープリター)

```hs
runPure :: [String] -> Teletype a -> [String]
runPure _        (Return _)         = []
runPure ins      (PutLine s :>>= k) = s : runPure ins (k ())
runPure []       (GetLine :>>= k)   = runPure [] (k "")
runPure (i : is) (GetLine :>>= k)   = runPure is (k i)
```

`:>>=` をパターンマッチで剥がすと、その枝では `b` が確定します。`PutLine` の枝では `b` が `()` なので継続は `k ()` で、`GetLine` の枝では `String` なので `k i` と入力を渡します。同じ `:>>=` でありながら枝ごとに `k` の引数の型が違ってよいのは、GADT で書いたおかげです。

`GetLine` の継続が、型の中の関数ではなく `:>>=` の右側に来た点も見どころです。`k i` で継続を得るのは前回と同じですが、命令の型の側で関数を捌く必要はもうありません。

先ほどの `greet` に、入力を与えて走らせます。

```hs
main = do
    mapM_ putStrLn $ runPure ["Haskell"] greet
    mapM_ putStrLn $ runPure ["世界"] greet
```
```text:実行結果
name?
Hello, Haskell!
name?
Hello, 世界!
```

本物の `IO` で走らせるインタープリターも同様に書けます。`runIO greet` とすれば、実際の入力を待って対話します。

```hs
runIO :: Teletype a -> IO ()
runIO (Return _)         = return ()
runIO (PutLine s :>>= k) = putStrLn s >> runIO (k ())
runIO (GetLine :>>= k)   = getLine >>= runIO . k
```

手順書の表し方を差し替えても、インタープリターの書き方は変わりませんでした。組み立てと解釈の分離という枠組みは、そのまま残っています。

# ジェネレーター

前回のもう 1 つの題材も、Operational 流に書き直しておきます。命令は値を 1 つ出力する `Yield` だけです。

```hs
data GenI o a where
    Yield :: o -> GenI o ()

type Gen o = Program (GenI o)

yield :: o -> Gen o ()
yield x = singleton (Yield x)
```

`Yield` の中身は出力する値だけになりました。継続は `:>>=` の右側の関数に入っています。

```hs
toList :: Gen o a -> [o]
toList (Return _)       = []
toList (Yield o :>>= k) = o : toList (k ())
```

`Yield` の結果は `()` なので、`k ()` を評価して継続の手順書を得ます。

```hs
count :: Gen Int ()
count = do
    yield 1
    yield 2
    yield 3

nats :: Gen Int ()
nats = mapM_ yield [0 ..]

main = do
    print $ toList count
    print $ take 5 $ toList nats
```
```text:実行結果
[1,2,3]
[0,1,2,3,4]
```

## `Show` は書けるのか

前回はここで、`Show` インスタンスを書いて手順書の中身を `print` で覗いていました。Operational ではどうでしょうか。

`GenI` では全命令の結果型が `()` に固定されている（`Yield :: o -> GenI o ()`）ので、継続の関数は `() -> Gen o a` で、常に `k ()` を呼べます。これを使うと、前回と似た形で書けます。

```hs
instance (Show o, Show a) => Show (Gen o a) where
    show (Return a)       = "Return " ++ show a
    show (Yield o :>>= k) = "Yield " ++ show o ++ " :>>= \n  " ++ show (k ())

main = print count
```
```text:実行結果
Yield 1 :>>= 
  Yield 2 :>>= 
  Yield 3 :>>= 
  Return ()
```

:::message
`Gen o` は `Program (GenI o)` の型シノニムなので、この `instance` は GHC2021 では書けますが、それ以前の標準（Haskell2010）では `TypeSynonymInstances` と `FlexibleInstances` が必要となります。

```hs
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
```
:::

ただし、よく見ると `k ()` を適用して辿る骨組みは `toList` と同じです。文字列を作るかリストを作るかの違いしかない、つまりこれはインタープリターです。Free 版の `show` が「データの構造をそのまま文字列に写す」ものだったのに対し、Operational 版の `show` は「継続を駆動して辿る」もので、中身を見るために解釈を行っています。「`Show` が書ける」からといって「インタープリターを通さずに中身を見られる」ことにはなりません。

この `Show` が書けたのは、`GenI` の全命令が `()` を返すという知識があったからです。`TeletypeI` では `GetLine :: TeletypeI String` が `()` 以外を返すので、継続の関数は `String -> Teletype a` です。駆動するには `String` の値が要りますが、手順書を表示する段階では本物の入力はまだ存在しません。`k ""` のようにダミーの入力を与えることはできますが、その時点で `runPure` と同じ「入力を仮定した解釈」をしているので、もはや手順書そのものの表示ではありません。

`Program instr a` 全体に汎用の `Show` が書けないのは、命令の結果型 `b` が外に見えないため、継続を駆動する値の作りようがないからです。

## 練習

【問1】前回の練習で作ったスタックマシンを、Operational 流に書き直します。整数のスタックを操作する命令の型 `StackI` と、スマートコンストラクター `push`・`pop` を定義してください。`push` は値を 1 つ積む命令、`pop` は 1 つ取り出す命令です。次の `calc` が書けることが目標です。

```hs
-- ここに StackI を定義する

type Stack = Program StackI

push :: Int -> Stack ()
push = undefined  -- ここを書く

pop :: Stack Int
pop = undefined   -- ここを書く

calc :: Stack Int
calc = do
    push 3
    push 4
    a <- pop
    b <- pop
    push (a + b)
    pop
```

:::details 解答例
```hs
data StackI a where
    Push :: Int -> StackI ()
    Pop :: StackI Int

push :: Int -> Stack ()
push n = singleton (Push n)

pop :: Stack Int
pop = singleton Pop
```

前回は `Pop` の継続が `Int -> next` という関数で、`deriving Functor` が要りました。今度は `Pop :: StackI Int` と、取り出した値の型を宣言するだけです。`Functor` インスタンスはまるごと不要になりました。

`calc` は 3 と 4 を積み、2 つ取り出して足し、積み直して、最後に取り出しています。
:::

【問2】問1の `calc` を走らせるインタープリター `runStack` を書いてください。第 1 引数が初期スタックです。`Pop` でスタックが空だったときは 0 を返すことにします。

```hs
runStack :: [Int] -> Stack a -> a
runStack = undefined  -- ここを書く

main = print $ runStack [] calc
```
```text:実行結果
7
```

:::details 解答例
```hs
runStack :: [Int] -> Stack a -> a
runStack _        (Return a)      = a
runStack st       (Push n :>>= k) = runStack (n : st) (k ())
runStack []       (Pop :>>= k)    = runStack [] (k 0)
runStack (x : xs) (Pop :>>= k)    = runStack xs (k x)
```

前回の解答と見比べると、違いは継続のありかだけです。`Push n k` の `k` が手順書そのものだったのに対し、`Push n :>>= k` の `k` は「結果を受け取って手順書を返す関数」なので、`k ()` と適用してから辿ります。

スタックという状態は手順書の側には現れません。状態を持つのはインタープリターの引数だけ、という点も前回のままです。
:::

# operational パッケージ

ここまで `Program` を自分で定義してきましたが、実際には [operational](https://hackage.haskell.org/package/operational) パッケージを使います。[`Control.Monad.Operational`](https://hackage.haskell.org/package/operational/docs/Control-Monad-Operational.html) の `Program` は、本記事で書いたものと同じ発想の型です。

ただし内部表現は同じではなく、コンストラクターも公開されていないので、`runIO` のように直接パターンマッチすることはできません。

:::message
コンストラクターが公開されていない、というのはモジュールのエクスポートの話です。Haskell では公開するものをモジュール名の後ろに列挙します。`module M (Program) where` のように型名だけを書くと、外からは型 `Program` は使えてもコンストラクターは見えません。両方公開するには `Program(..)` と書きます。`Data.Map` の `Map` などと同じで、内部表現を隠すことで、ライブラリ側が実装を変えても利用者のコードが壊れないようにします。
:::

代わりに、手順書を `Return`・`:>>=` の形に整えて見せる関数 `view` が用意されています。

```hs
view :: Program instr a -> ProgramView instr a

data ProgramView instr a where
    Return :: a -> ProgramView instr a
    (:>>=) :: instr b -> (b -> Program instr a) -> ProgramView instr a
```

`ProgramView` のコンストラクターは `Program` と同じ名前・同じ形ですが、こちらはパターンマッチに使えます。`view` を挟めば、あとは今までどおりインタープリターが書けます。

```hs
run :: Teletype a -> IO a
run p = case view p of
    Return a         -> return a
    PutLine s :>>= k -> putStrLn s >> run (k ())
    GetLine :>>= k   -> getLine >>= run . k
```

自作の `runIO` は `Return _` で結果を捨てて `IO ()` を返していましたが、動かす対象が `Teletype ()` の `greet` だけだったからです。ここでは `Return a` の値を取り出してそのまま結果として返すので、型は `IO a` になります。結果が `()` 以外の手順書にもそのまま使え、後述の `interpretWithMonad` とも型が揃います。

命令を 1 つずつ別のモナドへ変換する `interpretWithMonad` も用意されています。free パッケージの `foldFree` に相当します。👉[Freeモナド](https://zenn.dev/7shi/articles/20260808-haskell-free-monad#free-パッケージ)

```hs
import Control.Monad.Operational

interp :: TeletypeI a -> IO a
interp (PutLine s) = putStrLn s
interp GetLine     = getLine

main = do
    run greet
    interpretWithMonad interp greet
```
```text:実行結果（標準入力: alice、carol）
name?
Hello, alice!
name?
Hello, carol!
```

`interp` に型を書いてあるのには理由があります。`interpretWithMonad` の第 1 引数の型は次のようになっています。

```hs
interpretWithMonad :: Monad m => (forall a. instr a -> m a) -> Program instr b -> m b
```

手順書には `PutLine :: TeletypeI ()` と `GetLine :: TeletypeI String` のように、戻り値の型が違う命令が混ざります。変換する関数はそのどれにも使えなければならないので、`a` を 1 つに決めさせない `forall a.` が付いています。`runST` の型で出てきたのと同じ書き方です。👉[状態系モナド](https://qiita.com/7shi/items/2e9bff5d88302de1a9e9#forall)

型を書かずに `let` で定義して渡すと、`a` が 1 つに決め打ちされて型が合いません。`interp` のように型を明記すれば済みます。

:::message
`operational` は GHC に同梱されていないため、実行には導入が必要です。[Stack](https://docs.haskellstack.org/) を使う場合は次のように起動できます。

```
stack script --resolver lts-24.53 --package operational ファイル名.hs
```
:::

## 性能の注意

自作した `Program` は、`>>=` を左結合で重ねると遅くなります。Free と同じ現象です。

```hs
((yield 1 >> yield 2) >> yield 3) >> yield 4
```

`(i :>>= j) >>= k = i :>>= (\b -> j b >>= k)` は、左に積み上がった `>>=` を右へ倒す書き換えでした。左側の構造を 1 段剥がして継続を付け替えるので、左に積み上がっていると、後ろに 1 つ足すたびに先頭から辿り直すことになります。実測でも、左結合では要素数を 2 倍にすると時間が約 4 倍になる、二乗のオーダーが確認できました。`do` で素直に並べれば右結合になるので、通常は問題になりません。

パッケージの `Program` で同じ計測をすると、左結合でもほぼ線形のままです。内部表現が違うのはこのためで、`>>=` はその場で関数を合成せず、つないだ手順書をデータとして溜めておきます。そして `view` が 1 段求められるたびに、必要な分だけ右結合へ組み替えます。組み替えを後回しにすることで、先頭からの辿り直しが起きません。

# Free と Operational の使い分け

同じ「命令を組み立てて後から解釈する」枠組みの、2 つの表現です。

| |Free|Operational|
|---|---|---|
|継続のありか|命令の型の中（`next`）|`>>=` の側（関数）|
|命令の型への要求|`Functor` インスタンス|なし（GADT で戻り値の型を宣言）|
|必要な言語拡張|なし|GADTs|
|中身の検査|継続が値なら辿れる|インタープリターを通す以外に方法がない|

最後の行は `Show` のところで見たとおりです。前回 `print` で手順書の構造をそのままダンプできたのは、Free の継続が値だったからです。ただしこの違いは絶対ではなく、Free でも `GetLine` のように継続が関数の命令を含む手順書は、同じように中を見ることができません。

Free は再帰的なデータ構造そのものなので、木として扱いたい場合に向いています。Operational は命令の列挙が楽なので、DSL を手早く作るのに向いています。どちらが優れているということではなく、用途の違いです。

# まとめ

Operational モナドは、継続を命令の型から外して `>>=` の側に持たせた手順書でした。（Freer モナドもほぼ同じものです）

|Free|Operational|
|---|---|
|`data GenF o next = Yield o next deriving Functor`|`data GenI o a where Yield :: o -> GenI o ()`|
|継続は `next` の位置に埋め込む|継続は `>>=` 側が `b -> Program instr a` として持つ|
|`GetLine` の継続が関数になるのを自分で捌く|命令の戻り値の型を書くだけ|
|`liftF` で持ち上げる|`singleton` で持ち上げる|

`>>=` は継続の関数を合成するだけになり、`fmap` を使いません。だから命令の型に `Functor` インスタンスは要らず、前回手で書いた `instance Functor` がまるごと消えました。

代わりに必要になったのが GADTs です。各コンストラクターが戻り値の型を自分で宣言できるので、`GetLine :: TeletypeI String` のように、命令の結果の型を直接書けます。シリーズで初めて出てきた「それがないと表現できない」言語拡張でした。

組み立てと解釈の分離という枠組みは前回のままで、インタープリターの書き方も変わりませんでした。変わったのは手順書の表し方だけです。命令を並べて手順書にし、意味はインタープリターが与えます。操作的意味論から取られた Operational という名前は、この分担そのものを指していました。

手順書の中身を覗くには、`Show` を書いてもインタープリターを通す以外に方法がありませんでしたが、これは組み立てと解釈が分かれていることの裏返しでもあります。

# 参考

`operational` パッケージの作者である Heinrich Apfelmus 氏が、The Monad.Reader 誌のチュートリアル記事（2010 年）でこの方式を紹介しています。

https://apfelmus.nfshost.com/articles/operational-monad.html

Freer モナドは、拡張可能なエフェクト（extensible effects）の土台として使われています。

- Kiselyov, O., & Ishii, H. (2015). Freer monads, more extensible effects. In Proceedings of the 2015 ACM SIGPLAN Symposium on Haskell (pp. 94–105). ACM. https://doi.org/10.1145/2804302.2804319
