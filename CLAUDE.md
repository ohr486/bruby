# CLAUDE.md

このファイルは、このリポジトリのコードを扱う際にClaude Code (claude.ai/code) にガイダンスを提供します。

## プロジェクト概要

brubyはBEAM (Erlang VM) 上で動作するRuby実装です。プロジェクトは3つの主要なOTPアプリケーションで構成されています：
- **ruby**: トークナイザ、パーサー、評価器を含むRuby言語のコア実装
- **irb**: インタラクティブRubyシェル (REPL)
- **epmd**: Erlang Port Mapper Daemonコンポーネント

## ビルドシステム

すべてのビルドはMakeで統制されています。プロジェクトはEmakefile設定を使用したErlangの`erl -make`システムを使用しています。

### よく使うコマンド

```sh
# すべてのアプリケーションをビルド (ruby, irb, epmd)
make

# すべてのテストを実行
make test

# すべての生成ファイルをクリーン
make clean

# Lintチェックを実行（コンパイラ警告）
make lint

# Dialyzer（型チェッカー）を実行
make dialyzer

# Dialyzer用のPLTファイルを作成
make plt
```

### コンポーネント別コマンド

```sh
# 個別コンポーネントのビルド
make compile_ruby
make compile_irb
make compile_epmd

# 個別コンポーネントのテスト
make test_ruby
make test_irb
make test_epmd
```

### スクリプトの実行

```sh
# Rubyスクリプトを実行
./bin/bruby [script.rb]

# インタラクティブREPLを実行
./bin/birb

# トークナイザーのテスト（トークン化の出力を確認）
./bin/test_tokenizer.sh "def hello(name); puts name; end"

# パーサーのテスト（AST出力を確認）
./bin/test_parser.sh "1 + 2 * 3"

# 評価器のテスト（複数のサンプルRubyプログラムを実行）
./bin/test_eval.sh
```

### Docker開発環境

```sh
cd docker
./build.sh
./run.sh
# コンテナ内で: make && make test
```

## アーキテクチャ

### OTPアプリケーション構造

各アプリケーションは標準的なOTP規約に従っています：
- `lib/<app>/src/`: ソースファイル (.erl, .yrl, .hrl, .app.src)
- `lib/<app>/src/builtin/`: Ruby組み込みクラスの実装 (ruby アプリのみ)
- `lib/<app>/ebin/`: コンパイル済みbeamファイルと.appファイル (生成)
- `lib/<app>/test/erlang/`: テストファイル
- `lib/<app>/test/ebin/`: コンパイル済みテストbeamファイル (生成)
- `lib/<app>/Emakefile`: Erlangコンパイラ設定

### Rubyアプリケーションのコンポーネント

rubyアプリケーションは以下を管理する監視ツリー (ruby_sup) を使用しています：
1. **ruby_config**: 設定用gen_server
2. **ruby_code_server**: ETS (ruby_classesテーブル) を使用してRubyクラス定義と参照を管理
3. **class_server**: クラスプール管理用gen_server

**パーサーパイプライン:**
- `ruby_tokenizer.erl`: 字句解析 - Rubyソースコードをトークンに変換
- `ruby_parser.yrl`: `ruby_parser.erl`を生成するYecc文法ファイル
- `ruby_evaluator.erl`: パーサーが生成したASTを評価
- パーサーはコンパイル前にYecc文法からビルドされます

詳細は [docs/TOKENIZER_PARSER.md](docs/TOKENIZER_PARSER.md) と [docs/EVALUATOR.md](docs/EVALUATOR.md) を参照してください。

**エントリーポイント:**
- `ruby:run_script/0`: bin/brubyから呼び出され、utils:check_args/1を介してコマンドライン引数を処理
- `irb:run/0`: bin/birbから呼び出されREPLを実行

**実行モード:**

brubyは2つの実行モードをサポートします：
1. **インタープリタモード** (実装済み): Tree-walking interpreter
2. **コンパイルモード** (設計完了、実装予定): Ruby ASTをErlang ASTに変換し、BEAMバイトコードにコンパイル

詳細なアーキテクチャ図とデータフローは [docs/ARCHITECTURE_OVERVIEW.md](docs/ARCHITECTURE_OVERVIEW.md) を参照してください。

### ビルド依存関係

1. Rubyパーサー生成: `ruby_parser.yrl` → `ruby_parser.erl` (erlc経由)
2. アプリケーションファイルのコピー: `*.app.src` → `ebin/*.app`
3. ディレクトリのセットアップ: コンパイル前に`ebin/`ディレクトリを作成
4. Erlangコンパイル: すべての.erlファイルをebin/内の.beamにコンパイル

テストファイルは独立して`test/ebin/`にコンパイルされ、test_helperモジュールをエントリーポイントとして使用します。

## テスト

テストシステムはtest_helperモジュールをエントリーポイントとして使用しています：
- `test/erlang/`から`test/ebin/`へテスト.erlファイルをコンパイル
- `erl -pa <test_ebin> -s test_helper test`を実行
- test_helper:test/0がtest_tokenizer、test_parser、test_evaluatorを実行
- 成功時はコード0、失敗時はコード1で終了

### Erlangシェルでの対話的テスト

評価器を対話的にテストできます：
```sh
erl -pa lib/ruby/ebin
```

```erlang
% 基本的な算術演算
ruby_evaluator:eval_string("1 + 2 * 3").
% {ok,7,#{bindings => #{},parent => nil,return_value => undefined}}

% 変数
ruby_evaluator:eval_string("x = 10; y = 20; x + y").
% {ok,30,#{bindings => #{x => 10,y => 20},...}}

% 前の環境を引き継いで評価を続ける
{ok, Result1, Env1} = ruby_evaluator:eval_string("x = 10").
{ok, Result2, Env2} = ruby_evaluator:eval_string("y = 20; x + y", Env1).
% Result2は30（xの値が保持されている）
```

## CI/CD

CircleCIがすべてのコミットでErlang 28 Dockerイメージを使用して実行されます：
- `make` (ビルド)
- `make lint` (Lintチェック)
- `make dialyzer` (型チェック)
- `make test` (テスト)
- Slack通知がorb経由で設定済み

## Lint & 静的解析

プロジェクトには2つのlintツールが用意されています：

### コンパイラ警告 (`make lint`)
以下の警告を有効化しています（Emakefileで設定）：
- `warn_unused_vars`: 未使用変数
- `warn_export_all`: export_allの使用
- `warn_shadow_vars`: シャドウ変数
- `warn_unused_import`: 未使用インポート
- `warn_unused_function`: 未使用関数
- `warn_bif_clash`: BIF衝突
- `warn_unused_record`: 未使用レコード
- `warn_deprecated_function`: 非推奨関数
- `warn_obsolete_guard`: 廃止されたガード
- `warn_exported_vars`: エクスポートされた変数
- `warn_missing_spec`: 型仕様の欠如
- `warn_untyped_record`: 型なしレコード

### Dialyzer (`make dialyzer`)
Dialyzerは型の不整合とエラーを検出します。初回実行時にPLTファイル（`.bruby_plt`）を自動作成します。PLTファイルは`.gitignore`に含まれています。

## ドキュメント

詳細な設計ドキュメントは `docs/` ディレクトリにあります：

### アーキテクチャと設計
- **[ARCHITECTURE_OVERVIEW.md](docs/ARCHITECTURE_OVERVIEW.md)**: brubyの全体アーキテクチャ、2つの実行モード（インタープリタ/コンパイル）、モジュール構成、データフロー
- **[AST_DESIGN.md](docs/AST_DESIGN.md)**: Ruby ASTの設計、ノード構造、型定義
- **[AST_NODE_REFERENCE.md](docs/AST_NODE_REFERENCE.md)**: すべてのASTノード型の完全なリファレンス
- **[AST_IMPLEMENTATION_GUIDE.md](docs/AST_IMPLEMENTATION_GUIDE.md)**: AST実装のステップバイステップガイド

### コンパイラとトランスレータ
- **[RUBY_TO_ERLANG_AST.md](docs/RUBY_TO_ERLANG_AST.md)**: Ruby AST → Erlang AST変換の完全な設計仕様
- **[RUBY_TO_ERLANG_TUTORIAL.md](docs/RUBY_TO_ERLANG_TUTORIAL.md)**: コンパイルモードの実践的なチュートリアル

### 実装ガイド
- **[TOKENIZER_PARSER.md](docs/TOKENIZER_PARSER.md)**: トークナイザーとパーサーの使い方、サポートしている構文
- **[EVALUATOR.md](docs/EVALUATOR.md)**: 評価器（インタープリタ）の使い方とサンプルコード

## 重要な注意事項

### コード編集時の注意
- **`ruby_parser.erl`を直接編集しないでください** - `ruby_parser.yrl`（Yecc文法ファイル）から生成されます
- パーサーを変更する場合は `ruby_parser.yrl` を編集してから `make` でリビルドしてください
- コアモジュールには`ruby_*`、`class_*`、`code_*`のモジュール名プレフィックスパターンを使用してください
- 新しいコードには型仕様（`-spec`）とレコードの型定義を追加してください

### システムアーキテクチャ
- ETSテーブル`ruby_classes`はruby_code_serverによってクラスレジストリ用に管理されています
- すべてのアプリケーションはkernel、stdlib、compilerに依存しています
- rubyアプリケーションは監視ツリー（ruby_sup）でgen_serverプロセスを管理しています

### AST設計
- Ruby ASTは統一されたマップ形式で設計されています（詳細: [docs/AST_DESIGN.md](docs/AST_DESIGN.md)）
- 現在のタプル形式ASTから統一マップ形式への移行を計画中
- 新しいAST操作には `ruby_ast` モジュールのAPIを使用してください

### 開発方針
- **詳細な設計情報は `docs/` ディレクトリを参照**してください
- 新機能を実装する前に、関連ドキュメントと [TODO.md](TODO.md) を確認してください
- パフォーマンスが重要な場合は、コンパイルモードの実装を検討してください

## 現在の実装状況

### インタープリタモード（実装済み）

**基本機能:**
- リテラル: 整数、浮動小数点数、文字列、真偽値、nil
- ローカル変数: 代入と参照
- インスタンス変数: @変数名
- グローバル変数: $変数名（基本サポート）

**演算子:**
- 算術演算子: `+`, `-`, `*`, `/`, `%`
- 比較演算子: `==`, `!=`, `<`, `>`, `<=`, `>=`
- 論理演算子: `and`, `or`, `not`
- ビット演算子: `&`, `|`, `^`, `~`, `<<`, `>>`

**制御フロー:**
- 条件分岐: `if`/`elsif`/`else`/`end`
- ループ: `while`/`until`
- 早期リターン: `return`

**オブジェクト指向:**
- メソッド定義と呼び出し
- クラス定義（`class`/`end`）
- コンストラクタ（`initialize`）
- インスタンス変数とアクセサ
- クラス継承（基本サポート）

**ブロックとクロージャ:**
- ブロック構文: `{ }` および `do...end`
- `yield` によるブロック呼び出し
- `block_given?` によるブロック存在確認
- `lambda` と `proc` によるProcオブジェクト
- 基本的なクロージャ（変数キャプチャ）

**組み込みクラス:**
- `Numeric`, `Integer`, `String`, `Kernel` の基本的なメソッド

### コンパイルモード（設計完了、実装予定）

Ruby AST → Erlang AST → BEAM バイトコードへのコンパイル機能を設計済み。実装により10〜100倍の実行速度向上が期待されます。

詳細は以下を参照：
- 設計: [docs/RUBY_TO_ERLANG_AST.md](docs/RUBY_TO_ERLANG_AST.md)
- チュートリアル: [docs/RUBY_TO_ERLANG_TUTORIAL.md](docs/RUBY_TO_ERLANG_TUTORIAL.md)
- 実装タスク: [TODO.md](TODO.md) の「Ruby AST → Erlang AST変換」セクション

### 未実装・制限事項

**構文:**
- `break`/`next` 文（トークンは定義済み）
- `case`/`when` 文
- 多重代入
- 正規表現リテラル
- ヒアドキュメント

**データ構造:**
- 配列（`[]` 構文）
- ハッシュ（`{}` 構文）
- シンボル（`:symbol` 構文）
- 範囲（`..`, `...`）

**高度な機能:**
- モジュールとミックスイン
- 特異メソッド
- メタプログラミング（`define_method`, `method_missing` など）
- 例外処理（`begin`/`rescue`/`ensure`/`raise`）
- イテレータメソッド（`each`, `map`, `select` など）
- ファイルI/O
- 標準ライブラリ

## 開発の優先順位

### 高優先度（実装推奨）
1. **Ruby AST → Erlang AST変換**: コンパイルモードの実装により劇的な性能向上
2. **配列とハッシュ**: Rubyの基本的なデータ構造
3. **case/when文**: 実用的な制御フロー
4. **例外処理**: エラーハンドリングの基盤

### 中優先度
1. **イテレータメソッド**: `each`, `map`, `select` などの基本メソッド
2. **シンボル**: Rubyらしいコードのために必要
3. **モジュールシステム**: コードの再利用と構造化

### 低優先度（将来の拡張）
1. メタプログラミング機能
2. 正規表現サポート
3. ファイルI/O
4. 標準ライブラリの完全実装

詳細な実装タスクは [TODO.md](TODO.md) を参照してください。

## プロジェクトの目標

brubyは以下を目指しています：

1. **Ruby言語のBEAM上での実行**: RubyコードをErlang VM上で動作させる
2. **2つの実行モード**: 開発時はインタープリタ、本番環境ではコンパイル
3. **高いパフォーマンス**: BEAM バイトコードへのコンパイルによる高速実行
4. **Erlangエコシステムとの統合**: 既存のErlangコードとの相互運用

このプロジェクトは実験的・教育的な側面が強いですが、将来的には実用的なRuby実装を目指しています。
