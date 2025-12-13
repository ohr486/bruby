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

# 評価器のテスト（10個のサンプルRubyプログラムを実行）
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

**エントリーポイント:**
- `ruby:run_script/0`: bin/brubyから呼び出され、utils:check_args/1を介してコマンドライン引数を処理
- `irb:run/0`: bin/birbから呼び出されREPLを実行

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

## 重要な注意事項

- **`ruby_parser.erl`を直接編集しないでください** - Yecc文法から生成されます
- ETSテーブル`ruby_classes`はcode_serverによってクラスレジストリ用に管理されています
- すべてのアプリケーションはkernel、stdlib、compilerに依存しています
- コアモジュールには`ruby_*`、`class_*`、`code_*`のモジュール名プレフィックスパターンを使用してください
- 新しいコードには型仕様（`-spec`）とレコードの型定義を追加してください

## 現在の実装状況

**実装済み:**
- リテラル（整数、文字列、真偽値、nil）
- ローカル変数（代入と参照）
- 算術演算子（+, -, *, /, %）
- 比較演算子（==, !=, <, >, <=, >=）
- 論理演算子（and, or）
- ビット演算子（&, |, ^, ~, <<, >>）
- if/elsif/else文
- while/until文
- return文

**未実装:**
- メソッド呼び出しと定義
- クラス定義
- ブロック/イテレータ
- シンボル
- 配列・ハッシュ
- 例外処理
- break/next文
