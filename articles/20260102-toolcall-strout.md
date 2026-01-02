---
title: "ツールコールによる構造化出力の代用"
emoji: "🔧"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["ollama", "python", "構造化出力"]
published: true
---

以前、Claude API では構造化出力がサポートされていなかったため、ツールコールでの代用が推奨されていました（現在はプレビュー版としてサポートされています）。興味深い手法ではあるので、Ollama に移植して動作を確認します。

:::message
用語には揺れがあり、tool calling, tool use, function calling などいくつか表現がありますが、本記事では「ツールコール」で統一します。
:::

## 構造化出力の代用としてのツールコール

ツールコールは「現在時刻を知る」「Web検索する」といった外部機能をLLMに実行させるためのものですが、「結果を出力する架空の関数」を定義し、それを強制的に呼ばせることで、その関数の引数として構造化されたデータを抽出することが可能です。

Claude Cookbooks にサンプルが掲載されています。

- [Extracting Structured JSON using Claude and Tool Use](https://github.com/anthropics/claude-cookbooks/blob/main/tool_use/extracting_structured_json.ipynb)

関数の引数（`input_schema`）に、構造化出力のスキーマを押し込んだような構造になっています。

```python:一部抜粋
tools = [
    {
        "name": "print_summary",
        "description": "Prints a summary of the article.",
        "input_schema": {
            "type": "object",
            "properties": {
                "author": {"type": "string", "description": "Name of the article author"},
                "topics": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": 'Array of topics, e.g. ["tech", "politics"]. Should be as specific as possible, and can overlap.',
                },
                "summary": {
                    "type": "string",
                    "description": "Summary of the article. One or two paragraphs max.",
                },
                "coherence": {
                    "type": "integer",
                    "description": "Coherence of the article's key points, 0-100 (inclusive)",
                },
                "persuasion": {
                    "type": "number",
                    "description": "Article's persuasion score, 0.0-1.0 (inclusive)",
                },
            },
            "required": ["author", "topics", "summary", "coherence", "persuasion", "counterpoint"],
        },
    }
]
```

コンテキストを与えた上で "Use the `print_summary` tool." と指示することで、本文を引数の形式に合うように加工することで要約を行います。

## Ollama への移植と docstring の活用

この「ツールコールによる抽出」という考え方は、Ollama などのローカル LLM でも有効です。Ollama の Python ライブラリでは、docstring を活用した定義がサポートされています。

https://zenn.dev/7shi/articles/20251231-ollama-tools

これを利用して、想定される動作や引数の仕様を記述した空の関数（スタブ）を定義します。

```py
def print_summary(
    author: str,
    topics: List[str],
    summary: str,
    coherence: int,
    persuasion: float,
    counterpoint: str,
) -> None:
    """Prints a summary of the article.

    Args:
        author: Name of the article author
        topics: Array of topics, e.g. ["tech", "politics"]. Should be as specific as possible, and can overlap.
        summary: Summary of the article. One or two paragraphs max.
        coherence: Coherence of the article's key points, 0-100 (inclusive)
        persuasion: Article's persuasion score, 0.0-1.0 (inclusive)
        counterpoint: Alternative perspective or counterargument to the article's main points
    """
    return
```

:::message
元のコードでは `counterpoint` の説明が抜けていたため補っています。
:::

これ以外の部分を、可能な限り同じスタイルで移植したコードを示します。

```py
import json
import requests
from typing import List
from bs4 import BeautifulSoup
from ollama import chat

MODEL_NAME = "qwen3:4b"

url = "https://www.anthropic.com/news/third-party-testing"
response = requests.get(url, timeout=30)
soup = BeautifulSoup(response.text, "html.parser")
article = " ".join([p.text for p in soup.find_all("p")])

query = f"""
<article>
{article}
</article>

Use the `print_summary` tool.
"""

tools = [print_summary]
response = chat(
    model=MODEL_NAME, options={"num_predict": 4096}, tools=tools, messages=[{"role": "user", "content": query}]
)
json_summary = None
for tool_call in response.message.tool_calls or []:
    if tool_call.function.name == "print_summary":
        json_summary = tool_call.function.arguments
        break

if json_summary:
    print("JSON Summary:")
    print(json.dumps(json_summary, indent=2, ensure_ascii=False))
else:
    print("No JSON summary found in the response.")
```

このコードは以下の記事を要約して、構造化された JSON として出力します。

https://www.anthropic.com/news/third-party-testing

```json:実行結果
JSON Summary:
{
  "author": "Anthropic",
  "coherence": 95,
  "counterpoint": "Self-governance by private companies may lead to inconsistent standards, favoring larger firms with resources, and could undermine public trust if not transparently managed.",
  "persuasion": 0.85,
  "summary": "Anthropic advocates for a robust third-party testing regime to mitigate risks from frontier AI systems, emphasizing the need for oversight to prevent misuse, accidents, and societal harm. The article argues that current self-governance approaches are insufficient, calling for an ecosystem of trusted testing across industry, government, and academia. Key priorities include addressing national security risks, ensuring transparency in AI capabilities, and developing standards to balance safety with innovation. The authors stress that third-party testing is critical for validating AI safety, enabling broader societal participation in AI oversight, and avoiding the pitfalls of overly restrictive or ineffective regulation. They also highlight the importance of iterative development, noting that testing regimes must evolve as AI capabilities advance.\n\nThe proposal outlines a framework where third-party testing complements sector-specific regulations, drawing parallels to product safety standards in industries like healthcare and aerospace. Challenges include designing effective metrics, ensuring equitable access for all AI developers, and avoiding regulatory capture. The authors acknowledge debates around openly accessible models and the need for minimal viable policies that are both practical and adaptable. Ultimately, they envision a future where third-party testing becomes a legal requirement, fostering a safer and more transparent AI landscape.",
  "topics": [
    "AI safety",
    "third-party testing",
    "regulatory frameworks",
    "national security",
    "AI policy"
  ]
}
```

参考までに、上の実行結果を GPT-5.2 で日本語に翻訳したものを示します。

```json:日本語訳
JSON 要約:
{
  "著者": "Anthropic",
  "一貫性": 95,
  "反論": "民間企業による自己統治は、標準が一貫しなくなる可能性があり、リソースのある大企業が有利になり得るほか、透明性のある運用がなされなければ公共の信頼を損なうおそれがある。",
  "説得力": 0.85,
  "要約": "Anthropicは、フロンティアAIシステムに伴うリスクを軽減するために、強固な第三者テスト体制を提唱し、悪用・事故・社会的被害を防ぐための監督の必要性を強調している。記事では、現在の自己統治的な取り組みは不十分だとして、産業界・政府・学術界にまたがる信頼できるテストのエコシステム構築を求めている。優先事項として、国家安全保障上のリスクへの対処、AI能力に関する透明性の確保、安全性とイノベーションの両立に向けた標準策定が挙げられる。筆者らは、第三者テストがAI安全性の検証に不可欠であり、AI監督へのより広範な社会参加を可能にし、過度に厳しすぎる、または実効性に欠ける規制の落とし穴を避ける助けになると述べる。また、AI能力の進展に伴いテスト体制も進化させる必要があるとして、反復的な開発の重要性も強調している。\n\n提案では、第三者テストが分野別規制を補完する枠組みを提示し、医療や航空宇宙などの業界における製品安全基準と比較している。課題としては、有効な指標の設計、すべてのAI開発者が公平に利用できる体制の確保、規制の虜（レギュラトリー・キャプチャ）の回避が挙げられる。筆者らは、公開モデルをめぐる議論や、実用的かつ適応可能な最小限の実行可能な政策の必要性にも言及している。最終的に、第三者テストが法的要件となり、より安全で透明性の高いAI環境を促進する未来を描いている。",
  "トピック": [
    "AI安全性",
    "第三者テスト",
    "規制の枠組み",
    "国家安全保障",
    "AI政策"
  ]
}
```

テストに使用した qwen3:4b は小型のモデルですが、予想よりもうまく要約がこなせていることに驚きました。

## 構造化出力と Pydantic の活用

Ollama ではツールコールが利用できるのは一部のモデルだけですが、構造化出力はどのモデルでも使用できます。そのため、わざわざツールコールで代用する必要はなく、構造化出力を利用すれば済みます。

構造化出力では出力形式の定義に `Pydantic` が利用できます。ツールコールでは関数を定義しましたが、構造化出力ではクラスを定義します。

```py
class ArticleSummary(BaseModel):
    """Summary of an article with metadata and analysis."""
    author: str
    topics: List[str]
    summary: str
    coherence: int
    persuasion: float
    counterpoint: str
```

Ollama ではフィールドの説明を `description` に書いても参照されないため、システムプロンプトでフィールドの意味を与えます。

https://zenn.dev/7shi/articles/20250704-structured-output

```py
SYSTEM = """
Analyze this article and provide a summary with the following information:
- author: Name of the article author
- topics: Array of topics, e.g. ["tech", "politics"]. Should be as specific as possible, and can overlap.
- summary: Summary of the article. One or two paragraphs max.
- coherence: Coherence of the article's key points, 0-100 (inclusive)
- persuasion: Article's persuasion score, 0.0-1.0 (inclusive)
- counterpoint: Alternative perspective or counterargument to the article's main points
"""
```

それ以外のコードを示します。

```py
import json
import requests
from typing import List
from bs4 import BeautifulSoup
from pydantic import BaseModel
from ollama import chat

MODEL_NAME = "qwen3:4b"

url = "https://www.anthropic.com/news/third-party-testing"
response = requests.get(url, timeout=30)
soup = BeautifulSoup(response.text, "html.parser")
article = " ".join([p.text for p in soup.find_all("p")])

query = f"""
<article>
{article}
</article>
"""

response = chat(
    model=MODEL_NAME,
    options={"num_predict": 4096},
    format=ArticleSummary.model_json_schema(),
    messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": query}]
)

summary = ArticleSummary.model_validate_json(response.message.content)
print("JSON Summary:")
print(json.dumps(summary.model_dump(), indent=2, ensure_ascii=False))
```

`chat` 関数の `format` 引数にスキーマを渡せば、モデルはそれに従った JSON を生成します。定義した Pydantic モデルに、LLM の出力がそのまま流し込まれるイメージです。

実行結果はツールコールと基本的に同じため省略します。

## ストリーミング

以前、Ollama の構造化出力利用時に thinking を有効化できませんでしたが、記事執筆時点 (2026 年 1 月) では利用可能になっています。

thinking を含めてストリーミング出力する例を示します。思考内容をグレーで表示するため colorama ライブラリを使用します。

```py
from colorama import Fore, Style, init

init(autoreset=False)

def receive(response):
    content = ""
    is_thinking = False
    for chunk in response:
        if chunk.message.thinking:
            if not is_thinking:
                is_thinking = True
                print(Fore.LIGHTBLACK_EX, end="", flush=True)
            print(chunk.message.thinking, end="", flush=True)
        else:
            if is_thinking:
                is_thinking = False
                print(Style.RESET_ALL)
            content += chunk.message.content
            print(chunk.message.content, end="", flush=True)
    if is_thinking:
        print(Style.RESET_ALL)
    elif not content.endswith("\n"):
        print()
    return content

response = chat(
    model=MODEL_NAME,
    options={"num_predict": 4096},
    format=ArticleSummary.model_json_schema(),
    messages=[{"role": "system", "content": SYSTEM}, {"role": "user", "content": query}],
    stream=True,
)
receive(response)
```

## まとめ

本記事は実用に即したテクニックとは言い難いですが、「なぜ同じ結果が得られるのか」という原理を押さえることが重要です。

1.  **ツールコールによる代用**: 構造化出力が利用できない場合、ダミーの関数呼び出しを利用していた。
2.  **docstring による記述**: Ollama では、docstring を使うことでツールが定義できる。
3.  **構造化出力**: Ollama では、`format` パラメータに JSON スキーマを渡すことで、指定した構造を持った JSON が生成できる。
