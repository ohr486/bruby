# bruby Evaluator (評価器)

brubyの評価器は、Rubyコードを実際に実行できます。

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
{ok, _, Env4} = ruby_evaluator:eval_string("def add(a, b) a + b end; x = 10", new_env()).
{ok, Result4, _} = ruby_evaluator:eval_string("y = 20; add(x, y)", Env4).
% Result4 は 30 になる
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

## 未実装の機能

以下の機能は現在未実装です：

- ❌ クラス定義と継承
- ❌ レシーバー付きメソッド呼び出し（obj.method）
- ❌ 再帰的なメソッド呼び出し
- ❌ ブロック/イテレータ
- ❌ シンボル
- ❌ 配列・ハッシュ
- ❌ 例外処理（rescue/ensure）
- ❌ break/next文
- ❌ モジュール定義

これらの機能は今後のフェーズで実装予定です。
