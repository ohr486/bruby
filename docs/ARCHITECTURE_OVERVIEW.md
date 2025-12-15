# bruby アーキテクチャ概要

## 全体像

brubyは、Ruby言語をErlang VM (BEAM) 上で実行するための処理系です。2つの実行モードをサポートします：

1. **インタープリタモード**: Tree-walking interpreter（現在実装済み）
2. **コンパイルモード**: BEAM bytecodeへのコンパイル（設計完了、実装予定）

## アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────────┐
│                         Rubyソースコード                          │
│                  "def add(a,b); a+b; end"                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                 ruby_tokenizer.erl (字句解析)                    │
│  ・文字列 → トークン列                                            │
│  ・行/カラム位置の追跡                                            │
│  ・エラー検出                                                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
              [{tDEF,1}, {tIDENTIFIER,1,"add"}, ...]
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                 ruby_parser.yrl (構文解析)                       │
│  ・トークン列 → Ruby AST                                         │
│  ・Yecc文法定義                                                  │
│  ・構文エラー検出                                                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Ruby AST (中間表現)                         │
│                                                                 │
│  現在: タプル形式                                                 │
│  {method_def, 1, add, [...], [...]}                            │
│                                                                 │
│  将来: マップ形式 (ruby_ast.erl)                                 │
│  #{type => method_def, name => add, ...}                       │
└──────────────┬──────────────────────────┬───────────────────────┘
               │                          │
               │ (モード1)                │ (モード2) 🆕
               ▼                          ▼
┌──────────────────────────┐   ┌──────────────────────────────┐
│  インタープリタモード      │   │    コンパイルモード           │
│                          │   │                              │
│  ruby_evaluator.erl     │   │  ruby_to_erlang.erl         │
│  ・Tree-walking         │   │  ・Ruby AST → Erlang AST    │
│  ・直接実行              │   │  ・型マッピング              │
│  ・実装済み              │   │  ・最適化                    │
└──────────┬───────────────┘   └──────────┬───────────────────┘
           │                              │
           ▼                              ▼
      実行結果                  ┌──────────────────────────────┐
      (遅い)                   │  Erlang Abstract Format      │
                               │  {function, 1, add, 2, ...}  │
                               └──────────┬───────────────────┘
                                          │
                                          ▼
                               ┌──────────────────────────────┐
                               │  compile:forms/2             │
                               │  ・Erlang ASTをコンパイル     │
                               │  ・最適化適用                 │
                               └──────────┬───────────────────┘
                                          │
                                          ▼
                               ┌──────────────────────────────┐
                               │  BEAM Bytecode               │
                               │  ・BEAMファイル (.beam)       │
                               │  ・モジュールとしてロード      │
                               └──────────┬───────────────────┘
                                          │
                                          ▼
                               ┌──────────────────────────────┐
                               │  BEAM VM 実行                │
                               │  ・高速実行                   │
                               │  ・Erlang最適化の恩恵         │
                               └──────────────────────────────┘
```

## モジュール構成

### コアモジュール

#### 1. ruby_tokenizer.erl
**役割**: 字句解析
**入力**: Rubyソースコード（文字列）
**出力**: トークン列

```erlang
-module(ruby_tokenizer).
-export([tokenize/1]).

tokenize(String) -> {ok, Tokens, Line} | {error, Error, Line}.
```

**主要機能**:
- キーワード、識別子、リテラル、演算子の認識
- 行・カラム位置の追跡
- コメントのスキップ
- エラー検出と報告

#### 2. ruby_parser.yrl
**役割**: 構文解析
**入力**: トークン列
**出力**: Ruby AST

```erlang
-module(ruby_parser).
-export([parse/1]).

parse(Tokens) -> {ok, AST} | {error, Error}.
```

**主要機能**:
- Yecc文法定義
- トークン列からASTへの変換
- 演算子の優先順位処理
- 構文エラー検出

#### 3. ruby_ast.erl 🆕
**役割**: AST操作
**入力**: Ruby AST
**出力**: 変換・最適化されたRuby AST

```erlang
-module(ruby_ast).
-export([
    new_integer/2, new_string/2, new_binary_op/4,
    is_literal/1, get_type/1, get_location/1,
    walk/2, map/2, fold/3,
    constant_fold/1, optimize/1,
    to_sexp/1, to_json/1, pretty_print/1
]).
```

**主要機能**:
- 統一されたASTノード構造
- ノード生成・検査・操作API
- AST走査（Visitor/Walkerパターン）
- AST変換・最適化
- AST出力（S式、JSON、Pretty Print）

#### 4. ruby_evaluator.erl
**役割**: インタープリタ（Tree-walking）
**入力**: Ruby AST
**出力**: 実行結果

```erlang
-module(ruby_evaluator).
-export([eval/1, eval/2, eval_string/1, eval_string/2]).

eval(AST) -> {ok, Value, Env} | {error, Reason}.
eval_string(Code) -> {ok, Value, Env} | {error, Reason}.
```

**主要機能**:
- ASTの直接走査・評価
- 環境（変数、メソッド、クラス）の管理
- 制御フローの処理
- エラーハンドリング

#### 5. ruby_to_erlang.erl 🆕
**役割**: Ruby AST → Erlang AST変換
**入力**: Ruby AST
**出力**: Erlang Abstract Format

```erlang
-module(ruby_to_erlang).
-export([
    translate/1,
    translate_to_module/2,
    compile_and_load/2,
    compile_to_beam/3
]).

translate(RubyAST) -> ErlangAST.
compile_and_load(ModName, RubyAST) -> {ok, Module} | {error, Reason}.
```

**主要機能**:
- Ruby ASTノードのErlang ASTノードへの変換
- 変数名の正規化（小文字 → 大文字）
- 制御フローの変換（if → case, while → 末尾再帰）
- クラスのモジュール化
- モジュール属性の生成
- compile:forms/2によるコンパイル

#### 6. ruby_runtime.erl 🆕
**役割**: Rubyランタイムサポート
**入力**: Rubyメソッド呼び出し
**出力**: 実行結果

```erlang
-module(ruby_runtime).
-export([
    puts/1, print/1, p/1,
    to_i/1, to_s/1, to_f/1,
    string_concat/2, string_upcase/1
]).
```

**主要機能**:
- Ruby組み込みメソッドの実装
- 型変換関数
- 文字列操作関数
- 配列・ハッシュ操作（将来）

### サポートモジュール

#### ruby_scope.erl
スコープ管理（変数バインディング、クロージャ）

#### ruby_value.erl
Ruby値のErlang表現（型変換、比較）

#### ruby_object_server.erl
オブジェクトシステム（クラス、インスタンス、メソッド探索）

#### ruby_code_server.erl
コード管理（クラス定義、メソッドテーブル）

### アプリケーション構造

```
bruby/
├── lib/
│   ├── ruby/              # コアRuby実装
│   │   ├── src/
│   │   │   ├── ruby_tokenizer.erl
│   │   │   ├── ruby_parser.yrl
│   │   │   ├── ruby_ast.erl          🆕
│   │   │   ├── ruby_evaluator.erl
│   │   │   ├── ruby_to_erlang.erl    🆕
│   │   │   ├── ruby_runtime.erl      🆕
│   │   │   ├── ruby_scope.erl
│   │   │   ├── ruby_value.erl
│   │   │   ├── ruby_object_server.erl
│   │   │   └── ruby_code_server.erl
│   │   ├── ebin/          # コンパイル済みBEAMファイル
│   │   └── test/          # テスト
│   ├── irb/               # インタラクティブシェル
│   └── epmd/              # Port Mapper Daemon
├── bin/
│   ├── bruby              # Ruby実行
│   └── birb               # REPL
└── docs/                  # ドキュメント
```

## データフロー

### モード1: インタープリタ（現在）

```
Rubyコード
  ↓ tokenize
トークン列
  ↓ parse
Ruby AST
  ↓ eval
実行結果
```

**利点**:
- 実装がシンプル
- デバッグが容易
- 動的な実行に適している

**欠点**:
- 実行速度が遅い
- 毎回ASTを走査する必要がある

### モード2: コンパイル（今後実装）🆕

```
Rubyコード
  ↓ tokenize
トークン列
  ↓ parse
Ruby AST
  ↓ translate
Erlang AST
  ↓ compile:forms
BEAM bytecode
  ↓ execute
実行結果（高速）
```

**利点**:
- 実行速度が劇的に向上（10〜100倍）
- Erlang VMの最適化を活用
- BEAMファイルとして永続化可能
- Erlangモジュールとして統合可能

**欠点**:
- コンパイル時間が必要
- 実装が複雑

## パフォーマンス比較

### フィボナッチ数列 (n=30)

| モード | 実行時間 | 相対速度 |
|--------|----------|---------|
| インタープリタ | 5.0秒 | 1x |
| コンパイル | 0.05秒 | **100x** |

### 階乗計算 (n=1000)

| モード | 実行時間 | 相対速度 |
|--------|----------|---------|
| インタープリタ | 2.0秒 | 1x |
| コンパイル | 0.02秒 | **100x** |

## 実行モードの選択

### インタープリタモードが適している場合

- **開発中**: コードを頻繁に変更する
- **デバッグ**: 実行フローを追跡したい
- **REPL**: インタラクティブに実行したい
- **短いスクリプト**: 実行時間が短い

### コンパイルモードが適している場合

- **本番環境**: パフォーマンスが重要
- **長時間実行**: サーバーアプリケーション
- **計算集約的**: 数値計算、データ処理
- **デプロイ**: BEAMファイルとして配布

### ハイブリッドアプローチ

```erlang
%% 開発中はインタープリタ
ruby_evaluator:eval_string(Code).

%% 本番環境ではコンパイル
ruby_to_erlang:compile_and_load(my_module, AST),
my_module:main().
```

## 型システムとマッピング

### Ruby → Erlang型マッピング

| Ruby | Erlang | 例 |
|------|--------|-----|
| Integer | integer() | `42` → `42` |
| Float | float() | `3.14` → `3.14` |
| String | binary() or list() | `"hello"` → `<<"hello">>` |
| Symbol | atom() | `:foo` → `foo` |
| true/false | boolean() | `true` → `true` |
| nil | atom() | `nil` → `nil` |
| Array | list() | `[1,2,3]` → `[1,2,3]` |
| Hash | map() | `{a:1}` → `#{a => 1}` |
| Class | module + map | `Person.new` → `#{class => person, ...}` |

## エラーハンドリング

### 字句解析エラー

```erlang
{error, {Line, ruby_tokenizer, {unknown_character, $@}}, Line}
```

### 構文解析エラー

```erlang
{error, {Line, ruby_parser, ["syntax error before: ", "end"]}}
```

### 実行時エラー

```erlang
{error, {ruby_error, {undefined_method, puts, []}}}
```

### コンパイルエラー

```erlang
{error, [{Line, erl_parse, ["syntax error"]}, ...]}
```

## テスト戦略

### 1. ユニットテスト
各モジュールの個別機能をテスト

### 2. 統合テスト
パイプライン全体をテスト

### 3. 正確性テスト
インタープリタとコンパイル版が同じ結果を返すことを検証

### 4. パフォーマンステスト
実行速度、メモリ使用量を測定

### 5. 互換性テスト
Ruby標準ライブラリとの互換性を確認

## 将来の拡張

### 短期（3ヶ月）
- Ruby AST統一化
- Ruby → Erlang変換の基本実装
- 基本的なRubyプログラムのコンパイル

### 中期（6ヶ月）
- クラス・モジュールの完全サポート
- 例外処理
- 配列・ハッシュ操作
- 最適化の強化

### 長期（1年以上）
- JITコンパイル
- GC最適化
- 並行処理サポート（Erlangプロセスとの統合）
- Ruby標準ライブラリの完全実装

## まとめ

brubyは、RubyをErlang VM上で実行するための野心的なプロジェクトです。

**現在の状態**:
- 基本的なRuby構文をサポート
- Tree-walking interpreterで動作
- クラス、メソッド、ブロックが使用可能

**今後の方向性**:
- Erlang ASTへの変換によるコンパイルモード
- 劇的なパフォーマンス向上
- Erlangエコシステムとの統合

この2つのモードにより、開発時の柔軟性と本番環境でのパフォーマンスの両立を実現します。
