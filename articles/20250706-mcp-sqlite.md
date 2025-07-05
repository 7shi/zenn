---
title: "SQLite MCP サーバーリスト"
emoji: "🗃️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["mcp", "sqlite"]
published: true
---

mcp.so（MCPサーバーのカタログサイト）でSQLiteを検索して出てきたMCPサーバーをまとめました。

https://mcp.so/

:::message
本記事は各READMEをGemini 2.5 Flashによって要約してまとめました。
:::

## はじめに

MCPが発表された当時はAnthropicによって開発されたSQLiteのMCPサーバーがリファレンス実装として提供されていました。しかし現在ではアーカイブに移されてメンテナンスが終了しています。

https://github.com/modelcontextprotocol/servers

そのまま使い続けると問題に対応できなくなるため、乗り換え先の調査に着手しました。公式のアプリストアのようなものはなく、いくつかあるカタログサイトのうち最も充実しているmcp.soで検索したところ、思ったより多くのMCPサーバーがあったため、情報を整理しました。

:::message
いくつか絞り込んだ上で、別途動作確認を行う予定です。
:::

## リスト

スターが多い順に並べます。（同数の場合は最終更新日時が新しい順）

### [bytebase/dbhub](https://github.com/bytebase/dbhub)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 835 | 81 | 2025-06-26 | MIT License | TypeScript |

**Supported DBMS:** PostgreSQL, MySQL, MariaDB, SQL Server, SQLite

DBHubは、Model Context Protocol (MCP) サーバーインターフェースを実装した汎用データベースゲートウェイです。MCP互換クライアント（Claude Desktop、Cursorなど）が様々なデータベースに接続し、探索することを可能にします。主要機能として、スキーマ、テーブル、インデックス、プロシージャの探索、SQL実行、SQL生成、データベース要素の説明が挙げられます。PostgreSQL、MySQL、MariaDB、SQL Server、SQLiteなど複数のDBMSをサポートし、DockerやNPMで簡単に導入可能です。HTTPおよびstdioトランスポートに対応し、リードオンリーモードやSSL接続設定も可能です。

### [runekaagaard/mcp-alchemy](https://github.com/runekaagaard/mcp-alchemy)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 257 | 45 | 2025-06-19 | Mozilla Public License 2.0 | Python |

**Supported DBMS:** PostgreSQL, MySQL, MariaDB, SQLite, Oracle, Microsoft SQL Server, CrateDB, Vertica

MCP Alchemyは、Claude Desktopを様々なデータベースに直接接続するMCPサーバーです。主要機能として、データベース構造の探索と理解、SQLクエリの作成と検証支援、テーブル間のリレーションシップ表示、大規模データセットの分析とレポート作成を提供します。SQLAlchemy互換の多種多様なDBMSをサポートし、claude-local-files連携により大規模な結果セットも扱えます。これにより、Claudeをデータベースの専門家として活用し、データ操作や分析を効率化できます。Pythonで実装されており、シンプルな設定で利用可能です。

### [donghao1393/mcp-dbutils](https://github.com/donghao1393/mcp-dbutils)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 76 | 7 | 2025-05-12 | MIT License | Python |

**Supported DBMS:** SQLite, MySQL, PostgreSQL

MCP Database Utilitiesは、AIシステムが安全に多様なデータベース（SQLite、MySQL、PostgreSQLなど）にアクセスし、データ分析を実行できるようにする多機能なMCPサービスです。AIとデータベース間の安全な橋渡し役として機能し、AIが直接データベースにアクセスしたり、データを変更するリスクなしにデータを読み取り、分析することを可能にします。主要機能として、厳格な読み取り専用操作、直接アクセスなし、接続の分離、オンデマンド接続、自動タイムアウトによる「安全第一」の設計があります。また、ローカル処理や資格情報保護による「プライバシー保護」も特徴です。単一のYAMLファイルで簡単に設定でき、テーブル参照、スキーマ分析、クエリ実行などの高度な機能も提供します。

### [hannesrudolph/sqlite-explorer-fastmcp-mcp-server](https://github.com/hannesrudolph/sqlite-explorer-fastmcp-mcp-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 73 | 19 | 2025-05-07 | N/A | Python |

**Supported DBMS:** SQLite

このSQLite Explorer MCPサーバーは、Model Context Protocol (MCP) を介してLLM（大規模言語モデル）がSQLiteデータベースに安全かつ読み取り専用でアクセスできるように設計されています。FastMCPフレームワーク上に構築されており、組み込みの安全性機能とクエリ検証により、LLMがデータベースを探索し、クエリを実行することを可能にします。主要機能としては、安全なSELECTクエリ実行のためのread_queryツール（クエリ検証、サニタイズ、パラメーターバインディング、行数制限を含む）、テーブル一覧表示のlist_tables、詳細なスキーマ情報提供のdescribe_tableがあります。用途としては、Claude DesktopやCline VSCodeプラグインとの統合が挙げられます。技術的にはPython 3.6以上とSQLiteデータベースファイルが必要で、SQLITE_DB_PATH環境変数でパスを指定します。安全性に重点を置き、読み取り専用アクセス、クエリの検証とサニタイズ、パラメーターバインディングによる安全な実行、行数制限が特徴です。

### [jparkerweb/mcp-sqlite](https://github.com/jparkerweb/mcp-sqlite)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 20 | 2 | 2025-06-02 | MIT License | JavaScript |

**Supported DBMS:** SQLite

MCP SQLite Serverは、Model Context Protocol (MCP) を介してSQLiteデータベースとの包括的なインタラクションを提供するサーバーです。主な機能として、完全なCRUD操作、データベースの探索と内省、カスタムSQLクエリの実行が挙げられます。IDE（例：Cursor, VSCode）のMCPサーバー設定にコマンドを定義することで、手軽にSQLiteデータベースを操作できます。内部ではModel Context Protocol SDKとsqlite3ライブラリを利用しており、データベース情報の取得、テーブルリストの表示、スキーマ取得、レコードの作成・読み取り・更新・削除、および任意のSQL実行のための豊富なツールを提供します。これにより、開発者は効率的にSQLiteデータベースを管理・利用できます。

### [cuongtl1992/mcp-dbs](https://github.com/cuongtl1992/mcp-dbs)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 17 | 2 | 2025-04-28 | MIT License | TypeScript |

**Supported DBMS:** SQLite, PostgreSQL, Microsoft SQL Server, MongoDB

「MCP Database Server」は、MCP（Model Context Protocol）を実装し、SQLite、PostgreSQL、Microsoft SQL Server、MongoDBなど多様なデータベースシステムへの接続と操作を可能にするサーバーです。主要機能として、データベースの接続・切断、結果を返すクエリ実行、結果を返さない更新クエリ実行、そしてデータベースやテーブルのスキーマ情報取得を提供します。特にClaude Desktopとの連携が強調されており、AIを通じてデータベースにアクセスし、クエリ実行やスキーマ探索が行えます。技術的には、SSEモードとSTDIOモードでの運用が可能で、接続設定は環境変数またはコマンドライン引数で行います。SQL系DBに加え、MongoDBの多様なクエリ（シェル構文、アグリゲーション、生コマンド）に対応している点が特徴です。

### [jacksteamdev/mcp-sqlite-bun-server](https://github.com/jacksteamdev/mcp-sqlite-bun-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 16 | 6 | 2025-03-25 | MIT License | TypeScript |

**Supported DBMS:** SQLite

このMCPサーバーは、SQLiteデータベースを利用して、データベース操作とビジネスインテリジェンス機能を提供します。SQLクエリ（SELECT, INSERT, UPDATE, DELETE, CREATE TABLE）の実行、テーブルリストの取得、スキーマ参照が可能です。主要機能として、自動でビジネスインサイトメモを生成し、分析中に発見されたインサイトを蓄積します。Bunで動作し、Claude Desktopと連携して、特定のビジネスドメインに関するデータ分析をガイドし、インサイト生成をサポートします。データはdata.sqliteファイルに保存され、詳細なログはserver.logに出力されます。これにより、ユーザーはデータからビジネス価値を効率的に引き出すことができます。

### [rbatis/rbdc-mcp](https://github.com/rbatis/rbdc-mcp)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 13 | 2 | 2025-06-26 | N/A | Rust |

**Supported DBMS:** SQLite, MySQL, PostgreSQL, MSSQL

RBDC MCP Serverは、Model Context Protocol (MCP) に基づくデータベースサーバーです。SQLite, MySQL, PostgreSQL, MSSQLといった複数の主要なDBMSを統一されたインターフェースでサポートし、AI（特にClaude AI）との連携をネイティブで行います。主な機能として、SQLを書かずに自然言語でデータベースのクエリや変更が可能であり、データベース接続やリソースの自動管理、AIを介した安全なアクセス制御を提供します。これにより、ユーザーは複雑なSQL知識なしに、自然な会話形式でデータベース操作を実行できます。設定ファイルを通じて簡単にデータベースURLを指定でき、Windows, macOS, Linux向けのバイナリ提供やRust/Cargoによるビルドもサポートしています。

### [bsmi021/mcp-task-manager-server](https://github.com/bsmi021/mcp-task-manager-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 12 | 2 | 2025-06-11 | GNU General Public License v3.0 | TypeScript |

**Supported DBMS:** SQLite

MCPタスクマネージャーサーバーは、AIエージェントやスクリプトなどのローカルMCPクライアント向けに、プロジェクトとタスクの管理を支援する永続的なバックエンドを提供します。主要機能には、プロジェクトベースのタスク整理、SQLiteによるデータ永続化、クライアント主導のワークフロー支援、Model Context Protocolへの準拠があります。タスクの作成、追加、リスト表示、ステータス更新、サブタスクへの展開、次に行うべきタスクの特定に加え、プロジェクトデータのJSON形式でのインポート/エクスポートが可能です。設定によりSQLiteデータベースのパスをカスタマイズでき、シンプルで自己完結型のデータストレージを実現します。

### [johnnyoshika/mcp-server-sqlite-npx](https://github.com/johnnyoshika/mcp-server-sqlite-npx)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 10 | 9 | 2025-06-30 | MIT License | JavaScript |

**Supported DBMS:** SQLite

このプロジェクトは、Model Context Protocol (MCP) のSQLiteサーバーをNode.jsで実装したものです。公式Pythonリファレンスを基に開発されており、PythonのUVXランナーが利用できない環境（例：LibreChat）向けにnpxベースの代替手段を提供します。主要な機能としては、MCPを介したSQLiteデータベースへのアクセスを可能にし、Claude DesktopやMCP Inspectorのようなツールとの連携が可能です。技術的にはNode.jsとTypeScriptで構築されており、npxコマンドによる簡単なインストールと実行が特徴です。SQLiteデータベースファイル（.db）をデータストアとして利用します。

### [YUZongmin/sqlite-literature-management-fastmcp-mcp-server](https://github.com/YUZongmin/sqlite-literature-management-fastmcp-mcp-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 10 | 3 | 2025-04-16 | MIT License | Python |

**Supported DBMS:** SQLite

「Universal Source Management System」は、論文、書籍、ウェブページなど多様な情報源を統合的に管理し、ナレッジグラフと連携させるための柔軟なシステムです。UUIDによるユニバーサルな識別、複数の情報源タイプと識別子（arXiv、DOI、URLなど）のサポート、構造化されたノート作成、ステータス追跡といった主要機能を持ちます。また、情報源をナレッジグラフのエンティティと関連付け、その関係性（議論、導入、拡張など）を追跡できます。技術的には内部UUIDシステムを採用し、永続的なナレッジグラフストレージのためにMCP Memory Serverと統合されます。SQLiteデータベースを使用してデータが管理されます。

### [panasenco/mcp-sqlite](https://github.com/panasenco/mcp-sqlite)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 8 | 1 | 2025-07-02 | Apache License 2.0 | Python |

**Supported DBMS:** SQLite

mcp-sqliteは、AIエージェントが外部システムにアクセスすることなくSQLiteデータベース内のデータを利用できるようにするMCPサーバーです。主要機能として、データベースのテーブル構造やカラム情報を取得するsqlite_get_catalog、メタデータファイルで定義された定型クエリを実行するツール、および任意のSQLクエリを実行するsqlite_executeを提供します。これらのツールはAIエージェントが安全にデータにアクセスし、複雑なクエリを簡単に実行できるようにします。また、Datasetteとの高い互換性を持つメタデータを使用するため、人間がデータ探索を行う際にも同じ設定を利用でき、AIと人間の両方にとって効率的なデータ活用を実現します。

### [javsanmar5/mcp-server.sqlite](https://github.com/javsanmar5/mcp-server.sqlite)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 7 | 1 | 2025-04-23 | MIT License | TypeScript |

**Supported DBMS:** SQLite

このMCPサーバーは、TypeScriptで実装されており、SQLiteデータベースとの連携を目的としています。主要機能として、SQLクエリの実行（SELECTなど）、データベーススキーマの管理、ビジネスインサイトの生成が挙げられます。AIモデルが外部ツールやサービスと対話するための標準化されたプロトコルであるMCPを通じて、AIアシスタントにデータベースクエリの実行といった機能を提供します。これにより、AIモデル自体に直接統合することなく、構造化されたデータソースへのアクセスを可能にします。Dockerイメージとして提供され、Claude DesktopのようなAIクライアントと簡単に連携できます。

### [prayanks/mcp-sqlite-server](https://github.com/prayanks/mcp-sqlite-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 7 | 0 | 2025-04-15 | MIT License | Python |

**Supported DBMS:** SQLite

このPython製MCP（Model Context Protocol）サーバーは、SQLiteデータベースに接続し、スタートアップ資金データへのアクセスを提供します。主要機能として、データベースのテーブルスキーマをMCPリソースとして公開し、読み取り専用のSQLクエリ（SELECT文のみ）実行ツールを提供します。また、言語モデル（LLM）がデータ分析を行うためのプロンプトテンプレートも備えています。STDIOプロトコルを介して通信し、MCPクライアントやClaude DesktopのようなLLMとの統合を容易にします。ログ機能も搭載しており、データ分析タスクを効率化します。

### [brysontang/DeltaTask](https://github.com/brysontang/DeltaTask)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 7 | 7 | 2025-02-27 | MIT License | Python |

**Supported DBMS:** SQLite

DeltaTaskは、強力なローカルホスト型タスク管理システムです。緊急度や工数に基づいたスマートな優先順位付け、サブタスクへの分解、カスタムタグ付けなどの主要機能を提供します。用途としては、個人やチームのタスクを効率的に管理し、Obsidianとの双方向同期によりMarkdownベースでの編集・閲覧も可能です。また、Model Context Protocol (MCP) サーバーを通じて、タスクの作成、更新、検索、同期など多様なAPIアクセスを提供し、Claude for Desktopのような外部ツールとの連携を可能にします。技術的にはSQLiteをデータベースとして使用し、Python 3.10+で動作します。

### [mbcrawfo/KnowledgeBaseServer](https://github.com/mbcrawfo/KnowledgeBaseServer)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 4 | 1 | 2025-05-23 | MIT License | C# |

**Supported DBMS:** SQLite

MCP知識ベースサーバーは、LLMが会話中に記憶を保存し、後で検索できる機能を提供するサーバーです。記憶はSQLiteデータベースに格納され、SQLiteの強力な全文検索機能を利用して効率的な検索を実現します。このサーバーはModel Context Protocol (MCP)に準拠しており、LLMのコンテキスト管理や会話の継続性維持に貢献します。Dockerコンテナとしてデプロイできる他、.NET 9 SDKを使用してローカル環境でも実行可能です。データベースの保存場所は環境変数で柔軟に指定でき、永続化ストレージにも対応しています。

### [xavieryang007/database-mcp](https://github.com/xavieryang007/database-mcp)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 4 | 0 | 2025-04-30 | N/A | Go |

**Supported DBMS:** MySQL, PostgreSQL, SQLite, SQL Server, ClickHouse

本サービスは、GORMを活用しMySQL, PostgreSQL, SQLite, SQL Server, ClickHouseなど複数のデータベースタイプをサポートするMCP（Metoro Control Protocol）対応のデータベースサービスです。YAMLファイル、コマンドライン引数、環境変数による柔軟な設定が可能で、MCPプロトコルを介してデータベース操作を提供します。主な機能として、データベースのテーブル一覧取得、テーブル詳細情報の取得、任意のSQLクエリ実行をMCPツールとして提供し、データベース管理やデータ操作をリモートから効率的に行えるように設計されています。これにより、様々なデータベースを統一されたインターフェースで利用できます。

### [jonnyhoff/mcp-sqlite-manager](https://github.com/jonnyhoff/mcp-sqlite-manager)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 3 | 0 | 2025-04-14 | N/A | Python |

**Supported DBMS:** SQLite

mcp-sqlite-managerはFastMCPフレームワークで構築されたMCPサーバーです。主にSQLiteデータベースとの対話に特化しており、構造化されたツールを通じてデータベースのクエリ、更新、調査を容易に行えます。主要機能には、`read_query`によるSELECT文の実行（結果はJSON形式）、`write_query`によるINSERT/UPDATE/DELETE文の実行、`create_table`によるテーブル作成、`list_tables`によるテーブル一覧取得、`describe_table`によるテーブルスキーマ情報の表示が含まれます。pipxでのインストールが推奨されており、CursorなどのMCPクライアントと連携して、プログラム的にまたはAIツールからSQLiteデータを管理する用途に適しています。

### [waifuai/mcp-waifu-chat](https://github.com/waifuai/mcp-waifu-chat)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 2 | 0 | 2025-06-17 | MIT No Attribution | Python |

**Supported DBMS:** SQLite, PostgreSQL, MySQL

このMCP Waifuチャットサーバーは、会話型AI「Waifu」キャラクター向けの基本サーバーを実装しています。主な機能として、ユーザーの作成・管理、会話履歴の保存・リセット、Google Gemini APIを利用した基本的なチャット機能を提供します。PythonのmcpライブラリとFastMCPを使用しており、データ永続化にはデフォルトでSQLiteが用いられますが、本番環境ではPostgreSQLやMySQLの使用が推奨されています。環境変数とAPIキーファイルによる柔軟な設定が可能で、モジュール化された設計が特徴です。

### [Neurumaru/sqlite-kg-vec-mcp](https://github.com/Neurumaru/sqlite-kg-vec-mcp)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 2 | 1 | 2025-04-10 | MIT License | N/A |

**Supported DBMS:** SQLite

このMCPサーバーは、ナレッジグラフとベクトルデータベースをSQLite上に統合したシステムです。主な機能は、構造化された知識とベクトル埋め込みによるセマンティックな情報を一元的に管理・利用できる点にあります。SQLiteを基盤としているため、軽量かつ組み込みやすい特性を持ち、様々なアプリケーションにおける知識処理や検索機能の強化に貢献することが期待されます。ナレッジグラフによりエンティティ間の関係性を表現し、ベクトルデータベースにより高次元データに基づく類似検索や意味的関連付けを可能にします。

### [pmmvr/obsidian-index-service](https://github.com/pmmvr/obsidian-index-service)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 2 | 1 | 2025-03-23 | MIT License | Python |

**Supported DBMS:** SQLite

Obsidian Index Serviceは、Obsidianのノートファイルを監視し、Markdownのメタデータと全文をSQLiteデータベースに自動でインデックス化するサービスです。ファイルの作成、変更、削除を検知し、パス、タイトル、タグ、作成日、更新日、コンテンツなどの情報を抽出・保存します。これにより、他のアプリケーションが直接Markdownファイルを解析することなく、ノートデータにアクセスできるようになります。特に、ObsidianプラグインAPIへの移行前にはmcp-serverプロジェクトでの利用が想定されていました。Pythonで開発されており、Dockerでのデプロイもサポートし、SQLiteのWALモードを利用して同時アクセスを効率的に処理します。

### [myownipgit/RapidAPI-MCP](https://github.com/myownipgit/RapidAPI-MCP)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 2 | 2 | 2024-12-15 | N/A | Python |

**Supported DBMS:** SQLite

RapidAPI MCP Serverは、RapidAPI Global Patent APIと連携し、特許データをSQLiteデータベースに保存するMCPサーバーの実装です。主要機能として、API連携、特許データストレージ、高度な特許スコアリングシステム（pscore, cscore, lscore, tscore）、レートリミット、エラーハンドリングを備えています。特許検索リクエストの処理や特許データの蓄積に利用され、Python 3.11以上で動作し、condaまたはpipで依存関係をインストールできます。設定は環境変数で行い、拡張可能なモジュール構造が特徴です。

### [Svtter/chatdb](https://github.com/Svtter/chatdb)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 1 | 0 | 2025-04-29 | Other | Python |

ChatDBは、Cursorとの会話履歴を記録するためのMCPサーバーです。これは、GPTのような大規模言語モデルに対して、より簡便な記憶層を提供することを目的としています。主要な機能は、ユーザーとCursorの対話を自動的にキャプチャし、永続化することです。これにより、GPTは過去の会話履歴を参照しやすくなり、長期間にわたる対話でも一貫性のある応答を生成できるようになります。技術的には、Pythonプロジェクトの管理に`uv`ツールが使用されており、データベースのパスは環境変数`DB_PATH`で設定可能です。このシステムは、大規模な会話データを効率的に管理し、GPTの応答精度と連続性を向上させるための基盤を提供します。

### [isaacgounton/sqlite-mcp-server](https://github.com/isaacgounton/sqlite-mcp-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 2 | 2025-06-25 | N/A | JavaScript |

**Supported DBMS:** SQLite

SQLite MCPサーバーは、Model Context Protocol (MCP) を介してSQLiteデータベース操作を提供するサーバーです。インメモリデータベースとして動作し、ファイルベースストレージも設定可能です。主要機能には、SELECT, INSERT, UPDATE, DELETEなどのSQL操作、テーブルの作成・一覧表示・スキーマ記述といったテーブル管理、およびビジネスインサイトのメモ追跡が含まれます。DockerやNixpacksによる容易なデプロイをサポートし、SSE接続を介してn8nのようなツールとの連携が可能です。標準化されたインターフェースを通じて、SQLiteデータベースへのプログラム的なアクセスや自動化を可能にします。

### [iAchilles/memento](https://github.com/iAchilles/memento)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-06-12 | N/A | JavaScript |

**Supported DBMS:** SQLite

Mementoは、SQLiteを基盤とした知識グラフを利用して永続的な記憶機能を提供するMCPサーバーです。主要機能として、FTS5による高速なキーワード検索、sqlite-vecを活用した1024次元のセマンティックベクトル検索、およびオフラインで動作するbge-m3埋め込みモデルを備えています。これにより、エンティティ、観測、関係の構造化されたグラフを構築し、会話におけるインテリジェントなコンテキスト取得を可能にします。主にClaude DesktopなどのLLMと連携し、ユーザーの技術的・創造的プロジェクトの記憶（プロジェクト構造、意思決定、コーディング習慣、ワークフローなど）を効果的に管理・利用することを目的としています。SQLite 3.38以上が必須です。

### [abhinavnatarajan/sqlite-reader-mcp](https://github.com/abhinavnatarajan/sqlite-reader-mcp)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-06-04 | MIT License | Python |

**Supported DBMS:** SQLite

sqlite-reader-mcpは、SQLiteデータベースへの読み取り専用アクセスを提供する軽量なMCPサーバーです。主要機能として、SELECTクエリの実行、テーブル一覧の取得、テーブルスキーマの記述が可能です。データ整合性を保証するため、読み取り操作のみを許可し、パスホワイトリストとSQLクエリの厳格なバリデーションによりセキュリティを確保しています。非同期処理に`aiosqlite`を使用し、取得行数制限機能も備えています。用途としては、安全な方法でSQLiteデータベースの情報を参照したい場合に適しています。

### [jaiganesh-23/databases_mcp_server](https://github.com/jaiganesh-23/databases_mcp_server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-05-22 | N/A | JavaScript |

**Supported DBMS:** SQLite, MySQL, PostgreSQL, SQL Server

このMCPサーバーは、自然言語を用いてデータベースへの自動クエリ実行を可能にします。現在、SQLite、MySQL、PostgreSQL、SQL Serverなどの主要なデータベース管理システムに対応しており、ユーザーはコードを書くことなく、日常言語でデータベース操作を行うことができます。Node.jsで実装されており（`node`コマンドと`index.js`で実行）、VS Codeなどの開発環境と連携して利用されることが想定されています。これにより、データベースとのインタラクションがより直感的かつ効率的になります。

### [MCP-Mirror/johnnyoshika_mcp-server-sqlite-npx](https://github.com/MCP-Mirror/johnnyoshika_mcp-server-sqlite-npx)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 1 | 2025-05-14 | N/A | JavaScript |

**Supported DBMS:** SQLite

MCP SQLite Serverは、Model Context ProtocolのSQLiteサーバーをNode.jsで再実装したものです。PythonのUVXランナーが利用できない環境、特にLibreChatのようなプラットフォームやClaude Desktopでの使用を想定しており、npxを介して簡単に導入・実行できる代替ソリューションを提供します。主要機能はSQLiteデータベースへのアクセスをMCP経由で提供することです。技術的にはNode.jsで書かれており、TypeScriptでビルドされます。これにより、Python環境に依存せず、JavaScript/Node.jsエコシステム内でMCPサーバーを運用できる点が大きな特徴です。

### [MCP-Mirror/jacksteamdev_mcp-sqlite-bun-server](https://github.com/MCP-Mirror/jacksteamdev_mcp-sqlite-bun-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 1 | 2025-05-14 | N/A | TypeScript |

**Supported DBMS:** SQLite

このMCPサーバーは、SQLiteデータベースを基盤とし、データベース操作とビジネスインテリジェンス機能を提供します。SQLクエリ（SELECT, INSERT, UPDATE, DELETE, CREATE TABLE）の実行、テーブルスキーマの取得が可能です。主な用途は、ビジネスデータの分析と、分析で発見されたインサイトを自動でメモに生成することです。特に"memo://insights"リソースを通じて継続的に更新されるビジネスインサイトメモが提供され、"append-insight"ツールで洞察を追加できます。"mcp-demo"プロンプトは、データベース操作とインサイト生成のガイドを提供します。技術的には、Bunで構築されており、Claude Desktopと連携するように設計されています。データは"data.sqlite"に保存され、詳細なログも出力されます。

### [MCP-Mirror/hannesrudolph_sqlite-explorer-fastmcp-mcp-server](https://github.com/MCP-Mirror/hannesrudolph_sqlite-explorer-fastmcp-mcp-server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 1 | 2025-05-14 | N/A | Python |

**Supported DBMS:** SQLite

FastMCPフレームワーク上に構築されたMCPサーバーで、LLMがSQLiteデータベースへ安全にアクセスし、探索およびクエリ実行を可能にします。主要機能として、安全なSELECTクエリ実行を行う"read_query"、利用可能なテーブルを一覧表示する"list_tables"、テーブルの詳細なスキーマ情報を提供する"describe_table"を提供します。クエリ検証、サニタイズ、パラメータバインディング、行制限、読み取り専用アクセスといった豊富な安全機能が組み込まれており、データベースへの安全な対話を保証します。Claude DesktopやCline VSCode Pluginといった環境で利用できます。

### [under-doc/underdoc-tutorial-expense-analytics-mcp-sqlite](https://github.com/under-doc/underdoc-tutorial-expense-analytics-mcp-sqlite)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-28 | N/A | N/A |

**Supported DBMS:** SQLite

MCPサーバーは、LLMが多様なリソースやツールと標準化された方法で対話するためのプロトコルを実装します。本チュートリアルで利用されるSQLite用MCPサーバーは、特にLLMが自然言語を用いてSQLiteデータベースと対話し、データ分析を行うことを可能にします。主な機能には、データベーススキーマの公開、テーブルからのデータ取得（例：経費の合計金額の集計）、チャート形式での結果表示、通貨換算（Webからのレート取得を含む）があります。これにより、SQL知識なしで経費分析が容易に行えます。技術的には、Python 3.12とuvで動作し、Claude DesktopのようなMCP対応LLMアプリと連携します。

### [madhavarora1988/mcp_sqlite_poc](https://github.com/madhavarora1988/mcp_sqlite_poc)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 1 | 2025-04-27 | N/A | Python |

**Supported DBMS:** SQLite

本プロジェクトは、AIモデルが標準化されたツールを通じてSQLiteデータベースと対話することを可能にするMCP（Model Context Protocol）サーバーの実装です。SQLクエリの実行、スキーマの検出、行数カウント、サンプルデータの挿入、ユーザーフィードバックの収集といった主要機能を提供します。また、データベースの自動初期化機能や、安全性を高めるための読み取り専用モードも備えています。Python 3.8以上で動作し、`.env`ファイルでデータベースパスやポート、読み取り専用設定を柔軟に構成できます。AIアシスタント（例：Claude Desktop）との連携を想定しており、SQLクエリの検証などセキュリティ機能も含まれています。

### [WaelDataReply/MCP_demo_Sqlite_server](https://github.com/WaelDataReply/MCP_demo_Sqlite_server)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-25 | N/A | N/A |

**Supported DBMS:** SQLite

このリポジトリは、MCPプロジェクトの一環として提供されるデモサーバーであり、特にSQLiteデータベースとの連携に焦点を当てています。主な用途は、MCP関連のアプリケーションやシステムの開発・テスト環境において、SQLiteを使用したデータ処理やストレージ機能の動作検証を行うことです。技術的には、SQLiteをバックエンドデータベースとして利用し、サーバーサイドでのデータ操作の基礎的な例を提供します。具体的な機能や詳細なアーキテクチャについては、本READMEからは情報を得られませんが、デモンストレーション用途に特化していると考えられます。本サーバーは、簡単なデータ永続化や、サーバーとデータベース間のインタラクションの基礎を学ぶための参考として設計されている可能性があります。

### [alvnavraii/MCPDatabases](https://github.com/alvnavraii/MCPDatabases)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-24 | N/A | Python |

**Supported DBMS:** PostgreSQL, SQLite

本プロジェクトは、PostgreSQLとSQLiteデータベース間のデータ管理と移行を容易にするMCPサーバーです。主要機能として、PostgreSQLデータベースに対するCRUD操作（作成、読み取り、更新、削除）やテーブルの作成・変更・削除といった管理機能を提供します。また、PostgreSQLからSQLiteへのデータ構造とデータの自動移行スクリプトも備えており、異なるデータベースエンジン間での柔軟なデータ運用を可能にします。用途としては、PostgreSQLを主軸としたアプリケーションのデータベース管理、SQLiteへのデータ移行、高度なSQLクエリ実行が挙げられます。Pythonで実装されており、設定ファイルにより各DBMSへの接続を集中管理する技術的特徴を持ちます。

### [alvnavraii/mcpDataBases](https://github.com/alvnavraii/mcpDataBases)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-24 | N/A | Python |

**Supported DBMS:** PostgreSQL, SQLite

このプロジェクトは、PostgreSQLとSQLite間のデータ管理と移行を容易にするMCPサーバーです。主要機能として、PostgreSQLデータベースに対するCRUD操作、テーブルの作成・変更・削除といった管理機能、そしてPostgreSQLからSQLiteへの自動データ移行を提供します。これにより、異なるデータベースエンジン間での柔軟なデータ処理が可能です。カスタムSQLクエリ実行機能も備え、高度な分析やメンテナンスにも対応します。Pythonで開発されており、psycopg2-binaryとsqlite3を介して各DBMSに接続し、mcp_config.jsonで接続設定を管理します。データベース管理の効率化と柔軟なデータ連携が主な用途です。

### [dubydu/sqlite-mcp](https://github.com/dubydu/sqlite-mcp)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-16 | N/A | Python |

**Supported DBMS:** SQLite

このサーバーは、LLM（大規模言語モデル）がSQLiteデータベースと自律的に対話することを可能にする軽量なModel Context Protocol (MCP) サーバーです。主な機能は、LLMがSQLクエリを実行したり、データベーススキーマを理解したりするのに役立つ一連のMCPツールを提供することです。用途としては、AIアシスタントや自動化ツールがデータベースから情報を取得したり、データを操作したりするシナリオが挙げられます。技術的にはPythonで実装されており、`--db-path`コマンドラインオプションを使用して指定されたSQLiteデータベースファイルに接続します。MCPプロトコルを介して、5ireやClaude Desktopといった様々なLLMクライアントと簡単に連携できるよう設計されています。

### [br-silvano/mcp-todo](https://github.com/br-silvano/mcp-todo)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-12 | MIT License | TypeScript |

**Supported DBMS:** SQLite

MCP Todoは、WebSocketを介したタスク管理APIです。コマンドのモジュール化された実行とツールサポートが特徴で、特にAIエージェントとの統合を目的として設計されています。TypeScriptで開発されており、データベースにはSQLiteを使用しています。これにより、効率的なタスク管理と柔軟な拡張性をAIシステムに提供し、開発者は容易にタスクを管理できます。

### [cnosuke/mcp-sqlite](https://github.com/cnosuke/mcp-sqlite)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 1 | 2025-04-11 | N/A | Go |

**Supported DBMS:** SQLite

MCP SQLite ServerはGo言語で実装されたMCPサーバーで、JSON-RPCプロトコルを通じてSQLiteデータベースへのアクセスを可能にします。これにより、Claude DesktopのようなMCPクライアントが標準化された方法でSQLiteと対話できます。主要機能として、テーブルの作成・記述・一覧表示、読み書きクエリの実行といったSQLite操作をサポート。DockerまたはGoバイナリとして動作し、容易な導入が可能です。設定はYAMLファイルまたは環境変数で行え、ログ管理も柔軟に対応します。MCPクライアント向けにcreate_table, describe_table, list_tables, read_query, write_queryなどのツールを提供します。

### [anhnx000/model_context_protocol_examples](https://github.com/anhnx000/model_context_protocol_examples)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-04-02 | N/A | Python |

**Supported DBMS:** SQLite

このプロジェクトはFastMCPアプリケーション内で非同期SQLiteデータベースを扱うデモです。aiosqliteを用いた非同期データベース操作、自動でのデータベース初期化とサンプルデータ挿入、型安全なコンテキスト管理、適切な接続ライフサイクル処理が主な特徴です。Python 3.7以降で動作し、`server.py`がメインサーバー、`database.py`がSQLite実装を担います。`demo.db`ファイルが自動生成され、FastMCPでのデータベース連携の学習や開発基盤として利用できます。

### [marekkucak/sqlite-anet-mcp](https://github.com/marekkucak/sqlite-anet-mcp)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-03-30 | N/A | Rust |

**Supported DBMS:** SQLite

このSQLite-Anet-MCPサーバーは、Rustで実装されたModel Control Protocol (MCP) サーバーであり、AIエージェントが標準化されたプロトコル経由でSQLiteデータベースを直接操作できるようにします。主な機能には、SQLiteデータベーステーブルの作成・管理、データの読み書き（SELECT, INSERT, UPDATE, DELETE）、テーブルスキーマの記述、ビジネスインサイトの保存・合成が含まれます。NATSをトランスポート層として使用し、JSON-RPC 2.0互換のAPIを提供。Tokioによる非同期リクエスト処理が特徴です。これにより、AIシステムがデータ駆動型タスクを効率的に実行するための強力な基盤を提供します。

### [MCP-Mirror/santos-404_mcp-server.sqlite](https://github.com/MCP-Mirror/santos-404_mcp-server.sqlite)

| Stars | Forks | Last Updated | License | Language |
|------:|------:|--------------|---------|----------|
| 0 | 0 | 2025-03-28 | MIT License | TypeScript |

**Supported DBMS:** SQLite

このSQLite MCPサーバーは、TypeScriptで実装されたModel Context Protocol (MCP) サーバーです。SQLiteデータベースとの連携を目的とし、SQLクエリの実行、データベーススキーマの管理、ビジネスインサイトの生成といった機能を提供します。AIモデルが外部ツールやサービスと連携するための標準化されたプロトコルであるMCPを利用しており、AIクライアント（例: Claude Desktop）からデータベース操作を可能にします。Dockerでのデプロイがサポートされており、AIの能力を拡張し、会話だけでなく具体的なデータ操作を可能にする技術的特徴を持ちます。
