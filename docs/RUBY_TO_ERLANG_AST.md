# RubyのASTをErlangのASTに変換する設計

## 概要

このドキュメントは、brubyにおけるRuby ASTからErlang Abstract Format（Erlang AST）への変換機能の設計を記述します。この変換により、RubyコードをErlangのBEAMバイトコードにコンパイルし、Erlang VMの最適化の恩恵を受けることができます。

## モチベーション

### 現在のアーキテクチャ（Tree-walking Interpreter）

```
Rubyコード
  ↓ tokenize
トークン列
  ↓ parse
Ruby AST
  ↓ eval (直接走査)
実行結果
```

**問題点:**
- 毎回ASTを走査するため遅い
- 最適化の余地が少ない
- Erlang VMの最適化を活用できない

### 新しいアーキテクチャ（Compile to BEAM）

```
Rubyコード
  ↓ tokenize
トークン列
  ↓ parse
Ruby AST
  ↓ ruby_to_erlang (新機能)
Erlang AST (Abstract Format)
  ↓ compile:forms/2
BEAMバイトコード
  ↓ BEAM VM
実行結果（高速）
```

**利点:**
- **高速実行**: コンパイルされたコードはTree-walkingより圧倒的に速い
- **最適化**: Erlangコンパイラの最適化を活用
- **Erlang連携**: 生成されたモジュールは通常のErlangモジュールとして扱える
- **デバッグ**: Erlangのデバッガーやプロファイラーが使える
- **永続化**: コンパイル済みのBEAMファイルを保存・再利用可能

## Erlang Abstract Formatの概要

Erlangのコンパイラは、ソースコードをAbstract Formatと呼ばれる内部表現に変換します。これはタプルベースのAST表現です。

### 基本構造

```erlang
%% 整数リテラル
{integer, Line, Value}

%% 変数（先頭大文字）
{var, Line, 'X'}

%% アトム
{atom, Line, foo}

%% 文字列
{string, Line, "hello"}

%% 代入（パターンマッチ）
{match, Line, Pattern, Expression}

%% 二項演算
{op, Line, '+', Left, Right}

%% 関数呼び出し
{call, Line, {atom, Line, FunName}, Args}

%% case式
{case, Line, Expression, Clauses}

%% 関数定義
{function, Line, Name, Arity, Clauses}

%% 関数句（clause）
{clause, Line, Patterns, Guards, Body}

%% モジュール属性
{attribute, Line, module, ModuleName}
{attribute, Line, export, [{FunName, Arity}]}
```

### 完全な例

**Erlangコード:**
```erlang
-module(example).
-export([add/2]).

add(X, Y) ->
    X + Y.
```

**Abstract Format:**
```erlang
[
  {attribute, 1, module, example},
  {attribute, 2, export, [{add, 2}]},
  {function, 4, add, 2, [
    {clause, 4,
      [{var, 4, 'X'}, {var, 4, 'Y'}],
      [],
      [{op, 5, '+', {var, 5, 'X'}, {var, 5, 'Y'}}]
    }
  ]}
]
```

## Ruby AST → Erlang AST 変換規則

### 1. リテラル

#### 整数

**Ruby AST:**
```erlang
#{type => integer, location => Loc, value => 42}
```

**Erlang AST:**
```erlang
{integer, Line, 42}
```

**変換関数:**
```erlang
translate_integer(#{value := Value, location := Loc}) ->
    {integer, Loc#location.line, Value}.
```

#### 文字列

**Ruby AST:**
```erlang
#{type => string, location => Loc, value => <<"hello">>}
```

**Erlang AST:**
```erlang
{string, Line, "hello"}
```

**変換関数:**
```erlang
translate_string(#{value := Value, location := Loc}) ->
    Str = if
        is_binary(Value) -> binary_to_list(Value);
        is_list(Value) -> Value
    end,
    {string, Loc#location.line, Str}.
```

#### 真偽値

**Ruby AST:**
```erlang
#{type => boolean, location => Loc, value => true}
```

**Erlang AST:**
```erlang
{atom, Line, true}
```

**変換関数:**
```erlang
translate_boolean(#{value := Value, location := Loc}) ->
    {atom, Loc#location.line, Value}.
```

#### nil

**Ruby AST:**
```erlang
#{type => nil, location => Loc}
```

**Erlang AST:**
```erlang
{atom, Line, nil}
```

### 2. 変数

**重要な変換規則:**
- Rubyの変数名（小文字始まり）→ Erlangの変数名（大文字始まり）
- 例: `x` → `'X'`, `my_var` → `'My_var'`

**Ruby AST:**
```erlang
#{type => var, location => Loc, name => x}
```

**Erlang AST:**
```erlang
{var, Line, 'X'}
```

**変換関数:**
```erlang
translate_var(#{name := Name, location := Loc}) ->
    %% Ruby変数名をErlang変数名に変換（先頭大文字化）
    ErlangVarName = ruby_var_to_erlang_var(Name),
    {var, Loc#location.line, ErlangVarName}.

ruby_var_to_erlang_var(Name) when is_atom(Name) ->
    NameStr = atom_to_list(Name),
    [First | Rest] = NameStr,
    CapitalFirst = string:to_upper([First]),
    list_to_atom(CapitalFirst ++ Rest).
```

### 3. 代入

Rubyの代入はErlangのパターンマッチ（match）に変換されます。

**Rubyコード:**
```ruby
x = 10
```

**Ruby AST:**
```erlang
#{type => assign,
  location => Loc,
  var => #{type => var, name => x},
  expr => #{type => integer, value => 10}}
```

**Erlang AST:**
```erlang
{match, Line,
  {var, Line, 'X'},
  {integer, Line, 10}}
```

**変換関数:**
```erlang
translate_assign(#{var := Var, expr := Expr, location := Loc}) ->
    VarNode = translate_node(Var),
    ExprNode = translate_node(Expr),
    {match, Loc#location.line, VarNode, ExprNode}.
```

### 4. 二項演算

**Rubyコード:**
```ruby
x + y
```

**Ruby AST:**
```erlang
#{type => binary_op,
  location => Loc,
  op => '+',
  left => #{type => identifier, name => x},
  right => #{type => identifier, name => y}}
```

**Erlang AST:**
```erlang
{op, Line, '+',
  {var, Line, 'X'},
  {var, Line, 'Y'}}
```

**変換関数:**
```erlang
translate_binary_op(#{op := Op, left := Left, right := Right, location := Loc}) ->
    LeftNode = translate_node(Left),
    RightNode = translate_node(Right),
    ErlangOp = ruby_op_to_erlang_op(Op),
    {op, Loc#location.line, ErlangOp, LeftNode, RightNode}.

ruby_op_to_erlang_op('+') -> '+';
ruby_op_to_erlang_op('-') -> '-';
ruby_op_to_erlang_op('*') -> '*';
ruby_op_to_erlang_op('/') -> '/';
ruby_op_to_erlang_op('%') -> 'rem';
ruby_op_to_erlang_op('==') -> '==';
ruby_op_to_erlang_op('!=') -> '/=';
ruby_op_to_erlang_op('<') -> '<';
ruby_op_to_erlang_op('>') -> '>';
ruby_op_to_erlang_op('<=') -> '=<';
ruby_op_to_erlang_op('>=') -> '>=';
ruby_op_to_erlang_op('and') -> 'andalso';
ruby_op_to_erlang_op('or') -> 'orelse';
ruby_op_to_erlang_op('&&') -> 'andalso';
ruby_op_to_erlang_op('||') -> 'orelse'.
```

### 5. メソッド呼び出し

Rubyのメソッド呼び出しはErlangの関数呼び出しに変換されます。

**Rubyコード:**
```ruby
puts("Hello")
add(1, 2)
```

**Ruby AST:**
```erlang
#{type => call,
  location => Loc,
  name => puts,
  args => [#{type => string, value => <<"Hello">>}],
  block => nil}
```

**Erlang AST:**
```erlang
{call, Line,
  {atom, Line, puts},
  [{string, Line, "Hello"}]}
```

**変換関数:**
```erlang
translate_call(#{name := Name, args := Args, location := Loc}) ->
    %% 組み込み関数のマッピング（必要に応じて）
    ErlangFun = ruby_method_to_erlang_fun(Name),
    ArgsNodes = [translate_node(Arg) || Arg <- Args],
    {call, Loc#location.line, {atom, Loc#location.line, ErlangFun}, ArgsNodes}.

ruby_method_to_erlang_fun(puts) -> io:format;  % または専用のヘルパー関数
ruby_method_to_erlang_fun(Name) -> Name.
```

### 6. if文

Rubyのif文はErlangのcase式に変換されます。

**Rubyコード:**
```ruby
if x > 0
  puts "positive"
else
  puts "negative"
end
```

**Ruby AST:**
```erlang
#{type => if_stmt,
  condition => #{type => binary_op, op => '>', ...},
  then_stmts => [...],
  else_stmts => [...]}
```

**Erlang AST:**
```erlang
{case, Line, Condition, [
  {clause, Line, [{atom, Line, true}], [], ThenBody},
  {clause, Line, [{atom, Line, false}], [], ElseBody}
]}
```

**変換関数:**
```erlang
translate_if_stmt(#{condition := Cond, then_stmts := Then,
                     else_stmts := Else, location := Loc}) ->
    CondNode = translate_node(Cond),
    ThenBody = [translate_node(S) || S <- Then],
    ElseBody = [translate_node(S) || S <- Else],

    Line = Loc#location.line,
    {case, Line, CondNode, [
      {clause, Line, [{atom, Line, true}], [], ThenBody},
      {clause, Line, [{atom, Line, false}], [], ElseBody}
    ]}.
```

### 7. while文

Rubyのwhile文は末尾再帰関数に変換されます。

**Rubyコード:**
```ruby
while x < 10
  x = x + 1
end
```

**Erlangコード（概念）:**
```erlang
loop_1(X) when X < 10 ->
    NewX = X + 1,
    loop_1(NewX);
loop_1(X) ->
    X.
```

**変換戦略:**
1. 専用のループ関数を生成
2. ループ変数をパラメータとして渡す
3. 条件をガードとして使用
4. 末尾再帰で実装

### 8. メソッド定義

Rubyのメソッドは、Erlangの関数に変換されます。

**Rubyコード:**
```ruby
def add(a, b)
  a + b
end
```

**Ruby AST:**
```erlang
#{type => method_def,
  location => Loc,
  name => add,
  params => [
    #{type => param, name => a},
    #{type => param, name => b}
  ],
  body => [#{type => binary_op, op => '+', ...}]}
```

**Erlang AST:**
```erlang
{function, Line, add, 2, [
  {clause, Line,
    [{var, Line, 'A'}, {var, Line, 'B'}],
    [],
    [{op, Line, '+', {var, Line, 'A'}, {var, Line, 'B'}}]
  }
]}
```

**変換関数:**
```erlang
translate_method_def(#{name := Name, params := Params,
                        body := Body, location := Loc}) ->
    Line = Loc#location.line,
    Arity = length(Params),

    %% パラメータをErlang変数に変換
    ParamNodes = [translate_param(P) || P <- Params],

    %% ボディを変換
    BodyNodes = [translate_node(S) || S <- Body],

    %% 関数句を作成
    Clause = {clause, Line, ParamNodes, [], BodyNodes},

    {function, Line, Name, Arity, [Clause]}.

translate_param(#{type := param, name := Name, location := Loc}) ->
    {var, Loc#location.line, ruby_var_to_erlang_var(Name)}.
```

### 9. クラス定義

Rubyのクラスは、Erlangのモジュールに変換されます。

**Rubyコード:**
```ruby
class Person
  def initialize(name)
    @name = name
  end

  def greet
    puts "Hello, I'm #{@name}"
  end
end
```

**変換戦略:**
1. クラス → モジュール
2. インスタンス変数 → マップまたはレコード
3. メソッド → モジュール内の関数（第1引数にselfを渡す）
4. コンストラクタ（initialize）→ new/N関数

**Erlang AST（概念）:**
```erlang
-module(person).
-export([new/1, greet/1]).

new(Name) ->
    #{class => person, name => Name}.

greet(Self = #{name := Name}) ->
    io:format("Hello, I'm ~s~n", [Name]),
    Self.
```

### 10. ブロックとクロージャ

Rubyのブロックは、Erlangの無名関数（fun）に変換されます。

**Rubyコード:**
```ruby
[1, 2, 3].each { |x| puts x }
```

**Erlang AST:**
```erlang
{call, Line,
  {remote, Line, {atom, Line, lists}, {atom, Line, foreach}},
  [
    {'fun', Line, {clauses, [
      {clause, Line, [{var, Line, 'X'}], [], [
        {call, Line, {atom, Line, puts}, [{var, Line, 'X'}]}
      ]}
    ]}},
    {cons, Line, {integer, Line, 1},
      {cons, Line, {integer, Line, 2},
        {cons, Line, {integer, Line, 3}, {nil, Line}}}}
  ]
}
```

## ruby_to_erlangモジュールの設計

### モジュール構造

```erlang
-module(ruby_to_erlang).
-include("ruby.hrl").

%% 公開API
-export([
    translate/1,              % Ruby AST全体を変換
    translate_to_module/2,    % モジュールとして変換
    compile_and_load/2,       % 変換してコンパイル・ロード
    compile_to_beam/3         % 変換してBEAMファイルに保存
]).

%% 内部API（ノード変換）
-export([
    translate_node/1,
    translate_node/2
]).

%% 型定義
-type erlang_ast() :: term().
-type compile_options() :: #{
    output_dir => string(),
    debug_info => boolean(),
    optimize => boolean()
}.

%% ============================================================================
%% 公開API
%% ============================================================================

%% @doc Ruby ASTをErlang ASTに変換
-spec translate(ruby_ast:ast_node()) -> erlang_ast().
translate(RubyAST) ->
    translate_node(RubyAST, #{}).

%% @doc Ruby ASTをErlangモジュールとして変換
-spec translate_to_module(atom(), [ruby_ast:ast_node()]) -> [erlang_ast()].
translate_to_module(ModuleName, RubyStatements) ->
    %% モジュール属性
    ModuleAttr = {attribute, 1, module, ModuleName},

    %% 関数定義を抽出・変換
    Functions = extract_functions(RubyStatements),
    ExportList = [{Name, Arity} || {function, _, Name, Arity, _} <- Functions],
    ExportAttr = {attribute, 2, export, ExportList},

    %% Abstract Formを構築
    [ModuleAttr, ExportAttr | Functions].

%% @doc Ruby ASTを変換してコンパイル・ロード
-spec compile_and_load(atom(), [ruby_ast:ast_node()]) ->
    {ok, module()} | {error, term()}.
compile_and_load(ModuleName, RubyStatements) ->
    Forms = translate_to_module(ModuleName, RubyStatements),
    case compile:forms(Forms, [report, verbose]) of
        {ok, ModuleName, Binary} ->
            code:load_binary(ModuleName, atom_to_list(ModuleName) ++ ".erl", Binary),
            {ok, ModuleName};
        Error ->
            Error
    end.

%% @doc Ruby ASTを変換してBEAMファイルに保存
-spec compile_to_beam(atom(), [ruby_ast:ast_node()], compile_options()) ->
    ok | {error, term()}.
compile_to_beam(ModuleName, RubyStatements, Options) ->
    Forms = translate_to_module(ModuleName, RubyStatements),
    OutputDir = maps:get(output_dir, Options, "."),
    CompileOpts = [
        report,
        {outdir, OutputDir}
    ] ++ case maps:get(debug_info, Options, false) of
        true -> [debug_info];
        false -> []
    end,

    case compile:forms(Forms, CompileOpts) of
        {ok, ModuleName} ->
            ok;
        Error ->
            Error
    end.
```

## 実装例

### 簡単な例

**入力（Rubyコード）:**
```ruby
def add(a, b)
  a + b
end
```

**変換プロセス:**

```erlang
%% Step 1: Rubyコードをパース
{ok, RubyAST, _} = ruby_evaluator:eval_string("def add(a, b); a + b; end").

%% Step 2: Ruby AST → Erlang AST変換
ErlangForms = ruby_to_erlang:translate_to_module(example, [RubyAST]).

%% Step 3: コンパイル・ロード
{ok, example} = ruby_to_erlang:compile_and_load(example, [RubyAST]).

%% Step 4: 実行
30 = example:add(10, 20).
```

### 複雑な例

**入力（Rubyコード）:**
```ruby
def factorial(n)
  if n <= 1
    1
  else
    n * factorial(n - 1)
  end
end
```

**生成されるErlang AST（簡略版）:**
```erlang
{function, 1, factorial, 1, [
  {clause, 1, [{var, 1, 'N'}], [], [
    {case, 2,
      {op, 2, '=<', {var, 2, 'N'}, {integer, 2, 1}},
      [
        {clause, 2, [{atom, 2, true}], [], [{integer, 3, 1}]},
        {clause, 2, [{atom, 2, false}], [], [
          {op, 5, '*',
            {var, 5, 'N'},
            {call, 5,
              {atom, 5, factorial},
              [{op, 5, '-', {var, 5, 'N'}, {integer, 5, 1}}]
            }
          }
        ]}
      ]
    }
  ]}
]}
```

## 実装の課題と解決策

### 1. 変数スコープの違い

**課題:** Rubyは動的スコープをサポートするが、Erlangは静的スコープ

**解決策:**
- ローカル変数のみをサポート（初期実装）
- グローバル変数はプロセス辞書やETSで模倣

### 2. ミュータブル vs イミュータブル

**課題:** Rubyは変数の再代入が可能だが、Erlangは不可

**解決策:**
- 再代入は新しい変数名を生成（X, X1, X2, ...）
- SSA (Static Single Assignment) 形式に変換

### 3. クラスとオブジェクト

**課題:** Rubyは完全なOOP、Erlangは関数型

**解決策:**
- クラス → モジュール
- インスタンス → マップ `#{class => ClassName, ...fields...}`
- メソッド → 第1引数にselfを取る関数

### 4. 例外処理

**課題:** RubyのrescueとErlangのcatch/throwの違い

**解決策:**
- Ruby例外 → Erlangのthrow/catch
- エラークラス階層の模倣

### 5. 組み込みメソッド

**課題:** Rubyの組み込みメソッドをErlangで実装

**解決策:**
- ランタイムサポートモジュール（ruby_runtime.erl）を作成
- 頻繁に使用されるメソッドを実装
- 必要に応じてNIFで実装

## パフォーマンス最適化

### 1. インライン展開

簡単な関数はインライン展開して呼び出しオーバーヘッドを削減

### 2. 定数畳み込み

コンパイル時に計算可能な式を事前計算

### 3. 末尾再帰最適化

ループを末尾再帰に変換してスタック消費を削減

### 4. パターンマッチ最適化

Erlangコンパイラのパターンマッチ最適化を活用

## テスト戦略

### ユニットテスト

各変換関数を個別にテスト

```erlang
test_translate_integer() ->
    RubyNode = ruby_ast:new_integer(42, #location{line = 1}),
    {integer, 1, 42} = ruby_to_erlang:translate_node(RubyNode),
    ok.
```

### 統合テスト

完全なRubyプログラムを変換・実行してテスト

```erlang
test_full_program() ->
    Code = "def add(a,b); a+b; end",
    {ok, RubyAST, _} = ruby_evaluator:eval_string(Code),
    {ok, Mod} = ruby_to_erlang:compile_and_load(test_mod, [RubyAST]),
    30 = test_mod:add(10, 20),
    ok.
```

### ベンチマーク

Tree-walking vs コンパイル版のパフォーマンス比較

## まとめ

Ruby AST → Erlang AST変換により、brubyは以下のメリットを得られます：

1. **劇的な高速化**: コンパイルされたコードはインタープリタより遥かに速い
2. **Erlang VM最適化**: BEAMの強力な最適化を活用
3. **Erlang連携**: 生成されたモジュールは通常のErlangモジュール
4. **デバッグ容易性**: Erlangツールが使える
5. **将来性**: JITコンパイルやさらなる最適化の基盤

この変換機能は段階的に実装でき、既存のインタープリタと共存可能です。
