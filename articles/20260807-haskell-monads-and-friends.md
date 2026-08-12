---
title: "Haskell モナドとゆかいな仲間たち"
emoji: "🎩"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "モナド", "functor", "applicative"]
published: true
---

Haskell では、自作した型を `do` で使うには `Monad` 型クラスのインスタンスを実装する必要があり、そのためにスーパークラスの `Functor`・`Applicative` も求められます。この階層を順にたどってモナドを自作します。

タイトルの「ゆかいな仲間たち」は、この `Functor` と `Applicative` を指しています。

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
1. **Haskell モナドとゆかいな仲間たち** ← この記事
1. [Haskell Freeモナド 超入門](https://zenn.dev/7shi/articles/20260808-haskell-free-monad)
1. [Haskell Operationalモナド 超入門](https://zenn.dev/7shi/articles/20260809-haskell-operational-monad)
1. [Haskell Effモナド 超入門](https://zenn.dev/7shi/articles/20260811-haskell-eff-monad)
1. [Haskell アロー 超入門](https://zenn.dev/7shi/articles/20260813-haskell-arrow)

# do を使うための型クラス

このシリーズは、モナドを説明するたびに bind を書く練習問題を出題してきました。👉[状態系モナド](https://qiita.com/7shi/items/2e9bff5d88302de1a9e9#stateモナド)

State を扱う `bind` の解答例です。

```hs
a `bind` b = state $ \s ->
    let (r1, s1) = runState a s
        (r2, s2) = runState (b r1) s1
    in  (r2, s2)
return' x  = state $ \s -> (x , s)
```

きちんと動きますが、この `bind` は `do` ブロックで使うことはできないため、バッククォートで演算子にした `bind` を並べて書く必要がありました。

```hs
fib x = (`evalState` (0, 1)) $
    (replicateM_ (x - 1) $
        get' `bind` \(a, b) ->
        put' (b, a + b)) `bind` \_ ->
    get' `bind` \v ->
    return' $ snd v
```

`do` ブロック内のコードは `>>=` の連鎖に置き換えられますが、その `>>=` は `Monad` 型クラスのメソッドです。自作の型で `do` を使うには、`instance Monad` としてその型のインスタンスを宣言し、その中で `>>=` を実装する必要があります。

ただし `Monad` のインスタンスは単独では書けず、土台となる型クラスを先に実装しなければなりません。準備するものが多いため、まずは何が必要になるのかを `Monad` の宣言から確認します。

:::message
練習問題で `bind` を関数として自作してきたのは、その時点では型クラスを説明しておらず、インスタンスとして実装しようがなかったためです。
:::

## Monad のスーパークラス

型クラスは `class` で宣言し、`instance` で型ごとに実装します。`Monad` は標準ライブラリで宣言済みなので、書くのは `instance` だけです。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#class-と-instance)

まず宣言を見ます。

```text:GHCi
ghci> :i Monad
type Monad :: (* -> *) -> Constraint
class Applicative m => Monad m where
  (>>=) :: m a -> (a -> m b) -> m b
  (>>) :: m a -> m b -> m b
  return :: a -> m a
  {-# MINIMAL (>>=) #-}
（略）
```

最小完全定義が `(>>=)` だけなので、実装するのは bind ひとつで済みます。シリーズでずっと使ってきた `>>=` は、このように `class` のメソッドとして宣言されています。

問題は 1 行目の `class Applicative m => Monad m` です。`Applicative` がスーパークラスに指定されています。つまり `Monad` のインスタンスを実装するには、先に `Applicative` のインスタンスを実装しなければなりません。

その `Applicative` も同じ形をしています。

```text:GHCi
ghci> :i Applicative
type Applicative :: (* -> *) -> Constraint
class Functor f => Applicative f where
  pure :: a -> f a
  (<*>) :: f (a -> b) -> f a -> f b
  liftA2 :: (a -> b -> c) -> f a -> f b -> f c
  (*>) :: f a -> f b -> f b
  (<*) :: f a -> f b -> f a
  {-# MINIMAL pure, ((<*>) | liftA2) #-}
（略）
ghci> :i Functor
type Functor :: (* -> *) -> Constraint
class Functor f where
  fmap :: (a -> b) -> f a -> f b
  (<$) :: a -> f b -> f a
  {-# MINIMAL fmap #-}
（略）
```

3 つ並べると階層になっています。

```hs:3つの宣言を並べたもの
class                  Functor f     where fmap  :: (a -> b) -> f a -> f b
class Functor f     => Applicative f where pure  :: a -> f a
                                           (<*>) :: f (a -> b) -> f a -> f b
class Applicative m => Monad m       where (>>=) :: m a -> (a -> m b) -> m b
```

どれも種が `* -> *` の型クラスです。`Maybe`・`[]`・`IO` のように型を 1 つ受け取る型でなければインスタンスにできません。

|型クラス|メソッド|できること|
|---|---|---|
|`Functor`|`fmap` (`<$>`)|コンテナの中身に関数を適用する|
|`Applicative`|`pure`, `<*>`|引数が複数ある関数を適用する|
|`Monad`|`>>=`|前の結果を見て次を決める|

`<$>` と `<*>` は、シリーズの早い段階から Applicative スタイルとして使ってきたものです。👉[アクション](https://qiita.com/7shi/items/85afd7bbd5d6c4115ad6#applicativeスタイル)

それが `Functor`・`Applicative` という型クラスのメソッドであることは、これまで説明を先送りにしてきました。モナドを自作しようとすると、この 2 つを否応なく実装することになります。

階層を下から順に見ていきます。

# Functor

```hs:定義（抜粋）
class Functor f where
    fmap :: (a -> b) -> f a -> f b
```

:::message
`Functor` は数学の**関手**（functor）に由来する名前です。今回の範囲を超えるため、詳細は省略します。
:::

メソッドは `fmap` ひとつです。使う側から見た型には型クラス制約が付きます。

```hs:型
fmap :: Functor f => (a -> b) -> f a -> f b
```

`f a` の中身に関数 `a -> b` を適用して `f b` にします。

ここで渡す `a -> b` は、`f` のことを何も知らない普通の関数です。`(* 2)` は `Maybe` も `IO` も知りませんし、知る必要もありません。`fmap` はその関数を `f` の中まで運び込んで、中身に作用させます。コンテナは `f` のままで、中身の型だけが `a` から `b` に変わります。

## 持ち上げ

中に値が 1 つ入っているだけの `Identity` で `fmap` を試します。👉[モナド変換子](https://qiita.com/7shi/items/4408b76624067c17e933#identityモナド)

```text:GHCi
ghci> import Data.Functor.Identity
ghci> double = (* 2) :: Int -> Int
ghci> double 3
6
ghci> fmap double (Identity 3)
Identity 6
```

`double` は `Identity` を知りませんが、`fmap` によって `Identity` の中で働いています。コンテナはそのままで、中身が `3` から `6` に変わりました。

関数だけを渡すと、このことが型にも表れます。

```text:GHCi
ghci> :t double
double :: Int -> Int
ghci> :t fmap double
fmap double :: Functor f => f Int -> f Int
```

`Int -> Int` だったものが `f Int -> f Int` になりました。数値を扱うだけだった関数が、`Functor` を扱う関数に変わっています。関数の方が `Functor` の世界へ引き上げられたわけです。これを**持ち上げ**（lift）と表現します。

`Identity` のインスタンスを自分で定義してみれば、持ち上げの様子がそのまま書き下せることが分かります。

```hs
instance Functor Identity where
    fmap f (Identity x) = Identity (f x)
```

左辺では関数 `f` が `Identity` の外にありますが、右辺では `Identity` の中に入っています。`fmap` は関数 `f` を持ち上げて、コンテナの中で作用させているわけです。

## アドホック多相

他のコンテナでも `fmap` を使ってみます。

```hs
main = do
    print $ fmap (* 2) (Just 3)
    print $ fmap (* 2) (Nothing :: Maybe Int)
    print =<< fmap (* 2) (return 3 :: IO Int)
    print $ fmap (* 2) [1, 2, 3]
    print $ (* 2) <$> Just 3
```
```text:実行結果
Just 6
Nothing
6
[2,4,6]
Just 6
```

`Maybe` では `Just` の中身にだけ適用され、`Nothing` は中身がないのでそのままです。`IO` ではアクションの結果に適用されます。どちらも `Just` は `Just` のまま、アクションはアクションのままで、中身の型だけが `a` から `b` に変わっています。アドホック多相により、同じ `fmap` が型ごとに違う実装を選んでいます。

リストの場合は中身が複数あるため、結果的に全要素へ適用されます。

```hs:型
fmap :: Functor f => (a -> b) -> f a -> f b
map  ::              (a -> b) -> [a] -> [b]
```

`f` を `[]` に固定すると `map` の型と一致します。つまり `map` は `fmap` をリストに特殊化したものです。ただし「多数の要素へ一斉に適用する」のはリストという構造から出てくる性質であって、`fmap` 自体の意味ではないことに注意してください。

`<$>` は `fmap` の演算子版で、`f <$> m` は `fmap f m` と同じです。

## liftM

「持ち上げ」は、モナド変換子で `lift` や `liftM` を扱ったときと同じ言い回しです。👉[モナド変換子](https://qiita.com/7shi/items/4408b76624067c17e933#持ち上げ)

その `liftM` は標準ライブラリにある関数で、名前のとおりモナド（M）への持ち上げ（lift）です。

```hs
liftM :: Monad m => (a -> b) -> m a -> m b
liftM f m = do
    x <- m        -- モナドから値を取り出す
    return $ f x  -- 関数を適用してモナドに入れて返す
```

型クラス制約が `Functor` ではなく `Monad` になっていますが、`Monad` に対しては `fmap` と同じ結果が得られます。

```hs
import Control.Monad (liftM)

main = do
    print $ fmap  (* 2) [1, 2, 3]
    print $ liftM (* 2) [1, 2, 3]
```
```text:実行結果
[2,4,6]
[2,4,6]
```

同じ働きのものを `Monad` 専用として `>>=` と `return` で実装したということです。

:::message
`liftM` は制約が `Monad` であるため、`Monad` のインスタンスを持たない `Functor` には使えません。
:::

`liftM` は型クラスのメソッドではないため、型ごとに実装するものではなく、1 つの実装が `Monad` のインスタンスすべてに適用できます。

## ファンクター則

`Functor` のインスタンスが守るべき規則が 2 つあります。これを**ファンクター則**（functor law）と呼びます。

```hs
fmap id      == id               -- 単位元
fmap (f . g) == fmap f . fmap g  -- 準同型
```

式を == で区切り、両辺が等しくなることを要求しています。実際に評価する式ではありません。以降に出て来る規則もすべて同じ読み方です。

「何もしない関数を適用すれば何も変わらない」「関数を合成してから適用しても、適用してから合成しても同じ」という意味です。要するに `fmap` は中身に関数を適用するだけで、構造をいじってはいけない、ということです。

:::message
関数合成 `.` の側から見ると、`id` はその単位元です。1 つ目は単位元が単位元のまま持ち上がること、2 つ目は持ち上げても合成が崩れないことを要求しています。つまり `fmap` は、関数合成という構造を保つ**準同型**になっています。
:::

### ファンクター則を破る例

コンパイラはこれを検査してくれません。`Semigroup` の結合法則と同じく、インスタンスを書く側が守るべき約束です。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#semigroup-と-monoid)

たとえば `Maybe` の `fmap` を次のように書いても、型は通ります。

```hs:NG
instance Functor Maybe where
    fmap _ (Just _) = Nothing
    fmap _ Nothing  = Nothing
```

しかしこれでは `fmap id (Just 1)` が `Nothing` になり、`fmap id == id` を破ります。コンパイラが検査しない以上こういうインスタンスも書けてしまいますが、これは `Functor` ではありません。

:::message
GHC が検査しないのは、関数が等しいかどうかの判定が一般には不可能で、証明を書く仕組みも言語に用意されていないためです。

検査させる試みはあります。Liquid Haskell は、法則を証明として書いて SMT ソルバで検査します。`quickcheck-classes` のように、法則を性質テストとして回すライブラリもあります。
:::

## 練習

【問1】次の `main` が実行結果の通りになるように、`Pair` を `Functor` のインスタンスにしてください。

```hs
data Pair a = Pair a a deriving Show

-- ここに instance Functor Pair を書く

main = do
    print $ fmap (* 2) (Pair 1 2)
    print $ show <$> Pair 1 2
```
```text:実行結果
Pair 2 4
Pair "1" "2"
```

:::details 解答例
```hs
instance Functor Pair where
    fmap f (Pair x y) = Pair (f x) (f y)
```

2 つの要素それぞれに関数を適用します。`Pair` という構造自体は変わりません。`show <$> Pair 1 2` のように、適用する関数によって中身の型が `Int` から `String` へ変わる点にも注目してください。
:::

# Applicative

```hs:定義（抜粋）
class Functor f => Applicative f where
    pure  :: a -> f a
    (<*>) :: f (a -> b) -> f a -> f b
```

メソッドは `pure` と `<*>` の 2 つです。`pure` は値を `f` に入れるだけの関数で、`Monad` の `return` に相当します。

`fmap`（`<$>`）は 1 引数の関数を `f` の世界へ持ち上げました。引数が 2 つある関数を同じように持ち上げると何が起きるか、`Functor` のときと同じく `Identity` で試します。

```text:GHCi
ghci> import Data.Functor.Identity
ghci> :t (+) <$> Identity 1
(+) <$> Identity 1 :: Num a => Identity (a -> a)
```

`Identity` の中身 `1` を `(+)` に部分適用した結果、`Identity` の中に関数 `a -> a` が入った状態になります。ここから先へ進むには「`f` に入った関数を、`f` に入った値に適用する」道具が必要です。それが `<*>` です。

```hs:型
(<$>) :: Functor     f =>   (a -> b) -> f a -> f b
(<*>) :: Applicative f => f (a -> b) -> f a -> f b
```

違いは、関数が `f` に入っているかどうかだけです。`fmap`（`<$>`）は外にある関数を持ち上げますが、`<*>` は既に `f` に入っている関数をそのまま使います。残っていた引数を `<*>` で渡せば、2 引数の関数を持ち上げたことになります。

```text:GHCi
ghci> runIdentity ((+) <$> Identity 1 <*> Identity 2)
3
```

インスタンスを書くと、`fmap` との違いがそのまま形に表れます。`Functor` の側と並べます。

```hs
instance Functor Identity where
    fmap f (Identity x) = Identity (f x)

instance Applicative Identity where
    pure = Identity
    Identity f <*> Identity x = Identity (f x)
```

右辺はどちらも `Identity (f x)` で同じです。違うのは左辺で、`fmap` は関数 `f` が `Identity` の外にありますが、`<*>` は `Identity f` とパターンマッチして中から取り出しています。`pure` は値を `Identity` で包むだけです。

:::message
Applicative を直訳すれば「適用可能」で、「複数の引数が適用可能」という意味合いです。
:::

## Applicative スタイル

`<$>`・`<*>` を並べる書き方は、**Applicative スタイル**として紹介していました。`>>=` は「アクションを返す関数」としか繋げませんが、`<$>`・`<*>` なら素の関数をそのまま使えて、結果は自動的にアクションに入れて返されます。👉[アクション](https://qiita.com/7shi/items/85afd7bbd5d6c4115ad6#applicativeスタイル)

当時は演算子の使い方だけを示しましたが、その正体は `Functor`・`Applicative` のメソッドだったわけです。最初の引数を `<$>` で渡し、2 番目以降を `<*>` で繋いでいく、というのがこのスタイルの形です。

`Identity` 以外のコンテナでも同じ形で書けます。

```hs
main = do
    print $ (+) <$> Just 1 <*> Just 2
    print $ (+) <$> Just 1 <*> Nothing
    print $ (,) <$> [1, 2] <*> "ab"
```
```text:実行結果
Just 3
Nothing
[(1,'a'),(1,'b'),(2,'a'),(2,'b')]
```

片方が `Nothing` なら全体が `Nothing` になり、リストなら全組み合わせが作られます。`Identity` では中身が 1 つずつなので単に適用されるだけでしたが、コンテナの構造に応じて組み合わせ方が変わります。

書き方が変わらないのは、`(+)` や `(,)` が素の関数のままで、`Maybe` もリストも知らないためです。コンテナに合わせて振る舞いを変えているのは `<$>`・`<*>` の側で、アドホック多相によってインスタンスが選ばれています。

制約が付くのも `<$>`・`<*>` を使う側です。しかも `Monad f =>` ではなく `Functor f =>`・`Applicative f =>` で足ります。必要な機能だけを要求できるのが、階層が分かれていることの実用上の利点です。

## 片方の結果だけを残す演算子

`Applicative` には、片方の結果だけを残す演算子も定義されています。

```hs
main = do
    print $ Just 1 <* Just 2
    print $ Just 1 *> Just 2
```
```text:実行結果
Just 1
Just 2
```

`<*`・`*>` は、左右の両方を評価しながら、結果としては不等号が向いている側だけを残す演算子です。`<*` なら左の値、`*>` なら右の値が残ります。構文解析で括弧を読み飛ばすのに使いました。👉[構文解析](https://qiita.com/7shi/items/b8c741e78a96ea2c10fe#演算子)

## return と pure

`Applicative` のもう一つのメソッド `pure` は、値を `f` に入れる関数です。

```hs:型
pure   :: Applicative f => a -> f a
return :: Monad m       => a -> m a
```

シリーズでは `return` を使ってきました。この 2 つは制約が違うだけで、現在の GHC ではやることが同じです。

```hs
main = do
    print (pure   1 :: Maybe Int)
    print (return 1 :: Maybe Int)
    print (pure   1 :: [Int])
    print (return 1 :: [Int])
```
```text:実行結果
Just 1
Just 1
[1]
[1]
```

`return` は `Monad` のメソッドとして残ってはいますが、最小完全定義は `(>>=)` だけです。`return` にはデフォルト実装があり、その中身が `pure` です。歴史的な事情で `Monad` 側に残っている別名だと考えておけば良いでしょう。

:::message
以前は `Monad` が `Applicative` のスーパークラスではなかったため、`return` は `Monad` のメソッドとして必要でした。現在は `Applicative` がスーパークラスになったため、`pure` で代用できます。
:::

したがって自作の型で実装すべきは `pure` の方で、`return` は書きません。

:::message
このシリーズは一貫して `return` 表記で通してきましたが、使う分にはどちらでも動きます。本シリーズでは、モナドでは `return` を使うスタイルで進めます。
:::

## アプリカティブ則

ファンクター則と同じように、`Applicative` のインスタンスが守るべき**アプリカティブ則**もあります。こちらは 4 つです。

```hs
pure id <*> v              == v                  -- 恒等
pure f <*> pure x          == pure (f x)         -- 準同型
u <*> pure y               == pure ($ y) <*> u   -- 交換
pure (.) <*> u <*> v <*> w == u <*> (v <*> w)    -- 合成
```

`u`・`v`・`w` は `f` に包まれた値（`u` と `v` は中身が関数）、`f`・`x`・`y` は素の値です。

以降では**効果**（effect）という言葉を使います。`f` が中身の値とは別に持っている働きのことで、`Maybe` なら失敗するかもしれないこと、リストなら複数の候補に分岐すること、`IO` なら入出力が起きることです。`<*>` は中身に関数を適用しつつ、左右の効果をまとめます。`(+) <$> Just 1 <*> Nothing` が `Nothing` になったり、リストで全組み合わせが作られたりするのが効果の側の働きです。

一方、`pure` で包んだ値は効果を持ちません。`Maybe` なら必ず `Just`、リストなら必ず 1 要素で、失敗も分岐も起こさない「ただ包んだだけ」の値です。

この区別を踏まえて、4 つを順に見ていきます。

### 恒等

```hs
pure id <*> v == v
```

ファンクター則の `fmap id == id` に対応します。何もしない関数を `pure` で包んで適用しても、中身も構造も変わってはいけない、ということです。`Maybe` なら `Just` が `Nothing` になったりせず、リストなら要素が増減も並べ替えもされません。

### 準同型

```hs
pure f <*> pure x == pure (f x)
```

準同型（homomorphism）は、ファンクター則の 2 つ目と同じ呼び名です。両辺とも `pure` しか使っていないため、`f` 側の効果はどこにも関与しません。「先に包んでから中で適用する」のと「外で適用してから包む」のが一致する、という要求です。

言い換えれば `pure` は値を包むだけで、余計な効果を持ってはいけないということです。たとえばリストの `pure x` が `[x, x]` だったとすると、左辺は 1 要素、右辺は 2 要素になって破れます。

### 交換

```hs
u <*> pure y == pure ($ y) <*> u
```

交換（interchange）は「順番を入れ替えてよい」という可換性のことではなく、`pure` した側を左右どちらに置いてもよい、という意味です。

`($ y)` は `\f -> f y` と同じで、関数を受け取って `y` を適用する関数です（`$` の右側だけを部分適用したセクション）。

左辺は「効果を持つ関数 `u`」に「効果のない値 `pure y`」を適用する形、右辺はその左右を入れ替えて「効果のない関数 `pure ($ y)`」に「効果を持つ `u`」を適用する形です。効果は `u` にしかないので、どちらの側から処理しても結果は同じでなければなりません。

```hs
main = do
    print $ [(+ 1), (* 2)] <*> pure 10
    print $ pure ($ 10) <*> [(+ 1), (* 2)]
```
```text:実行結果
[11,20]
[11,20]
```

リストの `pure 10` は 1 要素なので、どちら側に置いても組み合わせの結果は変わりません。つまり `pure` した側は効果を持たないため、左右のどちらに移しても影響しない、というのがこの規則の内容です。

### 合成

```hs
pure (.) <*> u <*> v <*> w == u <*> (v <*> w)
```

ファンクター則の `fmap (f . g) == fmap f . fmap g` に対応します。左辺は `u` と `v` の中身の関数を関数合成 `.` で先に繋いでから `w` に適用する形、右辺は `v` を `w` に適用してから `u` を適用する形です。

内容は結合法則ですが、`(u <*> v) <*> w == u <*> (v <*> w)` とは書けません。型が合わないためです。

```hs:型
u :: f (b -> c)
v :: f (a -> b)
w :: f a

u <*> (v <*> w)    -- v <*> w が f b になるので適用できる
(u <*> v) <*> w    -- u の中身は (a -> b) を受け取る関数ではない
```

`>>=` の結合法則は両辺とも書けましたが、`<*>` は左結合にすると型が通りません。そこで左辺だけを「`u` と `v` の中身を `.` で繋いでから `w` に適用する」形に書き直したのが `pure (.) <*> u <*> v <*> w` です。持ち上げる関数を `.` にすることで、型を合わせながら結合法則を述べています。

どちらの辺でも `u`・`v`・`w` はこの順に並んでいます。`IO` なら左から順に実行されるように、効果がまとめられる順序は保ったまま、括弧の付け方だけが自由になる、という要求です。

### アプリカティブ則を破る例

4 つをまとめると、`<*>` に許されているのは「関数適用を `f` の中へ持ち込むこと」だけで、順序を入れ替えたり、効果を複製・削除したり、構造を作り替えたりしてはいけない、ということです。

ファンクター則と同じく、コンパイラはこれらを検査してくれないため、型が通るだけのインスタンスは書けてしまいます。問2 の `Pair` に対して、左右の位置を入れ替える `<*>` を考えてみます。

```hs:NG
instance Applicative Pair where
    pure x = Pair x x
    Pair f g <*> Pair x y = Pair (g y) (f x)
```

これは型は通りますが、`pure id <*> Pair 1 2` が `Pair 2 1` になり、恒等則を破ります。ファンクター則の節で見た例と同じく、これは `Applicative` ではありません。

### fmap との整合性

上の 4 つに加えて、下の段との整合性も要求されます。

```hs
fmap f x == pure f <*> x
```

`Functor` と `Applicative` は別々のインスタンスとして書くため、両者がばらばらの動きをしないように実装する必要があります。この式は `<$>` と `<*>` を混ぜた Applicative スタイルが意味を持つための前提でもあります。

```text:GHCi
ghci> (+) <$> Just 1 <*> Just 2
Just 3
ghci> pure (+) <*> Just 1 <*> Just 2
Just 3
```

`<$>` で始めても `pure` で始めても同じ、ということを保証する必要があるわけです。

## 練習

【問2】問1 の `Pair` を `Applicative` のインスタンスにしてください。

```hs
data Pair a = Pair a a deriving Show

instance Functor Pair where
    fmap f (Pair x y) = Pair (f x) (f y)

-- ここに instance Applicative Pair を書く

main = do
    print $ (+) <$> Pair 1 2 <*> Pair 10 20
    print (pure 0 :: Pair Int)
```
```text:実行結果
Pair 11 22
Pair 0 0
```

`<*>` は左右の同じ位置どうしを組み合わせます。

:::details 解答例
```hs
instance Applicative Pair where
    pure x = Pair x x
    Pair f g <*> Pair x y = Pair (f x) (g y)
```

`<*>` は左の 1 番目の関数を右の 1 番目の値に、2 番目を 2 番目に適用します。`pure` は同じ値を 2 つ並べます。`Pair` は要素数が必ず 2 なので、リストのように長さが食い違う心配がありません。

`Functor` を書いた型に `Applicative` を足す、という手順そのものが、この記事で階層を下から積み上げていく流れの縮小版になっています。
:::

# Monad

```hs:定義（抜粋）
class Applicative m => Monad m where
    (>>=) :: m a -> (a -> m b) -> m b
```

メソッドは実質 `>>=` ひとつです。では、階層が `Applicative` と `Monad` の 2 段に分かれているのはなぜでしょうか。両者の決定的な違いは、前の結果を見て次の計算を決められるかどうかです。

```hs
main = do
    print $ [1, 2, 3] >>= \x -> replicate x x
    print $ (,) <$> [1, 2] <*> [10, 20]
    print $ Just 1 >>= \x -> if x > 0 then Just (x * 2) else Nothing
```
```text:実行結果
[1,2,2,3,3,3]
[(1,10),(1,20),(2,10),(2,20)]
Just 2
```

1 行目の `>>=` では、`replicate x x` が作るリストの長さが `x` に依存しています。前の結果を受け取ってから次の計算を組み立てているので、結果の形は実行してみないと分かりません。

2 行目の `<*>` では、左右のリストの長さが 2 と 2 なので、結果が 4 要素になることが実行前に決まっています。`<*>` に渡す時点で両辺は完成しており、片方の中身を見てもう片方を作り替えることはできません。

3 行目の `Maybe` も同じです。`<*>` は「両方が `Just` なら適用する」だけですが、`>>=` は前の結果 `x` を見て `Just` を返すか `Nothing` を返すかを決めています。

この非対称は型に現れています。

```hs
(<*>) :: f (a -> b) -> f a -> f b
(>>=) :: m a -> (a -> m b) -> m b
```

`<*>` の第 2 引数は `f a` という完成した値ですが、`>>=` の第 2 引数は `a -> m b` という関数です。値を受け取ってから次を作る、という構造が型に書かれています。

## ap

`fmap` と同じ働きの `liftM` が `>>=` と `return` で書けたように、`<*>` と同じ働きの関数も同じ道具立てで書けます。それが標準ライブラリの `ap` です。

```hs
ap :: Monad m => m (a -> b) -> m a -> m b
ap mf m = do
    f <- mf       -- モナドから関数を取り出す
    a <- m        -- モナドから値を取り出す
    return $ f a  -- 値を関数に適用してモナドに入れて返す
```

型クラス制約が `Applicative` ではなく `Monad` になっていますが、`Monad` に対しては `<*>` と同じ結果が得られます。`liftM` と `fmap` の関係がそのまま 1 段上でも成り立っています。

## モナド則

自作した型が「本当にモナドか」を決めるのは、`instance Monad` が書けたことではなく、次の 3 つの規則を満たしていることです。

```hs
return x >>= f   == f x                      -- 左単位元
m >>= return     == m                        -- 右単位元
(m >>= f) >>= g  == m >>= (\x -> f x >>= g)  -- 結合法則
```

ファンクター則などと同じく、コンパイラは検査してくれません。規則を満たさないインスタンスも書けてしまいますが、それはモナドではありません。

### >=> で書き直す

上の 3 行にはコメントで左単位元・右単位元・結合法則と名前を付けましたが、`>>=` のままでは形が揃っておらず、特に 3 つ目は結合法則には見えません。演算子を替えると見え方が変わります。

`>=>` はモナドを返す関数同士を合成する演算子です。`Control.Monad` にあります。

```hs
(>=>) :: Monad m => (a -> m b) -> (b -> m c) -> a -> m c
(f >=> g) x = f x >>= g
```

`f` の結果はモナドに包まれているので、そのまま `g` に渡すことはできません。間に `>>=` を挟んで中身を取り出してから渡す、というのを 1 つの演算子にまとめたのが `>=>` です。普通の関数合成 `.` のモナド版で、向きが逆の `<=<` もあります。

これでモナド則を書き直します。先にモナド則を再掲します。3 つ目の関数名は後の都合で `g`・`h` に変え、ラムダ式の引数も `y` に変えます（意味は変わりません）。

```hs
return x >>= f  == f x
m >>= return    == m
(m >>= g) >>= h == m >>= (\y -> g y >>= h)
```

`>=>` は関数同士をつなぐ演算子なので、モナド `m` があると使えません。そこで `m` を「何らかの関数 `f` が値 `x` から作ったもの」と考えて `m = f x` と置きます。

```hs
return x >>= f    == f x
f x >>= return    == f x
(f x >>= g) >>= h == f x >>= (\y -> g y >>= h)
```

`関数 引数 >>= 関数` という形があちこちに現れました。これはちょうど `>=>` の定義の右辺です。左辺の形 `(f >=> g) x` に合わせます。

* `return x >>= f` → `(return >=> f) x`
* `f x >>= return` → `(f >=> return) x`
* `f x >>= g` → `(f >=> g) x`
* `\y -> g y >>= h` → `\y -> (g >=> h) y` → `g >=> h`（ポイントフリースタイル）

```hs
(return >=> f) x  == f x
(f >=> return) x  == f x
(f >=> g) x >>= h == f x >>= (g >=> h)
```

3 つ目は `(f >=> g)` と `(g >=> h)` をそれぞれ 1 つの関数と見れば、両辺にもう一度同じ書き換えが使えます。

```hs
((f >=> g) >=> h) x == (f >=> (g >=> h)) x
```

これで 3 つとも両辺が「`x` を引数に取る形」になったため、ポイントフリースタイルの要領で `x` を取り除きます。

```hs
return >=> f    == f                -- 左単位元
f >=> return    == f                -- 右単位元
(f >=> g) >=> h == f >=> (g >=> h)  -- 結合法則
```

`>=>` を掛け算だと思えば、`return` は `1` に当たります。モナド則は「`return` を単位元として、モナドを返す関数が `>=>` で結合的に合成できる」という要求だったことになります。

単位元を持ち結合法則を満たす構造は**モノイド**です。前回 `Semigroup` と `Monoid` で見たのと同じ形が、`<>` と `mempty` の代わりに `>=>` と `return` で現れています。👉[型クラス](https://zenn.dev/7shi/articles/20260805-haskell-type-classes#semigroup-と-monoid)

## ZipList

アプリカティブ則に `fmap f x == pure f <*> x` が付いていたのと同じように、`Monad` も `Applicative` と整合性を持つために `<*>` は `ap` と結果が一致する必要があります。`>>=` にはこれとモナド則が同時に要求されるわけです。

この 2 つを両立できないために、「`Applicative` にはなれるが `Monad` にはなれない」型が存在します。標準ライブラリの `ZipList` がその代表です。

定義に使う関数を先に確認します。`zipWith` は 2 つのリストを同じ位置どうし組み合わせ、`repeat` は同じ値の無限リストを作ります。

```text:GHCi
ghci> zipWith (+) [1, 2, 3] [10, 20, 30]
[11,22,33]
ghci> zipWith (+) [1, 2, 3] [10, 20]
[11,22]
ghci> zipWith ($) [(+ 1), (* 2)] [10, 20]
[11,40]
ghci> take 3 (repeat 0)
[0,0,0]
```

`zipWith` は短い方の長さに合わせて切り詰めます。最後の `($)` は関数適用の演算子で、`f $ x` が `f x` を意味するものです。演算子として関数を渡すと「関数と引数を組み合わせる」ことになるため、`zipWith ($) fs xs` は関数のリストを値のリストに同じ位置で適用します。`repeat` はそのまま表示すると止まらないので、`take` で打ち切っています。

### Applicative としての ZipList

リストの `<*>` は全組み合わせを作りますが、`ZipList` は同じ位置どうしを組み合わせます。中身はリストそのものです。`import Control.Applicative` で使えますが、定義を見たいので再実装して動かします。

```hs
newtype ZipList a = ZipList { getZipList :: [a] } deriving Show

instance Functor ZipList where
    fmap f (ZipList xs) = ZipList (map f xs)

instance Applicative ZipList where
    pure = ZipList . repeat
    ZipList fs <*> ZipList xs = ZipList (zipWith ($) fs xs)

main = do
    print $ (+) <$> [1, 2, 3] <*> [10, 20, 30]
    print $ (+) <$> ZipList [1, 2, 3] <*> ZipList [10, 20, 30]
    print $ zipWith (+) [1, 2, 3] [10, 20, 30]
    print $ (+) <$> pure 100 <*> ZipList [10, 20, 30]
    print $ take 3 $ getZipList (pure 0)
```
```text:実行結果
[11,21,31,12,22,32,13,23,33]
ZipList {getZipList = [11,22,33]}
[11,22,33]
ZipList {getZipList = [110,120,130]}
[0,0,0]
```

`ZipList` で包んで `<$>` と `<*>` で書いたものは、`zipWith` を直接呼ぶのと同じ計算になるため、2 行目と 3 行目が同じ値になっています。

`pure` は `repeat` なので無限リストですが、`<*>` が短い方に合わせるため、相手の長さに揃った定数リストとして働きます。

:::message
1 要素を相手の長さに合わせて繰り返すことで、アプリカティブ則の恒等 `pure id <*> v == v` を満たします。NumPy のブロードキャストと同じ考え方です。
:::

`Applicative` はこれで書けました。

### ZipList はモナドにはなれない

続けて `Monad` を書いてみます。`m = ZipList [x0, x1, x2, ...]` とします。

`m >>= f` は、各要素に `f` を当てて得られるリストのリストから、1 本のリストを作る操作です。行が並んだ表だと思ってください。

```text:m >>= f のイメージ
f x0 = [ a0,  a1,  a2, ... ]
f x1 = [ b0,  b1,  b2, ... ]
f x2 = [ c0,  c1,  c2, ... ]
...
```

この表からどこを拾うかは、単位元則を満たすように決めます。

行の選び方は右単位元 `m >>= return == m` が決めます。`return` は `pure` と同じ `repeat` なので、`i` 行目には `m` の `i` 番目が延々と並びます。

```text:左辺 m >>= return のイメージ
return x0 → [x0, x0, x0, ... ]
return x1 → [x1, x1, x1, ... ]
return x2 → [x2, x2, x2, ... ]
...

右辺 m → [x0, x1, x2, ...]
```

行の中はすべて同じ値なので、どの列を取るかは結果に影響しません。`i` 番目が `xi` になるには、`i` 行目から取ることになります。

列の選び方は左単位元 `return x >>= f == f x` が決めます。`return x` はどの行も同じ値なので、全行が同じ `f x` になります。

```text:左辺 return x >>= f のイメージ
f x → [ y0,  y1,  y2, ... ]
f x → [ y0,  y1,  y2, ... ]
f x → [ y0,  y1,  y2, ... ]
...

右辺 f x → [y0, y1, y2, ...]
```

今度は行がすべて同じなので、どの行を取るかは影響しません。`i` 番目が `yi` になるには、`i` 列目を取るしかありません。

つまり `i` 行目の `i` 列目、表の**対角線**です。

```text:対角線
m >>= f → [a0, b1, c2, ...]
```

これを `instance Monad` として書きます。

```hs
import Control.Monad (ap)

-- newtype と Functor・Applicative のインスタンスは上と同じ

-- i 番目の要素には f の結果の i 番目を使う
instance Monad ZipList where
    ZipList xs >>= f = ZipList (go 0 xs)
      where
        go i (x:rest) = case drop i (getZipList (f x)) of
            (y:_) -> y : go (i + 1) rest
            []    -> []
        go _ [] = []

main = do
    print $ ((,) <$> ZipList [1, 2]) <*>  ZipList [10, 20]
    print $ ((,) <$> ZipList [1, 2]) `ap` ZipList [10, 20]
```
```text:実行結果
ZipList {getZipList = [(1,10),(2,20)]}
ZipList {getZipList = [(1,10),(2,20)]}
```

`<*>` と `ap` が一致しました。左右の単位元則は、それを指導原理として対角線を導いたので満たします。

しかし、結合法則は破れます。先ほどのコードの `main` 以下を次のように書き換えて実行してみます。

```hs
m = ZipList [1, 2]

f 1 = ZipList [1, 1]
f 2 = ZipList [9, 2]

g 9 = ZipList []
g v = ZipList [v * 100, v * 100 + 1]

main = do
    print $ m >>= f
    print $ (m >>= f) >>= g
    print $ m >>= (\x -> f x >>= g)
```
```text:実行結果
ZipList {getZipList = [1,2]}
ZipList {getZipList = [100,201]}
ZipList {getZipList = [100]}
```

2 行目と 3 行目の結果が異なります。入り組んでいるため、順を追って確認します。

まず左辺を表で追います。

```text:(m >>= f) >>= g
m >>= f:
f 1 = [1, 1] → 1
f 2 = [9, 2] → 2
→ [1, 2]

[1, 2] >>= g:
g 1 = [100, 101] → 100
g 2 = [200, 201] → 201
→ [100, 201]
```

`f 2` の最初の要素である `9` は対角線から外れるため、この時点で捨てられます。`g 9` は一度も呼ばれません。

右辺も `m` の先頭から順に `x = 1`・`x = 2` として `f x >>= g` を処理します。

```text:m >>= (\x -> f x >>= g)
f 1 >>= g → [1, 1] >>= g:
g 1 = [100, 101] → 100（1番目）
g 1 = [100, 101] → 101（2番目）
→ [100, 101] → 100（1番目）

f 2 >>= g → [9, 2] >>= g:
g 9 = [] → 1番目が無いため打ち切り
→ [] → 2番目が無いため打ち切り

→ [100]
```

`f 1 = [1, 1]` はどちらも `g 1` になり、対角線上の `[100, 101]` から `100` を取ります。

次は `f 2 = [9, 2]` に `g` を当てますが、これも先頭から対角線を取るので、まず `g 9` の 1 番目が必要です。`g 9` は空リストのため 1 番目が無く、その場で打ち切られて `f 2 >>= g` は `[]` になります。`g 2` は評価されません。

外側から見ると、`m` の 2 番目に対応する行が `[]` です。ここから 2 番目の要素を取ることもできないため、全体も打ち切られます。

同じ `9` に対して、左辺では `g` を当てず、右辺では当てています。捨てる位置が結合の順序で前後するため、結果が食い違うわけです。

このようにモナド則が破れるため、`ZipList` は `Applicative` にはなれても、`Monad` にはなれません。そのため、標準ライブラリの `ZipList` に `instance Monad` は用意されていません。

# モナドの実装

3 段の型クラスが揃ったので、実際にモナドが実装できるようになりました。

## Identity

最小の `Identity` モナドから始めます。`Functor` と `Applicative` のインスタンスは階層の説明で先に書きましたが、ここで `Monad` まで揃えます。

標準ライブラリにも `Data.Functor.Identity` として同じものがありますが、`Prelude` には入っていないため、import しない限り名前は衝突しません。

`do` が使えるようになればよいので、まず `instance Monad` だけを書いてみます。

```hs:NG
newtype Identity a = Identity { runIdentity :: a }

instance Monad Identity where
    Identity x >>= f = f x
```
```text:エラー内容
    • No instance for ‘Applicative Identity’
        arising from the superclasses of an instance declaration
    • In the instance declaration for ‘Monad Identity’
```

`arising from the superclasses` と出ています。`Monad` を名乗るには `Applicative`、ひいては `Functor` のインスタンスでなければなりません。

3 段すべてを実装します。

```hs
newtype Identity a = Identity { runIdentity :: a }

instance Functor Identity where
    fmap f (Identity x) = Identity (f x)

instance Applicative Identity where
    pure = Identity
    Identity f <*> Identity x = Identity (f x)

instance Monad Identity where
    Identity x >>= f = f x

calc = do
    x <- return 3
    return (x * 2)

main = do
    print $ runIdentity (fmap (* 2) (Identity 3))
    print $ runIdentity ((+) <$> Identity 1 <*> Identity 2)
    print $ runIdentity calc
```
```text:実行結果
6
3
6
```

どのメソッドも `Identity` の世界で関数を適用しています。

|メソッド|やっていること|
|---|---|
|`fmap`|外にある関数を持ち上げて適用する|
|`pure`|値を `Identity` の世界へ持ち上げる|
|`<*>`|既に持ち上がっている関数を適用する|
|`>>=`|中身を、`Identity` を返す関数 `f` に渡す|

`fmap` と `<*>` の違いは、適用する関数が持ち上がる前か後かだけです。`>>=` の右辺に `Identity` が現れないのは、渡される関数 `f` が最初から `Identity a` を返すためです。この型の違いが `<*>` と `>>=` を分けています。

そして注目すべきは `calc` です。実装したのは上の 3 つの `instance` だけですが、`do` と `return` がそのまま動いています。冒頭で見た `bind` を並べ書きする問題は、`instance Monad` を書くことで解決しました。

## 3 段まとめて書く定型

`Identity` では 3 段とも手で書きましたが、毎回そうする必要はありません。`>>=` さえあれば `fmap` は `liftM`、`<*>` は `ap` で書けることは既に見ました。そこで次の定型が使えます。

```hs
import Control.Monad (liftM, ap)

instance Functor Foo where
    fmap = liftM

instance Applicative Foo where
    pure  = ...
    (<*>) = ap

instance Monad Foo where
    (>>=) = ...
```

自分で中身を書くのは `pure` と `>>=` の 2 つだけで、残りの 2 行は機械的に埋まります。本来は `Functor` から順に下から積み上げるべきところを、一番上の `>>=` さえあれば下の段は自動的に埋まる、という関係です。

`liftM` と `ap` の制約は `Monad` なので、この書き方ができるのは `Monad` のインスタンスでもある型に限られます。`Functor` や `Applicative` だけを実装したい型には使えません。

ここで `return` を書いて `pure` を省略すると警告が出ます。

```text:警告
warning: [GHC-06201] [-Wmissing-methods]
    • No explicit implementation for
        ‘pure’
    • In the instance declaration for ‘Applicative Foo’

warning: [-Wnoncanonical-monad-instances]
    Noncanonical ‘return’ definition detected
    in the instance declaration for ‘Monad Foo’.
    ‘return’ will eventually be removed in favour of ‘pure’
    Either remove definition for ‘return’ (recommended) or define as ‘return = pure’
```

`return` は将来 `Monad` から取り除かれる予定だと書かれています。実装するのは `pure` の方だと述べたのはこのためです。

:::message
`Monad` が `Applicative` をスーパークラスに持つようになったのは GHC 7.10（2015 年）からで、AMP（Applicative Monad Proposal）と呼ばれます。それ以前は `Monad` を `Applicative` と無関係に定義でき、`return` も `Monad` 自身のメソッドでした。

このシリーズの初期の回は AMP より前に書かれたもので、`Monad` と `Applicative` を別々のものとして扱っています。古い記事や書籍で両者の関係が説明されていないことがあるのは、多くがこの変更以前のものだからです。
:::

## 練習

【問3】State モナドを自作してください。内部で持つ関数の型は `s -> (a, s)` です。

```hs
import Control.Monad (replicateM_, liftM, ap)

newtype State s a = State { runState :: s -> (a, s) }

-- ここに instance Functor / Applicative / Monad を書く（定型を使う）
-- get' と put' も書く

evalState m s = fst (runState m s)

fib x = (`evalState` (0, 1)) $ do
    replicateM_ (x - 1) $ do
        (a, b) <- get'
        put' (b, a + b)
    (_, b) <- get'
    return b

main = print $ fib 10
```
```text:実行結果
55
```

`>>=` は次の形になります。状態系モナドの練習で書いたものと同じです。

```hs
    m >>= k = State $ \s ->
        let (a, s1) = runState m s
        in  runState (k a) s1
```

`instance` の宣言では、型変数 `s` を含めた `(State s)` の形で書きます。種が `* -> *` になっている必要があるためです。

:::details 解答例
```hs
instance Functor (State s) where
    fmap = liftM

instance Applicative (State s) where
    pure x = State $ \s -> (x, s)
    (<*>)  = ap

instance Monad (State s) where
    m >>= k = State $ \s ->
        let (a, s1) = runState m s
        in  runState (k a) s1

get'   = State $ \s -> (s , s)
put' x = State $ \_ -> ((), x)
```

自分で書いたのは `pure` と `>>=` の 2 つだけです。どちらも「状態 `s` を受け取って、結果と新しい状態の組を返す関数」を組み立てています。`pure` は状態をそのまま通し、`>>=` は `m` を走らせて得た新しい状態 `s1` を `k a` へ渡します。この状態の受け渡しが State の本体で、`fmap` と `<*>` は `liftM`・`ap` 経由で `>>=` から組み立てられます。

以前に書いた `bind`・`return'` を `>>=`・`pure` として `instance` に書き直しただけですが、それによって `do` と `<-` が使えるようになり、`fib` が `do` ブロックとして書けています。
:::

## Tree

`Identity` と `State` は、どちらも「中に値と文脈を持つ入れ物」でした。データ構造そのものがモナドになる例も見ておきます。二分木です。

```hs
data Tree a = Leaf a | Node (Tree a) (Tree a) deriving Show
```

葉に値が入っています。`>>=` は「それぞれの葉を、別の木に差し替える」操作にします。接ぎ木だと思ってください。

ここでは `liftM`・`ap` による定型を使います。

```hs
import Control.Monad (liftM, ap)

data Tree a = Leaf a | Node (Tree a) (Tree a) deriving Show

instance Functor Tree where
    fmap  = liftM

instance Applicative Tree where
    pure  = Leaf
    (<*>) = ap

instance Monad Tree where
    Leaf x   >>= f = f x
    Node l r >>= f = Node (l >>= f) (r >>= f)

grow x = Node (Leaf x) (Leaf (x * 10))

main = do
    let t = Node (Leaf 1) (Leaf 2)
    print $ fmap (* 2) t
    print $ t >>= grow
    print $ do { x <- t; grow x }
```
```text:実行結果
Node (Leaf 2) (Leaf 4)
Node (Node (Leaf 1) (Leaf 10)) (Node (Leaf 2) (Leaf 20))
Node (Node (Leaf 1) (Leaf 10)) (Node (Leaf 2) (Leaf 20))
```

`>>=` の中身は 2 行だけです。

* `Leaf x >>= f = f x` — 葉に来たら、その値を `f` に渡して得られた木で置き換える
* `Node l r >>= f = Node (l >>= f) (r >>= f)` — 枝は左右をそれぞれ辿る

`pure = Leaf` は「値 1 つだけの木」です。`fmap` と `<*>` は定型に任せましたが、`fmap (* 2) t` はちゃんと葉の値を 2 倍にしています。`liftM` が `>>=` と `return` から `fmap` を組み立てているためです。

最後の行は `>>=` を `do` で書いたものです。木というデータ構造が `do` で書けるようになりました。

## 練習

【問4】多分岐の木 `Rose` を `Monad` のインスタンスにしてください。枝が 2 本固定ではなくリストになっています。

```hs
import Control.Monad (liftM, ap)

data Rose a = Leaf a | Node [Rose a] deriving Show

-- ここに instance Functor / Applicative / Monad を書く

grow x = Node [Leaf x, Leaf (x * 10)]

main = do
    let r = Node [Leaf 1, Node [Leaf 2, Leaf 3]]
    print $ fmap (* 2) r
    print $ r >>= grow
```
```text:実行結果
Node [Leaf 2,Node [Leaf 4,Leaf 6]]
Node [Node [Leaf 1,Leaf 10],Node [Node [Leaf 2,Leaf 20],Node [Leaf 3,Leaf 30]]]
```

:::details 解答例
```hs
instance Functor Rose where
    fmap  = liftM

instance Applicative Rose where
    pure  = Leaf
    (<*>) = ap

instance Monad Rose where
    Leaf x  >>= f = f x
    Node ts >>= f = Node (map (>>= f) ts)
```

`Tree` では左右の枝に個別に `>>=` を書いていましたが、枝がリストになったので `map` でまとめて書けます。`(>>= f)` はセクションで、「各枝に `>>= f` を適用する」と読めます。

定型を使わずに `fmap` を手で書くなら次のようになります。枝を辿るのに `map` が必要なところが `>>=` と同じ形です。

```hs
instance Functor Rose where
    fmap f (Leaf x)  = Leaf (f x)
    fmap f (Node ts) = Node (map (fmap f) ts)
```
:::

# まとめ

`Monad` は 3 段の階層の一番上にあります。

|型クラス|メソッド|できること|
|---|---|---|
|`Monad`|`>>=`|前の結果を見て次を決める|
|`Applicative`|`pure`, `<*>`|引数が複数ある関数を適用する|
|`Functor`|`fmap` (`<$>`)|中身に関数を適用する|

上の段は下の段を包含します。`>>=` があれば `fmap` は `liftM`、`<*>` は `ap` で埋まりますが、逆はできません。`ZipList` はその境界にいる実例でした。

モナドを自作するのに必要なのは、実質 `pure` と `>>=` の 2 つだけです。そして書いた瞬間から `do`・`<-`・`return` に加え、`mapM_` や `forM` のような `Monad` を要求する既存の関数がすべて使えるようになります。

なお、本シリーズは途中で 10 年以上中断していましたが、当時は `Monad` の扱いも含めて仕様が動いている最中でした。結果的に、仕様が落ち着いてから続きを書いた形になりました。

# 関連記事

モナド則については、このシリーズの番外編で図を使って説明しています。

https://qiita.com/7shi/items/547b6137d7a3c482fe68

モナドを自作するという同じことを F# のコンピュテーション式で行った記事です。`Bind` と `Return` を書けば `let!` が使えるようになる、という構図は、`>>=` と `pure` を書けば `do` が使えるようになるのと同じです。

http://qiita.com/7shi/items/026c7daa5b0b24d02c0f

# 参考

Applicative スタイルについて参考にしました。

http://d.hatena.ne.jp/kazu-yamamoto/20101211/1292021817

モナド則の `>=>` での書き換えは、以下の記事を参考にしました。

https://qiita.com/tezca686/items/78d099987894ac7bec48

https://qiita.com/tezca686/items/73d135e372d547ad7266
