# 継続モナドによるジェネレーターは Haskell で書けるか

対象: Qiita 記事「CPS 変換から継続モナドへ」
（<https://qiita.com/7shi/items/27b6f3169961299a6195>、
qiita リポジトリの `series/cps-to-continuation/03-cps-to-continuation-monad.md`）

記事の記述:

> Haskell ではジェネレーターから継続を返す部分で型が循環してエラーになるため、単純に書き直しただけでは移植できません。
> ジェネレーターの例は単純な書き直しではコンパイルを通せないため、Haskell では実装していません。

## 結論

**書ける。** 循環する型を `data`（または `newtype`）で包むだけで通る。GHC 9.6.6 で確認。

## 何が循環しているか（詳細）

### 循環の出どころ

`Cont r a` の `r` は「答えの型」（`runCont :: (a -> r) -> r`）。ジェネレーターでは
`next` が `Cont` を返し、その `Cont` の答えの型は `next` 自身を含むレコードになる。
つまりレコードの型を `It` とすると

```
It = (Maybe Int, () -> Cont It b)
```

右辺に `It` が現れる。展開すると止まらない（無限の型）。

### なぜ Haskell では通らないのか

Haskell（HM 型推論）の型は**有限の木**で、型の等価性は構造的に判定する。
単一化では `t ~ f(t)` の形（左辺の変数が右辺に出現する）を occurs check で弾く。
無限に展開される型は表現できないので、循環はそのままでは扱えない。

`type` シノニムは「展開されるだけの別名」なので有限の木にならず、宣言の時点で弾かれる:

```hs
type It = (Maybe Int, () -> Cont It It)
```

```
error: Cycle in type synonym declarations
```

→ `GenSynonym.hs`

型注釈を書かずに推論に任せても同じところに行き着く。ただし `r` が多相なままの間は
エラーにならず、`evalCont` で `r` をレコード型に固定した瞬間に出る（`GenInfer.hs`）:

```
error: [GHC-27958]
    • Couldn't match type ‘b0’
                     with ‘a0
                           -> Control.Monad.Trans.Cont.ContT
                                (Maybe Int, b0) Data.Functor.Identity.Identity b1’
```

`b0` の中に `b0` が現れていて、これが循環そのもの。
（標準の `Cont r a` は `ContT r Identity a` の別名なのでメッセージが冗長になる。
自前定義の `Cont` で試すと `b0` と `a0 -> Cont (Maybe Int, b0) b1` の不一致と表示され、
言っていることは同じ。）

### なぜ data だと通るのか

`data`/`newtype` は**名前による（nominal な）型**を新しく導入する。
`It` は `It` という型定数であって、中身のタプル型と等価ではない。
型としては葉なので木は有限のまま。循環はコンストラクタのフィールドの型定義の中に
名前として畳み込まれ、型検査は名前どうしの比較で済む。

型理論の用語では、構造的に無限展開を認める方式を equirecursive、
コンストラクタによる明示的な包み／剝がしを要求する方式を isorecursive と呼ぶ。
Haskell は後者で、equirecursive にする拡張は無い。だから「包む」以外の逃げ道は無く、
逆に**一行 `data` を足せば済む**。

代償はコンストラクタの書き足しだけ。`It`（や `Yield`）を付けて作り、パターンマッチで
剝がす。これが isorecursive での fold/unfold にあたる。`newtype` なら実行時コストは無い。

同じ話は自己適用でも起きる。`\x -> x x` は occurs check で通らないが、
`newtype Mu a = Mu (Mu a -> a)` で包めば書ける。今回はその継続モナド版と言える。

### まとめ

「型が循環する」という観察は正しい。正しくないのは「だから移植できない」という結論で、
JS の無名オブジェクトを名前付きの `data` に置き換えるだけで循環は解消する。

## data で包んだ移植

```hs
data It = It { value :: Maybe Int, next :: () -> Cont It It }
```

これで JS 版をほぼ一対一に移植できる（`GenNaive.hs`、実行結果 `1 2 3`）。
`callCC` の `b` は `yield` を使う文脈で `It` に決まるので、多相性（RankNTypes）も不要。

## 整理した版

答えの型 `r` を `Gen a` 自身にして、終端をコンストラクタで表す。
以下のコルーチン部分は 2 つの版で**完全に同一**（`diff` で確認済み）。

- `GenStd.hs` — 継続モナドは標準の `Control.Monad.Trans.Cont` を使い、
  コルーチンの部分だけを実装したもの。
- `GenMin.hs` — 継続モナドも含めて全部自前の最小実装。
  差分は先頭の 17 行（`Cont` の定義・インスタンス・`evalCont`・`callCC`）だけ。
  `Functor`/`Applicative` は `Monad` のスーパークラスなので必要だが、
  `fmap = liftM` / `(<*>) = ap` で済む。

```hs
data Gen a
    = Done
    | Yield a (Cont (Gen a) (Gen a))  -- 値と、再開用の継続

type GenM a = Cont (Gen a)
type Out a = Gen a -> GenM a ()

yield :: Out a -> a -> GenM a ()
yield ccOut v = callCC $ \next -> ccOut (Yield v (next ()))

runGen :: (Out a -> GenM a x) -> Gen a
runGen body = evalCont $ callCC $ \ccOut -> body ccOut >> return Done

toList :: Gen a -> [a]
toList Done = []
toList (Yield v k) = v : toList (evalCont k)
```

使用例と実行結果:

```hs
g123    = runGen $ \ccOut -> do { let y = yield ccOut; y 1; y 2; y 3 }
nats    = runGen $ \ccOut -> let loop n = yield ccOut n >> loop (n + 1) in loop 0
squares = runGen $ \ccOut -> mapM_ (\n -> yield ccOut (n * n)) [1 .. 5]
```

```
[1,2,3]
[0,1,2,3,4]      -- take 5 (toList nats)：無限ジェネレーターも遅延して動く
[1,4,9,16,25]
[]               -- yield しない場合
```

**この出力は `GenStd.hs` と `GenMin.hs` で完全に一致する。**
つまり自前の最小実装は標準の `Cont` と同じ挙動をしており、
記事で `Cont` を自分で実装して見せた後、そのまま
「標準では `Control.Monad.Trans.Cont` にある」と接続できる。

`do` ブロックで書けるので JS の `bind` の入れ子より読みやすく、
`mapM_` などの既存のモナドコンビネーターもそのまま使える。

## 記事への反映（済）

詳細は単発記事 [`../../articles/20260730-haskell-generator.md`](../../articles/20260730-haskell-generator.md)
（継続モナドによるジェネレーターを Haskell で書く）に分離した。構成は

1. `# 継続モナド` — Haskell の `Cont` と JS への移植版・対応表
2. `# ジェネレーター` — JS 版の実装
3. `# type だけだと循環する` — 型シノニムの循環エラー、occurs check
4. `# data を使うと解決する` — `data` は名前で型を導入するので循環を通せる。移植コードと実行結果
5. `# 直和型による整理` — `Gen`/`Done`/`Yield` による整理版、無限ジェネレーター
6. `# リストによる書き換え` — 遅延リスト・`unfoldr` で足りること、継続が要る場面
7. `# まとめ`

冒頭に `# 注意` を置き、「遅延リストがジェネレーターなので実用上は不要、これは型の話」
と先に断ってから本題に入る構成にした（`# リストによる書き換え` へのアンカーリンク付き）。

`03-cps-to-continuation-monad.md` 側は「移植できない」としていた 2 箇所を修正し、
結論（`data It = It { ... }` の 1 行）だけ引用して上記へのリンクを置いた。

- `# Haskell と Scheme` 節: 「型が循環してエラーになるため移植できません」
  → 「型シノニムやタプルでは表せないが `data` で包めば移植できる」＋結論＋リンク
- `## 移植元` 節: 「Haskell では実装していません」→ 「別記事にまとめました」＋リンク

※ 単発記事は Qiita には投稿せず、この zenn リポジトリへ移した（2026.07.30）。
qiita リポジトリ側の `03-cps-to-continuation-monad.md` からのリンクは
`../haskell-generator.md` という相対パスのままなので、Zenn 公開後の URL
（`https://zenn.dev/7shi/articles/20260730-haskell-generator`）へ差し替える必要がある。

掲載コードは全て実行して確認済み。

1 行の `do` で `let` を使う書き方だけ注意が必要だった。
`do { let y = yield ccOut; y 1; y 2; y 3 }` は構文エラーになる。
明示的な波括弧の中ではレイアウト規則が働かないので、`;` が `let` ブロックの
区切りと解釈され、`y 1` が次の**束縛**として読まれてしまう。

以下はいずれも通る（4 通り検証済み、すべて `[1,2,3]`）。

```hs
runGen $ \ccOut -> do { let { y = yield ccOut }; y 1; y 2; y 3 }  -- let を波括弧で囲む
runGen $ \ccOut -> let y = yield ccOut in do { y 1; y 2; y 3 }    -- ★採用
runGen $ \ccOut -> let y = yield ccOut in y 1 >> y 2 >> y 3
runGen $ \ccOut -> mapM_ (yield ccOut) [1, 2, 3]
```

記事では 2 番目を採用した。`do` 記法と `y` の別名を保ったまま 1 行に収まる。

## ファイル

- `generator.js` — 記事の JS 実装（動作確認済み）
- `GenSynonym.hs` — `type` シノニムで循環エラーを再現
- `GenInfer.hs` — 型注釈なしで推論に任せた場合の循環エラーを再現
- `GenNaive.hs` — JS をほぼそのまま移植（`data` で包む）。**記事の掲載コードそのもの**
- `GenSnippet.hs` — 記事「直和型による整理」の掲載コードを記載どおり（型注釈なし）で検証
- `GenStd.hs` — 整理版・標準の `Cont` を使い、コルーチンだけ自前実装
- `GenMin.hs` — 整理版・継続モナドも含めて全部自前の最小実装
- `GenList.hs` — 記事「リストによる書き換え」の掲載コード（リスト版・`unfoldr` 版）を検証

`GenStd.hs` と `GenMin.hs` はコルーチン部分のコードも出力も一致する。
