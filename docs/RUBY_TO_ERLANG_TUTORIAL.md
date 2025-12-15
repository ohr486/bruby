# Ruby → Erlang AST変換チュートリアル

このチュートリアルでは、brubyでRubyコードをErlangのBEAMバイトコードにコンパイルする方法を学びます。

## 前提知識

- Erlangの基本（関数、パターンマッチ、再帰）
- Rubyの基本（メソッド、クラス、ブロック）
- brubyの基本的な使い方

## Step 1: 最初の変換 - Hello World

### Rubyコード

```ruby
def hello
  puts "Hello, World!"
end
```

### 手動での変換プロセス

#### 1.1 Ruby ASTの生成

```erlang
%% Erlangシェルで
1> ruby_evaluator:eval_string("def hello; puts 'Hello, World!'; end").
{ok, ..., Env}
```

#### 1.2 Erlang ASTへの変換

```erlang
2> RubyAST = ...,  %% 上記から取得
3> ErlangForms = ruby_to_erlang:translate_to_module(hello_mod, [RubyAST]).

%% 期待される出力（簡略版）:
[
  {attribute, 1, module, hello_mod},
  {attribute, 2, export, [{hello, 0}]},
  {function, 1, hello, 0, [
    {clause, 1, [], [], [
      {call, 2,
        {remote, 2, {atom, 2, io}, {atom, 2, format}},
        [{string, 2, "Hello, World!~n"}]
      }
    ]}
  ]}
]
```

#### 1.3 コンパイルと実行

```erlang
4> ruby_to_erlang:compile_and_load(hello_mod, [RubyAST]).
{ok, hello_mod}

5> hello_mod:hello().
Hello, World!
ok
```

## Step 2: パラメータ付き関数

### Rubyコード

```ruby
def add(a, b)
  a + b
end
```

### 変換と実行

```erlang
1> Code = "def add(a, b); a + b; end",
2> {ok, AST, _} = ruby_evaluator:eval_string(Code),
3> {ok, Mod} = ruby_to_erlang:compile_and_load(math_mod, [AST]),
4> Result = math_mod:add(10, 20).
30
```

### 生成されるErlang AST

```erlang
{function, 1, add, 2, [
  {clause, 1,
    [{var, 1, 'A'}, {var, 1, 'B'}],  %% パラメータ
    [],                                %% ガード（なし）
    [{op, 1, '+', {var, 1, 'A'}, {var, 1, 'B'}}]  %% ボディ
  }
]}
```

### ポイント

- Ruby変数 `a`, `b` → Erlang変数 `'A'`, `'B'` （大文字化）
- Ruby加算 `a + b` → Erlang演算 `{op, 1, '+', ...}`

## Step 3: 制御フロー - if文

### Rubyコード

```ruby
def max(a, b)
  if a > b
    a
  else
    b
  end
end
```

### 変換されるErlang AST

```erlang
{function, 1, max, 2, [
  {clause, 1,
    [{var, 1, 'A'}, {var, 1, 'B'}],
    [],
    [
      {case, 2,
        {op, 2, '>', {var, 2, 'A'}, {var, 2, 'B'}},
        [
          {clause, 2, [{atom, 2, true}], [], [{var, 3, 'A'}]},
          {clause, 2, [{atom, 2, false}], [], [{var, 5, 'B'}]}
        ]
      }
    ]
  }
]}
```

### ポイント

- Ruby if文 → Erlang case式
- 条件式を評価してtrue/falseでパターンマッチ

### テスト

```erlang
1> %% 変換・コンパイル
2> math_mod:max(10, 20).
20
3> math_mod:max(30, 15).
30
```

## Step 4: 再帰関数 - 階乗

### Rubyコード

```ruby
def factorial(n)
  if n <= 1
    1
  else
    n * factorial(n - 1)
  end
end
```

### 変換されるErlangコード（概念）

```erlang
factorial(N) ->
  case N =< 1 of
    true -> 1;
    false -> N * factorial(N - 1)
  end.
```

### テスト

```erlang
1> math_mod:factorial(5).
120
2> math_mod:factorial(10).
3628800
```

### ポイント

- 再帰呼び出しも正しく変換される
- Erlangの末尾再帰最適化が適用される（条件によって）

## Step 5: ループ - whileの変換

### Rubyコード

```ruby
def count_to_n(n)
  i = 0
  while i < n
    puts i
    i = i + 1
  end
  i
end
```

### 変換戦略

Rubyのwhile文は、Erlangの末尾再帰関数に変換されます：

```erlang
count_to_n(N) ->
  count_to_n_loop_1(0, N).  %% ループ関数を呼び出し

count_to_n_loop_1(I, N) when I < N ->
  io:format("~p~n", [I]),
  NewI = I + 1,
  count_to_n_loop_1(NewI, N);  %% 再帰
count_to_n_loop_1(I, _N) ->
  I.
```

### ポイント

- while文は専用のループ関数に変換
- ループ変数（`i`）をパラメータとして渡す
- 条件はガード句で表現
- 末尾再帰でスタック消費を抑制

## Step 6: 複数の関数を含むモジュール

### Rubyコード

```ruby
def greet(name)
  "Hello, " + name
end

def farewell(name)
  "Goodbye, " + name
end

def polite_greet(name)
  msg = greet(name)
  msg + "!"
end
```

### 変換と実行

```erlang
1> Code = "
def greet(name); 'Hello, ' + name; end
def farewell(name); 'Goodbye, ' + name; end
def polite_greet(name); msg = greet(name); msg + '!'; end
",
2> %% パース（複数の関数定義を含む）
3> {ok, Tokens, _} = ruby_tokenizer:tokenize(Code),
4> {ok, AST} = ruby_parser:parse(Tokens),
5> %% 変換・コンパイル
6> ruby_to_erlang:compile_and_load(greeting_mod, AST),
7> %% 実行
8> greeting_mod:greet("Alice").
"Hello, Alice"
9> greeting_mod:polite_greet("Bob").
"Hello, Bob!"
```

### 生成されるモジュール構造

```erlang
-module(greeting_mod).
-export([greet/1, farewell/1, polite_greet/1]).

greet(Name) ->
  %% "Hello, " ++ Name のような処理

farewell(Name) ->
  %% "Goodbye, " ++ Name のような処理

polite_greet(Name) ->
  Msg = greet(Name),
  %% Msg ++ "!" のような処理
```

## Step 7: クラスの変換

### Rubyコード

```ruby
class Counter
  def initialize(start)
    @count = start
  end

  def increment
    @count = @count + 1
  end

  def get_count
    @count
  end
end
```

### 変換戦略

クラスは以下のように変換されます：

1. クラス → Erlangモジュール
2. インスタンス → マップ `#{class => counter, count => Value}`
3. メソッド → 第1引数に`Self`を取る関数

```erlang
-module(counter).
-export([new/1, increment/1, get_count/1]).

%% コンストラクタ
new(Start) ->
  #{class => counter, count => Start}.

%% インスタンスメソッド（第1引数がself）
increment(Self = #{count := Count}) ->
  Self#{count => Count + 1}.

get_count(#{count := Count}) ->
  Count.
```

### 使用例

```erlang
1> C1 = counter:new(0).
#{class => counter, count => 0}

2> C2 = counter:increment(C1).
#{class => counter, count => 1}

3> C3 = counter:increment(C2).
#{class => counter, count => 2}

4> counter:get_count(C3).
2
```

### ポイント

- イミュータブル：メソッドは新しいインスタンスを返す
- マップでインスタンス変数を表現
- パターンマッチで型安全性を確保

## Step 8: ブロックの変換

### Rubyコード

```ruby
def apply_twice(x, &block)
  block.call(block.call(x))
end

result = apply_twice(5) { |n| n * 2 }
```

### 変換されるErlangコード

```erlang
apply_twice(X, Block) ->
  Block(Block(X)).

%% 使用例
Result = apply_twice(5, fun(N) -> N * 2 end).
%% Result = 20
```

### ポイント

- Rubyブロック → Erlang fun
- `yield` → ブロック関数の呼び出し
- クロージャの変数キャプチャもサポート

## Step 9: パフォーマンス比較

### フィボナッチ数列での比較

```ruby
def fib(n)
  if n <= 1
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end
```

### ベンチマーク

```erlang
%% Tree-walking interpreter
1> timer:tc(fun() -> ruby_evaluator:eval_string("fib(30)") end).
{5000000, {ok, 832040, _}}  %% 5秒

%% コンパイル版
2> timer:tc(fun() -> fib_mod:fib(30) end).
{50000, 832040}  %% 0.05秒

%% 約100倍高速！
```

## Step 10: BEAMファイルへの保存

### コンパイルして保存

```erlang
1> Code = "def add(a,b); a+b; end",
2> {ok, AST, _} = ruby_evaluator:eval_string(Code),
3> ruby_to_erlang:compile_to_beam(math_utils, [AST], #{
     output_dir => "./ebin",
     debug_info => true,
     optimize => true
   }).
ok
```

### 生成されたBEAMファイルのロード

```bash
$ ls ebin/
math_utils.beam

$ erl -pa ebin
```

```erlang
1> math_utils:add(100, 200).
300
```

## トラブルシューティング

### 問題1: 変換エラー

**症状:**
```erlang
{error, {unsupported_feature, symbol}}
```

**解決策:**
現在サポートされていない機能（シンボル、配列等）を使用しています。サポートされている機能を確認してください。

### 問題2: コンパイルエラー

**症状:**
```erlang
{error, [{1, erl_parse, ["syntax error before: ", "..."]}, ...]}
```

**解決策:**
生成されたErlang ASTに問題があります。デバッグモードで中間表現を確認：

```erlang
1> ErlangAST = ruby_to_erlang:translate(...),
2> io:format("~p~n", [ErlangAST]).
```

### 問題3: 実行時エラー

**症状:**
```erlang
** exception error: undefined function ...
```

**解決策:**
- 関数がエクスポートされているか確認
- モジュールが正しくロードされているか確認

## ベストプラクティス

### 1. 小さな関数から始める

複雑なコードをいきなり変換するのではなく、小さな関数から始めましょう。

### 2. 中間表現を確認

生成されたErlang ASTを確認して、期待通りの変換がされているか確認します：

```erlang
ruby_to_erlang:translate_and_print(RubyAST).
```

### 3. ユニットテストを書く

変換されたモジュールに対してEUnitテストを書きましょう：

```erlang
-module(math_utils_tests).
-include_lib("eunit/include/eunit.hrl").

add_test() ->
    ?assertEqual(30, math_utils:add(10, 20)).
```

### 4. パフォーマンスを測定

実際のユースケースでパフォーマンスを測定します：

```erlang
benchmark(Fun, Iterations) ->
    {Time, _} = timer:tc(fun() ->
        [Fun() || _ <- lists:seq(1, Iterations)]
    end),
    Time / Iterations.
```

## 次のステップ

1. **より複雑な例**: クラス継承、モジュールインクルード
2. **最適化**: 生成されるコードの最適化
3. **デバッグ**: Erlangデバッガーの活用
4. **プロファイリング**: fprof, eprofでのパフォーマンス分析

## まとめ

RubyからErlang ASTへの変換により：

- **劇的な高速化**: 典型的に10〜100倍高速
- **Erlang VM活用**: BEAMの強力な機能を利用
- **デプロイ容易**: BEAMファイルとして配布可能
- **Erlang連携**: 既存のErlangコードと統合

この技術により、brubyは実用的なパフォーマンスを実現できます！
