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

詳細は [docs/TOKENIZER_PARSER.md](docs/TOKENIZER_PARSER.md) を参照してください。

### クイックスタート

```sh
# トークナイザーのテスト
./bin/test_tokenizer.sh "def hello(name); puts name; end"

# パーサーのテスト
./bin/test_parser.sh "1 + 2 * 3"
```

詳細な使い方、サポートしている構文、実装の仕組みは [docs/TOKENIZER_PARSER.md](docs/TOKENIZER_PARSER.md) を参照してください。

## Test Evaluator (評価器のテスト)

brubyの評価器は、Rubyコードを実際に実行できます。

詳細は [docs/EVALUATOR.md](docs/EVALUATOR.md) を参照してください。

### クイックスタート

```sh
# テストスクリプトで15個のサンプルを実行
./bin/test_eval.sh

# Erlangシェルで対話的に実行
erl -pa lib/ruby/ebin
```

```erlang
% 基本的な使い方
ruby_evaluator:eval_string("1 + 2 * 3").           % 算術演算
ruby_evaluator:eval_string("x = 10; y = 20; x + y"). % 変数
ruby_evaluator:eval_string("if x > 10 100 else 200 end"). % 条件分岐
ruby_evaluator:eval_string("def add(x, y) x + y end; add(3, 4)"). % メソッド
```

### 主な機能

- ✅ リテラル、変数、演算子（算術、比較、論理、ビット）
- ✅ 制御フロー（if/elsif/else、while/until、return）
- ✅ メソッド定義と呼び出し
- ✅ クラス定義

詳細なサンプルコードと使い方は [docs/EVALUATOR.md](docs/EVALUATOR.md) を参照してください。

## Run Test on Docker

```sh
cd docker
./build.sh
./run.sh

make
make test
```

