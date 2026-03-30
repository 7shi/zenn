---
title: "【簡約版】GPT-2 推論エンジン入門"
emoji: "2️⃣"
type: "tech"
topics: ["gpt2", "transformer", "python"]
published: true
---

:::message
この記事は「[GPT-2 推論エンジン入門](https://zenn.dev/7shi/books/20260319-gpt2)」の簡約版です。各トピックの詳細な解説やコードは本編をご参照ください。
:::

# GPT-2 とは

GPT-2 は OpenAI が 2019 年に発表した言語モデルです。「テキストを受け取り、次のトークンを予測する」というシンプルな目的で訓練されています。

現代の LLM（GPT-4, Claude など）も Transformer アーキテクチャの基本はほぼ変わっておらず、GPT-2 との本質的な違いはパラメーター数と学習データの規模です。GPT-2 は現代の LLM の内部構造を理解するための最もコンパクトな出発点です。

なお、この記事で扱うのは**推論のみ**です。学習については対象外です。

# セットアップと実行

以下のリポジトリを使用します。

https://github.com/7shi/my-gpt2

```bash
git clone https://github.com/7shi/my-gpt2.git
cd my-gpt2
uv sync
make download
```

## テキスト生成

GPT-2 は「次に来る単語を予測する」ことだけを学習した Base モデルです。質問に答えたり指示に従ったりする訓練（Instruction Tuning）は受けていないため、入力したテキスト（プロンプト）の続きを確率的に生成することしかできません。

GPT-2 は主に英語のテキストで学習されたモデルです。プロンプト（書き出し）を与えて、続きを生成させてみましょう。

```bash
uv run my-gpt2 "Once upon a time"
```
> Once upon a time when no one could make impressions many people wished they had touched others who did. They stayed and drifted. Many don't even remember for years. One

英語ベースの GPT-2 はバイトレベル BPE により日本語の入力を受け付けますが、日本語として意味の通じる文章は生成できません。日本語を生成するには、日本語で学習された `rinna/japanese-gpt2-small` を `-m` オプションで指定します。モデル構造は GPT-2 と同一で、トークナイザーのみ SentencePiece に変更されています。

```bash
uv run my-gpt2 -n 20 -m rinna/japanese-gpt2-small "吾輩は猫で"
```
> 吾輩は猫で、子に親切にもした。 楽しげな娘を見るたびに、亡き妻が生きて

生成は確率的なため、実行するたびに異なる結果が得られます。以下のオプションで生成の振る舞いを調整できます。

- **Temperature** (`-t`): 低い値ほど確信度の高い単語が選ばれやすく、高い値ほど多様な出力
- **Top-k** (`-k`): 確率上位 k 個のトークンのみを候補にする
- **Top-p** (`-p`): 累積確率が p に達するまでのトークンを候補にする

# 推論パイプラインの全体像

GPT-2 に入力されたテキストは以下のパイプラインを通り、「次に来る単語の確率分布」として出力されます。

1. テキスト
   - トークナイザー
     - BPE
     - SentencePiece
2. トークン ID 列
   - Embedding
3. ベクトル列
   - Transformer Block × 12
     - LayerNorm
     - Attention
     - 残差接続
     - LayerNorm
     - MLP
     - 残差接続
   - 最終 LayerNorm
   - LM Head
4. ロジット
   - サンプリング
5. 次のトークン

## モデルの重み

safetensors 形式（約 523 MB）で格納されています。768 は埋め込み次元、50257 は語彙数、1024 は最大トークン列長です。

| キー | 形状 | 役割 |
|---|---|---|
| `wte.weight` | (50257, 768) | Embedding（トークン） |
| `wpe.weight` | (1024, 768) | Embedding（位置） |
| `h.0.ln_1.weight`, `.bias` | (768,) | LayerNorm（Attention 前） |
| `h.0.attn.c_attn.weight`, `.bias` | (768, 2304), (2304,) | Attention（Q,K,V 結合） |
| `h.0.attn.c_proj.weight`, `.bias` | (768, 768), (768,) | Attention（出力射影） |
| `h.0.ln_2.weight`, `.bias` | (768,) | LayerNorm（MLP 前） |
| `h.0.mlp.c_fc.weight`, `.bias` | (768, 3072), (3072,) | MLP（拡張） |
| `h.0.mlp.c_proj.weight`, `.bias` | (3072, 768), (768,) | MLP（射影） |
| `h.1` 〜 `h.11` | 同上 | Transformer Block × 12 |
| `ln_f.weight`, `.bias` | (768,) | 最終 LayerNorm |

## コア推論コード

推論パイプラインの中核は以下のステップに集約されます。

```python
# Step 0: トークナイザー — テキストをトークンIDの列に変換
input_ids = tokenizer.encode(text)

# Step 1: Embedding — トークンIDをベクトルに変換し、位置情報を加算
x = wte[input_ids] + wpe[np.arange(len(input_ids))]

# Step 2: Transformer Block × 12 — 文脈理解と特徴変換を繰り返す
for block in blocks:
    y = block.ln_1(x)  # 正規化
    y = block.attn(y)  # 文脈理解
    x = x + y          # 残差接続（加算）
    z = block.ln_2(x)  # 正規化
    z = block.mlp(z)   # 特徴変換
    x = x + z          # 残差接続（加算）

# Step 3: 最終 LayerNorm — 出力前の正規化
x = ln_f(x)

# Step 4: LM Head — 全語彙の埋め込みベクトルとの内積（ロジット）を一括計算
logits = x @ wte.T

# Step 5: サンプリング — 確率分布から次のトークンを選択
probs = softmax(logits[-1])
next_id = np.argmax(probs)
```

# トークナイザー

## BPE（Byte Pair Encoding）

GPT-2 は「頻出するバイト列の塊」を学習によってトークンとして定義する BPE を採用しています。

処理の流れ：

1. **事前分割**: 正規表現でテキストを単語・記号に分割（`'Hello, world!'` → `['Hello', ',', ' world', '!']`）
2. **バイトマッピング**: UTF-8 バイト列を表示可能な Unicode 文字に 1:1 変換（空白 → `Ġ` など）
3. **BPE マージ**: `merges.txt` のルールに従い、隣り合うペアを優先度順に結合。rank は `merges.txt` での順位で、小さいほど学習データ中で頻出したペアであり優先して結合される

```text
"Hello" のマージ過程:
初期: ['H', 'e', 'l', 'l', 'o']
step1: ['l', 'l'] (rank=41)       → ['H', 'e', 'll', 'o']
step2: ['e', 'll'] (rank=439)     → ['H', 'ell', 'o']
step3: ['ell', 'o'] (rank=10853)  → ['H', 'ello']
step4: ['H', 'ello'] (rank=15240) → ['Hello']
```

4. **ID マッピング**: `vocab.json` でトークン文字列を ID に変換（`'Hello'` → ID 15496）

BPE はバイト単位に分解するため未知語が発生しませんが、日本語など分かち書きしない言語では非効率になります。

## SentencePiece（Unigram モデル）

`rinna/japanese-gpt2-small` は SentencePiece の **Unigram モデル**を使用します。

Unigram モデルは、語彙内の各ピース（部分文字列）に「出現確率の対数」をスコアとして持たせ、テキストを「スコアの合計が最大になるピース列」に分割します。確率の積は対数の和に変換されるため、アンダーフローを避けつつ最大化できます。

```text
log P(▁, 日本語) = log P(▁) + log P(日本語)
                 = (-3.5238) + (-9.9070)
                 = -13.4308
```

最適な分割の探索には **Viterbi アルゴリズム**（動的計画法）を用います。「位置 `i` までの最適分割が決まれば、それ以降はその結果だけを引き継げばよい」という最適部分構造を利用して、左から右へ効率的に解きます。

`▁日本語` を例にすると：

```text
best[0] = (  0.0   , -1, None)     ← 起点
best[1] = ( -3.5238,  0, "▁")     ← "▁" のスコア
best[4] = (-13.4308,  1, "日本語") ← "▁" + "日本語" が最適
バックトラック: best[4] → best[1] → best[0] → ["▁", "日本語"]
```

## BPE と Unigram の比較

両者の主な違いをまとめます。

| 観点 | BPE | Unigram |
|---|---|---|
| アルゴリズム | 最頻ペアを繰り返し結合 | 各ピースに対数確率スコアを持つ言語モデル |
| 分割方法 | 決定論的（マージ順に従う） | 最尤分割（Viterbi で最高スコアを探す） |
| ファイル形式 | `vocab.json` + `merges.txt` | `spiece.model`（Protocol Buffers） |
| 単語境界 | スペースをバイトとして埋め込み | `▁`（U+2581）マーカーで表現 |

# Embedding

トークン ID（整数）をベクトル（数値のリスト）に変換するステップです。GPT-2 では「単語の意味」と「位置情報」の 2 つのベクトルを足し合わせます。

- **WTE（Word Token Embedding）**: 語彙中の各トークンに対応する埋め込みベクトルを格納した行列。トークン ID で行を取り出すと、そのトークンの意味ベクトルが得られます。形状 (50257, 768)
- **WPE（Word Position Embedding）**: 位置を区別するためのベクトルの行列。Attention は入力の順序に依存しないため、位置情報を明示的に与えなければ "I love you" と "you love I" を区別できません。形状 (1024, 768)

```python
x = wte[input_ids] + wpe[np.arange(len(input_ids))]
```

連結（concatenate）ではなく加算にすることで次元を維持し、パラメータ数を抑えています。加算しても学習によって位置と意味が自然に分離されることが知られています。

# Transformer Block

Transformer Block は LayerNorm・Attention・MLP・残差接続で構成されます。GPT-2 ではこれを 12 個積み重ねます。

```text
Input────┐
  │      ↓
  │  LayerNorm
  │      ↓
  │  Attention
  ↓      │
 (+)←────┘ 残差接続
  ├──────┐
  │      ↓
  │  LayerNorm
  │      ↓
  │     MLP
  ↓      │
 (+)←────┘ 残差接続
  ↓
Output
```

```python
class TransformerBlock:
    def __call__(self, x):
        x = x + self.attn(self.ln_1(x))
        x = x + self.mlp (self.ln_2(x))
        return x
```

各層は大まかに異なる抽象度の特徴を担っていると考えられています。

- **浅い層（0〜3）**: 文法構造、品詞パターン、局所的な共起関係
- **中間層（4〜8）**: 意味的な関係、エンティティの同定、文脈の統合
- **深い層（9〜11）**: タスク固有の判断、最終的な予測に向けた情報の絞り込み

ただし明確に分かれるわけではなく、複数の層が協調して機能を実現しています。

## LayerNorm

残差接続によって各層の出力が積み重なると、ベクトルのスケールはトークンごと・層ごとにばらつきます。このばらつきを放置すると、Attention のスコア計算（内積）が特定の次元に支配されやすくなり、計算が不安定になります。LayerNorm は各処理の直前でスケールを揃えることで、この問題を防ぎます。

具体的には、各トークンのベクトル（768 次元）を**平均 0・分散 1** に正規化してから、学習済みパラメーター γ（スケール）と β（シフト）を適用します。

```python
class LayerNorm:
    def __call__(self, x, eps=1e-5):
        mean = np.mean(x, axis=-1, keepdims=True)
        variance = np.var(x, axis=-1, keepdims=True)
        x_norm = (x - mean) / np.sqrt(variance + eps)
        return self.g * x_norm + self.b  # γ でスケール、β でシフト
```

正規化で全次元を同じスケールにした後、γ/β で必要なスケールの違いを復元します。GPT-2 全体で 25 回使用されます（12 ブロック × 2 + 最終 ln_f × 1）。

## Attention

各トークンが他のトークンとの関係性を計算し、文脈を取り込む処理です。Transformer の原論文のタイトルは "Attention Is All You Need" であり、Attention こそが Transformer の中核です。

原論文では Encoder（双方向に参照）と Decoder（過去のみ参照）の 2 つが導入されましたが、GPT-2 は Decoder のみを使用します。Decoder の Attention は **Self-Attention** と呼ばれ、同じシーケンス内のトークン同士の関係を計算します。

### Q, K, V への変換

関連するトークンを探して情報を集める処理は、検索の比喩で 3 つの役割に分けられます。

- **Q (Query)**: 「何を探しているか」（検索クエリ）
- **K (Key)**: 「自分は何を持っているか」（検索インデックス）
- **V (Value)**: 「実際の情報」（検索結果）

入力ベクトルをそのまま使うと検索する側とされる側を区別できないため、異なる投影行列で変換します。768 次元を 12 個のヘッドに分割（各 64 次元）し、ヘッドごとに独立して Attention を計算します（**Multi-Head Attention**）。複数のヘッドがそれぞれ異なる観点で文脈を捉えることで、多面的な情報を取り込めます。

`seq_len` を入力のトークン列長とします。

```python
# (seq_len, 768) → (seq_len, 2304)
qkv = x @ self.w_qkv + self.b_qkv
# (seq_len, 2304) → (seq_len, 768) × 3 分割
q, k, v = np.split(qkv, 3, axis=-1)
# 各 (seq_len, 768) → (seq_len, 12, 64) → (12, seq_len, 64)
q = q.reshape(seq_len, 12, 64).transpose(1, 0, 2)
k = k.reshape(seq_len, 12, 64).transpose(1, 0, 2)
v = v.reshape(seq_len, 12, 64).transpose(1, 0, 2)
```

ヘッド当たりの次元数 64 を `d_k` とします。

### スコア計算

Q と K の内積で関連度を計算します。内積はベクトルが同じ方向を向いているほど大きくなるため、関連性の高いトークン同士ほどスコアが高くなります。次元数が大きいと内積の値が過大になるため、$\sqrt{d_k}$ でスケーリングします。

```python
scores = q @ k.transpose(0, 2, 1) / np.sqrt(d_k)
```

### 因果マスキングと Softmax

GPT-2 は「次の単語を予測する」モデルのため、未来のトークンを参照できないよう上三角部分を $-10^{10}$ で上書きします。

スコアを確率分布に変換するため **Softmax** を適用します。Softmax は各スコアの指数 $\exp(x)$ を取り、合計で割ることで全体の和が 1 になるよう正規化する関数です。最もスコアが高い要素に高い確率が割り当てられます。マスクされた位置は $-10^{10}$ なので、$\exp(-10^{10}) \approx 0$ となり実質的に無視されます。

```python
def softmax(x):
    exp_x = np.exp(x - np.max(x, axis=-1, keepdims=True))
    return exp_x / np.sum(exp_x, axis=-1, keepdims=True)

mask = np.tril(np.ones((seq_len, seq_len)))
scores = np.where(mask == 0, -1e10, scores)
probs = softmax(scores)  # 注目度行列
```

`exp(x)` は値が大きいとオーバーフローするため、最大値を引いてから計算しています。最大値を引いても分子・分母に同じ定数がかかるため結果は変わりません。

### Value の重み付き平均

注目度を重みとして V の加重平均を取り、文脈を反映したベクトルを得ます。注目度の高いトークンほど多くの情報が流れ込みます。

```python
out = probs @ v
```

### 出力射影

最後に 12 ヘッドの結果を結合して 768 次元に戻し、出力射影を適用します。

```python
out = out.transpose(1, 0, 2).reshape(seq_len, embed_dim)
return out @ self.w_out + self.b_out
```

## MLP

各トークンを**独立に**処理する特徴変換です。Attention が「トークン間の情報伝達」（横方向）なら、MLP は「トークン単体の意味の深掘り」（縦方向）です。Attention は情報を集約しますが、集めた情報を「解釈」する処理は行いません。MLP がその役割を担います。

768 次元のベクトルを一度 4 倍の 3072 次元に拡張し、非線形変換してから元の 768 次元に圧縮します。高次元空間で多くの特徴を同時に表現し、非線形変換で選別するという仕組みです。

```python
class MLP:
    def __call__(self, x):
        i = x @ self.w_fc + self.b_fc         # 768 → 3072（4倍に拡張）
        a = gelu(i)                           # 非線形変換（活性化関数）
        return a @ self.w_proj + self.b_proj  # 3072 → 768（元に圧縮）
```

GELU は ReLU を滑らかにした活性化関数で、正の値はほぼそのまま通過し、負の値は大きく抑制されます。非線形変換がないと、どれだけ層を重ねても全体が単なる線形変換に潰れてしまうため、非線形性の導入が不可欠です。

## 残差接続

`x = x + f(x)` という形で各処理の出力を元の入力に加算することを**残差接続**と呼びます。層の出力で上書きするのではなく「変更分を加える」構造です。これにより勾配消失を防ぎ、深いモデルでも学習が安定します。

情報の流れとして見ると、`x` は情報の幹線（**残差ストリーム**）であり、Attention や MLP は幹線に情報を「追加」するだけです。初期の Embedding は最終層まで直接伝わります。

GPT-2 は処理の**前**に LayerNorm を置く **Pre-LayerNorm** を採用しています。残差接続のパスがモデル全体を貫通するため、信号が深層まで伝わりやすくなります。

## 文脈付き埋め込み

12 ブロックを通過すると、同じ単語でも文脈によって異なるベクトルに変化します。これを**文脈付き埋め込み** (Contextual Embedding) と呼びます。例えば "river bank" と "money bank" の "bank" は、Embedding 層では同一ですが、Attention によって周囲の単語の情報を取り込み、異なるベクトルへと分岐していきます。

因果マスクにより、各トークンは自分自身と過去のトークンだけを参照できるため、最後のトークンはそれより前のすべてのトークンの情報が集約されます。

# 出力とサンプリング

12 層の Transformer Block と最終 LayerNorm を通過したベクトルから、次の単語の確率分布を生成します。

## LM Head（Weight Tying）

通常、出力層には独立した重み行列を用意しますが、GPT-2 では入力の Embedding 行列（WTE）をそのまま出力層にも再利用します。この手法を **Weight Tying** と呼びます。「単語 A を表すベクトル」と「次の単語として A を予測するベクトル」は同じ意味空間にあるべきという考えに基づいており、GPT-2 の 124M パラメーターのうち約 30% を占める行列を共有することでメモリも節約できます。

```python
logits = x @ wte.T  # (seq_len, 768) @ (768, 50257) → (seq_len, 50257)
```

行列積によって各トークンのベクトルと全語彙の埋め込みベクトルとの内積を一括計算しています。内積はベクトルが同じ方向を向いているほど大きくなるため、モデルの最終出力に近い埋め込みを持つトークンほど高いスコアになります。この出力は確率分布の前段階となるスコアで、**ロジット**と呼ばれます。

## サンプリング手法

因果マスクにより最後のトークンにはそれ以前のすべてのトークンの情報が集約されているため、次の単語の予測には最終トークンのロジットだけを使用します。

最終トークンのロジットを Softmax で確率分布に変換した後、次のトークンを選びます。確率分布からどのようにトークンを選ぶかによって、生成されるテキストの性質が変わります。

- **貪欲法**: 最も確率が高いトークンを選択。決定論的だがループが発生しやすい
- **Temperature**: ロジットを温度 T で割ってから Softmax を適用し、分布の尖り具合を調整。低温（T < 1）で保守的、高温（T > 1）で多様な生成になる
- **Top-k**: 上位 k 個のトークン以外をマスクし、候補数を固定
- **Top-p（Nucleus）**: 累積確率が p に達するまでのトークンを候補にする。語彙の分布に応じて候補数が動的に変わるため、Top-k より適応的

## 自己回帰生成

GPT-2 は一度に 1 トークンずつ予測します。予測したトークンを入力に追加して再び推論するループを繰り返すことで文章を生成します。

```python
for _ in range(n_tokens_to_generate):
    logits = model(np.array(input_ids))
    next_token = int(np.argmax(logits[-1, :]))
    input_ids.append(next_token)
```

毎回入力全体をモデルに通し、最後のトークンの確率分布から次のトークンを選びます。なお、この素朴な実装では毎回全トークンを再計算しています。次のセクションで説明する KV キャッシュを使えば、新しいトークンの計算だけで済むようになります。

# KV キャッシュ

自己回帰生成では毎回全トークンを再計算しますが、Transformer Block の中で他のトークンを参照するのは Attention だけです。MLP・LayerNorm・Embedding・LM Head はすべてトークン単位の独立した処理です。さらに因果マスクにより過去のトークンの K, V は変わりません。そこで計算済みの K と V を保存しておき、新しいトークンの計算だけで済ませるのが **KV キャッシュ**です。

- **Prefill**: 全プロンプトを処理して K, V をキャッシュに保存
- **Incremental**: 新トークンのみ処理し、K, V をキャッシュに追加。新しいトークンの Q とキャッシュ全体の K でスコアを計算

Attention の計算量は Q の長さ × K の長さに比例します。プロンプト 4 トークンから 3 トークンを生成する場合の計算量を比較すると：

```text
キャッシュなし（毎回全トークンを処理）:
  4×4 + 5×5 + 6×6 + 7×7 = 126

キャッシュあり（Prefill + 新トークンのみ処理）:
  4×4 + 1×5 + 1×6 + 1×7 =  34
```

シーケンスが長くなるほど差は広がります。

# GPT-2 から現代の LLM へ

GPT-2 のアーキテクチャは現代の LLM の基本形です。本質的な違いはパラメータ数と学習データの規模であり、基本構造は驚くほど変わっていません。

| | GPT-2 | 現代の LLM |
|---|---|---|
| パラメータ数 | 124M | 数十B〜数百B |
| 層数 | 12 | 数十〜百以上 |
| コンテキスト長 | 1024 | 100K〜2M |
| 位置埋め込み | 学習済み絶対位置 | RoPE 等の相対位置 |
| 正規化 | LayerNorm | RMSNorm |
| 活性化関数 | GELU | SwiGLU |
| Attention | 標準 MHA | GQA / MLA |

構造の違いは効率やスケーラビリティの改善であり、「残差ストリーム上で Attention と MLP を繰り返す」という根本的な設計は共通しています。GPT-2 で理解した原理は、そのまま現代の LLM にも応用できます。
