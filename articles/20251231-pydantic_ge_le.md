---
title: "Pydantic V2 における Field 制約"
emoji: "🐍"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["python", "pydantic"]
published: true
---

Pydantic V2 では、`Field()` においてサポート外のキーワードを使用すると警告が出るようになりました。本記事では、整数の範囲制約を設定する方法について解説します。

## 問題の背景

Pydantic V1 では `minimum` と `maximum` をキーワード引数として指定しても、特に何も警告が出ませんでした。

```python
class Score(BaseModel):
  score: int = Field(minimum=0, maximum=20)
```

:::message
警告が出ないだけで、バリデーションは機能しません。
:::

しかし、Pydantic V2 でこのコードを実行すると、以下の警告が表示されます：

```
PydanticDeprecatedSince20: Using extra keyword arguments on `Field` is deprecated
and will be removed. Use `json_schema_extra` instead. (Extra keys: 'minimum', 'maximum').
```

警告には `json_schema_extra` を使うように書かれていますが、実際には、Pydantic V2の正式な制約パラメータを使うべきです。

## `ge`/`le` 制約パラメータ

Pydantic V2 では `ge` (greater than or equal) と `le` (less than or equal) を指定すれば、JSON スキーマでは `minimum` と `maximum` に変換されます。

https://docs.pydantic.dev/2.12/api/standard_library_types/

> |Constraint|Description|JSON Schema|
> |---|---|---|
> |`le`|The value must be less than or equal to this number|`maximum` keyword|
> |`ge`|The value must be greater than or equal to this number|`minimum` keyword|

```python
import json
from pydantic import BaseModel, Field

class Score(BaseModel):
  score: int = Field(ge=0, le=20)

print(json.dumps(Score.model_json_schema(), indent=2))
```
```json:実行結果
{
  "properties": {
    "score": {
      "maximum": 20,
      "minimum": 0,
      "title": "Score",
      "type": "integer"
    }
  },
  "required": [
    "score"
  ],
  "title": "Score",
  "type": "object"
}
```

このように、`ge=0, le=20` と指定すればと、JSONスキーマには自動的に `"minimum": 0` と `"maximum": 20` が設定されます。

- `ge=0`: `score >= 0` (0 以上)
- `le=20`: `score <= 20` (20 以下)

### バリデーション動作の検証

```python
# 正常値
valid = Score(score=15)  # OK

# 範囲外の値は拒否される
invalid_low = Score(score=-1)   # ValidationError
invalid_high = Score(score=21)  # ValidationError

# 境界値は許可される
edge_low = Score(score=0)   # OK
edge_high = Score(score=20)  # OK
```

## `json_schema_extra`（非推奨）

```python
class Score(BaseModel):
  score: int = Field(json_schema_extra={"minimum": 0, "maximum": 20})
```

JSON スキーマを出力するだけなら結果は同じですが、Pydantic が正式に認識するキーワードではないため、バリデーション機能（数値の範囲チェック）は働きません。

## まとめ

- 整数の範囲制約には`ge`と`le`を使う
- `json_schema_extra`は、標準の制約パラメータでは表現できない独自のメタデータを追加する場合にのみ使用する

## 参考

https://docs.pydantic.dev/latest/concepts/fields/

https://docs.pydantic.dev/latest/migration/
