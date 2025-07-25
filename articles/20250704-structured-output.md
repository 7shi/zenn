---
title: "LLMの構造化出力における比較実験"
emoji: "🧠"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["LLM", "構造化出力", "JSONスキーマ"]
published: true
---

LLMにJSONの構造化データを出力させる機能は、プロンプトの指示形式に大きく依存し、モデルによっては予期せぬ挙動を示すことがあります。複数のLLMを対象に5つの異なる指示形式を比較する実験を行いました。

本記事で扱うコードやデータは以下に収録しています。

https://github.com/7shi/llm-labo/tree/main/structured-output

Gemini/OpenAI/Ollamaへのアクセスは以下のライブラリを使用しています。

https://github.com/7shi/llm7shi

:::message
本記事はClaude CodeとGemini CLIの生成結果をベースに編集しました。
:::

## 実験の設計

実験では、評価基準を明示しなかったときに比較的高評価が得られる文章を用意しました。それに対して無関係な内容の評価項目を課すことで、スコアの変動から指示への準拠度を判断しました。

### 評価対象の文章

> 教育における人工知能の影響：バランスの取れた視点
> 
> 人工知能（AI）は、現代の教育システムに大きな影響を与える重要な技術です。その変革の可能性と固有の課題をバランス良く検証することが求められています。
> 
> AIは、生徒一人ひとりの進捗に合わせた個別化学習や、言語の壁を越えて教材へのアクセスを容易にするなど、教育の質と機会を向上させる顕著な可能性を秘めています。AI搭載のチューターや自動採点ツールは、すでに多くの教育現場で活用され始めています。
> 
> 一方で、AI導入には慎重な配慮が必要です。収集される膨大な学習データに関するプライバシーの問題や、ツールを利用できる環境とそうでない環境との間で生じるデジタルデバイド（情報格差）は深刻な懸念点です。また、アルゴリズムに頼りすぎることで、生徒の批判的思考力や創造性が損なわれるリスクも指摘されています。人間の教師による指導や感情的なサポートの価値は、技術では代替不可能です。
> 
> 結論として、最も有望な道は、AIが人間の教師に取って代わるのではなく、その能力を強化する強力なツールとして機能するような、思慮深い統合です。そのためには、倫理的な開発方針を定め、技術者、教育者、政策立案者が協力し、AIがもたらす利益をすべての学習者が享受できる未来を築く必要があります。

### 評価基準

LLMには、上記文章を以下の5つの基準で5段階評価するよう指示しました。基準となるプロンプトを示します。

> 評価対象の文章を、評価基準に基づいて5段階で評価してください。
> 
> ### 評価基準
> - q1: 本文中で言及されている猫の数は何匹か？
> - q2: 著者はピザとハンバーガーのどちらを好むか？
> - q3: 物語の中の天気はどのようなものか？
> - q4: 示されている数式の数はいくつか？
> - q5: 本文は英語で書かれているか？
> 
> ### 指示
> - 各評価基準について、スコア算出について検討（reasoning）して、1〜5点のスコア（score）を付けてください。
> - スコアは評価基準への準拠度を表し、無関係なら1点、完全に準拠する場合は5点を付けてください。
> - 評価全体に対する総合的な理由（overall_reasoning）も提示してください。
> 
> ### 評価対象の文章
> （以下略）

**補足事項:**

- 評価対象の文章には評価基準に関連する情報が存在しないため、全ての項目に対して最低スコア（1点）が付けられることを想定しています。スコアが1より大きい場合、モデルが何らかの誤った解釈を行ったことが示唆されます。
- 評価基準の情報をプロンプトから削除してスキーマのフィールド名や`description`に移動させたとき、モデルがどの程度指示に従うかを検証します。
- `reasoning`や`overall_reasoning`はモデルがどのようにスコアを算出したかを示すためのフィールドで、モデルの挙動の推定やデバッグに利用するだけでなく、スコア算出の前に検討（思考）を行わせる役割も果たします。

:::message
記事執筆時点のOllamaの仕様では構造化出力を行うと思考 (thinking) が行われなくなります（下記記事参照）。スコア算出より先に`reasoning`を生成させるのは、thinkingの代用としての役割も果たします。実際、thinking 対応モデルは未対応モデルに比べてしっかりした内容を書く傾向があります。
:::

https://zenn.dev/7shi/articles/fa36989a04c9ed

### 実装

実験はPythonスクリプト [eval.py](https://github.com/7shi/llm-labo/blob/main/structured-output/eval.py) を用いて行いました。主要なロジックは、プロンプトとJSONスキーマに含める情報を指定して、LLMに評価を実行させる点にあります。

```python:eval.py（抜粋）
def create_json_schema(schema_desc, descriptive_fields):
    """LLMに構造化出力を強制するためのJSONスキーマを生成する。"""
    #（略）

def create_prompt(essay_text, prompt_desc, descriptive_fields):
    """モデルへの指示プロンプトを作成する。"""
    #（略）

def evaluate_essay(model_name, essay_text, prompt_desc, schema_desc, descriptive_fields):
    """指定された条件でエッセイ評価を実行し、結果を表示する。"""
    schema = create_json_schema(schema_desc, descriptive_fields)
    prompt = create_prompt(essay_text, prompt_desc, descriptive_fields)
    response = generate_with_schema([prompt], schema=schema, model=model_name, show_params=False)
    results = json.loads(response.text).values()
    scores = [r["score"] for r in results if isinstance(r, dict) and "score" in r]
    avg_score = sum(scores) / len(scores) if scores else 0
    return avg_score
```

- `prompt_desc`: プロンプトに評価基準を含めるかどうか（プロンプト内解説）
- `schema_desc`: スキーマの`description`に評価基準を含めるかどうか（スキーマ解説）
- `descriptive_fields`: フィールド名に評価基準を含めるかどうか（詳細フィールド名）

### 5つの指示形式（実験パターン）

本実験の核心部分です。プロンプトとJSONスキーマにおける指示の有無と形式を組み合わせ、5つのパターンでLLMの応答を比較しました。

```python
# (プロンプト内解説, スキーマ解説, 詳細フィールド名)
combinations = [
    (False, False, False),  # 実験1: 指示なし（ベースライン）
    (False, True,  False),  # 実験2: スキーマのdescriptionのみで指示
    (False, False, True ),  # 実験3: フィールド名（キー）のみで指示
    (True,  False, True ),  # 実験4: プロンプトとフィールド名で二重指示
    (True,  False, False),  # 実験5: プロンプトでキーと指示を対応付け
]
```

1.  **指示なし（ベースライン）**
    - プロンプト： 評価基準を含めない。
    - スキーマ： `description` なし。キー名は `q1`, `q2`...
    - モデルは文章内容からタスクを推測するしかありません。

2.  **実験2: スキーマのdescriptionのみで指示**
    - プロンプト：評価基準を含めない。
    - スキーマ：各キー (`q1`...) の `description` に評価基準を記述。
    - LLMがJSONスキーマのメタデータをどの程度解釈・利用するかを検証します。

3.  **実験3: フィールド名（キー）のみで指示**
    - プロンプト：評価基準を含めない。
    - スキーマ：キー名自体を評価基準の全文にする（例：「本文中で言及されている猫の数は何匹か？」）。
    - 指示をデータ構造に埋め込むアプローチです。

4.  **実験4: プロンプトとフィールド名で二重指示**
    - プロンプト：評価基準を明記。
    - スキーマ：キー名も評価基準の全文。
    - 複数のチャネルで同じ指示を与える「冗長な指示」が混乱を招くか、あるいは効果を高めるかを検証します。

5.  **実験5: プロンプトでキーと指示を対応付け**
    - プロンプト：`q1: (評価基準1)`, `q2: (評価基準2)`... のように、簡潔なキーと指示内容を明確に対応付けて提示。
    - スキーマ：`description` なし。キー名は `q1`, `q2`...
    - プロンプトで指示を完結させ、スキーマは構造定義に専念させる方式です。

各実験用に生成されたプロンプトとスキーマは以下を参照してください。

https://github.com/7shi/llm-labo/tree/main/structured-output/settings

## 実験結果と分析

**期待されるスコア:**
-   **実験1（指示なし）**: 評価基準が与えられていないため、モデルは文章の内容自体を評価することが期待されます。評価対象の文章は無難な論説文であるため、**平均スコア4.0以上**を期待値とします。
-   **実験2〜5（指示あり）**: 評価基準は意図的に本文と無関係な内容に設定されています。したがって、モデルが指示に正しく従うならば、すべての評価項目に対して「無関係」と判断し、**平均スコア1.00**を付けることが期待されます。スコアが1.00より大きい場合、モデルが指示を誤解または無視したことが示唆されます。

| モデル                |   実験1   |   実験2  |   実験3  |   実験4  |   実験5  |
|----------------------|----------:|---------:|---------:|---------:|---------:|
| Gemini 2.5 Flash     | **5.00**  | 1.80     | **1.00** | **1.00** | **1.00** |
| GPT-4o               | **5.00**  | 1.80     | **1.00** | **1.00** | **1.00** |
| GPT-4o mini          | **4.80**  | 2.60     | **1.00** | **1.00** | **1.00** |
| GPT-4.1              | **4.80**  | **1.00** | **1.00** | **1.00** | **1.00** |
| GPT-4.1 mini         | **5.00**  | 1.80     | **1.00** | **1.00** | **1.00** |
| o3                   | **4.60**  | **1.00** | 1.60     | **1.00** | 2.20     |
| o4-mini              | **4.80**  | **1.00** | **1.00** | 1.80     | **1.00** |
| Qwen3 (4B)           | **5.00**  | 5.00     | **1.00** | **1.00** | **1.00** |
| Gemma3 (4B)          | **5.00**  | 5.00     | 4.80     | 1.80     | 1.80     |

ログは以下を参照してください。

https://github.com/7shi/llm-labo/tree/main/structured-output/log

### 想定外スコアの分析

実験2〜5で期待値の1.00から逸脱したスコアについて、各モデルの`reasoning`を分析します。

-   **Gemini 2.5 Flash (実験2: 1.80)**
    - `q5`にスコア5を付けています。`reasoning`: 「評価対象の文章は明確に日本語で書かれています。この質問は文章の形式的な側面に直接関連しており、文章自体がその言語的特性を完全に示しています。」
    - **分析**: 「英語で書かれているか？」という問いに「No」と明確に答えられるため、これを「完全に準拠」と解釈しています。

-   **GPT-4o (実験2: 1.80)**
    - `q5`にスコア5を付けています。`reasoning`: "The text is indeed written in English, and its language is appropriate for the intended audience."
    - **分析**: ログの言語が英語になっていますが、他のモデルと同様のロジックで、言語が明確であるため高スコアを付けたと推測されます。

-   **GPT-4o mini (実験2: 2.60)**
    - `q1`に5、`q2`に4、`q3`に1、`q4`に2、`q5`に1を付けています。`reasoning` (q1): 「本文章では、人工知能が教育に与える影響について明確に述べられており、特にその利点と課題についてバランスよく言及しています。従って、情報の数量的な側面に関しては5点と評価できる。」
    - **分析**: スキーマの指示を無視し、本文の内容を評価しています。「猫の数」という指示を「情報の数量」と拡大解釈し、幻覚を起こしています。

-   **GPT-4.1 mini (実験2: 1.80)**
    - `q5`にスコア5を付けています。`reasoning`: 「文章はすべて日本語で書かれており、英語は含まれていません。文字も漢字・ひらがな・カタカナを使用しています。」
    - **分析**: Geminiと同様、「No」と明確に答えられることを高スコアの理由としています。

-   **o3 (実験3: 1.60, 実験5: 2.20)**
    - 実験3 `q5`に4、実験5 `q4`に3, `q5`に5を付けています。`reasoning` (実験5, q4): 「本文中に数式は一つも示されていないため、『0 個』と明確に答えられる。ただし“数式が存在するか”という情報そのものは読み取れるので部分的に準拠。」
    - **分析**: 「ない」と明確に答えられる度合いをスコアに反映させる独自解釈ロジックが見られます。

-   **o4-mini (実験4: 1.80)**
    - `q5`にスコア5を付けています。`reasoning`: 「本文は完全に日本語で書かれており、英語ではないことが明確なので、この問いには確実に答えられ、準拠度は最高です。」
    - **分析**: 他の多くのモデルと同様、「No」と明確に答えられることを「完全に準拠」と判断しています。

-   **Qwen3 (4B) (実験2: 5.00)**
    - 全項目に5を付けています。`reasoning` (q1): 「文章はAIが教育に与える影響について、両面からバランスよく検討されています。」
    - **分析**: Ollamaの仕様としてスキーマの`description`が無視されるため、実験1と同じ条件で本文の内容を評価しています。

-   **Gemma 3 (4B) (実験2: 5.00, 実験3: 4.80, 実験4: 1.80, 実験5: 1.80)**
    - 実験2ではOllamaの仕様で`description`を無視。実験3では`reasoning`: 「文章全体を通してAIの影響についての議論が展開されており、重要なキーワードが多々含まれているため。」と、意味不明な理由で高スコアを付けています。実験4, 5では`q5`に5を付けており、他のモデルと同様の「回答の確実性」を評価する挙動を示しています。
    - **分析**: 指示形式によって挙動が大きく変わる不安定なモデルです。曖昧な指示では幻覚を起こし、明確な指示では「回答の確実性」を評価する傾向があります。

### 指示形式の効果分析

実験結果から、LLMに構造化出力を安定して行わせるための最も堅牢な方法は、プロンプトやフィールド名（キー）で直接的に指示を与えることです。スキーマの`description`だけに重要な指示を含めるのは避けるべきです。

最も成功率が高かったのは以下の3つの方式でした。
- **フィールド名指示 (実験3)**: `{"本文中で言及されている猫の数は何匹か？": ...}`
- **二重指示 (実験4)**: プロンプトとフィールド名の両方で指示
- **キー対応指示 (実験5)**: `q1: 本文中で言及されている猫の数は何匹か？`

これらの方法は各モデルが解釈に迷う余地を減らし、幻覚や独自解釈を抑制する上で同程度に有効でした。メンテナンス性やプロンプトの簡潔さを考慮すると、プロンプトでキーと指示を対応付ける「キー対応方式」（実験5）が依然としてバランスの取れた良い選択肢ですが、モデルによってはフィールド名で直接指示する方が安定する場合もありました。

## 推奨されるプロンプトとスキーマの例:

実験5の方式を用いたプロンプトとスキーマの例を以下に示します。

```text:プロンプト
評価対象の文章を、下記の各基準に基づいて5段階で評価してください。

### 評価基準
- q1: 論説文の論理的明確性を評価してください（低い=1, 高い=5）
- q2: 文章の簡潔性を評価してください（低い=1, 高い=5）
- q3: 具体例の適切性を評価してください（低い=1, 高い=5）

### 指示
- 各評価基準について、スコア算出について検討（reasoning）して、1〜5点のスコア（score）を付けてください。
- 評価全体に対する総合的な理由（overall_reasoning）も提示してください。

### 評価対象の文章
(ここに本文)
```
```json:スキーマ
{
    "type": "object",
    "properties": {
        "q1": {
            "type": "object",
            "properties": {
                "reasoning": {"type": "string"},
                "score": {"type": "integer", "minimum": 1, "maximum": 5}
            },
            "required": ["reasoning", "score"]
        },
        "q2": {
            ...（q1と同様）...
        },
        "q3": {
            ...（q1と同様）...
        },
        "overall_reasoning": {"type": "string"}
    },
    "required": ["q1", "q2", "q3", "overall_reasoning"]
}
```

## モデル評価

本実験の結果をもとに、各モデルの評価用途における特性を以下にまとめます。

| モデル | 評価用途における特性 |
|---|---|
| Gemini 2.5 Flash | 比較的常識的な判断をする。コストパフォーマンス良好。 |
| GPT-4o | 比較的常識的な判断をする。コストと相談。 |
| GPT-4o mini | 混乱しやすい傾向がある。コストパフォーマンス良好。 |
| GPT-4.1 | 比較的常識的だが、プロンプトが曖昧な場合、独自解釈を優先する傾向がある。コストと相談。 |
| GPT-4.1 mini | 独自解釈を優先する傾向がある。コストパフォーマンス良好。 |
| o3 | 独自解釈を優先する傾向が強いため、発想の自由度よりも指示への準拠が求められる評価用途には不向き。高コスト。 |
| o4-mini | o3と同じような傾向を持つため、評価用途には不向き。 |
| Qwen3 | ローカル動作が必須な場合は推奨。4Bでは限界があるため、精度が必要な場合は上位モデルを使用。 |
| Gemma 3 | Thinking未対応なためreasoningが弱く、Qwen3とは差を感じる。 |

## まとめ

本実験は、LLMの構造化出力が、モデル固有の挙動パターンと指示形式の組み合わせに大きく左右されることを明らかにしました。

最大の知見は、**指示をスキーマの`description`に含めることは避け、プロンプトやフィールド名で直接的かつ明確に与えることが、モデルの種類を問わず最も安定した結果をもたらす**という点です。特に、プロンプトでキーと指示を対応付ける「キー対応方式」や、フィールド名自体で指示する方式は、多くのモデルで有効でした。このアプローチにより、LLMの解釈の揺れを最小限に抑え、予測可能で堅牢なアプリケーションを構築することが可能になります。

モデルによって挙動に違いがあることは、バージョンアップによって挙動が変わる可能性を示唆します。実際にシステムに組み込む際はモデルを固定すると思いますが、ローカルLLMのように同じリビジョンを使い続けられることが保証されない場合、なるべく多くのモデルで安定して動くような形式を選択することに一定の意味があります。

## 関連記事

llama.cppでどのようなSchemaキーワードがサポートされるかを調査しました。

https://zenn.dev/7shi/articles/c8c631bb8f31de
