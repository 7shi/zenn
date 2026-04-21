---
title: "BitNet の計算方法を読み解く"
emoji: "3️⃣"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["llm", "bitnet"]
published: true
---

BitNet は、LLM の重みを 3 値 {-1, 0, +1} に量子化することで、モデルサイズとメモリ使用量を削減しつつ、推論の高速化を目指した技術です。3 値量子化に最適化された内積の計算方法をソースコードから読み解きます。

- https://github.com/microsoft/BitNet

以下の commit を対象とします。

- [01eb415772c342d9f20dc42772f1583ae1e5b102](https://github.com/microsoft/BitNet/commit/01eb415772c342d9f20dc42772f1583ae1e5b102)

:::message
本記事の執筆には GLM-5.1, GPT-5.4, Claude Sonnet 4.6 を利用しました。
:::

## 概要

BitNet の推論は重みベクトル w（3値）と活性化ベクトル a（入力）の内積が基本となります。w の各要素は {-1, 0, +1} の 3 値で表現されており、この性質を活かして行列積を高速化する実装が 2 種類あります。

| 実装 | 中心演算 |
|:---|:---|
| MAD (Multiply-Add) | 2-bit に詰めた重みを展開して内積を計算 |
| LUT (Look-Up Table) | 部分和テーブルを作り参照と加減算で計算 |

どちらを使うかはビルド時に決まります。

```cmake:CMakeLists.txt:15-16
option(BITNET_ARM_TL1 "use tl1 on arm platform" OFF)
option(BITNET_X86_TL2 "use tl2 on x86 platform" OFF)
```

両オプションをオフにすると MAD が使われます。TL1 が ARM 向け LUT、TL2 が x86 向け LUT です。

## MAD

MAD は、2-bit に圧縮した重みをその場で展開し、SIMD の整数積和命令で内積を直接計算する方式です。前処理が少なくシンプルな構造で、llama.cpp の量子化推論に近い発想です。乗算を排除するのではなく、重みの圧縮によるメモリ帯域の削減と積和命令の効率を活かして高速化します。

### 量子化による近似

MAD が近似しているのは浮動小数点の内積 $\sum_i w_i a_i$ です。$w_i$ は 3 値の整数型ですが、$a_i$ が float のままでは SIMD 整数命令に乗らないため、int8 に量子化します（I8_S 形式）。

重みスケール $s_w = \max(|w_i|)$ を別途保持し、3 値重みは $t_i \in \{-1, 0, +1\}$ として $w_i \approx t_i s_w$ と近似します。活性化スケール $s_a = 127 / \max(|a_i|)$ で量子化した値を $q_i = \mathrm{round}(a_i s_a)$ とし、量子化時に $S = \sum_i q_i$ も計算しておきます。

整数演算で得た $r = \sum_i e_i q_i$（$e_i = t_i + 1 \in \{0, 1, 2\}$）から、元の内積は次のように復元できます：

$$
\sum_i w_i a_i \approx \frac{r - S}{s_a} \cdot s_w
$$

$-S$ は $e_i = t_i + 1$ のオフセット補正、$/ s_a$ は活性化スケールの逆変換、$\cdot s_w$ は重みスケールの復元です。

### 重みの持ち方（I2_S 形式）

MAD は重みを I2_S 形式で保持します。3 値を 2-bit にエンコードして（{-1, 0, +1} → {0, 1, 2}）、4 値を 1 バイトに詰めます。ブロックサイズはアーキテクチャ依存です。

```cpp:src/ggml-bitnet-mad.cpp:11-15
#if defined(__AVX__) || defined(__AVX2__) || defined(__AVX512F__) || defined(__SSSE3__)
#define QK_I2_S 128
#elif defined(__ARM_NEON)
#define QK_I2_S 64
#endif
```

パッキングでは 128 要素（= 4 グループ × 32）を 32 バイトに詰めます。

```cpp:src/ggml-bitnet-mad.cpp:81-88
for (int i = 0; i < n / QK_I2_S; i++) {
    for (int j = 0; j < QK_I2_S; j++) {
        int group_idx = j / 32;         // 4グループ（0-3）
        int group_pos = j % 32;
        uint8_t temp = (q8[i * QK_I2_S + j] << (6 - 2 * group_idx));
        i2_weight[i * 32 + group_pos] |= temp;
    }
}
```

各バイトに 4 つの 2-bit 値が詰まります。ブロック末尾にスケール係数を置きます。

```cpp:src/ggml-bitnet-mad.cpp:90-91
float* scale_ptr = (float*)((char*)i2_weight + n / 4);
scale_ptr[0] = i2_scale;
```

この形式の目的は精度変換ではなく、後段の SIMD 命令に都合のよいメモリ配置を作ることです。

### 推論の流れ

推論時はまず「シフトして 0x03 でマスクする」だけで 2-bit 重みを展開します（x86 AVX2）。

```cpp:src/ggml-bitnet-mad.cpp:225-234
__m256i xq8_3 = _mm256_loadu_si256((const __m256i*)(px));
__m256i xq8_2 = _mm256_srli_epi16(xq8_3, 2);
__m256i xq8_1 = _mm256_srli_epi16(xq8_3, 4);
__m256i xq8_0 = _mm256_srli_epi16(xq8_3, 6);

xq8_3 = _mm256_and_si256(xq8_3, mask);  // mask = 0x03
xq8_2 = _mm256_and_si256(xq8_2, mask);
xq8_1 = _mm256_and_si256(xq8_1, mask);
xq8_0 = _mm256_and_si256(xq8_0, mask);
```

展開した重みと int8 の活性化を `_mm256_maddubs_epi16` で積和し、16-bit を経由して 32-bit 累積に積み上げます。

```cpp:src/ggml-bitnet-mad.cpp:242-253
__m256i yq8_0 = _mm256_loadu_si256((const __m256i*)(py));
__m256i yq8_1 = _mm256_loadu_si256((const __m256i*)(py + 32));
__m256i yq8_2 = _mm256_loadu_si256((const __m256i*)(py + 64));
__m256i yq8_3 = _mm256_loadu_si256((const __m256i*)(py + 96));

xq8_0 = _mm256_maddubs_epi16(xq8_0, yq8_0);  // u8×s8 → i16 積和
xq8_1 = _mm256_maddubs_epi16(xq8_1, yq8_1);
xq8_2 = _mm256_maddubs_epi16(xq8_2, yq8_2);
xq8_3 = _mm256_maddubs_epi16(xq8_3, yq8_3);
```

`_mm256_maddubs_epi16` は符号なし u8 と符号付き s8 の要素積を取り、隣接ペアの和を i16 として返す命令です。

ARM では展開が同じシフト＋マスク操作で、積和命令が DOTPROD 有無で分かれます。

```cpp:src/ggml-bitnet-mad.cpp:385-405
#if defined(__ARM_FEATURE_DOTPROD)
accu = vdotq_s32(accu, q8_0, yq8_0);  // 直接 32-bit ドット積
accu = vdotq_s32(accu, q8_1, yq8_1);
accu = vdotq_s32(accu, q8_2, yq8_2);
accu = vdotq_s32(accu, q8_3, yq8_3);
#else
accula = vmlal_s8(accula, vget_low_s8(q8_0),  vget_low_s8(yq8_0));  // s8×s8 → i16 積和
accula = vmlal_s8(accula, vget_high_s8(q8_0), vget_high_s8(yq8_0));
// ... q8_1〜q8_3 も同様 ...
accu = vaddq_s32(accu, vmovl_s16(vget_low_s16(accula)));  // i16 → i32 昇格
accu = vaddq_s32(accu, vmovl_high_s16(accula));
#endif
```

最後に 8 つの int32 を水平加算してスカラー $r$ に戻し、$(r - S) / s_a \cdot s_w$ を計算して float に復元します。

### 速さの本質

MAD では乗算命令を実際に使っています。「3 値だから乗算不要」というわけではありません。MAD の利点は次の組み合わせです。

- 活性化を int8（I8_S）に量子化することで、1 命令で 32 要素を処理できる SIMD 整数積和命令が使える
- 重みが 2-bit（I2_S）に圧縮されているためメモリ帯域が少ない

### 並列化の二方向

MAD には並列化の方向が二種類あります。

- **Activation Parallel**: 同じ活性化ベクトルを複数の重みベクトルで共有する
- **Weight Parallel**: 同じ重みベクトルを複数の活性化ベクトルで共有する

`include/gemm-config.h` で並列度（`PARALLEL_SIZE = 4`）などを設定し、`nrc` が `PARALLEL_SIZE` の倍数かどうかでディスパッチします。

```cpp:src/ggml-bitnet-mad.cpp:1043-1056
void ggml_vec_dot_i2_i8_s(int n, float * s, size_t bs, const void * vx, size_t bx, const void * vy, size_t by, int nrc) {
    if (nrc % PARALLEL_SIZE == 0)
    {
#if defined(ACT_PARALLEL)
        ggml_vec_dot_i2_i8_s_Nx1(n, s, bs, vx, bx, vy, by, nrc);
#else
        ggml_vec_dot_i2_i8_s_1xN(n, s, bs, vx, bx, vy, by, nrc);
#endif
    }
    else
    {
        ggml_vec_dot_i2_i8_s_1x1(n, s, bs, vx, bx, vy, by, nrc);
    }
}
```

端数は 1×1 の基本パターンに落とします。

## LUT

3 値重みを使った内積

$$
y = \sum_i w_i a_i \quad (w_i \in \{-1, 0, +1\})
$$

は、各 $w_i$ が -1・0・+1 のいずれかであるため、次のように書き換えられます。

$$
y = \sum_{w_i = +1} a_i - \sum_{w_i = -1} a_i
$$

乗算が消え、加算と減算だけになります。LUT はこの原理を「事前計算テーブル」として直接実装しています。

### 処理の流れ

1. **活性化量子化**: テンソル全体の絶対値最大から `scales = 127 / max(|a|)` を求め、活性化を int8 相当に変換する
2. **LUT 構築**: 活性化の小さな組（TL1 では 2 要素、TL2 では 3 要素）に対して、重みの組み合わせすべての部分和を加減算で事前計算する
3. **テーブル参照 GEMM**: 重み側のインデックスで LUT を引き、取得した部分和を加算して内積を復元する
4. **スケール復元**: `int32 累積 / lut_scales * weight_scales` で浮動小数点に戻す

### 活性化量子化

活性化量子化は x86 と ARM で実装が分かれますが、目的は同じです。x86 の例を示します。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl2.h:71-88
inline int32_t per_tensor_quant(int k, void* lut_scales_, void* b_) {
    __m256 max_vec = _mm256_set1_ps(0.f);
    const __m256 vec_sign = _mm256_set1_ps(-0.0f);
    for (int i = 0; i < k / 8; i++) {
        __m256 vec_b = _mm256_loadu_ps(b + i * 8);
        __m256 vec_babs = _mm256_andnot_ps(vec_sign, vec_b);
        max_vec = _mm256_max_ps(vec_babs, max_vec);
    }
    // ... 水平 max ...
    float scales = 127 / _mm_cvtss_f32(max1);
    *lut_scales = scales;
```

ここでの目的は精度向上ではなく、LUT に入れる部分和を SIMD で扱いやすい整数表現に落とすことです。

### LUT 構築の仕組み

活性化 2 要素 $(b_0, b_1)$ に対して、重みペア $(w_0, w_1) \in \{-1, 0, +1\}^2$ の 9 通りの部分和を作るとき、必要な演算は加算と減算だけです。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl1.h:136-152
vec_lut[0] = vdupq_n_s16(0) - vec_bs_0 - vec_bs_1;  // 0 - b0 - b1
vec_lut[1] = vdupq_n_s16(0) - vec_bs_0;             // 0 - b0
vec_lut[2] = vdupq_n_s16(0) - vec_bs_0 + vec_bs_1;  // 0 - b0 + b1
vec_lut[3] = vdupq_n_s16(0) - vec_bs_1;             // 0 - b1
vec_lut[4] = vdupq_n_s16(0);                        // 0
vec_lut[5] = vec_bs_1;                              //     b1
vec_lut[6] = vec_bs_0 - vec_bs_1;                   //     b0 - b1
vec_lut[7] = vec_bs_0;                              //     b0
vec_lut[8] = vec_bs_0 + vec_bs_1;                   //     b0 + b1
```

TL2 の 3 要素版（27 通りのうち 16 パターン）でも同じく加減算のみです。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl2.h:120-149
vec_lut[13] = vec_b0i + vec_b1i + vec_b2i;    // b0 + b1 + b2
vec_lut[12] = vec_b0i + vec_b1i;              // b0 + b1
vec_lut[11] = vec_b0i + vec_b1i - vec_b2i;    // b0 + b1 - b2
// ...
vec_lut[0]  = 0;                              // 0
vec_lut[15] = 0;                              // (パディング)
vec_lut[14] = 0;                              // (パディング)
```

LUT 構築後は 8×8 転置を経て int8 にパックし、SIMD 参照命令で引きやすいメモリ配置に整えます。

### 推論時の処理

LUT を作った後の推論ループは、重みのインデックスでテーブルを引いて累積するだけです。TL1 (ARM) の例を示します。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl1.h:206-214
uint8x16_t vec_a0_top = vshrq_n_u8(vec_a_0, 4);
uint8x16_t vec_a0_bot = vandq_u8(vec_a_0, vec_mask);

int8x16_t vec_v_0_left_tmp0  = vqtbl1q_s8(vec_lut[8 * k + 0], vec_a0_top);
int8x16_t vec_v_0_left_tmp1  = vqtbl1q_s8(vec_lut[8 * k + 1], vec_a0_top);
int8x16_t vec_v_0_right_tmp0 = vqtbl1q_s8(vec_lut[8 * k + 2], vec_a0_bot);
int8x16_t vec_v_0_right_tmp1 = vqtbl1q_s8(vec_lut[8 * k + 3], vec_a0_bot);
```

TL2 (x86) でも同じ発想で `_mm256_shuffle_epi8` で 4-bit インデックスを引き当てています。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl2.h:316-328
__m256i vec_v_top_0 = _mm256_and_si256(
    _mm256_srli_epi16(vec_a_0, 4), vec_mask);
__m256i vec_v_top_fir_0 = _mm256_shuffle_epi8(
    _mm256_set_m128i(vec_k1_0, vec_k1_0), vec_v_top_0);
__m256i vec_v_top_sec_0 = _mm256_shuffle_epi8(
    _mm256_set_m128i(vec_k2_0, vec_k2_0), vec_v_top_0);
```

`vqtbl1q_s8`（ARM）と `_mm256_shuffle_epi8`（x86）はどちらも SIMD レジスタ内の 16 バイトテーブルを 4-bit インデックスで高速に引く命令です。

通常の行列積と対比すると次のようになります。

| 通常の行列積 | LUT |
|:---|:---|
| $y = \sum_i w_i a_i$（毎回乗算） | LUT 構築: $\mathrm{LUT}[\mathrm{idx}] = \pm b_0 \pm b_1$（加減算のみ） |
| 各項で乗算を実行 | 推論: $y \mathrel{+}= \mathrm{LUT}[\mathrm{idx}_t]$（参照と加算のみ） |

### TL1 と TL2 の違い

TL1（ARM 向け）と TL2（x86 向け）でテーブルの単位が異なる根本の理由は、CPU ごとに「1 命令で効率よく実行できる演算の形」が違うからです。主な差は次の 4 点です。

| | ARM NEON / DOTPROD | x86 AVX2 |
|:---|:---|:---|
| 積和命令 | `vdotq_s32`（DOTPROD）/ `vmlal_s8` | `_mm256_maddubs_epi16` |
| テーブル参照命令 | `vqtbl1q_s8`（16 バイト） | `_mm256_shuffle_epi8`（256-bit） |
| SIMD 幅 | 128-bit | 256-bit |
| 転置・pack | `vzip` 系 | `_mm256_packs_epi32` 系 |

**MAD での影響**: x86 AVX2 では `_mm256_maddubs_epi16` が u8×s8 の積和を 1 命令でこなせるため、2-bit 展開後の重みと int8 活性化をそのまま流し込みやすいです。ARM 側は DOTPROD 拡張があれば `vdotq_s32` で同様に処理できますが、ない場合は `vmlal_s8` 経由の 16-bit 積和になり、書き方が変わります。

**LUT での影響**: ARM NEON の `vqtbl1q_s8` は 16 バイトのテーブルを 1 命令で引けるため、2 要素単位の 9 通り（16 エントリに収まる）が自然に対応します。一方 x86 の `_mm256_shuffle_epi8` は 256-bit 幅で並列化するため、3 要素単位を主軸にして 16 エントリのテーブルに収める構成が効率的です。K 次元の端数には 2 要素版を併用します。

アルゴリズムの本質は同じで、ハードウェアの都合に合わせて表現が変わっているだけです。

## 補助要素

### 重みのテンソル変換

LUT では推論前に重みテンソルをブロック単位に並べ替えます。ブロックサイズ（BM, BK）は行列形状ごとに固定値が決まっており、その情報を `bitnet_tensor_extra` に持たせて後続の GEMM カーネルが参照します。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl1.h:583-596
void ggml_bitnet_transform_tensor(struct ggml_tensor * tensor) {
    int k = tensor->ne[0];
    int m = tensor->ne[1];
    int bk = 0, bm = 0;

    if (m == 3200 && k == 8640) {
        bm = BM3200_8640;   // 160
        bk = BBK3200_8640;  // 64
    }
    else if (m == 3200 && k == 3200) {
        bm = BM3200_3200;   // 320
        bk = BBK3200_3200;  // 128
    }
    else if (m == 8640 && k == 3200) {
        bm = BM8640_3200;   // 320
        bk = BBK8640_3200;  // 64
    }
    // ...
}
```

この変換は推論開始時に一度だけ行われます。

### 8×8 転置

LUT 構築の最後に 8×8 転置が入るのは、作った部分和テーブルを SIMD の参照命令で引きやすいメモリ配置に整えるためです。ARM と x86 でそれぞれのレジスタ配置に合わせて実装されています。

ARM（NEON）版は `vzipq_s16` を 3 段階で組み合わせます。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl1.h:60-91
int16x8x2_t q04 = vzipq_s16(*v0, *v4);                            // 1
int16x8x2_t q0246_0 = vzipq_s16(q04.val[0], q26.val[0]);          // 2
int16x8x2_t q_fin_0 = vzipq_s16(q0246_0.val[0], q1357_0.val[0]);  // 3
// ...
```

x86（AVX2）版は `_mm256_merge_epi32/64/si128` を 3 段階で組み合わせます。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl2.h:57-68
_mm256_merge_epi32(*v0, *v1, &w0, &w1);  // 1. 32-bit 単位でマージ
_mm256_merge_epi32(*v2, *v3, &w2, &w3);
_mm256_merge_epi32(*v4, *v5, &w4, &w5);
_mm256_merge_epi32(*v6, *v7, &w6, &w7);
_mm256_merge_epi64(w0, w2, &x0, &x1);    // 2. 64-bit 単位でマージ
// ...
_mm256_merge_si128(x0, x4, v0, v1);      // 3. 128-bit 単位でマージ
// ...
```

### 形状別ディスパッチ

コードに多数ある形状分岐（`if (m == 3200 && k == 8640) ...`）は、「アルゴリズムが何をするか」を変えているのではなく、「どの最適化済みカーネルを呼ぶか」を選んでいるだけです。固定形状ごとにプリセットカーネルを用意するのが BitNet の設計方針で、汎用性より特定モデルへの最適化を優先しています。

```cpp:preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl1.h:553-581
void ggml_qgemm_lut(int m, int k, void* A, void* LUT, void* Scales, void* LUT_Scales, void* C) {
    if (m == 3200 && k == 8640) {
        qgemm_lut_3200_8640(A, LUT, Scales, LUT_Scales, C);
    }
    else if (m == 3200 && k == 3200) {
        qgemm_lut_3200_3200(A, LUT, Scales, LUT_Scales, C);
    }
    // ...
}
```

### コード生成

LUT カーネルは `utils/codegen_tl1.py` / `utils/codegen_tl2.py` で生成されます。モデル形状と BK パラメータを受け取り、対応する SIMD カーネルを出力します。手書きではなく生成済みコードなので、ファイル間に似たパターンが大量に繰り返されています。

## まとめ

MAD と LUT を比較します。スケール変換はどちらも浮動小数点乗算を行うため、以下の「乗算」はメインの計算ループに限った話です。

| 観点 | MAD  | LUT  |
|:---|:---|:---|
| 乗算 | SIMD 整数積和命令 | 排除 |
| 前処理 | 少ない | 多い（量子化 + LUT 構築） |
| 推論ループ | 展開 + 積和 | テーブル参照 + 加算 |
| 形状依存性 | 比較的低い | 高い（プリセットカーネル） |
| 実装の複雑さ | 低い | 高い |
| 3 値性の活用 | 2-bit 圧縮によるメモリ削減 | 乗算回避 |

## 参照ファイル

| ファイル | 役割 |
|:---|:---|
| [src/ggml-bitnet-mad.cpp](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/src/ggml-bitnet-mad.cpp) | MAD 本体 |
| [src/ggml-bitnet-lut.cpp](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/src/ggml-bitnet-lut.cpp) | LUT の初期化と周辺処理 |
| [include/ggml-bitnet.h](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/include/ggml-bitnet.h) | 公開 API と補助データ構造 |
| [include/gemm-config.h](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/include/gemm-config.h) | MAD の並列化設定 |
| [preset_kernels/*/bitnet-lut-kernels-tl1.h](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl1.h) | ARM 向け LUT カーネル |
| [preset_kernels/*/bitnet-lut-kernels-tl2.h](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/preset_kernels/bitnet_b1_58-3B/bitnet-lut-kernels-tl2.h) | x86 向け LUT カーネル |
| [utils/codegen_tl1.py](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/utils/codegen_tl1.py) | TL1 カーネル生成 |
| [utils/codegen_tl2.py](https://github.com/microsoft/BitNet/blob/01eb415772c342d9f20dc42772f1583ae1e5b102/utils/codegen_tl2.py) | TL2 カーネル生成 |

## 関連記事

BitNet とは別の 3 値量子化アプローチである Ternary Bonsai を試しました。

https://zenn.dev/7shi/articles/20260419-ternary-bonsai
