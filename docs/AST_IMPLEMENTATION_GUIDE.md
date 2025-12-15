# bruby AST実装ガイド

このドキュメントは、brubyのAST機能を実装する開発者向けのガイドです。

## 目次

1. [実装の全体像](#実装の全体像)
2. [Phase 1: 基盤構築](#phase-1-基盤構築)
3. [Phase 2: パーサー統合](#phase-2-パーサー統合)
4. [Phase 3: 評価器更新](#phase-3-評価器更新)
5. [Phase 4: AST操作API](#phase-4-ast操作api)
6. [Phase 5: 高度な機能](#phase-5-高度な機能)

## 実装の全体像

### アーキテクチャ図

```
┌─────────────────────────────────────────────────────────────┐
│                      Rubyソースコード                         │
│                    "x = 10; puts x"                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              ruby_tokenizer.erl (字句解析)                   │
│  ・文字列をトークン列に変換                                    │
│  ・行/カラム位置の追跡                                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              [{tIDENTIFIER,1,"x"}, {'=',1}, {tINTEGER,1,10}, ...]
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              ruby_parser.yrl (構文解析)                      │
│  ・トークン列をASTに変換                                       │
│  ・Yecc文法で定義                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                 AST (抽象構文木)                              │
│                                                              │
│  現在: タプル形式                                             │
│  {assign, 1, {var, 1, x}, {integer, 1, 10}}                 │
│                                                              │
│  将来: マップ形式 (ruby_ast)                                  │
│  #{type => assign, location => #location{...},              │
│    var => #{...}, expr => #{...}}                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              ruby_ast.erl (AST操作層) 🆕                     │
│  ・AST生成・検査・変換                                        │
│  ・AST走査・最適化                                            │
│  ・AST出力（S式、JSON、Pretty Print）                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│            ruby_evaluator.erl (評価器)                       │
│  ・ASTを走査して実行                                          │
│  ・Tree-walking interpreter                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                   実行結果 (10)
```

## Phase 1: 基盤構築

### Step 1.1: ruby.hrlの拡張

`lib/ruby/src/ruby.hrl`に位置情報とメタデータの定義を追加します。

```erlang
%% lib/ruby/src/ruby.hrl

%% @doc Ruby tokenizer state record
%% Used to maintain tokenizer state including warnings during lexical analysis
-record(ruby_tokenizer, {
  warnings = [] :: list()  % List of warnings accumulated during tokenization
}).

%% ========================================
%% AST関連の型定義 (🆕)
%% ========================================

%% @doc 位置情報レコード
%% ソースコード内の位置を表現します
-record(location, {
    line = 1 :: pos_integer(),              % 行番号（1始まり）
    column = 1 :: pos_integer(),            % カラム位置（1始まり）
    start_offset = 0 :: non_neg_integer(),  % ファイル先頭からのバイトオフセット
    end_offset = 0 :: non_neg_integer(),    % 終了位置のバイトオフセット
    file = undefined :: binary() | undefined % ファイル名（オプション）
}).

%% @doc コメント情報
-record(comment, {
    text :: binary(),           % コメントテキスト
    location :: #location{},    % 位置情報
    type :: line | block        % コメント種別
}).

%% @doc メタデータ型定義
-type metadata() :: #{
    comments => [#comment{}],   % 関連するコメント
    source => binary(),         % 元のソーステキスト
    annotations => map()        % 任意のアノテーション
}.

%% @doc ASTノードの基本型
-type ast_node() :: #{
    type := atom(),
    location := #location{},
    metadata => metadata()
}.

%% @doc 個別のノード型定義
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

-type boolean_node() :: #{
    type := boolean,
    location := #location{},
    value := boolean(),
    metadata => metadata()
}.

-type nil_node() :: #{
    type := nil,
    location := #location{},
    metadata => metadata()
}.

-type var_node() :: #{
    type := var,
    location := #location{},
    name := atom(),
    metadata => metadata()
}.

-type binary_op_node() :: #{
    type := binary_op,
    location := #location{},
    op := atom(),
    left := ast_node(),
    right := ast_node(),
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

### Step 1.2: ruby_astモジュールのスケルトン作成

`lib/ruby/src/ruby_ast.erl`を作成します。

```erlang
%% @doc Ruby AST（抽象構文木）操作モジュール
%%
%% このモジュールはRubyの抽象構文木（AST）を生成、検査、変換するための
%% 統一されたAPIを提供します。
%%
%% 主な機能：
%% - ASTノードの生成（new_*/2, new_*/3）
%% - ASTノードの検査（is_*/1, get_*/1）
%% - ASTの走査（walk/2, map/2, fold/3）
%% - ASTの変換（constant_fold/1, optimize/1）
%% - ASTの出力（to_sexp/1, to_json/1, pretty_print/1）

-module(ruby_ast).
-include("ruby.hrl").

%% ============================================================================
%% エクスポート
%% ============================================================================

%% ノード作成API
-export([
    new_integer/2, new_integer/3,
    new_string/2, new_string/3,
    new_boolean/2, new_boolean/3,
    new_nil/1, new_nil/2,
    new_var/2, new_var/3,
    new_binary_op/4, new_binary_op/5,
    new_assign/3, new_assign/4
]).

%% ノード検査API
-export([
    is_literal/1,
    is_expression/1,
    is_statement/1,
    get_type/1,
    get_location/1,
    get_value/1,
    get_name/1,
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

%% AST出力API
-export([
    to_sexp/1,
    to_json/1,
    pretty_print/1,
    pretty_print/2
]).

%% 型定義
-type ast_node() :: map().
-type walk_fun() :: fun((ast_node()) -> ast_node()).
-type fold_fun() :: fun((ast_node(), term()) -> term()).

%% ============================================================================
%% ノード作成API
%% ============================================================================

%% @doc 整数ノードを作成（メタデータなし）
-spec new_integer(integer(), #location{}) -> integer_node().
new_integer(Value, Location) ->
    new_integer(Value, Location, #{}).

%% @doc 整数ノードを作成（メタデータあり）
-spec new_integer(integer(), #location{}, metadata()) -> integer_node().
new_integer(Value, Location, Metadata) when is_integer(Value), is_record(Location, location) ->
    #{
        type => integer,
        location => Location,
        value => Value,
        metadata => Metadata
    }.

%% @doc 文字列ノードを作成（メタデータなし）
-spec new_string(binary() | string(), #location{}) -> string_node().
new_string(Value, Location) ->
    new_string(Value, Location, #{}).

%% @doc 文字列ノードを作成（メタデータあり）
-spec new_string(binary() | string(), #location{}, metadata()) -> string_node().
new_string(Value, Location, Metadata) when is_record(Location, location) ->
    BinValue = if
        is_binary(Value) -> Value;
        is_list(Value) -> list_to_binary(Value)
    end,
    #{
        type => string,
        location => Location,
        value => BinValue,
        metadata => Metadata
    }.

%% @doc 真偽値ノードを作成（メタデータなし）
-spec new_boolean(boolean(), #location{}) -> boolean_node().
new_boolean(Value, Location) ->
    new_boolean(Value, Location, #{}).

%% @doc 真偽値ノードを作成（メタデータあり）
-spec new_boolean(boolean(), #location{}, metadata()) -> boolean_node().
new_boolean(Value, Location, Metadata) when is_boolean(Value), is_record(Location, location) ->
    #{
        type => boolean,
        location => Location,
        value => Value,
        metadata => Metadata
    }.

%% @doc nilノードを作成（メタデータなし）
-spec new_nil(#location{}) -> nil_node().
new_nil(Location) ->
    new_nil(Location, #{}).

%% @doc nilノードを作成（メタデータあり）
-spec new_nil(#location{}, metadata()) -> nil_node().
new_nil(Location, Metadata) when is_record(Location, location) ->
    #{
        type => nil,
        location => Location,
        metadata => Metadata
    }.

%% @doc 変数ノードを作成（メタデータなし）
-spec new_var(atom(), #location{}) -> var_node().
new_var(Name, Location) ->
    new_var(Name, Location, #{}).

%% @doc 変数ノードを作成（メタデータあり）
-spec new_var(atom(), #location{}, metadata()) -> var_node().
new_var(Name, Location, Metadata) when is_atom(Name), is_record(Location, location) ->
    #{
        type => var,
        location => Location,
        name => Name,
        metadata => Metadata
    }.

%% @doc 二項演算ノードを作成（メタデータなし）
-spec new_binary_op(atom(), ast_node(), ast_node(), #location{}) -> binary_op_node().
new_binary_op(Op, Left, Right, Location) ->
    new_binary_op(Op, Left, Right, Location, #{}).

%% @doc 二項演算ノードを作成（メタデータあり）
-spec new_binary_op(atom(), ast_node(), ast_node(), #location{}, metadata()) -> binary_op_node().
new_binary_op(Op, Left, Right, Location, Metadata)
        when is_atom(Op), is_map(Left), is_map(Right), is_record(Location, location) ->
    #{
        type => binary_op,
        location => Location,
        op => Op,
        left => Left,
        right => Right,
        metadata => Metadata
    }.

%% @doc 代入ノードを作成（メタデータなし）
-spec new_assign(var_node(), ast_node(), #location{}) -> assign_node().
new_assign(Var, Expr, Location) ->
    new_assign(Var, Expr, Location, #{}).

%% @doc 代入ノードを作成（メタデータあり）
-spec new_assign(var_node(), ast_node(), #location{}, metadata()) -> assign_node().
new_assign(Var, Expr, Location, Metadata)
        when is_map(Var), is_map(Expr), is_record(Location, location) ->
    #{
        type => assign,
        location => Location,
        var => Var,
        expr => Expr,
        metadata => Metadata
    }.

%% ============================================================================
%% ノード検査API
%% ============================================================================

%% @doc ノードがリテラルかどうかを判定
-spec is_literal(ast_node()) -> boolean().
is_literal(#{type := Type}) ->
    lists:member(Type, [integer, string, boolean, nil, symbol]).

%% @doc ノードが式かどうかを判定
-spec is_expression(ast_node()) -> boolean().
is_expression(#{type := Type}) ->
    lists:member(Type, [integer, string, boolean, nil, symbol, var, identifier,
                        binary_op, unary_op, call, block]).

%% @doc ノードが文かどうかを判定
-spec is_statement(ast_node()) -> boolean().
is_statement(#{type := Type}) ->
    lists:member(Type, [assign, method_def, class_def, if_stmt, while_stmt,
                        until_stmt, return, break, next]).

%% @doc ノードの型を取得
-spec get_type(ast_node()) -> atom().
get_type(#{type := Type}) ->
    Type.

%% @doc ノードの位置情報を取得
-spec get_location(ast_node()) -> #location{}.
get_location(#{location := Location}) ->
    Location.

%% @doc ノードの値を取得（リテラルノード用）
-spec get_value(ast_node()) -> term().
get_value(#{value := Value}) ->
    Value;
get_value(_) ->
    undefined.

%% @doc ノードの名前を取得（変数・識別子ノード用）
-spec get_name(ast_node()) -> atom() | undefined.
get_name(#{name := Name}) ->
    Name;
get_name(_) ->
    undefined.

%% @doc ノードの子ノードを取得
-spec get_children(ast_node()) -> [ast_node()].
get_children(#{type := binary_op, left := Left, right := Right}) ->
    [Left, Right];
get_children(#{type := assign, var := Var, expr := Expr}) ->
    [Var, Expr];
get_children(_) ->
    [].

%% ============================================================================
%% ノード操作API
%% ============================================================================

%% @doc ノードの位置情報を更新
-spec update_location(ast_node(), #location{}) -> ast_node().
update_location(Node, Location) when is_map(Node), is_record(Location, location) ->
    Node#{location := Location}.

%% @doc メタデータを設定
-spec set_metadata(ast_node(), atom(), term()) -> ast_node().
set_metadata(Node, Key, Value) when is_map(Node), is_atom(Key) ->
    Metadata = maps:get(metadata, Node, #{}),
    Node#{metadata => Metadata#{Key => Value}}.

%% @doc メタデータを取得
-spec get_metadata(ast_node(), atom()) -> term() | undefined.
get_metadata(Node, Key) when is_map(Node), is_atom(Key) ->
    Metadata = maps:get(metadata, Node, #{}),
    maps:get(Key, Metadata, undefined).

%% @doc メタデータマップ全体を設定
-spec with_metadata(ast_node(), metadata()) -> ast_node().
with_metadata(Node, Metadata) when is_map(Node), is_map(Metadata) ->
    Node#{metadata => Metadata}.

%% ============================================================================
%% AST走査API（将来実装）
%% ============================================================================

walk(_Fun, _Node) ->
    erlang:error(not_implemented).

walk(_Fun, _Node, _Opts) ->
    erlang:error(not_implemented).

map(_Fun, _Node) ->
    erlang:error(not_implemented).

fold(_Fun, _Acc, _Node) ->
    erlang:error(not_implemented).

filter(_Pred, _Node) ->
    erlang:error(not_implemented).

%% ============================================================================
%% AST出力API（将来実装）
%% ============================================================================

to_sexp(_Node) ->
    erlang:error(not_implemented).

to_json(_Node) ->
    erlang:error(not_implemented).

pretty_print(_Node) ->
    erlang:error(not_implemented).

pretty_print(_Node, _Opts) ->
    erlang:error(not_implemented).
```

### Step 1.3: テストファイルの作成

`lib/ruby/test/erlang/test_ruby_ast.erl`を作成します。

```erlang
%% @doc ruby_astモジュールのテスト

-module(test_ruby_ast).
-include("../../src/ruby.hrl").
-export([test/0]).

test() ->
    io:format("~n=== ruby_ast tests ===~n"),
    test_integer_node(),
    test_string_node(),
    test_boolean_node(),
    test_nil_node(),
    test_var_node(),
    test_binary_op_node(),
    test_assign_node(),
    test_node_inspection(),
    test_node_manipulation(),
    io:format("All ruby_ast tests passed!~n"),
    ok.

test_integer_node() ->
    io:format("  Testing integer node creation... "),
    Loc = #location{line = 1, column = 1},
    Node = ruby_ast:new_integer(42, Loc),

    integer = ruby_ast:get_type(Node),
    42 = ruby_ast:get_value(Node),
    Loc = ruby_ast:get_location(Node),

    io:format("OK~n"),
    ok.

test_string_node() ->
    io:format("  Testing string node creation... "),
    Loc = #location{line = 1, column = 1},
    Node = ruby_ast:new_string("hello", Loc),

    string = ruby_ast:get_type(Node),
    <<"hello">> = ruby_ast:get_value(Node),

    io:format("OK~n"),
    ok.

test_boolean_node() ->
    io:format("  Testing boolean node creation... "),
    Loc = #location{line = 1, column = 1},
    NodeTrue = ruby_ast:new_boolean(true, Loc),
    NodeFalse = ruby_ast:new_boolean(false, Loc),

    boolean = ruby_ast:get_type(NodeTrue),
    true = ruby_ast:get_value(NodeTrue),
    false = ruby_ast:get_value(NodeFalse),

    io:format("OK~n"),
    ok.

test_nil_node() ->
    io:format("  Testing nil node creation... "),
    Loc = #location{line = 1, column = 1},
    Node = ruby_ast:new_nil(Loc),

    nil = ruby_ast:get_type(Node),

    io:format("OK~n"),
    ok.

test_var_node() ->
    io:format("  Testing var node creation... "),
    Loc = #location{line = 1, column = 1},
    Node = ruby_ast:new_var(x, Loc),

    var = ruby_ast:get_type(Node),
    x = ruby_ast:get_name(Node),

    io:format("OK~n"),
    ok.

test_binary_op_node() ->
    io:format("  Testing binary_op node creation... "),
    Loc = #location{line = 1, column = 1},
    Left = ruby_ast:new_integer(1, Loc),
    Right = ruby_ast:new_integer(2, Loc),
    Node = ruby_ast:new_binary_op('+', Left, Right, Loc),

    binary_op = ruby_ast:get_type(Node),
    [Left, Right] = ruby_ast:get_children(Node),

    io:format("OK~n"),
    ok.

test_assign_node() ->
    io:format("  Testing assign node creation... "),
    Loc = #location{line = 1, column = 1},
    Var = ruby_ast:new_var(x, Loc),
    Expr = ruby_ast:new_integer(42, Loc),
    Node = ruby_ast:new_assign(Var, Expr, Loc),

    assign = ruby_ast:get_type(Node),
    [Var, Expr] = ruby_ast:get_children(Node),

    io:format("OK~n"),
    ok.

test_node_inspection() ->
    io:format("  Testing node inspection functions... "),
    Loc = #location{line = 1, column = 1},

    %% リテラルノード
    IntNode = ruby_ast:new_integer(42, Loc),
    true = ruby_ast:is_literal(IntNode),
    true = ruby_ast:is_expression(IntNode),
    false = ruby_ast:is_statement(IntNode),

    %% 代入ノード
    Var = ruby_ast:new_var(x, Loc),
    AssignNode = ruby_ast:new_assign(Var, IntNode, Loc),
    false = ruby_ast:is_literal(AssignNode),
    false = ruby_ast:is_expression(AssignNode),
    true = ruby_ast:is_statement(AssignNode),

    io:format("OK~n"),
    ok.

test_node_manipulation() ->
    io:format("  Testing node manipulation functions... "),
    Loc1 = #location{line = 1, column = 1},
    Loc2 = #location{line = 2, column = 5},

    Node = ruby_ast:new_integer(42, Loc1),

    %% 位置情報の更新
    Node2 = ruby_ast:update_location(Node, Loc2),
    Loc2 = ruby_ast:get_location(Node2),

    %% メタデータの設定・取得
    Node3 = ruby_ast:set_metadata(Node2, foo, bar),
    bar = ruby_ast:get_metadata(Node3, foo),
    undefined = ruby_ast:get_metadata(Node3, baz),

    io:format("OK~n"),
    ok.
```

### Step 1.4: Emakefileの更新

`lib/ruby/Emakefile`にruby_astを追加：

```erlang
{'src/*', [
    debug_info,
    {i, "src"},
    {outdir, "ebin"},
    {d, 'DEBUG'},
    warn_unused_vars,
    warn_export_all,
    warn_shadow_vars,
    warn_unused_import,
    warn_unused_function,
    warn_bif_clash,
    warn_unused_record,
    warn_deprecated_function,
    warn_obsolete_guard,
    warn_exported_vars,
    warn_missing_spec,
    warn_untyped_record
]}.
```

### Step 1.5: ビルドとテスト

```bash
# ビルド
make compile_ruby

# テスト実行
erl -pa lib/ruby/ebin
```

```erlang
%% Erlangシェルで
test_ruby_ast:test().
```

## Phase 2: パーサー統合

（詳細は省略。パーサーを徐々に新しいAST形式に対応させる）

## Phase 3: 評価器更新

（詳細は省略。評価器を新しいAST形式に対応させる）

## まとめ

この実装ガイドに従って、段階的にbrubyのAST機能を強化していきます。各Phaseは独立してテスト可能であり、既存の機能を壊すことなく新機能を追加できます。
