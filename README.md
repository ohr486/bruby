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

## Run Test on Docker

```sh
cd docker
./build.sh
./run.sh

make
make test
```

