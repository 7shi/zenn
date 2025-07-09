---
title: "MCP サーバーでの outputSchema の注意点"
emoji: "🤖"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["mcp", "claudecode", "geminicli"]
published: true
---

MCP ではツールが `outputSchema` を定義している場合、レスポンスは `structuredContent` フィールドを使用して返す必要があります。しかし現状のクライアントではその値を見ないようなので、注意が必要です。

:::message
本記事は Claude Code の生成結果をベースに編集しました。
:::

## サンプル

Gemini CLI でテスト用の MCP サーバーを作成しました。元ファイルは TypeScript で書かれたコードですが、今回の記事に関係ある部分だけに簡略化して、ビルドの手間を省くためトランスパイル済のコードを示します。

適当な作業ディレクトリを作成して、以下の 2 つのファイルを作成します。

:::message
以下のコードには問題があります。その問題は本記事の核心部分のため、後で説明します。
:::

```javascript:index.js
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema, } from '@modelcontextprotocol/sdk/types.js';

const testServerToolDefinition = {
    name: 'test_call',
    description: 'Returns a test string.',
    inputSchema: {
        type: 'object',
        properties: {},
        required: []
    },
    outputSchema: {
        type: 'object',
        properties: {
            content: {
                type: 'array',
                items: {
                    type: 'object',
                    properties: {
                        type: { type: 'string' },
                        text: { type: 'string' }
                    },
                    required: ['type', 'text']
                }
            }
        },
        required: ['content']
    }
};
async function main() {
    const serverTransport = new StdioServerTransport();
    const serverInfo = { name: 'test_server', version: '0.1.0' };
    const server = new Server(serverInfo, { capabilities: { tools: {} } });
    server.setRequestHandler(ListToolsRequestSchema, async (request, extra) => {
        return { tools: [testServerToolDefinition] };
    });
    server.setRequestHandler(CallToolRequestSchema, async (request, extra) => {
        if (request.params.name == testServerToolDefinition.name) {
            return {
                content: [
                    {
                        type: 'text',
                        text: 'abc'
                    }
                ]
            };
        }
        else {
            throw new Error(`Tool "${request.params.name}" not found.`);
        }
    });
    try {
        await server.connect(serverTransport);
        await new Promise(() => {});
    }
    catch (error) {
        console.error('An error occurred:', error);
    }
    finally {
        await server.close();
    }
}
main().catch(console.error);
```
```json:package.json
{
  "type": "module",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.15.0"
  }
}
```

`npm install` を実行すれば、依存関係として [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk) がインストールされます。

### 動作確認

stdio サーバーのため、`node` で実行して JSON を入力すれば動作確認できます。（感覚的には httpd に telnet で接続するのに似ています）

```json:入力（ツール一覧）
{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}
```
```json:出力
{"result":{"tools":[{"name":"test_call","description":"Returns a test string.","inputSchema":{"type":"object","properties":{},"required":[]},"outputSchema":{"type":"object","properties":{"content":{"type":"array","items":{"type":"object","properties":{"type":{"type":"string"},"text":{"type":"string"}},"required":["type","text"]}}},"required":["content"]}}]},"jsonrpc":"2.0","id":1}
```
```json:入力（ツール実行）
{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "test_call"}}
```
```json:出力
{"result":{"content":[{"type":"text","text":"abc"}]},"jsonrpc":"2.0","id":2}
```

:::message
[Ctrl]+[D] または [Ctrl]+[C] で終了します。
:::

最初に `tools/list` でツールの一覧を取得し、次に `tools/call` で `test_call` ツールを実行して `abc` という結果を得ています。

### Claude Code での動作確認

カレントディレクトリに設定ファイル (`.mcp.json`) を置けば、そのディレクトリで起動した Claude Code で MCP サーバーが実行できます。

```json:.mcp.json
{
  "mcpServers": {
    "test_server": {
      "type": "stdio",
      "command": "node",
      "args": [
        "/home/7shi/llm/mcp-caesar/test/index.js"
      ],
      "env": {}
    }
  }
}
```
```text:Claude Code
> use test_call

● I'll call the test_call function for you.
  ⎿  abc

● The test_call function returned "abc".
```

一見問題ないように見えます。

### Gemini CLI での動作確認

`.mcp.json` と同じ内容を `.gemini/settings.json` に保存すれば、そのディレクトリで起動した Gemini CLI でも MCP サーバーが実行できます。

しかし `use test_call` と指示して実行すると、エラーが発生します。

```text:Gemini CLI
MCP error -32600: Tool test_call has an output schema but did not return structured content
```

## エラーの原因

MCP の仕様では、`outputSchema` は `result` ではなく、`structuredContent` の内容を定義します。Claude Code ではスキーマとは無関係に `content` の内容を見ますが、Gemini CLI では MCP の仕様に従って `structuredContent` がスキーマ通りの構造を持つかチェックした結果、エラーが発生します。

### `structuredContent` を返す

スキーマ通りに `structuredContent` を返せば以下のようになります。

```javascript:修正（正常動作しない）
            return {
                structuredContent: {
                    content: [
                        {
                            type: 'text',
                            text: 'abc'
                        }
                    ]
                }
            };
```

しかしこの修正を適用して実行しても、Claude Code では結果が得られません。

```text:Claude Code
> use test_call

● The test call completed successfully with no output.
```

Gemini CLI ではエラーは発生しなくなりますが、やはり結果が得られません。

```text:Gemini CLI
✦ I have used that tool and it produced no output.
```

これは、MCP の仕様通りでエラーはなく、ツールの実行自体は成功しているものの、`structuredContent` の中身を認識・表示できないことを示しています。

`content` と `structuredContent` の両方が定義されていれば、`content` が結果として認識されます。

```javascript:両方を定義
            return {
                content: [
                    {
                        type: 'text',
                        text: 'abc'
                    }
                ],
                structuredContent: {
                    content: [
                        {
                            type: 'text',
                            text: 'abc'
                        }
                    ]
                }
            };
```

MCP は汎用的な RPC プロトコルであるため、構造化された結果を直接使うようなクライアントを作ることは可能ですが、LLM では文字列を使うため `content` しか見ないということだと考えられます。

### `outputSchema` を削除

単純に `outputSchema` を削除してしまうのが簡単です。

```javascript:outputSchema を削除
const testServerToolDefinition = {
    name: 'test_call',
    description: 'Returns a test string.',
    inputSchema: {
        type: 'object',
        properties: {},
        required: []
    }
};
```
```javascript:戻り値はcontentだけ
            return {
                content: [
                    {
                        type: 'text',
                        text: 'abc'
                    }
                ]
            };
```

これは Claude Code でも Gemini CLI でも正常に動作します。

## まとめ

1. **outputSchema の有無**: ツール定義に `outputSchema` がある場合、レスポンスは `structuredContent` を使用する必要があります
2. **スキーマの一致**: `structuredContent` の内容は、定義された `outputSchema` と一致している必要があります
3. **実際の動作**: `structuredContent` が返されても、`content` フィールドしか使われません

## 参考

https://modelcontextprotocol.io/introduction

https://github.com/modelcontextprotocol/modelcontextprotocol

https://github.com/modelcontextprotocol/modelcontextprotocol/pull/371
