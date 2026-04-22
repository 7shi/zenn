---
title: "Windows で Ternary Bonsai を動かしてみた"
emoji: "🪴"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["llm", "onnx", "python"]
published: true
---

1.58 ビット 3 値量子化 LLM「Ternary Bonsai」を Windows で動かすため、q2 packed ONNX を q4 に変換して CPU で推論してみました。（一応動きましたが遅いです…）

変換スクリプトや詳細な実行手順は以下のリポジトリで公開しています。

- https://github.com/7shi/ternary-bonsai-test

:::message
本記事は Claude Opus 4.6 の生成結果をベースに編集しました。
:::

## Ternary Bonsai とは

2026 年 4 月、PrismML が **Ternary Bonsai** という言語モデルファミリーを Apache 2.0 ライセンスで公開しました。最大の特徴は **1.58 ビットの 3 値量子化**（ternary quantization）を採用している点にあります。

https://prismml.com/news/ternary-bonsai

通常の言語モデルは重みパラメータを 16 ビット（FP16）や 32 ビット（FP32）の浮動小数点数で保持します。Ternary Bonsai はこれを **{-1, 0, +1} の 3 値** に制約します。3 値を表現するのに必要な情報量は $\log_2 3 \approx 1.58$ ビットであり、これが「1.58 ビット」の由来です。実際には 128 要素ごとに FP16 のスケール係数を 1 つ共有し、各重みは $\{-s, 0, +s\}$ のいずれかとして表現されます。

8B パラメータ版のモデルサイズは約 1.75GB で、FP16 の同クラスモデル（約 16GB）の **約 1/9** に収まります。それでいてベンチマーク平均スコアは 75.5 に達し、同パラメータクラスでは Qwen3 8B（16.38GB）に次ぐ性能を示しています。サイズあたりの性能（intelligence density）では群を抜いています。

## Windows ユーザーの壁

:::message
【2026.04.22 追記】GGUF 版が公開され、独自の llama.cpp フォークで動くようになっています。

https://huggingface.co/prism-ml/Ternary-Bonsai-8B-gguf
:::

記事執筆時点では 3 つの形式でモデルが公開されていましたが、Windows ですんなり動かせない状況でした。

**MLX 版** ([prism-ml/Ternary-Bonsai-8B-mlx-2bit](https://huggingface.co/prism-ml/Ternary-Bonsai-8B-mlx-2bit)): 1.58 ビットの重みをネイティブに扱い、M4 Pro で 82 toks/sec という高速推論を実現します。ただし MLX は Apple Silicon 専用のフレームワークであり、Windows では利用できません。

**safetensors 版** ([prism-ml/Ternary-Bonsai-8B-unpacked](https://huggingface.co/prism-ml/Ternary-Bonsai-8B-unpacked)): 3 値の重みを通常の浮動小数点数に展開（unpack）した形式です。Transformers ライブラリから直接読み込めるので動作させること自体は容易ですが、重みは FP16 の dense テンソルに戻っているため、モデルサイズは通常の 8B モデルと同等の約 16GB になります。1.58 ビットのコンパクトさも演算上のアドバンテージも失われています。

**ONNX 版** ([onnx-community/Ternary-Bonsai-8B-ONNX](https://huggingface.co/onnx-community/Ternary-Bonsai-8B-ONNX)): 2 ビット packed 形式の ONNX モデルが公開されています。サイズは約 1.75GB とコンパクトですが、詳細な動作手順は提供されていません。実際に試すと、現状の ONNX Runtime は `MatMulNBits` op の 2 ビットモードに対応しておらず、そのままでは推論を実行できません。

つまり Windows ユーザーにとっては、**コンパクトなまま動かす方法が用意されていない**という状況でした。

## 2 つのルートで変換を試みる

そこで、公開されている 2 つの形式それぞれから変換を行い、Windows の ONNX Runtime で動作するモデルを作成する方向で調査を進めました。

### ルート 1: safetensors からの ONNX エクスポート

safetensors 版の dense 重みを `optimum-cli export onnx` で ONNX 形式に変換します。FP32・FP16 でのエクスポートが可能で、FP16 ONNX からさらに FP8（8 ビット浮動小数点）に後処理変換することもできます。

この方法で生成される ONNX モデルは、標準 ONNX op のみで構成されたグラフになります。CPU でも DirectML（Windows の GPU 推論バックエンド）でも安定して動作します。ただし、重みは dense のままなのでファイルサイズは FP16 で約 16GB、FP8 でも約 8GB と大きくなります。1.58 ビットのコンパクトさは失われており、このルートの主目的は **ONNX Runtime 上での正常動作を確認するための足掛かりを得ること**にあります。

### ルート 2: q2 packed ONNX からの変換

ONNX q2 版の 2 ビット packed 重みをデコードし、ONNX Runtime が扱える形式に再エンコードします。変換先として q4（4 ビット）、q8（8 ビット）、dense FP8 の 3 パターンを試しました。

この方法はコンパクトさを保てるのが利点です。q2 からのダウンロードは約 1.75GB で、q4 への変換後でも約 3.5GB に収まります。ただし、変換スクリプトが書き換えるのは重みに関する `MatMulNBits` ノードだけであり、**attention や normalization などのグラフ構造はそのまま引き継がれます**。この構造的な違いが、後述する DirectML での問題の原因となります。

## DirectML で出力が崩壊する

2 つのルートから生成したモデルを CPU と DirectML の両方で比較テストしたところ、意外な結果が得られました。

q2 由来のモデル（q4・q8・FP8 いずれも）を **DirectML で実行すると、出力が完全に崩壊**します。日本語のプロンプトに対して "AI Nation informed simply formats teacher norm Sh Earth" のような無関係な英単語の羅列が返ってきます。一方、**同じモデルを CPU で実行すると正常な日本語**が生成されます。

safetensors 由来のモデルは CPU でも DirectML でも正常に動作します。

この現象を掘り下げると、原因は重みの精度ではなくグラフ構造にあることが分かりました。同じ FP8 の重みを持つ `onnx_fp8`（safetensors 由来）と `onnx_q2_to_fp8`（q2 由来）で挙動が異なることが、その証拠です。

### グラフ構造の違い

safetensors 由来のモデルは標準 ONNX op だけで構成されています。一方、q2 由来のモデルには `com.microsoft` 名前空間のカスタム op が多数残っています。

| カスタム op | 個数 | 役割 |
|------------|-----:|------|
| `GroupQueryAttention` | 36 | Attention + KV キャッシュ + RoPE を融合したカーネル |
| `SkipSimplifiedLayerNormalization` | 72 | 残差接続 + RMSNorm の融合 |
| `SimplifiedLayerNormalization` | 1 | RMSNorm |
| `GatherBlockQuantized` | 1 | 4 ビットブロック量子化された埋め込み検索 |

ONNX Runtime の CPU 実行プロバイダにはこれらのカスタム op のリファレンス実装が含まれているため正常に動作します。しかし DirectML にはこれらの op の正しい実装がない（もしくは不完全である）ため、正しく実行できません。特に `GroupQueryAttention` は Grouped Query Attention、動的 KV キャッシュ管理、RoPE 適用を 1 つの op に凝縮した複雑なカーネルであり、これが 36 層すべてで誤った結果を返すことで、出力が最初のトークンから破綻します。

カスタム op を標準 op に展開し直せば DirectML でも動くはずですが、`GroupQueryAttention` の展開は GQA のヘッド展開、動的 KV キャッシュ結合、RoPE 回転、マスク付きスケールドドットプロダクト Attention、バイアス加算を 36 レイヤー分手動で実装する必要があり、現実的ではありません。

## ベンチマーク

全 11 条件での計測結果を以下に示します。`Load` には tokenizer の読み込みとウォームアップ（1 トークン入出力）を含みます。10 トークン生成、モデルは HDD に保存した状態での計測です。

**プロンプト**：AIの未来について考えてください。

| 形式 | 方式 | ロード | 推論 | 出力 |
|--------|--------|-----:|----------:|------|
| `safetensors_fp16` | CPU | 170.30s | 9.82s | AIの未来について考えるとき、いくつかの重要な |
| `onnx_fp16` | CPU | 213.59s | 9.59s | AIの未来について考えるとき、いくつかの重要な |
| `onnx_fp16` | DirectML | 149.75s | 4.75s | AIの未来について考えるとき、いくつかの重要な |
| `onnx_fp8` | CPU | 206.62s | 11.09s | AIの未来について考えるときは、いくつかの重要な |
| `onnx_fp8` | DirectML | 137.75s | 5.30s | AIの未来について考えるときは、いくつかの重要な |
| `onnx_q2_to_fp8` | CPU | 235.20s | 10.18s | AIの未来について考えるときは、いくつかの重要な |
| `onnx_q2_to_fp8` | DirectML | 131.84s | 2.48s | AI inki authoritative undert particles replicate faculty guess order |
| `onnx_q2_to_q8` | CPU | 106.68s | 199.62s | AIの未来について考えるとき、いくつかの重要な |
| `onnx_q2_to_q8` | DirectML | 8.65s | 7.02s | AI Nation informed simply Adult Hobby pis Agents contributing |
| `onnx_q2_to_q4` | CPU | 37.59s | 6.46s | AIの未来について考えるとき、いくつかの重要な |
| `onnx_q2_to_q4` | DirectML | 5.96s | 1.12s | AI Nation informed simply formats teacher norm Sh Earth |

【参考】1000 トークンまで生成した結果: [SAMPLE.md](https://github.com/7shi/ternary-bonsai-test/blob/main/SAMPLE.md)

DirectML の行で出力が英単語の羅列になっているのが、前節で述べたカスタム op 由来のグラフ構造問題です。CPU ではすべて正常な日本語が生成されています。

注目すべきは **onnx_q2_to_q4 / CPU** の列で、推論 6.46 秒という数値は、fp16 の DirectML 推論 4.75 秒に迫っています。

:::message
実際には **2 tps** 程度のため、実用には程遠い遅さです。(Ryzen 5 5600X)
:::

## 結論

検証の結果、Windows で Ternary-Bonsai-8B を動かすなら **q2 packed ONNX を q4 に変換して、CPU で推論する**のが現時点で最も**まし**な構成だと分かりました。

- ダウンロード約 1.75GB → 変換後約 3.5GB とコンパクト

DirectML で安定した出力品質が必要な場合は、safetensors 由来の FP16 / FP8 モデルを使うことになりますが、前述のように計算量的なメリットは失われます。ONNX Runtime や DirectML が `MatMulNBits` の 2 ビットモードや `GroupQueryAttention` などのカスタム op に対応すれば、より直接的な実行が可能になるでしょう。

## 関連記事

Ternary Bonsai では使用していませんが、3 値量子化の先駆けとなった BitNet を調査しました。

https://zenn.dev/7shi/articles/20260422-bitnet-algorithm
