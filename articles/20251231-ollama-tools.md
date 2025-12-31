---
title: "ollama-python のツールコール機能"
emoji: "🦙"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["ollama", "python"]
published: true
---

Ollama は、大規模言語モデル (LLM) から外部のツールや関数を呼び出すツールコール機能をサポートしています。関数がどのように変換されて Ollama に渡されるのかを追って、非対応モデルでの代用方法を検討します。

:::message
本記事は Gemini CLI の生成結果をベースに編集しました。
:::

## 基本的な利用方法

以下は [examples/tools.py](https://github.com/ollama/ollama-python/blob/main/examples/tools.py) に少し手を加えた、ツールコールの基本的な利用例です。

```py
from ollama import chat

MODEL = "qwen3:4b"
PROMPT = "りんごが3個、みかんが5個あります。果物は全部で何個ですか？"

def add_two_numbers(a: int, b: int) -> int:
  """
  Add two numbers

  Args:
    a (int): The first number
    b (int): The second number

  Returns:
    int: The sum of the two numbers
  """
  return int(a) + int(b)

print(PROMPT)
messages = [{"role": "user", "content": PROMPT}]
tools = [add_two_numbers]
tools_dict = {f.__name__: f for f in tools}

# tools引数に関数オブジェクトを直接渡す
response = chat(MODEL, messages=messages, tools=tools)

# モデルがツールの使用を判断した場合
for tool_call in response.message.tool_calls or []:
  name = tool_call.function.name
  args = tool_call.function.arguments
  print("Calling function:", name)
  print("Arguments:", args)

  # 実際に関数を実行する
  output = tools_dict[name](**args)
  print("Output:", output)
```
```text:実行結果
りんごが3個、みかんが5個あります。果物は全部で何個ですか？
Calling function: add_two_numbers
Arguments: {'a': 3, 'b': 5}
Output: 8
```

この例では、`add_two_numbers` という単純な足し算の関数を定義し、`chat` メソッドの `tools` 引数に渡しています。ユーザーからの質問に対し、モデルは `add_two_numbers` 関数を引数 `{"a": 3, "b": 5}` で呼び出すべきだと判断し、その情報を `response.message.tool_calls` に含めて返します。

### 比較

この程度の計算ならモデル自身が直接答えを出すことは可能です。

```py
from ollama import chat

MODEL = "qwen3:4b"
PROMPT = "りんごが3個、みかんが5個あります。果物は全部で何個ですか？"

print(PROMPT)
messages = [{"role": "user", "content": PROMPT}]
response = chat(MODEL, messages=messages)
print(response.message.content)
```
```text:実行結果
りんごが3個、みかんが5個あります。果物は全部で何個ですか？
りんご（3個）とみかん（5個）を合わせて計算すると、
**3 + 5 = 8** 個になります。

答え：**8個**。
```

ツールコールでは、明示的に外部に計算を委譲している点が異なります。より複雑な計算やデータ処理、外部APIの呼び出しなども同様の仕組みで実現可能です。

## `ollama-python` ライブラリにおけるツール（関数）のシリアライズ処理

`tools` 引数に渡された Python 関数は、ライブラリの内部で Ollama API が要求する JSON スキーマ形式に自動的に変換（シリアライズ）されます。

関数からJSONスキーマへの変換は、主に以下の3つのステップで行われます。

1.  **関数の構造解析**: Pythonの `inspect` モジュールを利用して、関数の名前、docstring、引数、型ヒントなどの情報を抽出します。
2.  **JSONスキーマ生成**: 抽出した情報を元に `pydantic.BaseModel` を動的に生成し、その `.model_json_schema()` メソッドを呼び出してJSONスキーマを生成します。
3.  **情報の統合**: 生成されたスキーマに、docstringから解析した説明文などを追加し、最終的な `Tool` オブジェクトを構築します。

### エントリーポイント: `ollama._client.Client.chat`

`chat` メソッドは、受け取った `tools` 引数を `_copy_tools` ヘルパー関数に渡します。

- [ollama/_client.py:328](https://github.com/ollama/ollama-python/blob/60e7b2f9ce710eeb57ef2986c46ea612ae7516af/ollama/_client.py#L328)

```py
def chat(self, ..., tools, ...):
    return self._request(
      # ...
      json=ChatRequest(
        # ...
        tools=list(_copy_tools(tools)),
        # ...
      ).model_dump(exclude_none=True),
      stream=stream,
    )
```

### 関数の振り分け: `ollama._client._copy_tools`

`_copy_tools` 関数は、`tools` リスト内の各要素をループ処理します。要素が `callable` (つまり関数) であれば、`convert_function_to_tool` を呼び出して変換処理を行います。辞書形式の場合は `Tool.model_validate` で検証します。

- [ollama/_client.py:1304](https://github.com/ollama/ollama-python/blob/60e7b2f9ce710eeb57ef2986c46ea612ae7516af/ollama/_client.py#L1304)

```py
def _copy_tools(tools: ...):
  for unprocessed_tool in tools or []:
    yield convert_function_to_tool(unprocessed_tool) if callable(unprocessed_tool) else Tool.model_validate(unprocessed_tool)
```

### シリアライズの核心: `ollama._utils.convert_function_to_tool`

`convert_function_to_tool` は、Pydantic の強力な機能を活用して、関数の引数を定義する `parameters` オブジェクト（JSON スキーマ）を生成します。

以下は説明に必要な要点だけを抜粋し、細部は `...` で省略したものです。

- [ollama/_utils.py:56](https://github.com/ollama/ollama-python/blob/60e7b2f9ce710eeb57ef2986c46ea612ae7516af/ollama/_utils.py#L56)

```py
def convert_function_to_tool(func: Callable) -> Tool:
  # docstring を解析して説明文（description）を取り出す
  parsed_docstring = _parse_docstring(inspect.getdoc(func))

  # 関数シグネチャから Pydantic モデルを動的生成し、JSON Schema を得る
  schema = type(...).model_json_schema()

  # Optional(T | None) 等は required から外し、description/type を埋める
  for name, prop in schema.get('properties', {}).items():
    ...
    schema['properties'][name] = {'description': parsed_docstring[name], 'type': ...}

  # Tool(function) 形式に詰め替える（parameters は schema をそのまま展開）
  tool = Tool(... parameters=Tool.Function.Parameters(**schema), ...)

  return Tool.model_validate(tool)
```

その過程は以下の通りです。

1.  **動的クラス生成**: `type()` を使い、関数のシグネチャ（引数と型ヒント）とdocstringを元に、その場限りの `pydantic.BaseModel` 継承クラスを動的に作成します。
    - `__annotations__`: Pydanticがモデルのフィールド（=関数の引数）と型を定義するために利用する、最も重要な属性です。
    - `__doc__`: クラスのdocstringは、生成されるJSONスキーマのトップレベルの `description` になります。

2.  **`model_json_schema()`の呼び出し**: 動的に生成したクラスオブジェクトに対して `.model_json_schema()` を呼び出します。これにより、**JSON Schema仕様に準拠した完全なスキーマ辞書が一度に生成されます。** この辞書には `type`, `properties`, `required` など、`parameters` に必要な情報がすべて含まれています。

3.  **`parameters`への適用**: 最後に、`Tool` オブジェクトを構築する際、`Tool.Function.Parameters(**schema)` のように、ステップ2で生成されたスキーマ辞書をアンパックして `parameters` フィールドに設定します。

つまり、`model_json_schema()` は `parameters` オブジェクトそのものを直接生成するのではなく、その**元となる完全なスキーマ辞書を生成する**役割を担っています。

この実装は、Python のような動的言語が持つ強力なメタプログラミング能力の好例です。`ollama-python` の利用者は、普段通りに Python 関数を定義するだけで、ライブラリが裏側で自動的に API が必要とする形式へと変換してくれます。

### 変換の実例

今回使用した `add_two_numbers` を `convert_function_to_tool` を使って変換し、その結果をJSONで出力してみます。

```py
from ollama._utils import convert_function_to_tool

def add_two_numbers(a: int, b: int) -> int:
  """
  Add two numbers

  Args:
    a (int): The first number
    b (int): The second number

  Returns:
    int: The sum of the two numbers
  """
  return int(a) + int(b)

converted_tool = convert_function_to_tool(add_two_numbers)
print(converted_tool.model_dump_json(indent=2))
```
```json:実行結果
{
  "type": "function",
  "function": {
    "name": "add_two_numbers",
    "description": "Add two numbers",
    "parameters": {
      "type": "object",
      "defs": null,
      "items": null,
      "required": [
        "a",
        "b"
      ],
      "properties": {
        "a": {
          "type": "integer",
          "items": null,
          "description": "The first number",
          "enum": null
        },
        "b": {
          "type": "integer",
          "items": null,
          "description": "The second number",
          "enum": null
        }
      }
    }
  }
}
```

関数の名前、docstring、引数と型ヒントが正しく JSON スキーマに変換されていることがわかります。

### API リクエストの構築

`ChatRequest` オブジェクト全体が `.model_dump()` メソッドでPythonの辞書に変換されます。このとき、ネストされた `Tool` オブジェクトも再帰的に `.model_dump()` が呼ばれて辞書に変換されます。最終的に、この大きな辞書全体が `httpx` ライブラリによってJSON文字列にシリアライズされ、Ollamaサーバーへのリクエストボディとして送信されます。

`ChatRequest.model_dump()` が返すのは、以下のような Python の辞書です。`tools` フィールドの値が辞書のリスト (`list[dict]`) になっている点に注意してください。

```json
{
  "model": "qwen3:4b",
  "messages": [...],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "add_two_numbers",
        "description": "Add two numbers",
        "parameters": { ... }
      }
    }
  ],
  ...
}
```

このように、Ollama サーバーとの間では JSON がやり取りされますが、`ollama-python` ライブラリが自動的に変換することで、その詳細を意識しなくても利用できるようになっています。

:::message
`curl` コマンドなどを使って Ollama サーバーと直接やり取りするときは、複雑なリクエストはライブラリで変換してひな形を作成すると便利です。
:::

## コード生成による代用

ツールコールは、サポートするモデルでしか使えません。一方で、モデルにコード（または関数呼び出し情報）を生成させることで、代用は可能です。

セキュリティ的な面から Python コードを生成させるのではなく、関数名と引数だけを JSON で返させる方法が無難です。

```json:例
[{"name": "...", "arguments": {...}}]
```

この形は、ツールコールが返してくる `tool_calls` にかなり近く、後から本物のツールコールへ移行するのも簡単です。

```py
import re
import json
from ollama import chat

MODEL = "gemma3:4b"

def add_two_numbers(a: int, b: int) -> int:
  return int(a) + int(b)

tools_dict = {"add_two_numbers": add_two_numbers}

SYSTEM = """
次のツールが使えます:
- name: add_two_numbers, arguments: {"a": int, "b": int}

必ず次のJSONだけを出力してください（余計な文章は禁止）:
[{"name": "...", "arguments": {...}}, ...]
""".strip()

PROMPT = "りんごが3個、みかんが5個あります。果物は全部で何個ですか？"
print(PROMPT)

messages = [
  {"role": "system", "content": SYSTEM},
  {"role": "user", "content": PROMPT},
]

response = chat(MODEL, messages=messages)
content = response.message.content
if m := re.match(r"```json\n(.*?)\n```", content, re.DOTALL):
  content = m.group(1)
print("Response:", content)

for tool_call in json.loads(content):
  name = tool_call["name"]
  args = tool_call["arguments"]
  print("Calling function:", name)
  print("Arguments:", args)

  # 実際に関数を実行する
  output = tools_dict[name](**args)
  print("Output:", output)
```
```text:実行結果
りんごが3個、みかんが5個あります。果物は全部で何個ですか？
Response: [{"name": "add_two_numbers", "arguments": {"a": 3, "b": 5}}]
Calling function: add_two_numbers
Arguments: {'a': 3, 'b': 5}
Output: 8
```

このコードは、ツールコールを通常のチャットとして模倣しているため、裏側に複雑な仕組みもなく、考え方を理解するのには適しているかもしれません。

### 構造化出力による代用

上の例は JSON で返すように指示しているだけなので、モデルが余計な文章を混ぜたり、キー名を微妙に変えたりしてパースに失敗することがあります。ここで構造化出力（JSON スキーマによる出力制約）を使えば、出力の安定性が上がります。

Ollama は `format` に Pydantic による型定義を渡すことで、構造化出力が利用できます。

```py
from typing import Any
from pydantic import BaseModel, RootModel
from ollama import chat

MODEL = "gemma3:4b"

def add_two_numbers(a: int, b: int) -> int:
  return int(a) + int(b)

tools_dict = {"add_two_numbers": add_two_numbers}

class ToolCall(BaseModel):
  name: str
  arguments: dict[str, Any]

class ToolCalls(RootModel[list[ToolCall]]):
  pass

format = ToolCalls.model_json_schema()

SYSTEM = """
次のツールが使えます:
- name: add_two_numbers, arguments: {"a": int, "b": int}
""".strip()

PROMPT = "りんごが3個、みかんが5個あります。果物は全部で何個ですか？"
print(PROMPT)

messages = [
  {"role": "system", "content": SYSTEM},
  {"role": "user", "content": PROMPT},
]

# format に JSON Schema を渡して出力を制約する
response = chat(MODEL, messages=messages, format=format)
content = response.message.content.strip()
print("Response:", content)

tool_calls = ToolCalls.model_validate_json(content).root
for tool_call in tool_calls:
  name = tool_call.name
  args = tool_call.arguments
  print("Calling function:", name)
  print("Arguments:", args)

  # 実際に関数を実行する
  output = tools_dict[name](**args)
  print("Output:", output)
```
```text:実行結果
りんごが3個、みかんが5個あります。果物は全部で何個ですか？
Response: [{"name": "add_two_numbers", "arguments": {"a": 3, "b": 5}}]
Calling function: add_two_numbers
Arguments: {'a': 3, 'b': 5}
Output: 8
```

ツールコールも構造化出力も JSON を返す点では同じなので、等価な内容の JSON を返すように指示することで模倣しています。

## まとめ

`ollama-python` のツールコールは、Python 関数を `inspect` で解析し、Pydantic で JSON Schema に落としてから Ollama に渡すことで成立しています。  

ツールコールに非対応のモデルでも、「関数名＋引数」の JSON を返させることで、代用が可能です。

## 関連記事

Ollama が構造化出力をどのように実現しているかを調査しました。

https://zenn.dev/7shi/articles/fa36989a04c9ed

MCP はツールコールをより組織的に整理したものと言えますが、比較した記事です。（Function calling はツールコールの別名で、同じものを指す）

https://qiita.com/7shi/items/e27866ce51c6b9a0f605

## 参考

構造化出力でツールコールを模倣しましたが、その逆パターン（ツールコールで構造化出力を模倣）もあります。

- https://github.com/anthropics/claude-cookbooks/blob/main/tool_use/extracting_structured_json.ipynb

MCP はコンテキスト消費量の肥大化が問題になることがあり、コード生成の方が効率的なケースもあるようです。

https://x.com/iwashi86/status/1992450542870659395
