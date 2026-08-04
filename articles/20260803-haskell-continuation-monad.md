---
title: "Haskell 継続モナド 超入門"
emoji: "🔀"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "monad", "continuation"]
published: true
---

Haskell ではモナドと呼ばれる部品を組み合わせてプログラムを作ります。`>>=`（bind）の中に隠れている**継続**を取り出し、それを値として扱えるようにした**継続モナド**を説明します。継続を値として取り出せると何が嬉しいのかを、実際に動くジェネレーターの実装を通して示します。

:::message
本記事の執筆には Claude Code (Opus 5) を利用しました。
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
1. **Haskell 継続モナド 超入門** ← この記事
1. 【予定】Haskell 型クラス 超入門
1. 【予定】Haskell モナドとゆかいな仲間たち
1. 【予定】Haskell Free モナド 超入門
1. 【予定】Haskell Operational モナド 超入門
1. 【予定】Haskell Eff モナド 超入門
1. 【予定】Haskell アロー 超入門

# bind と継続

他の言語でもおなじみのパターンとして、処理が終わった後に呼ばれるコールバックがあります。

```js:Node.js のコールバック
readFile("input.txt", (contents) => {
    console.log(contents);
});
```

`readFile` は「読み終わったら何をするか」を表すコールバックを受け取ります。この「次にすること」を**継続**（continuation）と呼びます。

同じ形は Python の `with` にもあります。

```py:Python の with
with open("input.txt", "r") as f:
    contents = f.read()
    print(contents)
```

見た目はブロック構文ですが、`with` の本体は「ファイルを開いた後に何をするか」を表しています。ただし Python は本体を関数として渡すのではなく、構文としてその場に展開します。同じ役割を関数として明示的に受け取るのが Haskell の `withFile` です。

```hs:Haskell の withFile
withFile "input.txt" ReadMode $ \h -> do
    contents <- hGetContents h
    putStr contents
```

`withFile` はファイルを開き、そのハンドルをラムダに渡して、終わったら閉じます。`ReadMode` は読み込みモード、`hGetContents` はハンドルから内容を読み込む関数です。ここではラムダが継続にあたります。

`readFile`・`with`・`withFile` は、いずれも「続きに何をするか」を先に切り出している点で同じ形です。渡し方だけが違います。

ここで区別しておきたいのが、継続そのものと、継続の渡し方です。`readFile`・`withFile` は結果を返り値にせず、コールバックという形で継続を引数として受け取っています。このように継続を引数として渡すことを**継続渡し**（continuation-passing）、そのように書くスタイルを**CPS**（Continuation-Passing Style: 継続渡しスタイル）と呼びます。

## bind と CPS

Haskell の bind（`>>=`）も同じ構造を持っています。`m >>= k` の `k` は「`m` の結果を受け取って続きを行う関数」、つまり継続です。`k` を引数として受け取る bind は、まさに継続渡しの形をしています。

IO モナドなら「次に実行するアクション」、Maybe モナドなら「値があったときに続ける処理」、リストモナドなら「各要素に対して行う処理」が継続にあたります。モナドの種類が変わっても `k` が継続だという構図は変わりません。

bind が CPS の構造を持っていることを、最も単純なモナドである恒等モナド（`Identity`）で確認します。中に値が入っているだけのモナドです。👉[Haskell モナド変換子 超入門](https://qiita.com/7shi/items/4408b76624067c17e933)

```hs
import Control.Monad.Identity

calc = do
    x <- return 3
    return (x * 2)

main = print $ runIdentity calc
```
```text:実行結果
6
```

`do` 記法は `>>=` の連鎖の糖衣構文です。展開すれば次のようになります。👉[Haskell アクションとラムダ 超入門](https://qiita.com/7shi/items/4a8a2807bb5186576c61)

```hs
calc =
    return 3 >>= \x ->
    return (x * 2)
```

`return 3 >>= k` の `k` に相当する `\x -> return (x * 2)` が、`return 3` の後に続く継続です。

`Identity` の bind の定義を、この継続 `k` に注目して見てみます。

```hs
m >>= k = k (runIdentity m)
```

`runIdentity m` は `Identity` から値を取り出す操作です。取り出した値を `k` に渡すことで計算を進めています。継続を引数として受け取って呼ぶという構造は CPS と同じです。

# 継続モナド

`Identity` の bind では、継続 `k` はその場で呼ばれるだけです。これは bind の定義が決めているため、外から挙動を変える余地はありません。

そこで、値の代わりに `k` の呼び出しを含む CPS の関数、つまり「継続に値を渡す関数」をモナドの中身にすることを考えます。`k` の呼び出しが関数の中に閉じ込められるため、それをどのように呼ぶかをコード側が制御できるようになります。これが継続モナド `Cont` です。

```hs:定義（簡略化）
newtype Cont r a = Cont { runCont :: (a -> r) -> r }
```

* `r`: 最終的な結果の型
* `a`: 継続モナドの中に含まれる値の型
* `runCont`: 継続に値を渡す関数

使用するには `Control.Monad.Trans.Cont` を import します。

:::message
実際のライブラリでは `Cont` は `newtype` ではなく `type Cont r a = ContT r Identity a` という型シノニムで、`runCont` も `Identity` の出し入れを含んだ形で定義されています。ここでは本質を見やすくするため、`Identity` を省いた形で説明します。実際の定義は後述の[ContT モナド変換子](#contt-モナド変換子)の節で扱います。
:::

## runCont

```hs:型
runCont :: Cont r a -> (a -> r) -> r
```

`Identity` が中に値を持っていて `runIdentity` で取り出せるのに対して、`Cont` は中に次の関数を持っていて `runCont` で取り出せます。

```hs:Cont が持つ関数
(a -> r) -> r
```

これは継続 `a -> r` を受け取って、その継続にモナドから取り出した値を渡して、得られた結果を返す関数です。`runCont` の第 2 引数 `a -> r` がこの継続にあたり、bind の中で使われる継続 `k`（`a -> Cont r b`）とは型が異なります。

```hs
import Control.Monad.Trans.Cont

main = do
    let a = return 1 :: Cont Int Int
    print $ runCont a (+ 100)  -- 継続に1が渡される
```
```text:実行結果
101
```

`runIdentity` は中の値をそのまま返すだけですが、`runCont` は値をどう使うかという継続を渡さないと結果が得られません。値を受け取ってから使い方を決めるのではなく、使い方を先に渡しておく、という順序の違いです。

:::message
`runCont` の呼び出し自体は普通に `r` を返すので、値を継続の先でしか使えないという制約はありません。内部の実装が CPS の形をしているだけです。
:::

## evalCont

```hs:型
evalCont :: Cont r r -> r
```

継続に `id`（何もしない関数）を指定して値を取り出す関数です。

```hs
evalCont = (`runCont` id)
```

`Identity` の `runIdentity` と同じように使えます。

```hs
import Control.Monad.Identity
import Control.Monad.Trans.Cont

main = do
    print $ runIdentity (return 1 :: Identity Int)
    print $ evalCont    (return 1 :: Cont Int Int)
```
```text:実行結果
1
1
```

## cont

```hs:型
cont :: ((a -> r) -> r) -> Cont r a
```

`(a -> r) -> r` という型の関数から継続モナドを作る関数です。

中に `1` を含む継続モナドを作ってみます。

```hs
import Control.Monad.Trans.Cont

main = do
    let m1 = return 1             -- 1が入ったモナド
        m2 = cont $ \c -> c 1     -- m1と等価: 継続 -> 継続に1を渡す
    print $ evalCont m1
    print $ evalCont m2
```
```text:実行結果
1
1
```

## bind

```hs:実装
m >>= k = cont $ \c -> runCont m (\x -> runCont (k x) c)
```

`k` と `c` という 2 つの関数が現れます。どちらも継続と呼ばれますが、型が違うことに注意が必要です。

| | 型 | 中身 |
|---|---|---|
| `k`（bind に渡す関数） | `a -> Cont r b` | 続きの計算をモナドとして書いたもの |
| `c`（`runCont` が受け取る継続） | `b -> r` | 値を受け取るだけの素の関数 |

`k` の戻り値からモナドを取り除いたのが `\x -> runCont (k x) c` です。それで `runCont m c` の `c` を置き換えます。

1. `m` の評価: `runCont m c`
2. `m >>= k` の評価: `runCont m (\x -> runCont (k x) c)`

bind の時点ではどのような `c` が渡されるか未定なので、それをラムダの引数で受け取る構造になっています。👉[詳細 (JavaScript)](https://qiita.com/7shi/items/27b6f3169961299a6195)

`Identity` のように `k` を bind 時には呼ばないで、モナドの中に閉じ込めています。これによって、継続をどのように呼ぶかをコード側が制御できるようになります。

# callCC

bind が CPS の形をしているのは `Cont` に限らずすべてのモナドに共通する性質です。それでも `Cont` が「継続モナド」と呼ばれるのは、`k` の呼び出しが `\c -> ...` という関数の中に閉じ込められ、「ここから先の計算全体」を表す継続として保持されるためです。

この「継続を保持できる」性質を使って、今まさに実行中の継続を取り出すのが `callCC` です。

```hs:型
callCC :: ((a -> Cont r b) -> Cont r a) -> Cont r a
```

`callCC` 自体も CPS の形をしています。`callCC f` として関数 `f` を渡せば、`f` に引数として現在の継続 `a -> Cont r b` が渡されて呼び出されます。`f` の中でこの継続を呼び出せば、それ以降の処理を飛ばして `callCC` から抜けられます。

```hs
import Control.Monad (when)
import Control.Monad.Trans.Cont (evalCont, callCC)

f x = evalCont $ callCC $ \ret -> do
    when (x == 0) (ret "zero")
    return "non-zero"

main = do
    print $ f 0
    print $ f 1
```
```text:実行結果
"zero"
"non-zero"
```

`x == 0` のとき `ret "zero"` を呼べば、`return "non-zero"` には到達せず `"zero"` が結果になります。この動作がどのように実現されているのかを、以下で組み立てていきます。

## 実装

```hs
callCC f = cont $ \c -> runCont (f (\x -> cont $ \_ -> c x)) c
```

`f` と、`f` に引数として渡される `\x -> cont $ \_ -> c x` という 2 つの関数が現れます。どちらも継続ですが、指しているスコープが違います。`callCC f` をひとつのブロックと見れば、`f` はそのブロックの内側での継続です。一方 `f` の引数は、`callCC f` の後に続けられた、ブロックの外側での継続です。これが `ret` の正体で、呼び出すとブロックの外へ抜けます。

`ret` の中身の `\x -> cont $ \_ -> c x` は、自分自身に続く継続 `_` は捨てて、外側の継続 `c` に `x` を渡す関数です。そのため `ret` を呼んだ時点で計算が打ち切られ、`callCC` の外側にジャンプします。呼ばなければ `f` の本体はそのまま最後まで実行され、末尾の `c` が結果を受け取ります。

bind と `callCC` は互いに逆方向の型変換をしています。

| | 変換元 | 変換先 | 実装 |
|---|---|---|---|
| bind | `k :: a -> Cont r b` | `b -> r` | `\x -> runCont (k x) c` |
| `callCC` | `c :: a -> r` | `a -> Cont r b` | `\x -> cont $ \_ -> c x` |

bind は `k` の戻り値からモナドを剥がしていたのに対して、`callCC` は逆に `c` の戻り値をモナドで包んでいます。👉[詳細 (JavaScript)](https://qiita.com/7shi/items/27b6f3169961299a6195)

## 練習

【問1】次の `main` が実行結果の通りになるように、リストを先頭から見ていき負の数が現れたらそこで打ち切る関数 `sumUntilNegative :: [Int] -> Maybe Int` を `callCC` を使って実装してください。

```hs
main = do
    print $ sumUntilNegative [1, 2, 3]
    print $ sumUntilNegative [1, -2, 3]
```
```text:実行結果
Just 6
Nothing
```

:::details 解答例
```hs
import Control.Monad.Trans.Cont (evalCont, callCC)

sumUntilNegative :: [Int] -> Maybe Int
sumUntilNegative xs = evalCont $ callCC $ \ret -> go ret 0 xs
  where
    go _   acc []     = return (Just acc)
    go ret acc (x:rest)
        | x < 0     = ret Nothing
        | otherwise = go ret (acc + x) rest
```

負の数に出会った時点で `ret Nothing` を呼べば、それ以降の再帰（`go`）には進まずそのまま `Nothing` が返ります。
:::

# ジェネレーター

継続を保持できることが最もはっきり効いてくるのが、`k` を後で呼ぶ自由です。これを使えばジェネレーターが実装できます。

## 実装

Python や JavaScript のジェネレーターは、`yield` で値を 1 つ返してその場で中断し、呼び出し元が次を要求したら中断した位置から再開します。中断して呼び出し元まで戻るところは `callCC` による脱出と同じで、後から再開できるところが、継続を値として保持できることに対応します。

そのため中断のたびに、生成した値と、そこから再開するための継続を組にして呼び出し元へ渡します。もう値がないことも伝える必要があるため、「値と継続の組」か「終了」かの 2 択になります。これを直和型で表します。👉[Haskell 代数的データ型 超入門](http://qiita.com/7shi/items/1ce76bde464b4a55c143)

```hs
data Gen a = Yield a (Cont (Gen a) (Gen a)) | Done
```

`Yield` は生成した値と再開用の継続を持ち、`Done` は終了を表します。再開用の継続を評価すれば次の中断点まで進むので、そこでまた `Gen a` が返ります。そのため `Gen a` の定義の中に `Gen a` 自身が現れる再帰的な型になります。

```hs
import Control.Monad.Trans.Cont (Cont, evalCont, callCC)

data Gen a = Yield a (Cont (Gen a) (Gen a)) | Done

runGen body = evalCont $ callCC $ \ccOut -> body ccOut >> return Done
yield ccOut v = callCC $ \next -> ccOut (Yield v (next ()))
```

`runGen` は本体（`body`）を `callCC` で包み、脱出用の継続 `ccOut` を本体に渡します。途中で `ccOut` が呼ばれればその時点で `callCC` を抜け、最後まで走り切れば `return Done` に到達します。どちらの場合も結果は `Gen a` になり、`evalCont` で値を取り出します。継続モナドの結果の型 `r` が `Gen a` なのはこのためです。

`yield` には継続が 2 つ登場します。

| 継続 | 呼ぶと何が起きるか |
|---|---|
| `ccOut` | `runGen` の外へ抜ける（`callCC` で取り出した脱出用の継続）|
| `next` | `yield` の次の行から本体を再開する（`yield` 自身の現在の継続）|

`yield` はまず `callCC` で自分の現在の継続 `next` を取り出します。これが再開ポイントです。値を渡して再開させる作りではないため、`next ()` のように `()` を渡した形にして `Yield` に格納します。そうして値と再開用の継続を組にしたものを `ccOut` に渡すと、`runGen` の `callCC` を一気に抜けて、`Yield` がそのまま `runGen` の結果になります。

抜けるときに再開用の継続を一緒に持ち出すのがポイントです。抜けた後も継続は普通の値として手元に残るので、受け取った側は好きなタイミングでそれを `evalCont` で評価できます。評価すれば `yield` の次の行から本体が再開し、次の `yield` でまた `ccOut` が呼ばれて次の `Yield` が返ります。本体が終われば `return Done` に到達して `Done` が返ります。

`do` の中に `yield` を並べるだけで、他の言語のジェネレーターと同じ書き味になります。簡単な例を示します。

```hs:例
loop (Yield v next) = print v >> loop (evalCont next)
loop Done = return ()

gen = runGen $ \ccOut -> do
    yield ccOut 1
    yield ccOut 2
    yield ccOut 3

main = loop gen
```
```text:実行結果
1
2
3
```

取り出す側の `loop` は、`Yield` から値と継続を取り出し、値を表示してから継続を評価するのを `Done` が来るまで繰り返します。

ジェネレーターの利点は、値を全部作ってから渡すのではなく、必要になった時点で 1 つずつ生成できることです。ただし Haskell では、値が必要になるまで計算されない**遅延評価**のため、リストも同じ性質を持ちます。この例なら `[1, 2, 3]` と書けば済みますし、`[1 ..]` のような無限リストでも先頭から必要な分だけ計算されます。

つまり値を出すだけのジェネレーターは、Haskell ではリストで代用できます。ここで確認しているのは、継続を保持することで同じ動きが組み立てられるという点です。

## 何度でも再開できる

`Gen a` は純粋な値なので、同じ中断点から何度でも再開できます。

先ほどの `gen` と `loop` をそのまま使います。最初の 1 個だけ自分で取り出して、そのときの再開用の継続 `next` を保管しておきます。その先は `loop` に任せますが、取り出し終わった後で、保管しておいた `next` から改めて `loop` を掛けます。

```hs
main = do
    let Yield v next = gen  -- 最初の1個だけ取り出す
    print v
    loop (evalCont next)    -- 続きを最後まで
    loop (evalCont next)    -- 同じ中断点からもう一度
```
```text:実行結果
1
2
3
2
3
```

`callCC` で取り出した継続は普通の関数なので、何度でも呼べます。`loop` は継続を評価しながら最後まで進みますが、それによって `next` が変化することはありません。何度使っても消費されないため、2 回目も同じ中断点（`1` を `yield` した直後）から再開できます。そのため 2 回目は `2` から始まります。

:::message
JavaScript や Python のジェネレーターは消費すると元の状態が失われるため、これができません。👉[参考 (JavaScript)](https://qiita.com/7shi/items/6575cbb98c5a710a2945)

`Promise` も `resolve` を 2 回呼べないという点で同様です。👉[参考 (JavaScript)](https://qiita.com/7shi/items/a2bb35f27cd4a56f7bac)
:::

## 練習

【問2】次の `main` が実行結果の通りになるように、この節の `Gen a`・`runGen`・`yield`・`loop` を使って、`toList` の逆にあたる `fromList :: [a] -> Gen a` を実装してください。

```hs
main = loop (fromList [10, 20, 30])
```
```text:実行結果
10
20
30
```

:::details 解答例
```hs
fromList :: [a] -> Gen a
fromList xs = runGen $ \ccOut -> mapM_ (yield ccOut) xs
```

`mapM_ (yield ccOut) xs` でリストの各要素に `yield` を適用するだけで、`yield` が中断と再開を担ってくれます。
:::

# 限定継続

「継続を保持できる」ことの威力を `callCC` で確認してきましたが、`callCC` は継続を扱う唯一の方法ではありません。もう一つの道具である**限定継続**（delimited continuation）を導入し、ここまで作ったジェネレーターの実装がどう単純化されるかを確認します。

## 区切り

「継続を保持できる」と言っても、取り出した継続がどこまで届くかには制約があります。`callCC` で確認します。

```hs
main = do
    let r = evalCont $ callCC $ \ret -> do
            _ <- ret (1 :: Int)
            return 999           -- ここには来ない
    print r
    putStrLn "after"             -- 脱出はここまで飛べない
```
```text:実行結果
1
after
```

`ret` を呼んで `callCC` を脱出しても、`evalCont` の外側（`putStrLn "after"`）は必ず実行されます。bind で連結された `Cont` ひとつがひとまとまりの単位で、`evalCont` はその外側で結果を取り出すだけの関数だからです。

この「継続が届く範囲」の境界を**区切り**（delimiter）と呼びます。`Cont` では bind で連結された範囲ひとつ、`evalCont` の呼び出しがその境界にあたります。`callCC` で取り出した継続は、この区切りの中でしか意味を持ちません。

## shift/reset

区切りを明示的に作るのが `reset`、区切りまでの継続を値として取り出すのが `shift` です。どちらも `Control.Monad.Trans.Cont` に標準で用意されています。

```hs:型
reset :: Cont r r -> Cont r' r
shift :: ((a -> r) -> Cont r r) -> Cont r a
```

`reset e` は `e` をひとつの区切りにします。`shift f` は `f` に「`reset` までの継続」を関数として渡し、`f` の中でそれを呼び出せるようにします。

同じ形の式を `callCC` と `shift`/`reset` の両方で書き、挙動を比較します。

まず `callCC` です。

```hs
import Control.Monad.Trans.Cont (evalCont, callCC)

viaCallCC = evalCont $ do
    x <- callCC $ \ret -> do
        n <- ret 5
        return (2 + n)  -- 到達しない
    return (2 * (1 + x))

main = print viaCallCC
```
```text:実行結果
12
```

`ret 5` を呼ぶと `callCC` から即座に `5` が返り、`x` に `5` が入って `2 * (1 + 5)` が計算されて `12` になります。`ret 5` の継続である `return (2 + n)` は実行されません。

次に同じ形を `shift`・`reset` で書きます。

```hs
import Control.Monad.Trans.Cont (evalCont, reset, shift)

viaShift = evalCont $ reset $ do
    x <- shift $ \k -> do
        let n = k 5     -- k は素の値を返すので let で受けられる
        return (2 + n)  -- 到達する
    return (2 * (1 + x))

main = print viaShift
```
```text:実行結果
14
```

`callCC` の `ret` と同じく、`shift` の `k` もここで呼び出されます。ただし `ret` と違って、呼んだ時点で残りのコードが捨てられることはありません。呼んだ場所に戻ってきて `do` ブロックの続きがそのまま実行されます。`do` ブロックが（ふつうの関数のように）最後まで進むと、そこで得られた値がそのまま `shift` を抜けて区切り全体の値になります。

1. `k` には「`shift` の後に続くコード」、つまり戻り値の `x` への束縛と `return (2 * (1 + x))` が、`reset` の区切りの終端まであらかじめ 1 つの関数にまとめられて渡されます。`reset` の外側（呼び出し元やそれ以降のコード）は含まれません。渡された時点で完成した、ただの関数です。
2. `k 5` を呼ぶと、その関数がその場で実行されます。引数の `5` が `shift` の戻り値として `x` に束縛され、続けて `2 * (1 + 5)` が計算され、`12` という値が呼んだ場所にそのまま返ります。
3. `12` が `n` に束縛され、`do` ブロックが最後の `return (2 + n)` に到達して `14` になります。この値がそのまま区切り（`reset`）全体の値になります。

注意したいのは、`shift` の `do` ブロックを抜けた先が、テキスト上で外に書かれている `return (2 * (1 + x))` ではないことです。`shift` は本体を抜けると常に区切り（`reset`）へ直接抜けます。外側の続きが実行されるのは `k` を呼んだときだけで、この例では手順 2 の `k 5` の中で実行されています。手順 3 で本体を抜けた後にもう一度実行されることはありません。

`callCC` では `ret 5` の後に書いた `2 + n` の部分が捨てられて `12` になるのに対し、`shift` では `k 5` が呼んだ場所に戻ってくるため `2 + n` が生き残って `14` になります。

## 呼ぶ回数は自由

`shift` の `k` はただの関数として渡されるので、`f` の中で呼ぶかどうか、何回呼ぶかはコード次第です。

`k` を一度も呼ばなければ、外側の続きはそもそも実行されません。

```hs
noCall = evalCont $ reset $ do
    x <- shift $ \k -> return 999
    return (2 * (1 + x))
```
```text:実行結果
999
```

`f` が `999` を返すだけで `k` を呼ばなかったため、その `999` がそのまま区切り全体の値になります。`return (2 * (1 + x))` は `k` の中身として渡されているだけで、`k` を呼ばない限り実行されることはありません。

逆に `k` は呼べば戻ってくる普通の関数なので、同じ `k` を 2 回呼ぶこともできます。

```hs
twice = evalCont $ reset $ do
    x <- shift $ \k -> return (k 10 + k 20)
    return (x * 2)
```
```text:実行結果
60
```

`k 10` は `10 * 2`、`k 20` は `20 * 2` を返し、足して `60` になります。`callCC` の `ret` は呼べばその場で脱出するので、呼ばなければ本体が最後まで進むだけ、2 回書いても 2 回目には到達しません。呼ぶ回数で外側の続きを操作するという選択肢自体がありません。

### 実装

```hs
reset e = cont $ \k -> k (evalCont e)
shift f = cont $ \k -> evalCont (f k)
```

`reset e` は `evalCont e` で `e` を評価し切って値を取り出します。区切りの内側を先に「ただの値」まで還元してから、外側の継続 `k` に渡しています。

`shift f` では `cont $ \k -> ...` の `k` こそが「`reset` までの継続」です。`shift f` の後に続くコードは、bind によってこの `k` として `f` に渡されます。`f` の中で `k` を呼べば、呼んだ場所に結果が返ってくる普通の関数呼び出しとして働きます。呼ばなければ `evalCont (f k)` が `f` の結果をそのまま区切りの値として使います。

`callCC` の実装と並べると、対比がはっきりします。

| | 取り出す関数の型 | 呼んだときの挙動 |
|---|---|---|
| `callCC` の `ret` | `a -> Cont r b`（モナドに包まれる） | その場で `callCC` を脱出する |
| `shift` の `k` | `a -> r`（素の値を返す関数） | 呼び出した場所に戻り、結果を式の中で使える |

`callCC` の `ret` は「呼ぶと戻らない」関数として渡されるのに対し、`shift` の `k` は「呼べば戻ってくる」普通の関数として渡されます。

## ジェネレーターを shift/reset で書き直す

`shift`・`reset` を使うと、前節で組み立てたジェネレーターはもっと簡単に書けます。

```hs
import Control.Monad.Trans.Cont (Cont, evalCont, reset, shift)

data Gen a = Yield a (Cont (Gen a) (Gen a)) | Done

runGen body = evalCont $ reset (body >> return Done)
yield v = shift $ \next -> return (Yield v (return (next ())))

loop (Yield v next) = print v >> loop (evalCont next)
loop Done = return ()

gen = runGen $ do
    yield 1
    yield 2
    yield 3

main = loop gen
```
```text:実行結果
1
2
3
```

`Gen` と `loop` は `callCC` 版と同じもので、結果も一致します。違うのは `yield`・`runGen` と、`ccOut` が消えた本体だけです。

`callCC` 版では脱出継続 `ccOut` を `yield` と `runGen` の間で引き回す必要がありましたが、`shift` は呼び出し元まで戻るのでその引き回しが要りません。`yield` から引数が 1 つ消えています。👉[参考 (Scheme)](https://qiita.com/7shi/items/6db3e19ddc1f8552d9a0)

## 共通部品としての限定継続

`shift`・`reset` は抽象的な道具で、それが何を可能にするのか定義だけからは掴みにくいものです。その具体的な応用例がジェネレーターです。多くの言語が処理系の専用構文として組み込んでいるジェネレーターが、限定継続を土台にすれば数行で書けます。

Python や JavaScript の `yield` は「関数の途中で止まり、呼び出し元へ値を返し、後で同じ場所から再開する」という動きをします。「`yield` から関数の終わりまでの残り」を保留したまま呼び出し元へ抜け、後からその続きを再開する、という点で `shift` と対応します。保留される範囲がその関数の中に収まる点も、`reset` の区切りと同じ構図です。`await` から先を後で再開する async/await も同じ構図です。👉[参考 (JavaScript)](https://qiita.com/7shi/items/a2bb35f27cd4a56f7bac)

対応するのはあくまで振る舞いで、実現方法までは同じとは限りません。処理系が中断した実行状態をそのまま保持する形で実装することも、状態機械へ変換することもあり、いずれにせよ継続が第一級の値として手に入るとは限りません。言語組み込みのジェネレーターが同じ中断点から一度しか再開できないのは、この違いによるものです。

つまり限定継続は、各言語が個別の構文として作り込んできたこれらの機能を、共通の部品として取り出したものだと言えます。専用構文は書きやすい代わりに処理系が決めた使い方しかできませんが、部品として持っていれば `Gen` のような型も再開の仕方も自分で決められます。何度でも再開できるジェネレーターが書けたのは、その一例です。

## 練習

【問3】次の `main` が実行結果の通りになるように、問2の `fromList` を、この節の `shift`/`reset` 版の `runGen`・`yield` を使って書き直してください。

```hs
main = loop (fromList [10, 20, 30])
```
```text:実行結果
10
20
30
```

:::details 解答例
```hs
fromList :: [a] -> Gen a
fromList xs = runGen $ mapM_ yield xs
```

`yield` から `ccOut` の引数が消えたことで、`fromList` 側も `mapM_ (yield ccOut) xs` から `mapM_ yield xs` へと単純になります。
:::

# リソース管理

ここまでは原理を通すことを優先してきましたが、継続モナドは実用でも使われています。ここで実用面を回収します。

対象はファイルなどのリソースを扱う `withFile` で、IO が絡みます。ここまで使ってきた `Cont` のままでは IO を扱えないため、まず継続モナドのモナド変換子を導入します。👉[Haskell モナド変換子 超入門](https://qiita.com/7shi/items/4408b76624067c17e933)

## ContT モナド変換子

```hs:定義
newtype ContT r m a = ContT { runContT :: (a -> m r) -> m r }
```

`Cont r a` に対して `m` が増えています。`Cont` が持っていた関数 `(a -> r) -> r` は、`m` が挟まって `(a -> m r) -> m r` になります。出し入れする関数も `T` が付いた版を使います。

| `Cont` | `ContT` | `ContT` 版の型 |
|---|---|---|
| `runCont` | `runContT` | `ContT r m a -> (a -> m r) -> m r` |
| `cont` | `ContT` | `((a -> m r) -> m r) -> ContT r m a` |
| `evalCont` | `evalContT` | `ContT r m r -> m r` |

包むのは `cont` に相当する関数ではなく、`ContT` というコンストラクタそのものです。また `evalCont` が継続に `id` を渡すのに対して、`evalContT` は `return` を渡します。

`State` と `StateT` の関係と同じく、`m` に何もしない `Identity` を指定して変換子を無効化したものが `Cont` です。

```hs:定義
type Cont r a = ContT r Identity a
```

`m` に `IO` を指定した `ContT r IO` が、以下で使うモナドです。IO アクションは `liftIO` で持ち上げます。

以下のコードは共通して次の import を前提とします。`ContT` をコンストラクタとして使うため `(..)` が必要です。

```hs
import Control.Monad.Trans.Cont (ContT (..), evalContT, callCC)
import Control.Monad.IO.Class (liftIO)
import System.IO
```

## withFile と ContT の型が一致

冒頭で継続の例として挙げた `withFile` に戻ります。

2 つのファイルを開いて中身をコピーする処理を考えます。`withFile` をネストして書くと以下のようになります。

```hs:ネスト
copyFile src dest =
    withFile src ReadMode $ \hSrc ->
        withFile dest WriteMode $ \hDest -> do
            content <- hGetContents hSrc
            hPutStr hDest content

main = copyFile "a.txt" "b.txt"
```

`withFile path mode` を部分適用すれば `(Handle -> IO r) -> IO r` という型になります。これは `ContT r IO Handle` が `runContT` として持つ関数そのもののため、`ContT` で包むことができます。

これによって、ネストしていた `with` 系の呼び出しが `do` の中ではフラットになります。

```hs:ContT でフラット化
copyFile src dest = evalContT $ do
    hSrc  <- ContT $ withFile src  ReadMode
    hDest <- ContT $ withFile dest WriteMode
    content <- liftIO $ hGetContents hSrc
    liftIO $ hPutStr hDest content

main = copyFile "a.txt" "b.txt"
```

見た目がフラットになっても、`withFile` がラムダを包んでいる構造は変わりません。`hSrc` 以降の行はすべて `withFile src ReadMode` に渡されたラムダの中身なので、`do` ブロックを抜けるときにハンドルは確実に解放されます。いわゆる RAII（Resource Acquisition Is Initialization）です。

:::message
Python の `with` を `@contextmanager` で書くと、`yield` の位置で `with` の本体（＝継続）が実行されます。ここまで作ってきたジェネレーターの `yield` と原理的には同じ仕組みで、ジェネレーターとリソース管理が密接に関係することが見て取れます。
:::

## forM

ファイルを 1 つコピーするだけならネストのままでも大差ありませんが、複数のファイルを開こうとすると差が出ます。`with` 系のままではリストに対する明示的な再帰が必要になりますが、`ContT` なら `forM` が使えます。

```hs
import Control.Monad (forM, forM_)

openAll paths = forM paths $ \p -> ContT $ withFile p ReadMode

main = evalContT $ do
    hs <- openAll ["a.txt", "b.txt", "c.txt"]
    liftIO $ forM_ hs $ \h -> hGetContents h >>= putStr
```

:::message
`forM` と `forM_` の違いは、`forM` は結果をリストとして返すのに対し、`forM_` は結果を返さずにアクションだけを実行する点です。ここではハンドルのリストを取得するために `forM` を使っています。👉[Haskell アクションとラムダ 超入門](http://qiita.com/7shi/items/4a8a2807bb5186576c61)
:::

## 解放の順序と注意点

解放の順序を確かめるため、取得と解放をログ出力する疑似リソース `withRes` を用意します。`withFile` と同じく、本体を受け取って前後を挟む形です（具体的な実装は、後の練習問題4で扱います）。

```hs
main = evalContT $ do
    a <- ContT $ withRes "A"
    b <- ContT $ withRes "B"
    liftIO $ putStrLn $ "use " ++ a ++ b
```
```text:実行結果
open A
open B
use AB
close B
close A
```

解放は取得の逆順（LIFO）になり、ネストで書いた場合と同じ順序です。

:::message
この `withRes` は順序を見るためのもので、例外時の解放は考えていません。実際の `withFile` は `Control.Exception` の `bracket` を使っており、本体が例外で終わっても解放されます。
:::

`callCC` で途中脱出しても、後片付けはきちんと走ります。

```hs
escape = evalContT $ callCC $ \ret -> do
    a <- ContT $ withRes "A"
    liftIO $ putStrLn $ "use " ++ a
    ret ()                           -- ここで脱出
    b <- ContT $ withRes "B"         -- 実行されない
    liftIO $ putStrLn $ "use " ++ b

main = escape >> putStrLn "done"
```
```text:実行結果
open A
use A
close A
done
```

脱出以降で取得するはずだったリソース（B）はそもそも取得されないため、A の解放だけがきちんと走ります。

注意点として、`hGetContents` の結果を `ContT` の外へ持ち出すと、ハンドルが閉じた後に読むことになってエラーになります。

```hs
main = do
    content <- evalContT $ do
        h <- ContT $ withFile "a.txt" ReadMode
        liftIO $ hGetContents h  -- 遅延読み込みなのでまだ読んでいない
    putStr content               -- 読むのはここ（ハンドルは閉じた後）
```
```text:実行結果（エラー）
a.txt: hGetContents: illegal operation (delayed read on closed handle)
```

`ContT` を抜ける前に読み切ってしまえば、後は普通の文字列として扱えます。`hGetContents'` は最後まで読んでから返す正格版です。

```hs
main = do
    content <- evalContT $ do
        h <- ContT $ withFile "a.txt" ReadMode
        liftIO $ hGetContents' h  -- 読み切ってから返す
    putStr content
```

:::message
`hGetContents'` は base 4.15（GHC 9.0）以降で使えます。それより古い環境では、`evaluate` で式をその場で評価して読み切る必要があります。👉[Haskell 例外処理 超入門](https://qiita.com/7shi/items/73e534c47bbebc71b37e)

```hs
main = do
    content <- evalContT $ do
        h <- ContT $ withFile "a.txt" ReadMode
        s <- liftIO $ hGetContents h
        liftIO $ evaluate (length s)  -- ここで読み切る
        return s
    putStr content
```
:::

`with` 系全般に共通する罠ですが、`ContT` では「どこでリソースが閉じるか」が `do` の見た目から消えるため、特に踏みやすくなっています。

## 練習

【問4】この節で実装を伏せてきた `withRes` を実装してください。取得・解放をログ出力する疑似リソースで、`ContT` で3つ以上ネストしたときも解放が取得の逆順（LIFO）になります。次の `main` が実行結果の通りになることを確認してください。

```hs
main = evalContT $ do
    a <- ContT $ withRes "A"
    b <- ContT $ withRes "B"
    c <- ContT $ withRes "C"
    liftIO $ putStrLn $ "use " ++ a ++ b ++ c
```
```text:実行結果
open A
open B
open C
use ABC
close C
close B
close A
```

:::details 解答例
```hs
withRes name body = do
    putStrLn $ "open " ++ name
    r <- body name
    putStrLn $ "close " ++ name
    return r
```

`ContT` で3つ包んだだけですが、解放は `with` 系をネストして書いた場合と同じく取得の逆順（C → B → A）になります。
:::

# まとめ

`m >>= k` の `k` という、これまで `>>=` の中に隠れていた継続を、`Cont r a` というモナドの中に保持できる値として取り出しました。取り出した継続は `callCC` の `ret` のようにその場で呼んで脱出することも、後から呼ぶこともできます。後者の応用がジェネレーターです。

そのジェネレーターは、値を出すだけならリストでも書けるものです。そしてリストと同じく `Gen a` も純粋な値なので、消費されることなく同じ中断点から何度でも再開できます。一度消費すると元の状態が失われる他言語のジェネレーターとは、ここが違います。

限定継続として `shift`・`reset` を導入しました。`reset` で区切りを明示でき、`shift` の `k` は呼べば戻ってくる普通の関数なので、呼ぶかどうかも回数もコード側で決められます。これを使えば脱出継続の引き回しが不要になり、同じジェネレーターがより簡潔に書けました。

最後に見た `ContT` によるリソース管理は、原理としては同じ仕組みが実用の場面でどう使われているかの実例です。

# 参考

`ContT` によるリソース管理について、以下の記事を参考にしました。

https://qiita.com/tanakh/items/81fc1a0d9ae0af3865cb

https://qiita.com/sparklingbaby/items/2eacabb4be93b9b64755
