# bruby Evaluator (評価器)

brubyの評価器は、Rubyコードを実際に実行できます。

## アーキテクチャ

### 値の表現（ruby_value.erl）

brubyはRuby値をErlangのネイティブな型で効率的に表現します。`ruby_value.erl`モジュールは型チェック、型変換、等価性チェックなどの基本的な操作を提供します。

**Ruby値のErlang表現：**
- **整数値**: Erlangの整数型 (integer()) - 例: 42, -100, 0
- **浮動小数点数**: Erlangの浮動小数点型 (float()) - 例: 3.14, -0.5, 1.0e10
- **文字列**: Erlangの文字列リスト (string()) またはバイナリ (binary()) - 例: "hello", <<"world">>
- **シンボル**: Erlangのアトム (atom()) - 例: symbol, 'my_symbol'
- **真偽値**: Erlangのアトム true | false
- **nil**: Erlangのアトム nil
- **オブジェクト**: マップ形式 #{type => object, class => atom(), ...}

**主な機能：**
- **型チェック関数**: is_ruby_integer/1, is_ruby_string/1, is_ruby_nil/1など
- **型変換関数**: to_integer/1, to_float/1, to_string/1など
- **等価性チェック**: equal/2 (Rubyの==), eql/2 (Rubyのeql?), identical/2 (Rubyのequal?)

**使用例：**
```erlang
% 型チェック
true = ruby_value:is_ruby_integer(42),
true = ruby_value:is_ruby_string("hello"),

% 型変換
{ok, 42} = ruby_value:to_integer("42"),
{ok, "123"} = ruby_value:to_string(123),

% 等価性チェック
true = ruby_value:equal(42, 42.0),  % 数値は型を超えて等しい
false = ruby_value:eql(42, 42.0).   % 型が異なる
```

### スコープ管理（ruby_scope.erl）

brubyはスコープ管理を専用モジュール `ruby_scope.erl` で実装しています。スコープチェーンを使用して、変数の束縛と検索を効率的に行います。

**主な機能：**
- **スコープの生成**: トップレベルスコープまたは親スコープを持つ子スコープを作成
- **変数の束縛**: スコープ内で変数に値を束縛
- **変数の検索**: スコープチェーンを辿って変数を検索
- **スコープスタック**: 将来の拡張用にスコープスタックのpush/pop操作をサポート

**スコープチェーンの仕組み：**
```
ローカルスコープ (x=3)
    ↓ parent
中間スコープ (y=2)
    ↓ parent
グローバルスコープ (z=1)
    ↓ parent
   nil
```

変数検索は現在のスコープから開始し、見つからなければ親スコープを順に辿ります。これにより、Rubyのスコープルールを正確に実装しています。

### オブジェクトシステム（ruby_object_server.erl）

brubyは完全なオブジェクトシステムを実装しています。`ruby_object_server.erl`モジュールは、Rubyのオブジェクト指向プログラミングとメタプログラミングの基盤を提供します。

**主な機能：**
- **オブジェクトID管理**: gen_serverでスレッドセーフに一意なIDを生成
- **基底クラス**: Object、Class、Moduleの定義
- **インスタンス変数管理**: オブジェクトごとのインスタンス変数の取得/設定
- **メソッドテーブル管理**: クラスごとにメソッドを管理
- **メソッド探索**: クラス階層を辿ってメソッドを検索
- **メソッドディスパッチ**: オブジェクトに対するメソッド呼び出し
- **メソッドキャッシュ**: メソッド探索の結果をキャッシュして高速化
- **アクセサメソッド**: attr_reader、attr_writer、attr_accessorのサポート
- **動的メソッド定義**: define_method、send、method_missingのサポート

**オブジェクト構造：**
```erlang
#{
    type => object,
    class => 'MyClass',           % クラス名
    id => 123,                    % 一意のオブジェクトID
    instance_vars => #{           % インスタンス変数
        '@name' => "Alice",
        '@age' => 30
    }
}
```

**基底クラス定義：**
- **Object**: すべてのRubyオブジェクトの基底クラス（ID: 0）
- **Class**: クラスを表すクラス（ID: 1）
- **Module**: モジュールを表すクラス（ID: 2）

**使用例：**
```erlang
% オブジェクトシステムを起動（ruby_supが自動で起動）
{ok, _} = application:start(ruby),

% 新しいオブジェクトを作成
{ok, Obj} = ruby_object_server:new_instance('MyClass'),

% インスタンス変数を設定
Obj2 = ruby_object_server:set_instance_var(Obj, '@name', "Alice"),
Obj3 = ruby_object_server:set_instance_var(Obj2, '@age', 30),

% インスタンス変数を取得
{ok, "Alice"} = ruby_object_server:get_instance_var(Obj3, '@name'),
{ok, 30} = ruby_object_server:get_instance_var(Obj3, '@age'),

% すべてのインスタンス変数を取得
{ok, #{'@name' => "Alice", '@age' => 30}} = ruby_object_server:get_instance_vars(Obj3),

% オブジェクトのクラスを取得
{ok, 'MyClass'} = ruby_object_server:get_class(Obj3),

% オブジェクトIDを取得
{ok, Id} = ruby_object_server:get_object_id(Obj3).
```

**オブジェクトID管理：**
ruby_object_serverは gen_serverとして動作し、オブジェクトIDをスレッドセーフに生成します。IDは3から開始され（0-2は基底クラス用に予約）、オブジェクトごとに自動的にインクリメントされます。

**継承とミックスイン機能：**

brubyはRubyの継承とモジュールシステムを完全にサポートしています。

```erlang
% クラスを登録（親クラス指定）
ok = ruby_object_server:register_class('Animal', nil),
ok = ruby_object_server:register_class('Dog', 'Animal'),

% モジュールを登録
ok = ruby_object_server:register_module('Walkable'),
ok = ruby_object_server:register_module('Runnable'),

% 親クラスを取得
{ok, 'Animal'} = ruby_object_server:get_superclass('Dog'),

% 祖先チェーンを取得
{ok, Ancestors} = ruby_object_server:get_ancestors('Dog'),
% Ancestors = ['Dog', 'Animal', 'BasicObject']

% モジュールをinclude（クラスの後に挿入）
ok = ruby_object_server:include_module('Dog', 'Walkable'),
{ok, Ancestors2} = ruby_object_server:get_ancestors('Dog'),
% Ancestors2 = ['Dog', 'Walkable', 'Animal', 'BasicObject']

% モジュールをprepend（クラスの前に挿入）
ok = ruby_object_server:prepend_module('Dog', 'Runnable'),
{ok, Ancestors3} = ruby_object_server:get_ancestors('Dog'),
% Ancestors3 = ['Runnable', 'Dog', 'Walkable', 'Animal', 'BasicObject']

% インスタンスチェック（継承を考慮）
{ok, Dog} = ruby_object_server:new_instance('Dog'),
true = ruby_object_server:is_instance_of(Dog, 'Dog'),
true = ruby_object_server:is_instance_of(Dog, 'Animal'),      % 親クラス
true = ruby_object_server:is_instance_of(Dog, 'BasicObject'), % 祖先

% メソッド探索は祖先チェーンを辿る
% prependされたモジュール → クラス → includeされたモジュール → 親クラス の順
```

**メタプログラミング機能：**

```erlang
% メソッドテーブルの管理
% クラスにメソッドを定義
MethodDef = #{
    name => greet,
    params => [],
    body => "Hello",
    closure_env => nil
},
ok = ruby_object_server:define_class_method('MyClass', greet, MethodDef),

% メソッドを検索
{ok, Method} = ruby_object_server:lookup_method('MyClass', greet),

% クラスの全メソッドを取得
{ok, Methods} = ruby_object_server:get_class_methods('MyClass'),

% attr_accessorの使用
ok = ruby_object_server:attr_accessor('Person', [name, age]),
% これにより、name、name=、age、age= メソッドが自動生成される

% attr_readerの使用（読み取り専用）
ok = ruby_object_server:attr_reader('Product', [price, title]),

% attr_writerの使用（書き込み専用）
ok = ruby_object_server:attr_writer('Config', [debug, verbose]),

% define_methodで動的にメソッドを定義
ok = ruby_object_server:define_method('Calculator', add, [a, b], {'+', {var, a}, {var, b}}),

% sendでメソッドを動的に呼び出し
{ok, Result, Env} = ruby_object_server:method_send(Obj, greet, []),

% method_missingハンドラの設定
MissingHandler = #{
    name => method_missing,
    params => [method_name, args],
    body => "Unknown method",
    closure_env => nil
},
ok = ruby_object_server:set_method_missing('MyClass', method_missing, MissingHandler),

% method_missingが設定されているかチェック
true = ruby_object_server:has_method_missing('MyClass').
```

### 名前空間の管理（ruby_scope.erl）

`ruby_scope.erl` は変数スコープに加えて、Rubyの名前空間（定数管理）もサポートしています。

**主な機能：**
- **トップレベルの名前空間**: グローバルな定数を管理（`::Object` に相当）
- **クラス/モジュールの名前空間**: 各クラス・モジュールが独自の定数テーブルを持つ
- **ネストした名前空間の解決**: `A::B::C` のような階層的な定数アクセスをサポート

**名前空間チェーンの仕組み：**
```
A::B::C 名前空間 (C定数)
    ↓ parent
A::B 名前空間 (B定数)
    ↓ parent
A 名前空間 (A定数)
    ↓ parent
トップレベル名前空間 (グローバル定数)
    ↓ parent
   nil
```

**使用例：**
```erlang
% トップレベル名前空間を作成
TopLevel = ruby_scope:new_namespace(),

% A モジュールを定義
ANS = ruby_scope:new_namespace('A', TopLevel),
TopLevel2 = ruby_scope:bind_constant('A', ANS, TopLevel),

% A::B モジュールを定義
BNS = ruby_scope:new_namespace('B', ANS),
ANS2 = ruby_scope:bind_constant('B', BNS, ANS),

% A::B::C 定数を定義
BNS2 = ruby_scope:bind_constant('C', 42, BNS),

% A::B::C を解決
{ok, 42} = ruby_scope:lookup_constant_path(['A', 'B', 'C'], TopLevel2).
```

定数検索は現在の名前空間から開始し、見つからなければ親名前空間を順に辿ります。これにより、Rubyの定数検索ルールを実装しています。

## 使い方

### 方法1: テストスクリプト

15個のサンプルコードを自動実行：

```sh
./bin/test_eval.sh
```

出力例：
```
Test 1: Basic arithmetic
  Code:   1 + 2 * 3
  Result: 7

Test 5: Fibonacci (10th number)
  Code:   a = 0; b = 1; i = 0; while i < 10 temp = a + b; a = b; b = temp; i = i + 1 end; b
  Result: 89

Test 11: Method definition and call
  Code:   def add(x, y) x + y end; add(3, 4)
  Result: 7
```

### 方法2: Erlangシェルから対話的に実行

```sh
erl -pa lib/ruby/ebin
```

#### 基本的な使い方

```erlang
% 簡単な計算
1> ruby_evaluator:eval_string("1 + 2 * 3").
{ok,7,#{bindings => #{},parent => nil,return_value => undefined}}

% 変数を使った計算
2> ruby_evaluator:eval_string("x = 10; y = 20; x + y").
{ok,30,#{bindings => #{x => 10,y => 20},parent => nil,return_value => undefined}}

% if文
3> ruby_evaluator:eval_string("x = 15; if x > 10 100 else 200 end").
{ok,100,#{...}}

% while文
4> ruby_evaluator:eval_string("i = 0; while i < 5 i = i + 1 end; i").
{ok,5,#{...}}
```

## サンプルコード集

### 1. 算術演算

```erlang
% 基本的な演算
ruby_evaluator:eval_string("1 + 2").          % {ok, 3, ...}
ruby_evaluator:eval_string("10 - 3").         % {ok, 7, ...}
ruby_evaluator:eval_string("4 * 5").          % {ok, 20, ...}
ruby_evaluator:eval_string("20 / 4").         % {ok, 5, ...}
ruby_evaluator:eval_string("17 % 5").         % {ok, 2, ...}

% 演算子の優先順位
ruby_evaluator:eval_string("1 + 2 * 3").      % {ok, 7, ...}
ruby_evaluator:eval_string("(1 + 2) * 3").    % {ok, 9, ...}
```

### 2. 変数の代入と参照

```erlang
% 単純な変数
ruby_evaluator:eval_string("x = 42; x").                    % {ok, 42, ...}

% 複数の変数
ruby_evaluator:eval_string("a = 5; b = 3; a + b").          % {ok, 8, ...}

% 変数の再代入
ruby_evaluator:eval_string("x = 10; x = x + 5; x").         % {ok, 15, ...}
```

### 3. 比較演算

```erlang
ruby_evaluator:eval_string("5 == 5").         % {ok, true, ...}
ruby_evaluator:eval_string("5 != 3").         % {ok, true, ...}
ruby_evaluator:eval_string("3 < 5").          % {ok, true, ...}
ruby_evaluator:eval_string("5 > 3").          % {ok, true, ...}
ruby_evaluator:eval_string("5 <= 5").         % {ok, true, ...}
ruby_evaluator:eval_string("5 >= 3").         % {ok, true, ...}
```

### 4. 論理演算

```erlang
ruby_evaluator:eval_string("true and true").   % {ok, true, ...}
ruby_evaluator:eval_string("true and false").  % {ok, false, ...}
ruby_evaluator:eval_string("false or true").   % {ok, true, ...}

% Rubyの真偽値判定（nilとfalse以外は真）
ruby_evaluator:eval_string("5 and true").      % {ok, true, ...}
ruby_evaluator:eval_string("nil or true").     % {ok, true, ...}
```

### 5. ビット演算

```erlang
ruby_evaluator:eval_string("12 & 10").        % {ok, 8, ...}    % 0b1100 & 0b1010 = 0b1000
ruby_evaluator:eval_string("12 | 10").        % {ok, 14, ...}   % 0b1100 | 0b1010 = 0b1110
ruby_evaluator:eval_string("12 ^ 10").        % {ok, 6, ...}    % 0b1100 ^ 0b1010 = 0b0110
ruby_evaluator:eval_string("~5").             % {ok, -6, ...}
ruby_evaluator:eval_string("5 << 2").         % {ok, 20, ...}   % 5 * 2^2
ruby_evaluator:eval_string("20 >> 2").        % {ok, 5, ...}    % 20 / 2^2
```

### 6. if文

```erlang
% 基本的なif文
ruby_evaluator:eval_string("if true 100 end").                % {ok, 100, ...}
ruby_evaluator:eval_string("if false 100 end").               % {ok, nil, ...}

% if-else文
ruby_evaluator:eval_string("if true 100 else 200 end").       % {ok, 100, ...}
ruby_evaluator:eval_string("if false 100 else 200 end").      % {ok, 200, ...}

% if-elsif-else文
ruby_evaluator:eval_string("x = 5; if x < 3 100 elsif x < 7 200 else 300 end").
% {ok, 200, ...}

% 変数を使った条件分岐
ruby_evaluator:eval_string("x = 15; if x > 10 100 else 200 end").
% {ok, 100, ...}
```

### 7. while文

```erlang
% カウントアップ
ruby_evaluator:eval_string("i = 0; while i < 5 i = i + 1 end; i").
% {ok, 5, ...}

% 累積計算（1+2+3+...+10 = 55）
ruby_evaluator:eval_string("sum = 0; i = 1; while i <= 10 sum = sum + i; i = i + 1 end; sum").
% {ok, 55, ...}
```

### 8. until文

```erlang
% カウントアップ（untilはwhileの逆）
ruby_evaluator:eval_string("i = 0; until i >= 5 i = i + 1 end; i").
% {ok, 5, ...}
```

### 9. メソッド定義と呼び出し

```erlang
% 引数なしのメソッド
ruby_evaluator:eval_string("def hello 42 end; hello()").
% {ok, 42, ...}

% 引数1つのメソッド
ruby_evaluator:eval_string("def double(x) x * 2 end; double(5)").
% {ok, 10, ...}

% 引数2つのメソッド
ruby_evaluator:eval_string("def add(x, y) x + y end; add(3, 4)").
% {ok, 7, ...}

% メソッド内でのローカル変数
ruby_evaluator:eval_string("def compute(x) y = 10; x + y end; compute(5)").
% {ok, 15, ...}

% return文を持つメソッド
ruby_evaluator:eval_string("def check(x) if x > 10 return 999 end; 1 end; check(15)").
% {ok, 999, ...}

% メソッドから別のメソッドを呼び出す
ruby_evaluator:eval_string("def square(x) x * x end; def square_plus_one(x) square(x) + 1 end; square_plus_one(4)").
% {ok, 17, ...}

% 式を引数として渡す
ruby_evaluator:eval_string("def triple(x) x * 3 end; triple(2 + 3)").
% {ok, 15, ...}
```

### 10. 複雑な例

```erlang
% フィボナッチ数列（10項目 = 89）
ruby_evaluator:eval_string("a = 0; b = 1; i = 0; while i < 10 temp = a + b; a = b; b = temp; i = i + 1 end; b").
% {ok, 89, ...}

% ネストしたif文
ruby_evaluator:eval_string("x = 7; if x > 5 if x > 10 100 else 50 end else 10 end").
% {ok, 50, ...}

% 複雑な算術式
ruby_evaluator:eval_string("((10 + 5) * 2 - 6) / 3").
% {ok, 8, ...}

% メソッドを使った計算
ruby_evaluator:eval_string("def calc(a, b) a * 2 + b * 3 end; x = 5; y = 10; calc(x, y)").
% {ok, 40, ...}
```

### 11. クラス定義

```erlang
% 空のクラス定義
ruby_evaluator:eval_string("class MyClass
end").
% {ok, 'MyClass', ...}

% メソッドを含むクラス定義
ruby_evaluator:eval_string("class Calculator
  def add(x, y)
    x + y
  end
  def multiply(x, y)
    x * y
  end
end").
% {ok, 'Calculator', ...}

% クラス内でローカル変数を使うメソッド
ruby_evaluator:eval_string("class Counter
  def increment(n)
    result = n + 1
    result
  end
end").
% {ok, 'Counter', ...}

% 複数のクラス定義
ruby_evaluator:eval_string("class ClassA
end
class ClassB
end").
% {ok, 'ClassB', ...}
```

### 12. ブロックとProc

#### yieldを使ったブロック実行

```erlang
% 基本的なyield
ruby_evaluator:eval_string("def greet() yield end; greet() { 42 }").
% {ok, 42, ...}

% yieldに引数を渡す
ruby_evaluator:eval_string("def with_value() yield(10) end; with_value() { |n| n * 2 }").
% {ok, 20, ...}

% 複数の引数を渡す
ruby_evaluator:eval_string("def add_nums() yield(3, 4) end; add_nums() { |a, b| a + b }").
% {ok, 7, ...}

% メソッドの引数とyield
ruby_evaluator:eval_string("def transform(n) yield(n) end; transform(10) { |x| x * 3 }").
% {ok, 30, ...}

% do...end形式のブロック
ruby_evaluator:eval_string("def compute() yield end; compute() do 99 end").
% {ok, 99, ...}
```

#### block_given?でブロックの有無を確認

```erlang
% ブロックが渡された場合
ruby_evaluator:eval_string("def check() if block_given? 1 else 0 end end; check() { }").
% {ok, 1, ...}

% ブロックが渡されない場合
ruby_evaluator:eval_string("def check() if block_given? 1 else 0 end end; check()").
% {ok, 0, ...}

% block_given?を使った条件分岐
ruby_evaluator:eval_string("def maybe_yield(n) if block_given? yield(n) else n end end; maybe_yield(5) { |x| x * 2 }").
% {ok, 10, ...}

ruby_evaluator:eval_string("def maybe_yield(n) if block_given? yield(n) else n end end; maybe_yield(5)").
% {ok, 5, ...}
```

#### Proc.newとlambda

```erlang
% Proc.newでブロックをオブジェクトとして保存
ruby_evaluator:eval_string("p = proc { |x| x * 2 }; p").
% {ok, #{...}, ...}  % Procオブジェクトが返される

% lambdaでブロックを作成
ruby_evaluator:eval_string("l = lambda { |x| x + 1 }; l").
% {ok, #{...}, ...}  % Lambdaオブジェクトが返される

% クロージャ（環境のキャプチャ）
ruby_evaluator:eval_string("def make_multiplier(n) lambda { |x| x * n } end; mult = make_multiplier(3); mult").
% {ok, #{...}, ...}  % nの値をキャプチャしたLambdaオブジェクト
```

#### ブロックの応用例

```erlang
% カウンターをブロックで実装
ruby_evaluator:eval_string("def count_to(n) i = 0; while i < n yield(i); i = i + 1 end end; count_to(3) { |x| x }").
% {ok, 2, ...}  % 最後のyieldの戻り値

% 複雑な計算をブロックで
ruby_evaluator:eval_string("def apply_twice(n) yield(yield(n)) end; apply_twice(5) { |x| x + 3 }").
% {ok, 11, ...}  % (5 + 3) + 3 = 11
```

### 13. バインディング（binding）

#### bindingオブジェクトの基本

```erlang
% bindingオブジェクトを取得
ruby_evaluator:eval_string("x = 10; y = 20; binding()").
% {ok, #{type => binding, scope => ..., captured_bindings => #{x => 10, y => 20}}, ...}

% bindingは現在のコンテキストをキャプチャする
ruby_evaluator:eval_string("a = 100; b = 200; c = 300; binding()").
% {ok, #{type => binding, captured_bindings => #{a => 100, b => 200, c => 300}}, ...}
```

#### メソッド内でのbinding

```erlang
% メソッド内の変数をキャプチャ
ruby_evaluator:eval_string("def get_binding(x, y) z = x + y; binding() end; get_binding(5, 3)").
% {ok, #{type => binding, captured_bindings => #{x => 5, y => 3, z => 8}}, ...}

% ローカル変数のスコープをキャプチャ
ruby_evaluator:eval_string("def capture_locals() local_var = 42; binding() end; capture_locals()").
% {ok, #{type => binding, captured_bindings => #{local_var => 42}}, ...}
```

#### バインディングを使った変数の取得

```erlang
% バインディングから変数を取得
{ok, Binding, _} = ruby_evaluator:eval_string("x = 100; y = 200; binding()"),
{ok, 100} = ruby_scope:binding_get_variable(x, Binding),
{ok, 200} = ruby_scope:binding_get_variable(y, Binding).

% 全変数を取得
AllVars = ruby_scope:binding_get_all_variables(Binding).
% #{x => 100, y => 200}
```

#### バインディングを使った変数の設定

```erlang
% バインディングに新しい変数を追加
{ok, B1, _} = ruby_evaluator:eval_string("x = 10; binding()"),
B2 = ruby_scope:binding_set_variable(y, 20, B1),
{ok, 10} = ruby_scope:binding_get_variable(x, B2),
{ok, 20} = ruby_scope:binding_get_variable(y, B2).

% バインディングの変数を更新
B3 = ruby_scope:binding_set_variable(x, 999, B2),
{ok, 999} = ruby_scope:binding_get_variable(x, B3).
```

#### 階層的なスコープのキャプチャ

```erlang
% 外側と内側のスコープをキャプチャ
Code = "
  x = 10
  def foo()
    y = 20
    binding()
  end
  foo()
",
{ok, Binding, _} = ruby_evaluator:eval_string(Code),
% Bindingには y => 20 が含まれる（メソッド内のローカル変数）

% グローバルとローカルの両方をキャプチャ
Code2 = "
  global = 100
  def bar()
    local = 200
    binding()
  end
  bar()
",
{ok, Binding2, _} = ruby_evaluator:eval_string(Code2).
% Binding2には local => 200 が含まれる
```

## 環境を引き継いだ評価

eval_string/2を使用すると、前の評価結果の環境を引き継げます：

```erlang
% 変数の引き継ぎ
{ok, Result1, Env1} = ruby_evaluator:eval_string("x = 10").
{ok, Result2, Env2} = ruby_evaluator:eval_string("y = 20; x + y", Env1).
% Result2 は 30 になる（xの値が引き継がれている）

% メソッドの引き継ぎ
{ok, _, Env3} = ruby_evaluator:eval_string("def double(x) x * 2 end").
{ok, Result3, _} = ruby_evaluator:eval_string("double(5)", Env3).
% Result3 は 10 になる（メソッド定義が引き継がれている）

% 変数とメソッドの両方を引き継ぐ
{ok, _, Env4} = ruby_evaluator:eval_string("def add(a, b) a + b end; x = 10").
{ok, Result4, _} = ruby_evaluator:eval_string("y = 20; add(x, y)", Env4).
% Result4 は 30 になる

% クラスの引き継ぎ
{ok, _, Env5} = ruby_evaluator:eval_string("class Calculator
  def add(x, y)
    x + y
  end
end").
{ok, Result5, _} = ruby_evaluator:eval_string("x = 10", Env5).
% クラス定義が引き継がれている
```

## 現在サポートしている機能

- ✅ リテラル（整数、文字列、真偽値、nil）
- ✅ ローカル変数の代入と参照
- ✅ 算術演算子（+, -, *, /, %）
- ✅ 比較演算子（==, !=, <, >, <=, >=）
- ✅ 論理演算子（and, or）
- ✅ ビット演算子（&, |, ^, ~, <<, >>）
- ✅ if/elsif/else文
- ✅ while/until文
- ✅ return文
- ✅ メソッド定義（def...end）
- ✅ メソッド呼び出し（引数の評価、メソッドディスパッチ）
- ✅ クラス定義（class...end）
- ✅ ブロック（{ }、do...end）
- ✅ yield文
- ✅ block_given?
- ✅ Proc.new/lambda
- ✅ クロージャ（環境のキャプチャ）
- ✅ binding（バインディングオブジェクト）
- ✅ 名前空間管理（定数、トップレベル、ネスト解決）
- ✅ オブジェクトシステム（Object、Class、Module、オブジェクトID管理、インスタンス変数）
- ✅ メタプログラミング基盤
  - ✅ メソッドテーブル管理（クラスごと）
  - ✅ メソッド探索（method lookup）
  - ✅ メソッドディスパッチ
  - ✅ メソッドキャッシュ
  - ✅ attr_accessor/attr_reader/attr_writer
  - ✅ define_method/send/method_missing
- ✅ 継承とミックスイン
  - ✅ クラス継承（superclass）
  - ✅ 祖先チェーン（ancestors）
  - ✅ モジュールのinclude
  - ✅ モジュールのprepend
  - ✅ 継承を考慮したメソッド探索
  - ✅ 継承を考慮したis_instance_of

## 未実装の機能

以下の機能は現在未実装です：

- ❌ クラスのインスタンス化（new、インスタンスメソッド呼び出し）
- ❌ レシーバー付きメソッド呼び出し（obj.method）
- ❌ モジュールのextend
- ❌ Procオブジェクトの実行（.callメソッド）
- ❌ 組み込みイテレータメソッド（each、map、selectなど）
- ❌ シンボル
- ❌ 配列・ハッシュ
- ❌ 例外処理（rescue/ensure）
- ❌ break/next文
- ❌ モジュール定義（構文レベル）

これらの機能は今後のフェーズで実装予定です。
