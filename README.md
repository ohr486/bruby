# bruby

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/ohr486/bruby/tree/develop.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/ohr486/bruby/tree/develop)

## Build
```sh
make
```

## Test
```sh
make test
```

## Run Script
```sh
./bin/bruby
```

## Run Test

```sh
make
make test
```

## Test Tokenizer and Parser

トークナイザーとパーサーの動作を個別に確認できます。

### トークナイザーのテスト

Rubyコードをトークンに分解する様子を確認：

```sh
./bin/test_tokenizer.sh "def hello(name); puts name; end"
```

出力例：
```
=== Input ===
def hello(name); puts name; end

=== Tokens ===
  {tDEF,1}
  {tIDENTIFIER,1,"hello"}
  {'(',1}
  {tIDENTIFIER,1,"name"}
  {')',1}
  {';',1}
  {tIDENTIFIER,1,"puts"}
  {tIDENTIFIER,1,"name"}
  {';',1}
  {tEND,1}

=== Summary ===
Total tokens: 10
End line: 1
```

### パーサーのテスト

トークンから抽象構文木(AST)を生成する様子を確認：

```sh
./bin/test_parser.sh "1 + 2 * 3"
```

出力例：
```
=== Input Code ===
1 + 2 * 3

=== Tokens ===
  {tINTEGER,1,1}
  {'+',1}
  {tINTEGER,1,2}
  {'*',1}
  {tINTEGER,1,3}

=== Parsing ===
Success!

=== Abstract Syntax Tree (AST) ===
[{binary_op,1,'+',
            {integer,1,1},
            {binary_op,1,'*',{integer,1,2},{integer,1,3}}}]
```

その他の例：
```sh
# 変数代入
./bin/test_parser.sh "x = 10"

# メソッド呼び出し
./bin/test_parser.sh "foo(1, 2)"

# if文
./bin/test_parser.sh "if x == 10; true; else; false; end"
```

## Test Evaluator (評価器のテスト)

brubyの評価器は、Rubyコードを実際に実行できます。

### 方法1: テストスクリプト

10個のサンプルコードを自動実行：

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

#### サンプルコード集

**1. 算術演算**

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

**2. 変数の代入と参照**

```erlang
% 単純な変数
ruby_evaluator:eval_string("x = 42; x").                    % {ok, 42, ...}

% 複数の変数
ruby_evaluator:eval_string("a = 5; b = 3; a + b").          % {ok, 8, ...}

% 変数の再代入
ruby_evaluator:eval_string("x = 10; x = x + 5; x").         % {ok, 15, ...}
```

**3. 比較演算**

```erlang
ruby_evaluator:eval_string("5 == 5").         % {ok, true, ...}
ruby_evaluator:eval_string("5 != 3").         % {ok, true, ...}
ruby_evaluator:eval_string("3 < 5").          % {ok, true, ...}
ruby_evaluator:eval_string("5 > 3").          % {ok, true, ...}
ruby_evaluator:eval_string("5 <= 5").         % {ok, true, ...}
ruby_evaluator:eval_string("5 >= 3").         % {ok, true, ...}
```

**4. 論理演算**

```erlang
ruby_evaluator:eval_string("true and true").   % {ok, true, ...}
ruby_evaluator:eval_string("true and false").  % {ok, false, ...}
ruby_evaluator:eval_string("false or true").   % {ok, true, ...}

% Rubyの真偽値判定（nilとfalse以外は真）
ruby_evaluator:eval_string("5 and true").      % {ok, true, ...}
ruby_evaluator:eval_string("nil or true").     % {ok, true, ...}
```

**5. ビット演算**

```erlang
ruby_evaluator:eval_string("12 & 10").        % {ok, 8, ...}    % 0b1100 & 0b1010 = 0b1000
ruby_evaluator:eval_string("12 | 10").        % {ok, 14, ...}   % 0b1100 | 0b1010 = 0b1110
ruby_evaluator:eval_string("12 ^ 10").        % {ok, 6, ...}    % 0b1100 ^ 0b1010 = 0b0110
ruby_evaluator:eval_string("~5").             % {ok, -6, ...}
ruby_evaluator:eval_string("5 << 2").         % {ok, 20, ...}   % 5 * 2^2
ruby_evaluator:eval_string("20 >> 2").        % {ok, 5, ...}    % 20 / 2^2
```

**6. if文**

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

**7. while文**

```erlang
% カウントアップ
ruby_evaluator:eval_string("i = 0; while i < 5 i = i + 1 end; i").
% {ok, 5, ...}

% 累積計算（1+2+3+...+10 = 55）
ruby_evaluator:eval_string("sum = 0; i = 1; while i <= 10 sum = sum + i; i = i + 1 end; sum").
% {ok, 55, ...}
```

**8. until文**

```erlang
% カウントアップ（untilはwhileの逆）
ruby_evaluator:eval_string("i = 0; until i >= 5 i = i + 1 end; i").
% {ok, 5, ...}
```

**9. 複雑な例**

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
```

#### 環境を引き継いだ評価

eval_string/2を使用すると、前の評価結果の環境を引き継げます：

```erlang
% 初回評価
{ok, Result1, Env1} = ruby_evaluator:eval_string("x = 10").

% 環境を引き継いで評価
{ok, Result2, Env2} = ruby_evaluator:eval_string("y = 20; x + y", Env1).
% Result2 は 30 になる（xの値が引き継がれている）
```

### 現在サポートしている機能

- ✅ リテラル（整数、文字列、真偽値、nil）
- ✅ ローカル変数の代入と参照
- ✅ 算術演算子（+, -, *, /, %）
- ✅ 比較演算子（==, !=, <, >, <=, >=）
- ✅ 論理演算子（and, or）
- ✅ ビット演算子（&, |, ^, ~, <<, >>）
- ✅ if/elsif/else文
- ✅ while/until文
- ✅ return文

### 未実装の機能

以下の機能は現在未実装です：

- ❌ メソッド呼び出し
- ❌ メソッド定義
- ❌ クラス定義
- ❌ ブロック/イテレータ
- ❌ シンボル
- ❌ 配列・ハッシュ
- ❌ 例外処理
- ❌ break/next文

これらの機能は今後のフェーズで実装予定です。

## Run Test on Docker

```sh
cd docker
./build.sh
./run.sh

make
make test
```

