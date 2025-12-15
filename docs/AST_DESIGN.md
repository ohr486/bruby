# bruby AST設計ドキュメント

## 概要

このドキュメントはbrubyにおける抽象構文木（AST）の設計方針と実装計画を記述します。

## 現状分析

### 現在のアーキテクチャ

```
Rubyソースコード
    ↓
[ruby_tokenizer.erl] 字句解析
    ↓
トークン列
    ↓
[ruby_parser.yrl] 構文解析
    ↓
AST（タプル形式）
    ↓
[ruby_evaluator.erl] 評価
    ↓
実行結果
```

### 現在のAST表現

現在のbrubyでは、ASTをErlangタプルで直接表現しています：

```erlang
%% 整数リテラル
{integer, Line, Value}

%% 文字列リテラル
{string, Line, Value}

%% 二項演算
{binary_op, Line, Op, Left, Right}

%% 変数代入
{assign, Line, Var, Expr}

%% メソッド定義
{method_def, Line, Name, Params, Body}

%% クラス定義
{class_def, Line, Name, Body}
```

### 現状の課題

1. **型定義の不足**: ASTノードの型が暗黙的で、Dialyzerによる型チェックが不十分
2. **位置情報の制限**: 行番号のみで、カラム位置や範囲情報がない
3. **メタデータの欠如**: コメント、ソースマッピング、型情報などが保持できない
4. **操作の一貫性**: ノード操作が各所に散在し、統一されたAPIがない
5. **拡張性**: 新しいノードタイプの追加や最適化の実装が困難

## 設計目標

### 1. 統一されたノード構造

すべてのASTノードを統一的に扱えるようにします：

```erlang
%% ruby.hrl

%% 位置情報
-record(location, {
    line :: pos_integer(),           % 行番号（1始まり）
    column :: pos_integer(),         % カラム位置（1始まり）
    start_offset :: non_neg_integer(), % ファイル先頭からのバイトオフセット
    end_offset :: non_neg_integer(),   % 終了位置のバイトオフセット
    file :: binary() | undefined       % ファイル名（オプション）
}).

%% メタデータ
-type metadata() :: #{
    comments => [comment()],      % 関連するコメント
    source => binary(),           % 元のソーステキスト
    annotations => map()          % 任意のアノテーション
}.

%% ASTノードの基本構造（マップベース）
-type ast_node() :: #{
    type := atom(),               % ノードタイプ (integer, string, binary_op, etc.)
    location := #location{},      % 位置情報
    metadata => metadata(),       % メタデータ（オプション）
    %% ... ノード固有のフィールド
}.
```

### 2. ノードタイプの型定義

各ノードタイプに対して明示的な型を定義：

```erlang
%% リテラルノード
-type integer_node() :: #{
    type := integer,
    location := #location{},
    value := integer(),
    metadata => metadata()
}.

-type string_node() :: #{
    type := string,
    location := #location{},
    value := binary() | string(),
    metadata => metadata()
}.

%% 演算ノード
-type binary_op_node() :: #{
    type := binary_op,
    location := #location{},
    op := atom(),          % '+', '-', '*', '/', etc.
    left := ast_node(),
    right := ast_node(),
    metadata => metadata()
}.

%% 変数ノード
-type var_node() :: #{
    type := var,
    location := #location{},
    name := atom(),
    metadata => metadata()
}.

-type assign_node() :: #{
    type := assign,
    location := #location{},
    var := var_node(),
    expr := ast_node(),
    metadata => metadata()
}.
```

### 3. ruby_astモジュールの設計

新しい`ruby_ast`モジュールを作成し、ASTの操作を集約します：

```erlang
-module(ruby_ast).

%% ノード作成API
-export([
    new_integer/2, new_integer/3,
    new_string/2, new_string/3,
    new_binary_op/4, new_binary_op/5,
    new_assign/3, new_assign/4,
    new_method_def/4, new_method_def/5,
    new_class_def/3, new_class_def/4
]).

%% ノード検査API
-export([
    is_literal/1,
    is_expression/1,
    is_statement/1,
    get_type/1,
    get_location/1,
    get_children/1
]).

%% ノード操作API
-export([
    update_location/2,
    set_metadata/3,
    get_metadata/2,
    with_metadata/2
]).

%% AST走査API
-export([
    walk/2,
    walk/3,
    map/2,
    fold/3,
    filter/2
]).

%% AST変換API
-export([
    constant_fold/1,
    normalize/1,
    optimize/1
]).

%% AST出力API
-export([
    to_sexp/1,
    to_json/1,
    pretty_print/1,
    pretty_print/2
]).
```

### 4. パーサーとの統合

`ruby_parser.yrl`を更新して、新しいAST構造を生成するようにします：

```erlang
%% ruby_parser.yrl の Erlang code セクション

%% ヘルパー関数
line_of(Token) when is_tuple(Token) -> element(2, Token);
line_of(_) -> 0.

value_of({_, _, Value}) -> Value;
value_of({_, Line}) -> Line;
value_of(Value) -> Value.

%% 新しいAST構築ヘルパー
make_integer(Token) ->
    Line = line_of(Token),
    Value = value_of(Token),
    ruby_ast:new_integer(Value, #location{line = Line, column = 0}).

make_string(Token) ->
    Line = line_of(Token),
    Value = value_of(Token),
    ruby_ast:new_string(Value, #location{line = Line, column = 0}).

make_binary_op(Op, Left, Right) ->
    Line = line_of(Op),
    OpAtom = value_of(Op),
    ruby_ast:new_binary_op(OpAtom, Left, Right, #location{line = Line, column = 0}).
```

## 実装計画

### フェーズ1: 基盤の構築（優先度: 高）

1. **位置情報とメタデータの定義**
   - `ruby.hrl`に`#location{}`レコードを追加
   - メタデータの型定義を追加

2. **基本的なノード型の定義**
   - リテラルノード（integer, string, boolean, nil）
   - 変数ノード（var, assign）
   - 演算ノード（binary_op, unary_op）

3. **ruby_astモジュールの基本実装**
   - ノード作成関数
   - 基本的なノード検査関数

### フェーズ2: AST走査の実装（優先度: 高）

1. **Visitor/Walkerパターンの実装**
   - 深さ優先探索
   - コールバック関数のサポート

2. **基本的なAST操作**
   - map/2（ノード変換）
   - fold/3（ノード集約）
   - filter/2（ノード選択）

### フェーズ3: AST変換と最適化（優先度: 中）

1. **定数畳み込み**
   - 算術演算の事前計算
   - 論理演算の簡約

2. **デッドコード除去**
   - 到達不可能コード検出

### フェーズ4: デバッグと分析（優先度: 中）

1. **AST出力機能**
   - S式表現
   - JSON表現
   - Pretty Printer

2. **AST統計機能**
   - ノードカウント
   - 複雑度メトリクス

### フェーズ5: 高度な機能（優先度: 低）

1. **メタデータ管理**
   - コメント情報の保持
   - ソースマッピング

2. **AST検証**
   - 構造的検証
   - 意味的検証

## マイグレーション戦略

### 段階的な移行

既存のコードへの影響を最小限にするため、段階的に移行します：

1. **Phase 1: 並行稼働**
   - 新しいAST形式と古いタプル形式を両方サポート
   - 変換関数を提供（`old_to_new/1`, `new_to_old/1`）

2. **Phase 2: 評価器の更新**
   - `ruby_evaluator`を新しいAST形式に対応させる
   - フォールバック機能で古い形式もサポート

3. **Phase 3: 完全移行**
   - すべてのモジュールを新形式に統一
   - 古い形式のサポートを削除

### 互換性の維持

```erlang
%% ruby_ast.erl

%% 古い形式から新しい形式への変換
-spec from_legacy(term()) -> ast_node().
from_legacy({integer, Line, Value}) ->
    new_integer(Value, #location{line = Line, column = 0});
from_legacy({string, Line, Value}) ->
    new_string(Value, #location{line = Line, column = 0});
from_legacy({binary_op, Line, Op, Left, Right}) ->
    new_binary_op(Op,
                  from_legacy(Left),
                  from_legacy(Right),
                  #location{line = Line, column = 0});
%% ... その他のノードタイプ

%% 新しい形式から古い形式への変換（移行期間用）
-spec to_legacy(ast_node()) -> term().
to_legacy(#{type := integer, location := Loc, value := Value}) ->
    {integer, Loc#location.line, Value};
to_legacy(#{type := string, location := Loc, value := Value}) ->
    {string, Loc#location.line, Value};
%% ... その他のノードタイプ
```

## パフォーマンス考慮事項

### マップ vs レコード

ASTノードの実装にマップとレコードのどちらを使用するか：

**マップの利点:**
- 動的なフィールド追加が容易
- メタデータやアノテーションの扱いが柔軟
- パターンマッチが直感的

**レコードの利点:**
- コンパイル時の型チェックが強力
- メモリ効率が良い
- アクセス速度が速い

**推奨**: 初期実装はマップベースで行い、パフォーマンスが問題になった場合にレコードに移行

### 大規模ASTの扱い

- 遅延評価の活用
- ストリーム処理の検討
- メモリ効率的な走査アルゴリズム

## テスト戦略

### ユニットテスト

```erlang
%% test/erlang/test_ruby_ast.erl

-module(test_ruby_ast).
-export([test/0]).

test() ->
    test_node_creation(),
    test_node_inspection(),
    test_ast_walking(),
    test_ast_transformation(),
    test_ast_output(),
    ok.

test_node_creation() ->
    %% 整数ノードの作成
    Node = ruby_ast:new_integer(42, #location{line = 1, column = 1}),
    42 = ruby_ast:get_value(Node),
    integer = ruby_ast:get_type(Node),

    %% 二項演算ノードの作成
    Left = ruby_ast:new_integer(1, #location{line = 1, column = 1}),
    Right = ruby_ast:new_integer(2, #location{line = 1, column = 5}),
    OpNode = ruby_ast:new_binary_op('+', Left, Right, #location{line = 1, column = 1}),
    binary_op = ruby_ast:get_type(OpNode),

    ok.

test_ast_walking() ->
    %% AST: 1 + 2 * 3
    AST = ruby_ast:new_binary_op('+',
        ruby_ast:new_integer(1, #location{line = 1, column = 1}),
        ruby_ast:new_binary_op('*',
            ruby_ast:new_integer(2, #location{line = 1, column = 5}),
            ruby_ast:new_integer(3, #location{line = 1, column = 9}),
            #location{line = 1, column = 5}),
        #location{line = 1, column = 1}),

    %% すべてのノードをカウント
    Count = ruby_ast:fold(
        fun(Node, Acc) -> Acc + 1 end,
        0,
        AST
    ),
    5 = Count,  %% 3つの整数 + 2つの演算子

    ok.
```

### 統合テスト

- トークナイザー → パーサー → AST → 評価器のパイプライン全体をテスト
- 実際のRubyコードサンプルでの動作確認

## ドキュメント

### APIドキュメント

- EDocを使用した関数ドキュメント
- 使用例の充実
- 型仕様（-spec）の完備

### 設計ドキュメント

- このドキュメント（AST_DESIGN.md）
- アーキテクチャ図
- ノードタイプリファレンス

## 参考実装

### Ruby公式（MRI）

- RubyVM::AbstractSyntaxTree モジュール
- ノード構造とメソッド

### whitequark/parser

- Rubyで書かれた強力なパーサー
- 詳細なAST表現
- ソースマッピング

### Elixir

- Erlang VM上の動的言語
- マクロシステムでASTを直接操作
- quoted expressionsの設計

## まとめ

この設計により、brubyのAST実装は以下のメリットを得られます：

1. **型安全性**: Dialyzerによる型チェックで早期にエラーを発見
2. **拡張性**: 新しいノードタイプや機能の追加が容易
3. **保守性**: 統一されたAPIで一貫したコード
4. **デバッグ性**: 詳細な位置情報と出力機能
5. **最適化**: ASTレベルでの変換と最適化が可能

段階的な実装により、既存の機能を壊すことなく、着実に改善を進めることができます。
