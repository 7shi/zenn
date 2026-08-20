---
title: "Haskell Freeモナド 超入門"
emoji: "🌲"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "モナド"]
published: true
---

Free モナドは bind に意味を与えず、命令をデータとしてつなぐだけのモナドです。組み立てた手順書は後からインタープリターで解釈します。木構造の一般化として導入し、ジェネレーターなどを例に説明します。

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
1. [Haskell 継続モナド 超入門](https://zenn.dev/7shi/articles/20260803-haskell-continuation-monad)
1. [Haskell 型クラス 超入門](https://zenn.dev/7shi/articles/20260805-haskell-type-classes)
1. [Haskell モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends)
1. **Haskell Freeモナド 超入門** ← この記事
1. [Haskell Operationalモナド 超入門](https://zenn.dev/7shi/articles/20260809-haskell-operational-monad)
1. [Haskell Effモナド 超入門](https://zenn.dev/7shi/articles/20260811-haskell-eff-monad)
1. [Haskell アロー 超入門](https://zenn.dev/7shi/articles/20260813-haskell-arrow)
1. [Haskell 圏論 超入門](https://zenn.dev/7shi/articles/20260820-haskell-category-theory)

# 木構造を一般化する

Free モナドは、既に書いたことのあるコードの中に隠れています。まずそれを見つけるところから始めます。

データ構造そのものをモナドにすることができます。葉に値が入っている二分木です。👉[モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends#tree)

```hs
data Tree a = Leaf a | Node (Tree a) (Tree a)

instance Monad Tree where
    Leaf x   >>= f = f x
    Node l r >>= f = Node (l >>= f) (r >>= f)
```

`>>=` は「それぞれの葉を、別の木に差し替える」操作です。接ぎ木だと思ってください。

枝が 2 本固定ではなくリストになった多分岐の木でも、同じことができます。

```hs
data Rose a = Leaf a | Node [Rose a]

instance Monad Rose where
    Leaf x  >>= f = f x
    Node ts >>= f = Node (map (>>= f) ts)
```

2 つの `>>=` を並べます。

```hs
Leaf x   >>= f = f x                        -- Tree
Node l r >>= f = Node (l >>= f) (r >>= f)

Leaf x  >>= f = f x                         -- Rose
Node ts >>= f = Node (map (>>= f) ts)
```

葉の行は完全に同じです。違うのは枝の行だけで、それも「枝が抱えている木のそれぞれに `>>= f` を適用して、元の形に戻す」という同じことを、2 つ組とリストという別の入れ物に対して書いているだけです。

そして「中身のそれぞれに関数を適用して、元の形に戻す」のは `fmap` の仕事です。

## 枝の形をくくり出す

枝が木を抱える形だけを、型として抜き出します。`Tree` の枝は木を 2 つ持つので、次の型になります。

```hs
data Two x = Two x x
```

`Rose` の枝は木をリストで持ちます。リスト `[]` は最初から「型を 1 つ受け取る入れ物」なので、`Two` にあたる型を新しく定義する必要はなく、そのまま使えます。

これを使って 2 つの木を書き直すと、枝が「入れ物 1 つ」に揃います。

```hs
data Tree a = Leaf a | Node (Two (Tree a))
data Rose a = Leaf a | Node [Rose a]
```

`[Rose a]` は `[]` に `Rose a` を入れた形で、`Two (Tree a)` と同じ構造です。リストだけは `[] (Rose a)` とは書けないので見た目が揃いませんが、やっていることは同じです。

違いは `Two` と `[]` だけになりました。抜き出した「枝の形」を型引数 `f` にして、木を定義し直します。

```hs
data Free f a = Pure a | Free (f (Free f a))
```

コンストラクターが 2 つあるところは元の木と同じです。`Pure` が値を 1 つ持つ葉、`Free` が `f` という形で木を抱える枝です。`f` に `Two` や `[]` を入れると、元の木の枝に戻ります。

||`Free`|`f = Two`|`f = []`|
|---|---|---|---|
|葉|`Pure a`|`Pure a`|`Pure a`|
|枝|`Free (f (Free f a))`|`Free (Two (Free Two a))`|`Free [Free [] a]`|

値の側も含めて対応をまとめます。

|元の型|`Free` での書き方|
|---|---|
|`Tree a`|`Free Two a`|
|`Rose a`|`Free [] a`|
|`Leaf x`|`Pure x`|
|`Node l r`|`Free (Two l r)`|
|`Node ts`|`Free ts`|

枝の形が違うだけで、木としての骨組みは同じでした。その「枝の形」を型引数にくくり出したものが `Free` です。これが Free モナドの正体です。

## 種

`f` に入るのは `Two` や `[]` で、単独では型にならず、型を 1 つ受け取って初めて型になります。この「型の型」を**種**（kind）と呼びます。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#型引数を取る型クラス)

GHCi の `:k` で確認します。

```hs:GHCi
ghci> :k Two
Two :: * -> *
ghci> :k Free
Free :: (* -> *) -> * -> *
ghci> :k Free Two
Free Two :: * -> *
ghci> :k Free Two Int
Free Two Int :: *
```

`Free` は `(* -> *)` を 1 つと `*` を 1 つ受け取ります。1 つ目が枝の形、2 つ目が葉に入る値の型です。`Free Two` まで与えると `* -> *` になり、`Monad` のインスタンスにできる種になります。

:::message
`Two` はタプルで済ませられそうにも見えますが、タプルは左右で別々の型が指定できるため、型変数を 2 つ取ります。

```hs:GHCi
ghci> :k (,)
(,) :: * -> * -> *
```

`Two` に求められる `* -> *` とは種が違うので、そのままでは `f` に入りません。「左右が同じ型」という制約はタプルには書けないため、自分で定義する必要があります。
:::

## インスタンス

`Monad` を実装します。`>>=` さえ書けば `fmap` は `liftM`、`<*>` は `ap` で埋まる定型が使えます。👉[モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends#3-段まとめて書く定型)

```hs
import Control.Monad (liftM, ap)

data Free f a = Pure a | Free (f (Free f a))

instance Functor f => Functor (Free f) where
    fmap = liftM

instance Functor f => Applicative (Free f) where
    pure  = Pure
    (<*>) = ap

instance Functor f => Monad (Free f) where
    Pure a >>= k = k a
    Free g >>= k = Free (fmap (>>= k) g)
```

`>>=` は 2 行です。元の木の `>>=` と見比べてください。

* `Pure a >>= k = k a` — 葉に来たら、その値を `k` に渡して得られた木で置き換える
* `Free g >>= k = Free (fmap (>>= k) g)` — 枝は `fmap` で中の木それぞれを辿る

`Tree` では左右を個別に書き、`Rose` では `map` で書いていたところが、`fmap` の 1 行にまとまりました。

その `fmap` は、枝の形 `f` に対して呼んでいます。つまり `f` が `Functor` のインスタンスでなければ、この行は書けません。そのため `instance` に `Functor f =>` という制約が付いています。`instance` 側に型クラス制約を書けることは既に見た通りです。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#instance-側の制約)

逆に言えば、`Functor` が必要になるのはこの 1 か所だけです。Free モナドが枝の形に求めるのは「辿れること」だけで、それが `Functor` という形で現れています。

## 動かす

`Free Two` で木を組み立てて、元の `Tree` と同じことができるのを確認します。

`Two` の `Functor` インスタンスを書き、葉と枝を作る関数に名前を付けます。木の形を見るために、葉を値、枝を括弧で表示する `Show` インスタンスも書きます。上の `Free` の定義に続けて書きます。

```hs
data Two x = Two x x

instance Functor Two where
    fmap f (Two l r) = Two (f l) (f r)

type Tree = Free Two

instance Show a => Show (Tree a) where
    show (Pure a)         = show a
    show (Free (Two l r)) = "(" ++ show l ++ " " ++ show r ++ ")"

leaf :: a -> Tree a
leaf = Pure

node :: Tree a -> Tree a -> Tree a
node l r = Free (Two l r)

grow x = node (leaf x) (leaf (x * 10))

main = do
    let t = node (leaf 1) (leaf 2)
    print t
    print $ fmap (* 2) t
    print $ t >>= grow
```
```text:実行結果
(1 2)
(2 4)
((1 10) (2 20))
```

`grow` は葉の値 `x` を `x` と `x * 10` の 2 枚の葉に育てる関数です。`t >>= grow` で 2 枚の葉がそれぞれ育ち、その場所に小さな木が挿さっています。接ぎ木がそのまま動いています。

表示は `Show` インスタンスを手で書きました。`Free f a` に `deriving Show` は付けられません。中身を表示するには `f (Free f a)` が `Show` であることが必要ですが、`f` が型変数のままなので、その条件を `deriving` で書けないためです。`Free Two` のように `f` を固定すれば条件が決まるので、上のように `instance` を書けます。

`show` は本来、`read` で読み戻せる Haskell の式を返すのが建前です。`(1 2)` はそうなっていません。ここでは木の形が見やすいことを優先して、表示専用の形式にしています。

:::message
`Free Two a` のように型を固定した `instance` は、GHC2021 では書けますが、それ以前の標準（Haskell2010）では `FlexibleInstances` という言語拡張が必要となります。言語拡張はソースの先頭に `{-# LANGUAGE ~ #-}` と書きます。👉[IOモナド](https://qiita.com/7shi/items/d3d3492ddd90d47160f2#アンボックス化タプル)

```hs
{-# LANGUAGE FlexibleInstances #-}
```
:::

`f` を `[]` に替えれば多分岐の木になります。`Free` と `Pure` をそのまま使うので、専用のコンストラクターは不要です。

```hs
type Rose = Free []

instance Show a => Show (Rose a) where
    show (Pure a)  = show a
    show (Free ts) = "[" ++ unwords (map show ts) ++ "]"

grow x = Free [Pure x, Pure (x * 10)]

main = do
    let r = Free [Pure 1, Free [Pure 2, Pure 3]]
    print r
    print $ r >>= grow
```
```text:実行結果
[1 [2 3]]
[[1 10] [[2 20] [3 30]]]
```

`Functor` インスタンスは 1 行も書き足していません。`[]` は最初から `Functor` なので、`Free []` はそれだけでモナドになります。書き足したのは表示のための `Show` だけです。

## 練習

【問1】自作した `Tree`（`Leaf`・`Node`）と `Free Two` が本当に同じものか、両方で同じ木を組み立てて `>>=` と `fmap` の結果を見比べてください。`Tree` の `Show` インスタンスを本文の `Free Two` 版と同じ形式で書けば、表示が揃って直接比べられます。

```hs
data Tree a = Leaf a | Node (Tree a) (Tree a)

instance Show a => Show (Tree a) where
    show = undefined  -- ここを書く

-- Tree 側
grow :: Int -> Tree Int
grow x = Node (Leaf x) (Leaf (x * 10))

-- Free Two 側
grow' :: Int -> Free Two Int
grow' x = Free (Two (Pure x) (Pure (x * 10)))

main = do
    let t  = Node (Leaf 1) (Leaf 2)
        t' = Free (Two (Pure 1) (Pure 2))
    print $ t  >>= grow
    print $ t' >>= grow'
    print $ fmap (* 2) t
    print $ fmap (* 2) t'
```
```text:実行結果
((1 10) (2 20))
((1 10) (2 20))
(2 4)
(2 4)
```

:::details 解答例
```hs
instance Show a => Show (Tree a) where
    show (Leaf a)   = show a
    show (Node l r) = "(" ++ show l ++ " " ++ show r ++ ")"
```

本文の `Free Two` 版と見比べてください。`Pure a` が `Leaf a` に、`Free (Two l r)` が `Node l r` に変わっただけで、右辺は同じです。パターンの名前が違うだけで、書くことがありません。

表示が一致するということは、`>>=` も `fmap` も同じ木を組み立てているということです。`Free Two` は `Tree` の別名でした。
:::

# 手順書を組み立てる

ここまで `f` は「枝の形」でした。ここで読み替えを行います。

`f` を命令の型だと思うと、`Free f a` は命令を並べたデータになります。枝が抱えていたのは「子の木」でしたが、命令だと思えば、それは「その命令の後に続く手順」です。木を辿ることが、手順を順に実行することに対応します。

この読み替えが Free モナドの使いどころです。題材としてジェネレーターを作ります。

## 命令の型

ジェネレーターは、値を 1 つ出してその場で中断し、呼び出し元が次を要求したら中断した位置から再開する仕組みです。継続モナドでは、中断した時点の「続き」を継続として取り出し、出力する値と組にして持ち出すことで実現しました。👉[継続モナド](https://zenn.dev/7shi/articles/20260803-haskell-continuation-monad#ジェネレーター)

Free モナドでは、継続を取り出す仕組みは不要です。命令の型に置き場所を作っておけば、そこに継続が入ります。

```hs
data GenF o next = Yield o next
```

`Yield` は値を 1 つ出す命令です。`o` が出力する値の型、`next` が継続です。`Free (GenF o) a` の形で使うと、`next` の位置に後続の手順が入ります。

## Functor インスタンス

`Free` の `>>=` が `fmap` を使うので、`GenF o` を `Functor` にします。

```hs
instance Functor (GenF o) where
    fmap f (Yield o next) = Yield o (f next)
```

`fmap` が触るのは `next` だけです。出力する値 `o` は型引数の位置が違うので、そのまま残ります。`instance` に指定したのが `(GenF o)` になっているのがその理由です。`Functor` にできるのは種が `* -> *` の型だけで、`GenF` は種が 1 つ多いため、そのままではインスタンスにできません。

```hs:GHCi
ghci> :k GenF
GenF :: * -> * -> *
ghci> :k GenF Int
GenF Int :: * -> *
```

`o` を埋めて `* -> *` に揃えると、残る型引数は最後の `next` だけになります。同じことは標準の型でも起きていて、`Either e a` のインスタンスは `Functor (Either e)` なので、`fmap` は `Right` 側にしか効きません。

つまり `Functor` にしたい対象を最後の型引数に置くよう、`GenF o next` の順序を決めてあるということです。作用する対象がこうして型から機械的に決まるため、`Functor` には `deriving` が使えます。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#deriving)

```hs
data GenF o next = Yield o next deriving Functor
```

これで `instance Functor` の 2 行が消えます。標準の `deriving` は 6 種類に限られていましたが、言語拡張で対象を増やせるということです。`Functor` を対象に加えるのは `DeriveFunctor` という言語拡張で、GHC2021 では既定で有効になっています。

:::message
Haskell2010 で試すときは `DeriveFunctor` を明示的に有効にします。

```hs
{-# LANGUAGE DeriveFunctor #-}
```
:::

## liftF

命令 1 つを `Free` の値に持ち上げる関数を用意します。

```hs
liftF :: Functor f => f a -> Free f a
liftF c = Free (fmap Pure c)
```

`c = Yield 1 ()` としたときの変化を追います。

```hs
c                  = Yield 1 ()
fmap Pure c        = Yield 1 (Pure ())
Free (fmap Pure c) = Free (Yield 1 (Pure ()))
```

継続の位置にあった `()` が葉 `Pure ()` に変わり、それを `Free` で包んで木になりました。「1 を出して終わり」という 1 命令の手順書です。

`Pure` で包みたい値は命令の中にあるので、直接は適用できません。そのために `fmap` で中まで届かせています。`Free` が受け取れるのは継続の位置に木が入った命令だけなので、先にその形へ整えてから被せる、という順序です。

これを使って、コンストラクターを直接使う代わりの窓口となる関数を用意します。このように使いやすい形に整えて公開する関数を**スマートコンストラクター**と呼びます。

```hs
type Gen o = Free (GenF o)

yield :: o -> Gen o ()
yield x = liftF (Yield x ())
```

`Yield x ()` の `()` は継続の位置に置いた仮の値です。`liftF` がこれを `Pure ()` に変えるので、`yield x` は「`x` を出して終わり」という 1 命令の手順書になります。

## 手順書を書く

ここまで来ると `do` が使えます。

```hs
count :: Gen Int ()
count = do
    yield 1
    yield 2
    yield 3
```

この `count` は何もしません。`do` で書いてあっても実行されるわけではなく、正体はただのデータです。それを確かめるため、`Tree` のときと同じように `Show` インスタンスを書いて中身を覗きます。コンストラクターと同じ表記を出力する形にします。

```hs
instance (Show o, Show a) => Show (Gen o a) where
    show (Pure a)           = "Pure " ++ show a
    show (Free (Yield o k)) = "Free (Yield " ++ show o ++ " (" ++ show k ++ "))"

main = print count
```
```text:実行結果
Free (Yield 1 (Free (Yield 2 (Free (Yield 3 (Pure ()))))))
```

`>>=` が命令をつないだ結果、`Yield` が 3 つ数珠つなぎになり、最後が `Pure ()` で終わっています。`do` で書いた 3 行が、そのまま木として組み上がっていたということです。

無限の手順書も組めます。組むだけなら終わらないということはありません。

```hs
nats :: Gen Int ()
nats = mapM_ yield [0 ..]
```

:::message
`print nats` を試すと無限ループになります。組み立てはデータを作るだけなので終わりますが、`show` は木を最後まで辿ろうとするため、`Pure` に到達しない `nats` では止まりません。
:::

`mapM_` が使えるのは、`Gen o` が `Monad` のインスタンスだからです。モナドを自作すると `Monad` を要求する既存の関数がそのまま使えます。

ここまでで組み立ては完了ですが、まだ何の意味も与えていません。意味を与えるのは次の節です。

# インタープリター

組み上がった手順書を辿って、実際の処理に変換する関数を**インタープリター**と呼びます。

`Yield` の値を集めてリストにするインタープリターを書きます。

```hs
toList :: Gen o a -> [o]
toList (Pure _)           = []
toList (Free (Yield o k)) = o : toList k
```

* `Pure _` は手順書の終わりなので、空リスト
* `Free (Yield o k)` は「`o` を出して、継続は `k`」なので、`o` を先頭に付けて `k` を辿る

これは `count` の中身を覗くために書いた `show` と同じパターンです。`Pure` と `Free` で場合分けし、`Free` の中を辿って 1 つの値にまとめています。違うのはまとめ方だけで、文字列を作れば表示、リストを作ればインタープリターになります。特別な仕組みではなく、木を辿る関数に意味づけを載せたものです。

## ジェネレーターの全体

ここまでのコードをまとめます。

```hs
liftF :: Functor f => f a -> Free f a
liftF c = Free (fmap Pure c)

data GenF o next = Yield o next deriving Functor

type Gen o = Free (GenF o)

instance (Show o, Show a) => Show (Gen o a) where
    show (Pure a)           = "Pure " ++ show a
    show (Free (Yield o k)) = "Free (Yield " ++ show o ++ " (" ++ show k ++ "))"

yield :: o -> Gen o ()
yield x = liftF (Yield x ())

count :: Gen Int ()
count = do
    yield 1
    yield 2
    yield 3

nats :: Gen Int ()
nats = mapM_ yield [0 ..]

toList :: Gen o a -> [o]
toList (Pure _)           = []
toList (Free (Yield o k)) = o : toList k

main = do
    print count
    print $ toList count
    print $ take 5 $ toList nats
```
```text:実行結果
Free (Yield 1 (Free (Yield 2 (Free (Yield 3 (Pure ()))))))
[1,2,3]
[0,1,2,3,4]
```

1 行目が `count` の中身で、手順書がデータである以上、こうして覗けます。この `Show` インスタンスも `Pure` と `Free` を辿るだけなので、`toList` と同じ形をしています。

無限の手順書 `nats` にも `take 5` が効いています。`toList` は先頭から必要な分だけ木を辿るので、遅延評価がそのまま働きます。

## Functor だけでモナドになる

ここで、モナドとして扱うために書いたのは実質的に 1 行だけです。

```hs
data GenF o next = Yield o next deriving Functor
```

データ型を 1 つ宣言して `Functor` にしただけです。`instance Monad` は 1 行も書いていません。それでも `count` は `do` で書けています。モナドとして働いているのは `Free f` の側で、`GenF o` が渡したのは `Functor` インスタンス、それも `deriving` の 1 語だけです。

モナドを 1 つ自作するには `>>=` を定義し、`Functor`・`Applicative`・`Monad` の 3 段を揃える必要がありました。👉[モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends#3-段まとめて書く定型)

Free モナドを使えば、その部分は `Free f` が肩代わりします。作る側は命令の型を書いて `Functor` にするだけで、新しいモナドが手に入ります。

しかも `do` や `mapM_` のような、モナドを要求する既存の道具がそのまま使えます。DSL の制御構造を自分で用意する必要がありません。

## 継続で作った場合との違い

継続モナドで同じものを作ったときは、中断した位置から再開するために、取り出しておいた継続を `evalCont` で評価する必要がありました。

```hs:継続モナド版
loop (Yield v next) = print v >> loop (evalCont next)
loop Done = return ()
```

`next` に入っているのは継続、つまり呼び出して初めて先へ進む関数です。そのため取り出す側にも「評価して駆動する」という仕事がありました。

Free 版の `next` はデータです。既に組み上がっている木が継続としてそこに入っているだけなので、インタープリターはパターンマッチで辿るだけで済みます。継続を作るのは `>>=` の仕事で、それが済んだ後の形を受け取っている、という違いです。

違いは `>>=` の結果にも出ます。継続モナドの `>>=` は関数を合成して関数を作るので、できあがるのは中を覗けない一塊です。継続版の `Gen` は `Show` を導出できません。`next` の位置にあるのが関数だからです。`Yield` を 1 つ取り出すことはできても、その先を知るには評価するしかありません。

Free モナドの `>>=` は木を作るので、手順書の全体が最初からデータとして手元にあります。`print count` が手順書を丸ごと表示できたのは、中身がデータなので `Show` が書けたからです。

## IO と何が違うのか

`toList` は手順書を辿るだけで、`Yield` をどう扱うかを決めているのはインタープリター側です。ということは、同じ `count` に別のインタープリターを当てれば、別のことが起きます。値を集める代わりに `print` すれば、`IO` で走らせるインタープリターになります（練習【問2】）。

ここが `IO` で直接書くのとの違いです。アクションは実行するためのものなので、`mapM_ print [1, 2, 3]` と書いてしまえば、あとは実行するしかありません。中身を覗くことも、別の意味に読み替えることもできません。👉[アクション](https://qiita.com/7shi/items/85afd7bbd5d6c4115ad6)

Free モナドで書いた `count` は、`do` の見た目こそアクションと同じですが、実体は検査できるデータです。

|やりたいこと|`IO` で書いた場合|Free で書いた場合|
|---|---|---|
|実行する|そのまま実行|`IO` 版インタープリターを当てる|
|中身を見る|できない|`print` で手順書そのものを表示|
|結果を検査する|実行しないと分からない|`toList` で純粋な値として取れる|
|テスト用に差し替える|できない|モック用インタープリターを書く|
|ログを取る|処理に埋め込む|記録するインタープリターを書く|

この違いはデバッグのときに効きます。`IO` で書いたものが期待どおりに動かないときは、実行して出力を眺め、そこから逆算するしかありません。Free で書いたものは、実行する前に手順書を表示して、意図した命令が意図した順に並んでいるかを直接確かめられます。組み立てと解釈のどちらに問題があるのかを切り分けられる、と言い換えてもいいでしょう。

手順書は 1 つ、解釈は複数。これが Free モナドの「組み立てと解釈の分離」です。

## 練習

【問2】上の `count` をそのまま使って、`Yield` の値を `print` していく `IO` 版のインタープリター `runIO` を書いてください。手順書 `count` はそのまま使います。

```hs
runIO :: Show o => Gen o a -> IO ()
runIO = undefined  -- ここを書く

main = do
    print $ toList count
    runIO count
```
```text:実行結果
[1,2,3]
1
2
3
```

:::details 解答例
```hs
runIO :: Show o => Gen o a -> IO ()
runIO (Pure _)           = return ()
runIO (Free (Yield o k)) = print o >> runIO k
```

`toList` と形がそっくりです。`[]` が `return ()` に、`o :` が `print o >>` に変わっただけで、木を辿る骨組みは同じです。

同じ `count` から、リストと `IO` という 2 つの結果が得られました。手順書を書き換えていないことが重要です。
:::

# テレタイプ

命令の種類を増やすと、DSL らしくなってきます。行の入出力を表す命令を作ります。

```hs
data TeletypeF next
    = PutLine String next
    | GetLine (String -> next)
```

`PutLine` は `Yield` と同じ形で、出力する文字列と継続を持ちます。`GetLine` は継続が関数になっています。読み込んだ文字列が決まらないと継続が決まらないためです。「文字列を受け取ったら継続を返す」という形で、継続を保留しています。

`Functor` インスタンスを手で書くと、この違いがはっきりします。

```hs
instance Functor TeletypeF where
    fmap f (PutLine s next) = PutLine s (f next)
    fmap f (GetLine k)      = GetLine (f . k)
```

`PutLine` は継続に `f` を適用するだけですが、`GetLine` は継続が関数なので、その結果に `f` を適用する形、つまり関数合成 `f . k` になります。`DeriveFunctor` はここも機械的に導出してくれます。

## スマートコンストラクター

型の別名を用意して、命令を 1 つずつ持ち上げます。

```hs
type Teletype = Free TeletypeF

putLine :: String -> Teletype ()
putLine s = liftF (PutLine s ())

getLine' :: Teletype String
getLine' = liftF (GetLine id)
```

`putLine` は `yield` と同じ形です。継続の位置に仮の値 `()` を置くと、`liftF` がそれを `Pure ()` に変えます。`getLine'` の名前に `'` が付いているのは、標準の `getLine` と衝突を避けるためです。

`getLine'` の `id` が要点です。`GetLine` の継続は `String -> next` という関数なので、置くのは値ではなく関数になります。`liftF c = Free (fmap Pure c)` と `fmap f (GetLine k) = GetLine (f . k)` から、変化を追います。

```hs
c                  = GetLine id
fmap Pure c        = GetLine (Pure . id)
Free (fmap Pure c) = Free (GetLine (\s -> Pure s))
```

「文字列を受け取ったら、それを結果として終わる」という 1 命令の手順書です。`GetLine id :: TeletypeF String` なので、`liftF :: f a -> Free f a` を通した全体は `Teletype String` になります。

継続の位置に置いた関数が、そのまま「読み込んだ文字列から結果を作る関数」になっている、と読めます。試しに `id` の代わりに `length` を置けば `Teletype Int` になり、行の長さを結果とする別の命令ができます。継続が値の命令では置いた値が結果になり、継続が関数の命令では置いた関数の戻り値が結果になる、という対応です。

これで `do` が使えます。

```hs
greet :: Teletype ()
greet = do
    putLine "name?"
    name <- getLine'
    putLine ("Hello, " ++ name ++ "!")
```

`name <- getLine'` で文字列を受け取れるのは、`getLine'` が `Teletype String` だからです。`count` と同じで、これもまだ何も起きていないデータです。

## 2 つのインタープリター

`greet` を `IO` を使わずに走らせます。入力をリストで与え、出力をリストで集めるインタープリターです。入力が尽きたら空文字列を返すことにします。

```hs
runPure :: [String] -> Teletype a -> [String]
runPure _        (Pure _)             = []
runPure ins      (Free (PutLine s k)) = s : runPure ins k
runPure []       (Free (GetLine k))   = runPure [] (k "")
runPure (i : is) (Free (GetLine k))   = runPure is (k i)

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

第 1 引数が残りの入力です。`PutLine` は出力を先頭に付けて入力はそのまま渡し、`GetLine` は入力を 1 つ取り出して関数 `k` に渡します。`k i` を評価すると継続の手順書が得られるので、それを辿ります。

`IO` は一度も出てきません。それでも `greet` の振る舞いを、入力を与えて出力を確かめるという形で検査できています。テスト用のモックが、特別な仕掛けなしに書けるということです。

本物の `IO` で走らせたければ、同じ `greet` に別のインタープリターを当てます。

```hs
runIO :: Teletype a -> IO ()
runIO (Pure _)             = return ()
runIO (Free (PutLine s k)) = putStrLn s >> runIO k
runIO (Free (GetLine k))   = getLine >>= runIO . k
```

骨組みは `runPure` と同じで、`PutLine` を `putStrLn`、`GetLine` を `getLine` に対応させただけです。`greet` は書き換えていません。

## 練習

【問3】今度は自分で DSL を設計します。整数のスタックを操作する命令の型 `StackF` と、スマートコンストラクター `push`・`pop` を定義してください。`push` は値を 1 つ積む命令、`pop` は 1 つ取り出す命令です。次の `calc` が書けることが目標です。

```hs
-- ここに StackF を定義する

type Stack = Free StackF

push :: Int -> Stack ()
push = undefined  -- ここを書く

pop :: Stack Int
pop = undefined  -- ここを書く

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
data StackF next
    = Push Int next
    | Pop (Int -> next)
    deriving Functor

push :: Int -> Stack ()
push n = liftF (Push n ())

pop :: Stack Int
pop = liftF (Pop id)
```

`Push` は積む値と継続を持つので `PutLine` と同じ形です。`Pop` は取り出した値が決まらないと継続が決まらないので、継続が `Int -> next` という関数になります。`GetLine` の `String` が `Int` に変わっただけです。

スマートコンストラクターも対応しています。`push` は継続の位置に `()` を置くので結果が `()`、`pop` は `id` を置くので取り出した値がそのまま結果になります。だから `a <- pop` で受け取れます。

`calc` は 3 と 4 を積み、2 つ取り出して足し、積み直して、最後に取り出しています。
:::

【問4】問3の `calc` を走らせるインタープリター `runStack` を書いてください。第 1 引数が初期スタックです。`Pop` でスタックが空だったときは 0 を返すことにします。

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
runStack _        (Pure a)          = a
runStack st       (Free (Push n k)) = runStack (n : st) k
runStack []       (Free (Pop k))    = runStack [] (k 0)
runStack (x : xs) (Free (Pop k))    = runStack xs (k x)
```

`runPure` と同じ形です。違うのは、持ち回るものが残りの入力ではなくスタックであることと、`Pure` まで来たときに集めたリストではなく手順書の結果 `a` を返すことです。`Push` はスタックの先頭に積んで継続を辿り、`Pop` は先頭を取り出して関数 `k` に渡します。

スタックという状態は手順書の側には現れません。`calc` は「積む・取り出す」と書いてあるだけで、それがリストで表されていることを知らないままです。状態を持つのはインタープリターの引数だけ、ということです。
:::

# 「自由」とは何か

なぜ「Free」（自由）と呼ぶのかを説明します。

リストはモノイドです。`<>` で結合でき、単位元が `[]` です。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#semigroup-と-monoid)

```hs:GHCi
ghci> [1, 2] <> [3]
[1,2,3]
```

このとき `[1] <> [2]` は `[1,2]` になるだけで、`3` にも `2` にもなりません。足し算や掛け算のような意味を持っていないからです。要素を並べて保持しているだけで、どう畳むかは後から `foldr` などで決められます。

このように「モノイド則だけを満たし、それ以上の性質を持たない」構造を**自由モノイド**と呼びます。リストがそれです。

Free モナドはこれのモナド版です。`>>=` は命令をつなぐだけで、何の意味も与えません。モナド則だけを満たし、それ以上の意味づけを持たないので、意味を後から選べます。意味を後から決められるのは、意味を持っていないからです。

|自由モノイド（リスト）|Free モナド|
|---|---|
|`<>` は要素を並べるだけ|`>>=` は命令をつなぐだけ|
|畳み方は `foldr` などで後から決める|意味はインタープリターで後から決める|
|`[1] <> [2]` は `3` にならない|`yield 1 >> yield 2` は何も出力しない|

比べてみると、これまでのモナドは意味を持っていました。`IO` なら実行され、`Maybe` なら失敗が伝播し、`State` なら状態が流れます。`>>=` でつないだ時点で何が起きるかが決まっていました。Free モナドはその決定を手放したモナドです。

こうした「ある性質だけを満たし、余計なものを持たない構造」を作ることを**自由生成**（free construction）と呼び、`Free` の名前はここから来ています。

:::message
ここでは「自由」を代数（モノイド）の側から説明しました。数学的な準備なしに済ませたかったためで、以下は補足です。

圏論では「自由」を忘却関手の左随伴として定義します。モノイドから中身の集合だけを取り出す忘却関手を考えると、その左随伴が「集合からリストを作る」対応にあたり、これが自由モノイドです。Free モナドも同じ形で、モナドから `Functor` の部分だけを取り出す忘却関手の左随伴が `Free` になります。「余計な性質を持たない」という言い方は、この随伴が持つ普遍性を指しています。命令の型 `f` を `m` の操作へ翻訳する方法を 1 つ与えれば、`Free f` 全体を `m` へ移す解釈がそこから一意に決まる、というのがその内容で、後述の `foldFree` がまさにそれです。随伴と普遍性については、シリーズの後の回で扱います。👉[圏論](20-category-theory.md#随伴と自由生成)
:::

# free パッケージ

ここまで `Free` を自分で定義してきましたが、実用では [free](https://hackage.haskell.org/package/free) パッケージを使います。[`Control.Monad.Free`](https://hackage.haskell.org/package/free/docs/Control-Monad-Free.html) の定義は、本記事で書いたものとコンストラクター名まで同じです。

```hs
data Free f a = Pure a | Free (f (Free f a))
```

`>>=` の実装も同じです。`Functor`・`Applicative` はパッケージ側では `liftM`・`ap` に頼らず直接書かれていますが、結果は変わりません。

インタープリターを書くための関数も用意されています。

|関数|型|用途|
|---|---|---|
|`liftF`|`f a -> Free f a`|命令 1 つを手順書にする|
|`foldFree`|`(forall x. f x -> m x) -> Free f a -> m a`|命令を 1 つずつ別のモナドへ変換する|
|`iterM`|`(f (m a) -> m a) -> Free f a -> m a`|継続が解釈済みの状態で 1 段ずつ潰す|

`foldFree` と `iterM` を使うと、`IO` 版インタープリターが 1 行で書けます。木を辿る再帰の部分をパッケージが持っているので、命令 1 つの扱い方だけを渡せば済みます。

```hs
import Control.Monad.Free

data GenF o next = Yield o next deriving Functor

type Gen o = Free (GenF o)

yield :: o -> Gen o ()
yield x = liftF (Yield x ())

count :: Gen Int ()
count = do
    yield 1
    yield 2
    yield 3

toList :: Gen o a -> [o]
toList (Pure _)           = []
toList (Free (Yield o k)) = o : toList k

runIO :: Show o => Gen o a -> IO a
runIO = foldFree $ \(Yield o next) -> print o >> return next

runIterM :: Show o => Gen o a -> IO a
runIterM = iterM $ \(Yield o next) -> print o >> next

main = do
    print $ toList count
    runIO count
    runIterM count
```
```text:実行結果
[1,2,3]
1
2
3
1
2
3
```

`foldFree` に渡す関数は `Yield o next` の `next` をそのまま返しているのに対し、`iterM` に渡す関数は `next` を `IO` として実行しています。`iterM` は継続を先に解釈してから渡すためで、この違いが型に出ています。

:::message
`free` は GHC に同梱されていないため、実行には導入が必要です。[Stack](https://docs.haskellstack.org/) を使う場合は次のように起動できます。

```
stack script --resolver lts-24.53 --package free ファイル名.hs
```
:::

## 性能の注意

`>>=` を左結合で重ねると遅くなります。

```hs
((yield 1 >> yield 2) >> yield 3) >> yield 4
```

`Free g >>= k` は枝を `fmap` で辿るので、左側に木が積み上がっていると、後ろに 1 つ足すたびに先頭から辿り直すことになります。リストの `++` を左結合で重ねると遅くなるのと同じ現象です。`do` で素直に並べれば右結合になるので、通常は問題になりません。

# まとめ

Free モナドは、木の枝の形を型引数にくくり出したものでした。

|木|`Free`|
|---|---|
|`Tree a`（枝は 2 つ組）|`Free Two a`|
|`Rose a`（枝はリスト）|`Free [] a`|
|`Leaf x`|`Pure x`|
|枝を辿る|`fmap` で辿る（だから `Functor` が必要）|

そして枝の形を命令の型と読み替えると、`Free f a` は命令を並べた手順書になります。

|段階|やっていること|
|---|---|
|命令の型|`data GenF o next = Yield o next`。`next` が継続|
|持ち上げ|`liftF` で命令 1 つを手順書にする|
|組み立て|`do` と `>>=` で命令をつなぐ。まだ何も起きない|
|解釈|インタープリターが手順書を辿って意味を与える|

継続の位置には値でも関数でも置けます。`GetLine (String -> next)` のように関数にすると、受け取った値が決まってから継続が決まる命令になり、スマートコンストラクターは `liftF (GetLine id)` のように関数を置いて書きます。

`>>=` が意味を持たないので、意味を後から選べます。同じ手順書に別のインタープリターを当てれば、リストにも `IO` にもテスト用のモックにもなります。これが「組み立てと解釈の分離」です。

手順書がデータであることは、そのまま検査できるという利点にもなります。実行する前に `print` して、意図した命令が意図した順に並んでいるかを確かめられます。

これまで扱ってきたモナドは、`>>=` でつないだ時点で何が起きるかが決まっていました。Free モナドはそこを空けておくことで、モナドを自作するのではなくモナドを作る型になっています。

作る側の手間も違います。モナドを 1 つ自作するには `>>=` を定義して 3 段を揃える必要がありましたが、Free モナドを使うなら命令の型を `Functor` にするだけです。ジェネレーターで書いたのも `data GenF o next = Yield o next deriving Functor` の 1 行で、`instance Monad` は書いていません。`>>=` の側は `Free f` が持っているので、命令の型を書けば、その分だけ新しいモナドが手に入ります。

# 関連記事

初期の Haskell についての記事です。テレタイプと同じような仕組みで `OS` を模倣する例があります。

https://zenn.dev/7shi/articles/20260731-haskell-io-history
