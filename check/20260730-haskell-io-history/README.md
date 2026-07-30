# Haskell 1.0 のストリーム I/O と継続の関係（検証）

記事 [`../../articles/20260730-haskell-io-history.md`](../../articles/20260730-haskell-io-history.md)
（IOモナドに至るまでのHaskellのI/O）の検証コード。
当時の I/O モデルを現行の GHC に移植して動かしたもの。
GHC 9.6.6。実行は `runghc {ファイル名}`。

| ファイル | 内容 |
|---|---|
| `Haskell10.hs` | `Request`/`Response`/`Behaviour` と OS シミュレーター（共通モジュール） |
| `figure3.hs` | Haskell 1.0 Report の Figure 3「Stream-based I/O」 |
| `Transaction.hs` | Figure 4 のトランザクション定義（共通モジュール） |
| `figure4.hs` | 同 Figure 4「Continuation I/O」（入れ子のラムダ版） |
| `figure4op.hs` | 同 Figure 4 を `>>>` 演算子で平らにした版 |
| `figureDo.hs` | Figure 4 を `Cont` で包んで `do` 記法にした版 |
| `figure6.hs` | 同 Figure 6「Monadic I/O」を現行の Haskell へ移植 |
| `WorldPassing.hs` | 却下された第 3 案「世界渡し」と、単一スレッド性が破れる様子 |
| `WorldGHC.hs` | 現行 GHC の `IO` を剥がして世界渡しを直接書く（`UnboxedTuples`） |
| `GenBehaviour.hs` | 双方向ジェネレーターが `Behaviour` そのものであることの確認 |

`figure6.hs` だけは実ファイルを読むので `hello.txt` を使う
（標準入力にファイル名を与える: `echo hello.txt | runghc figure6.hs`）。
他は OS シミュレーター内の仮想ファイルシステムを使う。

Report の `Response` は `Failure IOError`、`FailCont` は `IOError -> Behaviour` だが、
検証コードでは `IOError` を `String` に簡略化した（動作は変わらない）。
記事本文では Report どおりの型を示している。

この検証は当初 qiita リポジトリの `series/haskell-intro/check/stream-io/` にあり、
歴史を単発記事へ分離した際に `articles/haskell/check/haskell-io-history/` へ移動、
記事を Zenn へ移したのに合わせてここへ移した。
シリーズ本編（qiita リポジトリの継続モナド 超入門）からは記事経由で参照する。

## 典拠

Hudak, Hughes, Peyton Jones, Wadler,
[*A History of Haskell: Being Lazy with Class*](https://www.microsoft.com/en-us/research/publication/a-history-of-haskell-being-lazy-with-class/)
(HOPL III, 2007) の 7 節。Figure 3〜6 と型定義はこの論文が引用する
Haskell 1.0 Report のコードをそのまま使った。

論文から確認できた事実:

- Haskell 1.0 (1990) には**ストリーム版と継続版の 2 つの I/O モデルが両方載っていた**。
  両者は相互に定義可能（Hudak & Sundaresh 1989）で、Report では
  **ストリームを primitive、継続をその上の派生**として定義した。
- プログラムの型は `type Behaviour = [Response] -> [Request]`。
  「遅延評価のおかげで、応答を処理する前に要求を出せる」ことが前提。
- 継続版が primitive にされなかった理由は**効率**。継続でストリームを定義すると
  要求数に対して線形空間・二次時間かかり、期待される定数空間・線形時間にならなかった。
  「継続の方が使いやすいと考えられていたにもかかわらず」ストリームを primitive にした。
- 継続版の方が好まれた理由は**制御の流れが局所的**だから。ストリーム版は
  「応答を表すパターンと要求の間を読者の視点が行き来する」。
- モナド版は Haskell 1.3 (1996) で採用され、両方を置き換えた。
- 世界を渡す `World -> (a, World)` 方式も検討されたが、単一スレッド性を保証できず
  却下された（Clean が後に uniqueness type で解決）。

## 確認できたこと

### Figure 3 は動く。`~` を外すとデッドロックする

```hs
main ~(Success : ~(Str userInput : ~(Success : ~(r4 : _)))) =
    [ AppendChan stdout "enter filename\n"
    , ReadChan stdin
    , ...
```

```
enter filename
hello.txt
Hello, stream I/O!
```

`~` を外すと、要求を 1 つも出さないうちに応答を見ようとして自分を待つ。
要求リストの先頭を評価しようとしただけでタイムアウトした。

```
=== Figure 3: 遅延パターンなし（~ を外す） ===
  → 例外: <<timeout>>
```

プログラムと OS は `reqs = behaviour resps; resps = os reqs` という相互再帰で回る。
**遅延評価だけがこれを可能にしていて、順序の正しさは型で守られていない。**
論文が言う「読者の視点がパターンと要求の間を行き来する」の実体はこれ。

### Haskell 1.0 の継続 I/O は継続モナドそのもの

Report の型定義:

```hs
type Behaviour = [Response] -> [Request]
type StrCont   = String -> Behaviour

readFile :: Name -> FailCont -> StrCont -> Behaviour
```

失敗継続を `abort` に固定して部分適用すると

```hs
readFile name abort :: StrCont -> Behaviour
                    =  (String -> Behaviour) -> Behaviour
```

**これは `Cont Behaviour String` の中身そのもの。** 実際に包んで動かした。

```hs
readFileC :: Name -> Cont Behaviour String
readFileC name = Cont (readFileT name abort)
```

`Cont` の `Monad` インスタンスを与えると、Figure 4（入れ子のラムダ）が
そのまま Figure 6（`do` 記法のモナド版）と同形になる。

```hs
figureDo = evalIO $ do
    appendChanC stdout "enter filename\n"
    userInput <- readChanC stdin
    let (name : _) = lines userInput
    appendChanC stdout (name ++ "\n")
    contents <- readFileC name
    appendChanC stdout contents
```

Figure 4・`>>>` 版・`Cont` の `do` 版の 3 つで**出力が完全に一致した**。

これは論文の記述と符合する。論文は IO モナドが継続で実装できることを
`type IO a = FailCont -> SuccCont a -> Behaviour` と明示しており、また
`>>>` 演算子（`f >>> x = f abort x`）を導入した結果が
「モナド版のコードと驚くほど似ている」と述べている。
さらに「Haskell プログラムを命令型っぽく見せたのはモナドそれ自体ではなく
`do` 記法の登場だった」とも書いている。

**答えの型 `r` が `Behaviour`＝ストリームだった**、というのがこの節の核心。
継続モナドの `r` は抽象的で掴みにくいが、歴史上の実例では
「これから OS に出す要求の列」という具体物だった。

### 双方向ジェネレーターは `Behaviour` そのもの

構成案 6 (a) の `feed` の型を並べるだけで分かる。

```hs
feed      :: Gen i o -> [i] -> [o]
feed prog ::            [Response] -> [Request]   -- i = Response, o = Request
          =  Behaviour
```

Figure 3 のプログラムをコルーチンとして `do` 記法で書き、`feed prog` を
Haskell 1.0 の OS シミュレーターに差したら**そのまま動いた**。

```
=== ジェネレーターを Behaviour として OS に差す ===
enter filename
hello.txt
Hello, coroutine!
```

つまり `[Response] -> [Request]` は**双方向コルーチンを 2 本の遅延リストで
表現したもの**だった。出力 `[Request]` と入力 `[Response]` の対応が
型で保証されず、n 番目の要求と n 番目の応答が揃っている前提を
プログラマが守る必要があったのが弱点で、継続で書けばその前提が
制御の流れとして明示される。

### `~` の必要性は `feed` の書き方に対応する

`series/haskell-intro/check/gen-bidirectional/GenBi.hs` の `feed` は入力リストを先にパターンマッチしている。

```hs
feedStrict (Yield v next) (i : is) = v : feedStrict (evalCont (next i)) is
```

これを knot-tying の中で使うと、**`~` なしの Figure 3 と全く同じくデッドロックした**。

```
=== 入力を先にパターンマッチする feed（~ なしの Figure 3 と同じ） ===
  → 例外: <<timeout>>
```

出力を先に出してから入力を要求する形に直すと通る。

```hs
feed (Yield v next) is =
    v : case is of
        (i : rest) -> feed (evalCont (next i)) rest
        [] -> []
```

`gen-bidirectional/README.md` に書いた「最初の `yield` は入力を消費する前に起きる」
という注意は、Haskell 1.0 が `~` で担保していたことと同じ内容。
**配慮の置き場所がプログラム側からドライバー側へ移っただけ**で、
コルーチンとして書けばプログラム本体では意識せずに済む。

### 「余分に生産される」問題との関係

`series/haskell-intro/check/gen-io/` では `ContT r IO` にしたとき、
素朴な `take` が 1 つ余分に生産した。あれも「必要になる前に相手を進めてしまう」
という同じ型の同期のずれで、純粋なら遅延が吸収してくれるが、副作用が付くと露出する。
Haskell 1.0 のストリーム I/O が壊れやすかったのはこの一点に集約される。

### 世界渡しは単一スレッド性を保証できない（`WorldPassing.hs`）

`type IOw a = World -> (a, World)` は素直に使えば命令型のように書けるが、
同じ世界を 2 回使うことを型が止めない。

```
=== 同じ世界を 2 回使える（単一スレッド性が破れる） ===
  branch1: common / branch A
  branch2: common / branch B
=== 出力を巻き戻せる（second が消える） ===
  first / third
```

論文が却下理由として挙げる「単一スレッドなアクセスを保証する手段がなかった」の実演。

Clean は同じ方式を一意型（`*World`）で型付けし、同じ値を 2 回使うことを
コンパイルエラーにして成立させた。詳細は
[Clean 一意型 調査メモ](https://qiita.com/7shi/items/ab3b819871d7b0710949)。

### 却下された世界渡しは現行 GHC の実装（`WorldGHC.hs`）

`IO` を剥がすと世界渡しが現れる。GHC 9.6.6 で実行を確認した。

```hs
main = IO $ \world ->
    let (# world1, _  #) = unIO (print "hello") world
        (# world2, _  #) = unIO (print "world") world1
    in  (# world2, () #)
```

```
"hello"
"world"
```

Clean の `#` による受け渡しと同じ形。Haskell は一意型を持たない代わりに
`newtype` による抽象化で一意性を守っている。

### Figure 6 は現行の Haskell でそのまま動く（`figure6.hs`）

`appendChan`/`readChan` を `hPutStr`/`hGetContents` に置き換えるだけ。
ストリーム版・継続版・`Cont` 版・モナド版の 4 つで実行結果が一致した。

## シリーズ本編（継続モナド 超入門）との関係

歴史そのものは単発記事へ分離したので、本編では要点だけ参照する。
本編にとって効くのは以下の 2 点（詳細は qiita リポジトリの
`series/haskell-intro/PLAN.md` の「Haskell 1.0 の I/O」節）。

- 答えの型 `r` の具体例が歴史上にある（`r` = `Behaviour` = 要求の列）。
- 双方向ジェネレーターが `Behaviour` そのもの（`GenBehaviour.hs`）。
  本編 6 (a) の後に「今書いたものが Haskell 1.0 だった」と落とせる。
