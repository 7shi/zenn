---
title: "Haskell 型クラス 超入門"
emoji: "🧩"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["haskell", "型クラス", "polymorphism"]
published: true
---

Haskell では**型クラス**と呼ばれる仕組みにより、型ごとに違う実装を選べます。`class`・`instance` による定義から、コンパイラが実装を選ぶ仕組みまで、型クラスの基礎を説明します。

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
1. **Haskell 型クラス 超入門** ← この記事
1. [Haskell モナドとゆかいな仲間たち](https://zenn.dev/7shi/articles/20260807-haskell-monads-and-friends)
1. [Haskell Freeモナド 超入門](https://zenn.dev/7shi/articles/20260808-haskell-free-monad)
1. [Haskell Operationalモナド 超入門](https://zenn.dev/7shi/articles/20260809-haskell-operational-monad)
1. [Haskell Effモナド 超入門](https://zenn.dev/7shi/articles/20260811-haskell-eff-monad)
1. [Haskell アロー 超入門](https://zenn.dev/7shi/articles/20260813-haskell-arrow)

# パラメトリック多相とアドホック多相

同じ名前の関数がいろいろな型に使えることを**多相**（polymorphism）と呼びます。Haskell の多相には性質の異なる 2 種類があり、その違いが今回の記事の軸になります。

まず `id` と `length` を見ます。

```hs:型
id     :: a -> a
length :: [a] -> Int
```

`a` はどんな型にもなれる型変数です。`id` は受け取ったものをそのまま返すだけなので、`a` が `Int` でも `String` でもやることは同じです。`length` も要素の個数を数えるだけで、要素が何型かは関係ありません。実装は 1 つで足ります。

これを**パラメトリック多相**（parametric polymorphism）と呼びます。型変数が何であっても同じ実装が動きます。

次に `show` を見ます。

```hs:型
show :: Show a => a -> String
```

`a -> String` の部分は関数の型を表していますが、その前に `Show a =>` が付いています。これは `a` という型が `Show` という型クラスに属することを示し、型クラス制約と呼ばれます。（詳細は後述します）

`show` は値を文字列に変換する関数なので、`Int` の `123` と `Bool` の `True` ではやることが違います。数値を 10 進表記に直す処理と、`True`・`False` という名前を返す処理は別物です。つまり実装が型ごとに必要です。

これを**アドホック多相**（ad hoc polymorphism）と呼びます。ad hoc はラテン語由来で「その場限りの」という意味で、型ごとに個別に実装することを指します。

:::message
「その場しのぎ」「場当たり的」といったネガティブな含みはなく、あくまで分類上の名前です。
:::

シリーズでこれまで使ってきたものは、ほとんどがアドホック多相の仕組みの上に載っています。

* bind (`>>=`), `return`
* `deriving Show` 👉[代数的データ型](https://qiita.com/7shi/items/1ce76bde464b4a55c143#show)
* `Monad m =>` 👉[リストモナド](https://qiita.com/7shi/items/deb19c4cba933590ffbf#型クラス制約)

これらがどのように機能しているのか、型クラスを定義するところから見ていきます。

:::message
オブジェクト指向で継承を使って実現する多相は**部分型多相**（subtype polymorphism）と呼ばれ、上記のどちらとも別の分類になります。Haskell でも型クラスには継承関係を作れますが、それは「この型クラスに属する型は、あの型クラスにも属する」という型クラス同士の関係です。型そのものには包含関係がなく、ある型を別の型として扱うことができないため、この形の多相はありません。
:::

# class と instance

他言語にある関数のオーバーロード（同じ名前で引数の型が違う関数を複数定義すること）は、型クラスを自分で定義すれば同じようなことができます。👉[代数的データ型](https://qiita.com/7shi/items/1ce76bde464b4a55c143#オーバーロード)

Java のオーバーロードの例です。

```java:Java
class Test {
    public static String foo(int i) {
        if (i == 1) return "one";
        return "other";
    }
    public static String foo(boolean b) {
        if (b) return "ok";
        return "ng";
    }
}
```

Haskell では、関数の名前と型を `class` で定義して、`instance` で型ごとの実装を与えます。

```hs
class Foo a where
    foo :: a -> String

instance Foo Int where
    foo 1 = "one"
    foo _ = "?"

instance Foo Bool where
    foo True  = "ok"
    foo False = "?"

main = do
    putStrLn $ foo (0 :: Int)
    putStrLn $ foo (1 :: Int)
    putStrLn $ foo False
    putStrLn $ foo True
```
```text:実行結果
?
one
?
ok
```

`class Foo a where` の `Foo` が型クラスの名前です。`a` は型変数で、「`Foo` という型クラスに属する型を `a` と呼ぶ」という意味です。その下に `foo :: a -> String` と書くことで、「`Foo` に属する型には `foo` という関数がある」ことを宣言します。この関数を型クラスの**メソッド**と呼びます。

:::message
標準の Haskell（拡張なし）では、`class` に書ける型変数は 1 つだけです。複数の型変数を使うには `MultiParamTypeClasses` 拡張が必要ですが、今回の範囲を超えるため詳細は省略します。
:::

`instance Foo Int where` は「`Int` を `Foo` のインスタンスにする」宣言で、その下にメソッドの実装を書きます。宣言（`class`）と実装（`instance`）が分離しているため、インスタンスは後から好きなだけ追加できます。これはアドホック多相ならではの使い勝手です。

:::message
Java において、`class`（型クラスの宣言）はインターフェース、`instance`（型ごとの実装）はそれを実装するクラスに近い関係です。「クラスを個別に具体化したものがインスタンス」という点は共通していますが、具体化される対象が Haskell では型、Java ではオブジェクトという違いがあります。また、Java では型定義の時点でインターフェースを組み込む必要がありますが、型クラスは型定義とは切り離してインスタンスを後付けできます。
:::

自分で定義した型もインスタンスにできます。以前使った `Color` を使います。👉[代数的データ型](https://qiita.com/7shi/items/1ce76bde464b4a55c143#列挙型)

```hs
data Color = Blue | Red | Green

instance Foo Color where
    foo Blue = "Blue"
    foo _    = "?"

main = do
    putStrLn $ foo Blue
    putStrLn $ foo Green
```
```text:実行結果
Blue
?
```

インスタンスを定義していない型に使うとエラーになります。

```hs:NG
main = putStrLn $ foo (1.0 :: Double)  -- Double のインスタンスがない
```
```text:エラー内容
    • No instance for ‘Foo Double’ arising from a use of ‘foo’
```

## 型注釈が必要な理由

上の例で `foo (0 :: Int)` と型注釈を付けましたが、外すとエラーになります。

```hs:NG
main = putStrLn $ foo 1
```
```text:エラー内容
    • Ambiguous type variable ‘a0’ arising from a use of ‘foo’
      prevents the constraint ‘(Foo a0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘a0’ should be.
      Potentially matching instance:
        instance Foo Int
```

数値リテラルの `1` は `Int` とは限らず、`Integer` や `Double` にもなれます。この時点では型が決まらず、決まらない以上 `foo` のどの実装を使えばよいかも決められないため、曖昧（ambiguous）だとしてエラーになります。

ここで注目したいのは、エラーメッセージ自身が「候補になり得るインスタンス」として `Foo Int` ただ一つを挙げていることです。候補が1つしかないのに、GHC は「では `Int` だろう」とは推論しません。型クラスのインスタンスは後で追加できるため、今見えているインスタンスの数を型推論の根拠にしないのです。あくまで型が先に決まり、決まった型に対して実装を引く、という順序になります。

これは型クラスの核心に関わる現象なので、後で改めて扱います。ここでは「実装を選ぶには型が決まっている必要がある」とだけ覚えておいてください。

# デフォルト実装

`class` の中にはメソッドの型だけでなく、実装を書いておくこともできます。これを**デフォルト実装**と呼びます。`instance` 側で書かなければ、そちらが使われます。

標準の `Eq` がその例です。

```hs:Eqの定義（抜粋）
class Eq a where
    (==), (/=) :: a -> a -> Bool
    x == y = not (x /= y)
    x /= y = not (x == y)
```

`==` と `/=` が互いのデフォルト実装になっているため、どちらか一方を実装すればもう一方が付いてきます。

:::message
どちらも実装しなくてもコンパイルは通りますが、`No explicit implementation for either ‘==’ or ‘/=’` という警告が出ます。実行すると無限に呼び合ってしまいます。
:::

```hs
data Color = Blue | Red | Green

instance Eq Color where
    Blue  == Blue  = True
    Red   == Red   = True
    Green == Green = True
    _     == _     = False

main = do
    print $ Blue == Blue
    print $ Blue == Red
    print $ Blue /= Red     -- 定義していないが使える
    print $ Blue /= Blue
```
```text:実行結果
True
False
True
False
```

`/=` は一切書いていませんが、デフォルト実装の `not (x == y)` が働きます。

このように「最低限これだけ実装すればよい」という組み合わせを**最小完全定義**（minimal complete definition）と呼びます。GHCi の `:i` で確認できます。

```text:GHCi
ghci> :i Eq
type Eq :: * -> Constraint
class Eq a where
  (==) :: a -> a -> Bool
  (/=) :: a -> a -> Bool
  {-# MINIMAL (==) | (/=) #-}
（略）
```

`MINIMAL (==) | (/=)` が最小完全定義で、`|` は「どちらか」を表します。両方とも書かなければデフォルト実装同士が無限に呼び合ってしまうため、少なくとも一方は必要です。

## 練習

【問1】次の `data` と `main` がそのまま動くように、型クラス `Shape` とそのインスタンスを定義してください。

```hs
data Circle = Circle Double
data Rect   = Rect Double Double

-- ここに class Shape と instance を書く

main = do
    putStrLn $ name (Circle 1) ++ ": " ++ show (area (Circle 1))
    putStrLn $ name (Rect 2 3) ++ ": " ++ show (area (Rect 2 3))
```
```text:実行結果
円: 3.141592653589793
図形: 6.0
```

`Shape` は面積を求める `area` と名前を返す `name` の 2 つのメソッドを持ちます。`name` にはデフォルト実装として `"図形"` を与えておき、`Circle` 側だけ `"円"` で上書きしてください。

:::details 解答例
```hs
class Shape a where
    area :: a -> Double
    name :: a -> String
    name _ = "図形"          -- デフォルト実装

instance Shape Circle where
    area (Circle r) = pi * r * r
    name _ = "円"            -- 上書き

instance Shape Rect where
    area (Rect w h) = w * h  -- name はデフォルト実装のまま
```

`area` にはデフォルト実装がないため、どちらのインスタンスでも実装が必要です。`name` は `Rect` では省略したのでデフォルト実装が使われます。
:::

# deriving

`class` と `instance` が分かったところで、これまで使ってきた `deriving` を振り返ります。その正体はインスタンス定義の自動生成です。👉[代数的データ型](https://qiita.com/7shi/items/1ce76bde464b4a55c143#show)

```hs:derivingを使う
data Color = Blue | Red | Green deriving (Show, Read)

main = do
    print Blue
    print (read "Red" :: Color)
```
```text:実行結果
Blue
Red
```

`Show` は値を文字列にする型クラス、`Read` はその逆で文字列から値に戻す型クラスです。`read` は変換先の型が決まらないと実装を選べないため、`:: Color` と型注釈を付けています。

`deriving` できるのが標準の 6 種類（`Eq`・`Ord`・`Enum`・`Bounded`・`Show`・`Read`）に限られているのは、型の構造から機械的に実装が決まるものだけだからです。

|型クラス|機械的に決まる根拠|
|---|---|
|`Show` / `Read`|コンストラクタの名前をそのまま文字列にする|
|`Eq`|同じコンストラクタで、中身も等しいか|
|`Ord` / `Enum`|`data` に書いた順番|
|`Bounded`|最初と最後のコンストラクタ|

:::message
機械的に実装が決まらないものは自動生成できません。
:::

## 練習

【問2】`deriving Read` と同じように `read` が使えるように、`instance Read Color` を手で書いてください。

```hs
data Color = Blue | Red | Green deriving Show

-- ここに instance Read Color を書く

main = do
    print (read "Blue"  :: Color)
    print (read "Red"   :: Color)
    print (read "Green" :: Color)
```
```text:実行結果
Blue
Red
Green
```

`Read` のメソッドは `readsPrec` です。

```hs:型
readsPrec :: Int -> String -> [(a, String)]
```

第 1 引数は優先順位ですが、今回は使わないので `_` で受けて構いません。残りは「文字列を受け取り、（読み取った値, 残りの文字列）の候補をリストで返す」という形です。読めなければ空リストを返します。

ここでは文字列全体がコンストラクタ名と完全に一致する場合だけを扱うことにして、残りの文字列は常に空とします。

:::details 解答例
```hs
instance Read Color where
    readsPrec _ "Blue"  = [(Blue,  "")]
    readsPrec _ "Red"   = [(Red,   "")]
    readsPrec _ "Green" = [(Green, "")]
    readsPrec _ _       = []
```

`show` に比べると戻り値が複雑です。文字列から値への変換は、読み取れない場合や途中まで読んだ場合があるためです。（値, 残りの文字列）を返す形は、構文解析でパーサに持たせた形と同じです。👉[構文解析](https://qiita.com/7shi/items/b8c741e78a96ea2c10fe#動作原理)

この実装は完全一致しか扱わないため、`deriving Read` のように前後の空白を読み飛ばしたり、リストの中に現れる `Color` を読んだりはできません。
:::

# Num

`deriving` できない型クラスの例として `Num` を取り上げます。数値の演算をまとめた型クラスで、これまで当たり前に使ってきた `+` もそのメソッドです。

```hs:型
(+) :: Num a => a -> a -> a
```

`+` は特別な構文ではありません。`Int` でも `Double` でも `+` が使えるのは、どちらも `Num` のインスタンスだからです。これもアドホック多相で、整数の足し算と浮動小数点数の足し算は実装が別物です。

`Num` の中身を見てみます。

```text:GHCi
ghci> :i Num
type Num :: * -> Constraint
class Num a where
  (+) :: a -> a -> a
  (-) :: a -> a -> a
  (*) :: a -> a -> a
  negate :: a -> a
  abs :: a -> a
  signum :: a -> a
  fromInteger :: Integer -> a
  {-# MINIMAL (+), (*), abs, signum, fromInteger, (negate | (-)) #-}
（略）
```

続けてインスタンスの一覧も表示され、標準では `Int`・`Integer`・`Word`・`Float`・`Double` が挙がります。

メソッドは 7 つですが、最小完全定義を見ると `negate | (-)` だけが `|` で結ばれています。引き算 `x - y` は `x + negate y`、符号反転 `negate x` は `0 - x` と、互いをデフォルト実装にできるためです。`Eq` の `==` と `/=` と同じ関係です。

裏を返せば、それ以外のメソッドはすべて実装が必要です。省略してもコンパイルは通りますが、`No explicit implementation for` という警告が出ます。`negate` と `-` はどちらか一方を書けばよいため、両方を省いたときだけ `(either ‘negate’ or ‘-’)` という形で警告に現れます。

割り算が入っていないことにも注意してください。

```text:GHCi
ghci> :t (/)
(/) :: Fractional a => a -> a -> a
```

`/` は `Fractional` という別の型クラスのメソッドです。整数どうしの割り算は結果が整数にならないため、`Num` の段階では持てません。数値の型クラスはこのように細かく分かれており、型ごとにできることが型クラスで表されています。

最後の `fromInteger` は整数リテラルの変換です。ソースに書いた `1` は `Num a => a` という型を持ち、どの数値型にもなれます。

```text:GHCi
ghci> :t 1
1 :: Num a => a
```

自作の型でも `fromInteger` を実装すれば、数値リテラルをそのままその型として書けるようになります。numpy のブロードキャストのように数値が要素全体に配られる書き味になりますが、効くのは数値リテラルだけです。`x = 1 :: Int` のように変数を経由すると型が合わずエラーになります。

これらの実装は、いずれも型の構造からは決まりません。`data` に書いたコンストラクタをいくら眺めても「足すとは何か」は出てこないため、`Num` は `deriving` できません。自作の型で `+` を使いたければ、意味の方を自分で与える必要があります。

## 練習

【問3】2 次元ベクトル `Vec` で `+`・`-`・`negate` が使えるように、`instance Num Vec` を書いてください。

```hs
data Vec = Vec Double Double deriving Show

-- ここに instance Num Vec を書く

main = do
    print $ Vec 1 2 + Vec 3 4
    print $ Vec 1 2 - Vec 3 4
    print $ negate (Vec 1 2)
    print $ Vec 1 2 + Vec 3 4 - Vec 1 1
```
```text:実行結果
Vec 4.0 6.0
Vec (-2.0) (-2.0)
Vec (-1.0) (-2.0)
Vec 3.0 5.0
```

`Num` のメソッドは `+`・`-`・`*`・`negate`・`abs`・`signum`・`fromInteger` です。使わないメソッドは `= undefined` で構いません。

:::details 解答例
```hs
instance Num Vec where
    Vec a b + Vec c d = Vec (a + c) (b + d)
    Vec a b - Vec c d = Vec (a - c) (b - d)
    negate (Vec a b)  = Vec (negate a) (negate b)
    (*)         = undefined
    abs         = undefined
    signum      = undefined
    fromInteger = undefined
```

`Num` のインスタンスを書いただけで、自作の型に `+` や `-` が使えるようになりました。演算子のオーバーロードがアドホック多相として実現されている例です。`undefined` を並べず省略した場合は、`‘*’, ‘abs’, ‘signum’, and ‘fromInteger’` が実装されていないという警告が出ます。

`fromInteger` も実装すると、数値リテラルが `Vec` になります。

```hs:fromIntegerを実装した場合
    fromInteger n = Vec (fromInteger n) (fromInteger n)
```
```hs
main = do
    print (fromInteger 1 :: Vec)
    print $ Vec 1 2 + 1
    print $ sum [Vec 1 1, Vec 2 2, Vec 3 3]
```
```text:実行結果
Vec 1.0 1.0
Vec 2.0 3.0
Vec 6.0 6.0
```

`fromInteger 1` が `Vec 1 1` を返すため、`Vec 1 2 + 1` の `1` も `Vec 1 1` として解釈されます。`sum` が動くのも、初期値の `0` が `Vec 0 0` になるためです。
:::

# 型クラス制約

冒頭で触れた**型クラス制約**を詳しく見ます。まず GHCi で `show` の型を確認します。

```hs
ghci> :t show
show :: Show a => a -> String
```

`a -> String` の前に `=>` で区切って書かれた `Show a` の部分が型クラス制約です。「`a` は `Show` のインスタンスでなければならない」という要求を表しています。

この `show` は `Show` 型クラスのメソッドです。定義を見ると、制約なしで書かれています。

```hs:Showの定義（抜粋）
class Show a where
    show :: a -> String
```

`Show` に属する型を `a` と呼ぶという前提が `class` の宣言で与えられているためです。この `show` を外から使うときは前提が明示されている必要があるため、`Show a =>` が付いた型になります。

制約は自作の関数にも書けます。`Eq` のメソッド `==` を使う関数を定義してみます。

```hs
same :: Eq a => a -> a -> String
same x y = if x == y then "same" else "different"
```

`Eq a =>` は「`a` は `Eq` のインスタンスでなければならない」、言い換えると「`a` に `==` の実装があること」を要求しています。この要求があるおかげで、関数の中で `==` が使えます。

:::message
型注釈から `Eq a =>` を省いて `same :: a -> a -> String` だけにするとエラーになります。型変数のままではどの実装を呼べばよいか分からないためです。

逆に、型注釈自体を省略するのは問題ありません。`x == y` を書いた時点で「`a` に `==` の実装が必要」ということが決まり、`Eq a =>` は型推論によって自動的に付くためです。
:::

制約は複数書けます。括弧で囲んでカンマで区切ります。

```hs
describe :: (Eq a, Show a) => a -> a -> String
describe x y = show x ++ (if x == y then " == " else " /= ") ++ show y

main = do
    putStrLn $ describe (1 :: Int) 1
    putStrLn $ describe 'a' 'b'
```
```text:実行結果
1 == 1
'a' /= 'b'
```

## instance 側の制約

制約は `instance` にも書けます。標準の `Show` にこの形があります。

```hs:Showの定義（抜粋）
instance Show a => Show [a] where
    （略）
```

「`a` が `Show` のインスタンスなら、`[a]` も `Show` のインスタンスになる」という意味です。リストの表示は各要素を `show` で文字列に変換して `,` で繋いで `[]` で囲むため、`a` は `Show` のインスタンスである必要があります。それを表しているのが制約 `Show a =>` です。

`print [1,2,3]` が動いているのはこの仕組みによります。自分で定義した型でも同じです。`deriving Show` が生成するのは `Color` 自身のインスタンスだけですが、それをリストや `Maybe` に包んでも表示できます。

```hs
data Color = Blue | Red | Green | White deriving Show

main = do
    print [Blue, Red]
    print [[Blue], [Red, Green]]
    print (Just [Blue, Red])
```
```text:実行結果
[Blue,Red]
[[Blue],[Red,Green]]
Just [Blue,Red]
```

`[Color]`・`[[Color]]`・`Maybe [Color]` がすべて表示できるのは、インスタンスが制約を辿って再帰的に組み立てられるためです。

# 型注釈で実装が選ばれる

ここまでに見たメソッドは、`foo :: a -> String` のように型変数が引数に現れていました。渡した値の型を見れば実装が決まります。

しかし実装を選ぶ手掛かりは型そのものであって、引数に限りません。型さえ決まればよいので、戻り値や値であっても型注釈で指定すれば実装が選べます。

```hs
main = do
    print (read "1" :: Int)
    print (read "1" :: Double)
    print (return 1 :: [Int])
    print (return 1 :: Maybe Double)
    print (minBound :: Int)
    print (minBound :: Bool)
```
```text:実行結果
1
1.0
[1]
Just 1.0
-9223372036854775808
False
```

同じ `read "1"` という式が、`:: Int` を付ければ整数に、`:: Double` を付ければ小数になります。文字列は同じなのに結果が変わるのは、型が実装を選んでいるからです。

`return 1` も同様で、リストなら要素が 1 つのリスト、`Maybe` なら `Just` になります。どちらの実装が使われるかは型注釈だけが決めています。

`minBound` は引数がないため、型注釈以外に手掛かりがありません。それでも `Int` なら最小の整数、`Bool` なら `False` と、型に応じた値が得られます。

:::message
Java のオーバーロードは引数の型で選び分けるもので、引数が同じで戻り値の型だけが違うメソッドは定義できません。型クラスにはこの制限がなく、戻り値の型だけが手掛かりでも実装を選べます。
:::

## ambiguous type variable

型注釈を外すと型が決まらず、エラーになります。

```hs:NG
main = print (read "123")
```
```text:エラー内容
    • Ambiguous type variable ‘a0’ arising from a use of ‘print’
      prevents the constraint ‘(Show a0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘a0’ should be.
（略）
    • Ambiguous type variable ‘a0’ arising from a use of ‘read’
      prevents the constraint ‘(Read a0)’ from being solved.
      Probable fix: use a type annotation to specify what ‘a0’ should be.
```

`read` は文字列を受け取って何かの型を返しますが、`print` はどんな型でも表示できてしまうため、間に挟まった型が最後まで決まりません。これは Haskell を書いていると必ず一度は踏むエラーです。`Ambiguous type variable` を見たら「型注釈が足りない」と読み替えてください。

`class と instance` の節で `foo 1` が通らなかったのも同じ理由です。

## 数値リテラルだけ注釈が不要な理由

一方で `print 1` は注釈なしで動きます。

```hs
main = do
    print 1
    print (1 + 2)
```
```text:実行結果
1
3
```

`1` の型は `Num a => a` で本来は曖昧なのですが、数値については**型のデフォルト規則**（type defaulting）があり、決まらない場合は `Integer`（小数が絡めば `Double`）が選ばれます。数値リテラルを書くたびに `:: Int` と注釈するのは煩雑すぎるための特例です。

この規則が働くのは標準の型クラスだけで、自分で定義した `Foo` のような型クラスには適用されません。`foo 1` がエラーになったのはそのためです。

# スーパークラス

型クラスには継承関係を持たせられます。`class` の宣言に制約を書くと、それが**スーパークラス**になります。

```hs:Ordの定義（抜粋）
class Eq a => Ord a where
    compare :: a -> a -> Ordering
    (<)  :: a -> a -> Bool
    （略）
```

「`Ord` のインスタンスであるためには `Eq` のインスタンスでもあること」という要求です。大小比較ができるなら等値比較もできるはずだ、という関係が型で表現されています。

この関係は `deriving` にも現れます。以前に `deriving (Eq, Ord, Enum, Read, Show, Bounded)` と並べて書いていたのは、`Ord` を導出するには `Eq` も一緒に導出しておく必要があるためです。👉[代数的データ型](https://qiita.com/7shi/items/1ce76bde464b4a55c143#bool)

## Semigroup と Monoid

もう一組、実際に使われる例を見ます。ログなどを蓄積していく Writer モナドは、蓄積する値の型 `w` に `Monoid` という型クラス制約を要求します。複数の値を 1 つにまとめる操作と、何も蓄積していない初期値の両方が必要になるためです。👉[状態系モナド](https://qiita.com/7shi/items/2e9bff5d88302de1a9e9#writerモナド)

```hs:定義（抜粋）
class Semigroup a where
    (<>) :: a -> a -> a

class Semigroup a => Monoid a where
    mempty :: a
```

2 段構えになっています。

|型クラス|持つもの|意味|
|---|---|---|
|`Semigroup`|`<>`|2 つを**結合**できる|
|`Monoid`|`<>` と `mempty`|結合できて、**単位元**もある|

`Semigroup`（半群）は結合の演算 `<>` だけを持つ段階です。`Monoid`（モノイド）はそれに加えて、結合しても何も変わらない値 `mempty`（単位元）を持ちます。リストなら `<>` が `++`、`mempty` が `[]` です。文字列も同じです。

```hs
main = do
    print $ "abc" <> "def"
    print $ [1,2] <> [3 :: Int]
    print (mempty :: String)
    print (mempty :: [Int])
```
```text:実行結果
"abcdef"
[1,2,3]
""
[]
```

`mempty` は前節で見た「引数に型変数が現れない」メソッドそのものです。`:: String` と `:: [Int]` という型注釈だけで実装が選ばれています。

自分の型をインスタンスにしてみます。カウントを表す型で、`<>` を足し算、`mempty` を `0` とします。

```hs
newtype Count = Count Int deriving Show

instance Semigroup Count where
    Count a <> Count b = Count (a + b)

instance Monoid Count where
    mempty = Count 0

main = do
    print $ Count 1 <> Count 2
    print (mempty :: Count)
    print $ mconcat [Count 1, Count 2, Count 3]
```
```text:実行結果
Count 3
Count 0
Count 6
```

`mconcat` は `Monoid` のメソッドで、リストをまとめて結合します。`mempty` から始めて `<>` で畳み込むだけなので、デフォルト実装が用意されており、こちらで書く必要はありません。

`Semigroup` のインスタンスを書かずに `Monoid` だけ書くとエラーになります。

```hs:NG
newtype Count = Count Int deriving Show

instance Monoid Count where
    mempty = Count 0
```
```text:エラー内容
    • No instance for ‘Semigroup Count’
        arising from the superclasses of an instance declaration
    • In the instance declaration for ‘Monoid Count’
```

`arising from the superclasses`（スーパークラスに由来する）と、はっきり書かれています。

:::message
用語は数学に由来します。集合と、その上の二項演算（2 つの要素から 1 つの要素を作る演算）に、満たすべき規則を少しずつ足していくと、「マグマ→半群→モノイド→群」という階層が構成されます。👉[参考](https://mathlog.info/articles/e4aD1MZfKjQKcNO4ilRG)

|名前|規則|
|---|---|
|マグマ|演算の結果が集合からはみ出さない `(<>) :: a -> a -> a`|
|半群|＋結合法則 `(a <> b) <> c == a <> (b <> c)`|
|モノイド|＋単位元 `mempty <> a == a`、`a <> mempty == a`|
|群|＋逆元（演算すると単位元に戻る相手がある）|

マグマの条件は Haskell では自動的に満たされます。上記の型そのものが「結果が `a` からはみ出さない」ことを保証しているためです。

逆に言えば、`Semigroup` の宣言が型として要求しているのはマグマまでです。結合法則はコンパイラが検査できないため、インスタンスを書く側が守るべき約束として文書で定められています。`Monoid` も同様で、`mempty` という値の存在は型で要求できますが、それが本当に単位元として振る舞うかは検査されません。

Haskell が型クラスにしているのは半群とモノイドの 2 段階だけです。リストは連結の逆演算がないため群にはなれず、モノイドで止まります。
:::

## Writer

Writer モナドは計算の結果とは別に値を書き出していくモナドで、書き出しには `tell` を使い、`runWriter` で「結果と書き出された値」の組を取り出します。👉[状態系モナド](https://qiita.com/7shi/items/2e9bff5d88302de1a9e9#writerモナド)

`tell` の型は次の通りです。

```hs:型
tell :: Monoid w => w -> Writer w ()
```

`w` が `Monoid` であることを要求しています。`tell` は状態を上書きするのではなく追記する操作でしたが、その「追記」の実体が `<>` です。そして何も書き込んでいない初期状態が `mempty` です。これまで Writer モナドで主にリストを使っていたのは、リストが `Monoid` のインスタンスで `<>` が `++` になるためでした。

`Count` を載せれば、リスト以外でも Writer が使えます。

```hs
import Control.Monad.Writer

newtype Count = Count Int deriving Show

instance Semigroup Count where
    Count a <> Count b = Count (a + b)

instance Monoid Count where
    mempty = Count 0

test :: Writer Count ()
test = do
    tell (Count 1)
    tell (Count 2)
    tell (Count 3)

main = print $ runWriter test
```
```text:実行結果
((),Count 6)
```

ログを溜め込む代わりに合計だけを取る Writer になりました。Writer 側は何も変えていません。`Monoid` のインスタンスを差し替えるだけで振る舞いが変わるのがアドホック多相です。

## 練習

【問4】最大値を保持する型 `MaxInt` について、次のコードがそのまま動くように `Semigroup` と `Monoid` のインスタンスを定義してください。

```hs
import Control.Monad.Writer

newtype MaxInt = MaxInt Int deriving Show

-- ここに instance Semigroup と instance Monoid を書く

test :: [Int] -> Writer MaxInt ()
test = mapM_ (tell . MaxInt)

main = do
    print $ mconcat [MaxInt 3, MaxInt 1, MaxInt 4]
    print $ runWriter (test [3, 1, 4, 1, 5, 9, 2, 6])
```
```text:実行結果
MaxInt 4
((),MaxInt 9)
```

`<>` は 2 つの値の大きい方を返します。`mempty` はその単位元です。

:::details 解答例
```hs
instance Semigroup MaxInt where
    MaxInt a <> MaxInt b = MaxInt (max a b)

instance Monoid MaxInt where
    mempty = MaxInt minBound
```

単位元は「`max` を取っても相手が変わらない値」なので、`Int` の最小値 `minBound` になります。ここでも `minBound` が戻り値の型だけで決まるメソッドです。
:::

# 型引数を取る型クラス

ここまでに出てきた型クラスは `Int`・`Bool`・`Color` のような型に付いていました。型クラスはもう 1 種類あります。

`Maybe` や `[]` は、単独では型になりません。`Maybe Int` や `[] Int`（`[Int]` の別表記）のように型を 1 つ受け取って初めて型になります。こういうものにも型クラスは付けられます。

```hs
class Container f where
    empty :: f a
    wrap  :: a -> f a

instance Container Maybe where
    empty = Nothing
    wrap  = Just

instance Container [] where
    empty  = []
    wrap x = [x]

main = do
    print (empty  :: Maybe Int)
    print (wrap 1 :: Maybe Int)
    print (empty  :: [Int])
    print (wrap 1 :: [Int])
```
```text:実行結果
Nothing
Just 1
[]
[1]
```

`class Container f where` の `f` に入るのは `Maybe` や `[]` です。メソッドの型に `f a` と書かれている通り、`f` は単独では使わず、型 `a` を受け取った形で現れます。

:::message
`empty` は引数に `f` も `a` も現れないため、これまでの `mempty`・`minBound` と同じく型注釈がないと実装が決まりません。上記で `empty :: Maybe Int` と書いているのはそのためです。
:::

この「型の型」を**種**（kind）と呼びます。GHCi の `:k` で確認できます。

```text:GHCi
ghci> :k Int
Int :: *
ghci> :k Bool
Bool :: *
ghci> :k Maybe
Maybe :: * -> *
ghci> :k []
[] :: * -> *
ghci> :k IO
IO :: * -> *
ghci> :k Either
Either :: * -> * -> *
```

`*` が「そのままで型であるもの」を表します。`Maybe` は `* -> *` で、型を 1 つ受け取って型を返します。関数の型と同じ読み方です。`Either` は 2 つ受け取ります。

型クラスの種も見られます。

```text:GHCi
ghci> :k Show
Show :: * -> Constraint
ghci> :k Container
Container :: (* -> *) -> Constraint
```

まず矢印 `->` の右側を見ます。ここが `*` ではなく `Constraint` になっています。`Constraint` は**型クラス制約**を表します。上で見た `Maybe :: * -> *` が型を受け取って型を返すのに対し、`Show :: * -> Constraint` は型を受け取って制約を返します。`Show Int` は型ではなく、`show :: Show a => a -> String` の `Show a` の位置に書けるもの、と解釈できます。

```text:GHCi
ghci> :k Maybe Int
Maybe Int :: *
ghci> :k Show Int
Show Int :: Constraint
```

`Maybe` に `Int` を与えると型ができますが、`Show` に `Int` を与えても型にはならず、制約ができます。値を持てるのは `*` だけなので、`Show Int` 型の値というものは存在しません。

次に矢印の左側を見ます。`Show` は `*` を、`Container` は `* -> *` を受け取ります。型クラスが 2 種類あることが分かります。

|種|型クラスの例|インスタンスの例|
|---|---|---|
|`*`|`Show`, `Eq`, `Ord`, `Monoid`|`Int`, `Bool`, `Color`|
|`* -> *`|`Container`, `Monad`|`Maybe`, `[]`, `IO`|

種が合わないインスタンスは書けません。

```hs:NG
instance Container Int where
    empty  = 0
    wrap _ = 0
```
```text:エラー内容
    • Expected kind ‘* -> *’, but ‘Int’ has kind ‘*’
    • In the first argument of ‘Container’, namely ‘Int’
```

`Int` は `*` なので、`Container` が要求する `* -> *` に合いません。型に型が付くのと同じように、種が合わないものは弾かれます。

表に入れた `Monad` も、種が `* -> *` の型クラスです。

```text:GHCi
ghci> :k Monad
Monad :: (* -> *) -> Constraint
```

`IO`・`[]`・`Maybe` といったモナドがどれも型引数を 1 つ取っていたのは、`Monad` がこの種の型クラスだからです。`Monad` とその周辺の型クラスは次回に扱います。

# 辞書渡し

最後に、アドホック多相が実行時にどのように処理されているのかを見ます。

`Eq` を例に説明します。簡単のためメソッドは `==` だけに絞ります。

型クラス制約は、コンパイラが `Eq` からメソッドの実装をまとめたレコード型 `EqDict` を自動生成し、`Eq a =>` を `EqDict a ->` という隠れた引数に変換することで実現されています。このレコードを**辞書**（dictionary）と呼びます。

```hs
-- 型クラス制約を使った元のコード
same :: Eq a => a -> a -> String
same x y = if x == y then "same" else "different"

-- コンパイラが変換した後のコード
same :: EqDict a -> a -> a -> String
same d x y = if eqM d x y then "same" else "different"
```

データ型定義まで含めてコードとして書き下してみます。

```hs
-- class → メソッドをまとめたレコード型
data EqDict a = EqDict { eqM :: a -> a -> Bool }

-- instance → そのレコードの値
dEqInt :: EqDict Int
dEqInt = EqDict (==)

dEqBool :: EqDict Bool
dEqBool = EqDict (==)

-- 型クラス制約 (Eq a =>) → 隠れた引数
same :: EqDict a -> a -> a -> String
same d x y = if eqM d x y then "same" else "different"

main = do
    putStrLn $ same dEqInt  1 1
    putStrLn $ same dEqBool True False
```
```text:実行結果
same
different
```

対応関係をまとめます。

|型クラスの構文|辞書渡しでの姿|
|---|---|
|`class`|メソッドをまとめたレコード型|
|`instance`|そのレコードの値|
|`Eq a =>`|隠れた引数|
|メソッドの呼び出し|レコードのフィールドの取り出し|

要点としては、`=>` の左側は、実行時には `->` の引数になっています。

:::message
これは意味論としての説明です。実際の GHC は最適化で辞書渡しを消してしまうことが多く（型が具体的に分かる箇所は特殊化して直接呼び出しにする）、生成されるコードが常にこの形とは限りません。
:::

この見方を持つと、これまでに見た「戻り値の型だけで実装が選べる」ことと、「型注釈が必要な理由」で見た ambiguous エラーが、同じ理由から出てくることが分かります。

## 戻り値の型だけで実装が選べる理由

辞書は値とは独立した引数なので、引数に型変数が現れる必要がありません。`mempty` を辞書で書けばこうなります。

```hs
data MonoidDict a = MonoidDict
    { appendM :: a -> a -> a
    , emptyM  :: a
    }

dMonoidList :: MonoidDict [b]
dMonoidList = MonoidDict (++) []

main = do
    print (emptyM dMonoidList :: String)
    print (appendM dMonoidList "abc" "def")
```
```text:実行結果
""
"abcdef"
```

`emptyM dMonoidList` は辞書を渡しただけで値が出てきます。オブジェクト指向では、オブジェクト自身が実装表（vtable）を持ち歩くため、値がなければメソッドを呼べません。Haskell は辞書が値から独立しているので、型さえ決まれば値がなくても実装を選べます。

## ambiguous エラーになる理由

型が決まらないということは、渡すべき辞書が決まらないということです。「曖昧」の正体はこれです。先に「型注釈が必要な理由」で見た `foo 1` の例で言うと、`foo` は辞書渡しで書けば `foo :: FooDict a -> a -> String` です。`1` だけでは `a` が `Int` なのか他の数値型なのか決まらず、`dFooInt` を渡せばよいのか判断できません。辞書という「隠れた引数」を埋められないことこそが、ambiguous エラーの正体です。

## スーパークラス

スーパークラスも辞書の構造として説明できます。`class Eq a => Ord a where` という宣言は、`OrdDict` が中に `EqDict` をフィールドとして持つ形に変換されます。

```hs
data EqDict a = EqDict { eqM :: a -> a -> Bool }

data OrdDict a = OrdDict
    { ordEqDict :: EqDict a       -- スーパークラスの辞書
    , compareM  :: a -> a -> Ordering
    }

dEqInt :: EqDict Int
dEqInt = EqDict (==)

dOrdInt :: OrdDict Int
dOrdInt = OrdDict dEqInt compare

-- Ord a => a -> a -> String が OrdDict a -> a -> String に変換された形
sameViaOrd :: OrdDict a -> a -> a -> String
sameViaOrd d x y = if eqM (ordEqDict d) x y then "same" else "different"

main = putStrLn $ sameViaOrd dOrdInt 1 1
```
```text:実行結果
same
```

`sameViaOrd` は `compareM`（`Ord` のメソッド）を一切使っていませんが、`ordEqDict d` を辿るだけで `Eq` の辞書が取り出せるため、`eqM` が呼べます。`Ord a =>` と書くだけで `==` まで使えるのは、この入れ子構造のおかげです。スーパークラスの制約を並べて書く（`Eq a, Ord a =>` のように）必要がないのも、`Ord` の辞書が `Eq` の辞書を包含しているからです。

:::message
この「フィールドとして埋め込む」形は、Go 言語の構造体埋め込み（embedding）と発想が似ています。Go にはクラス継承がありませんが、構造体の中に別の構造体を無名フィールドとして埋め込むと、埋め込んだ側が持つメソッドをそのまま呼び出せるようになります。`OrdDict` が `EqDict` を中に持つことで `eqM` まで使えるようになるのと同じ仕組みです。継承ではなく合成（コンポジション）によって「上位互換」の型を組み立てる、という点が共通しています。
:::

# まとめ

型クラスはアドホック多相、つまり型ごとに違う実装を選ぶ仕組みです。

|   |実装|制約|例|
|---|---|---|---|
|パラメトリック多相|すべての型で同じ|なし|`id`, `length`|
|アドホック多相|型ごとに違う|`=>` が付く|`show`, `==`, `return`|

`class` で宣言し、`instance` で型ごとに実装します。デフォルト実装を書いておけば `instance` 側を省略でき、その最低限が最小完全定義です。`deriving` はインスタンス定義の自動生成で、構造から機械的に決まるものに限られます。スーパークラスで階層を作れます。

型クラスは `Int` のような型だけでなく、`Maybe` のように型を受け取る型（種が `* -> *`）にも付けられます。`Container` や `Monad` がその例で、種が合わなければインスタンスは書けません。

そして実装を選ぶのは値ではなく型です。そのため `read s :: Int` のように戻り値の型だけで実装が決まり、型が決まらなければ ambiguous エラーになります。これは、制約が実行時の隠れた引数（辞書）になっているためです。

シリーズでずっと使ってきた `return :: Monad m => a -> m a` も同じ形です。`IO`・`[]`・`Maybe`・`Cont` のどれにもなれたのは、`m` が決まった時点でその `Monad` インスタンスの実装が選ばれていたからです。

# 関連記事

型クラスはオブジェクト指向のインターフェースと似ていて、特に F# では書式まで似ています。しかし細かく見ると違いがあります。

http://qiita.com/7shi/items/cd7f65a898dd5696c73d

スーパークラスの応用例です。ベクトル空間・ノルム空間・計量ベクトル空間という数学的な空間の階層を、そのまま型クラスの継承で表現しています。

http://qiita.com/7shi/items/0bd828489aa176252fe8
