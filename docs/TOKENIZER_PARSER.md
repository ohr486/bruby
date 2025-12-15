# bruby Tokenizer and Parser (トークナイザーとパーサー)

トークナイザーとパーサーの動作を個別に確認できます。

## トークナイザーのテスト

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

## パーサーのテスト

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

## サンプル

### 変数代入

```sh
./bin/test_parser.sh "x = 10"
```

### メソッド呼び出し

```sh
./bin/test_parser.sh "foo(1, 2)"
```

### if文

```sh
./bin/test_parser.sh "if x == 10; true; else; false; end"
```

### メソッド定義

```sh
./bin/test_parser.sh "def add(x, y); x + y; end"
```

### 複雑な式

```sh
./bin/test_parser.sh "x = 5; if x > 3; y = x * 2; else; y = 0; end"
```

## トークナイザーの仕組み

トークナイザー（`ruby_tokenizer.erl`）は、Rubyソースコードを字句解析し、トークン列に変換します。

### サポートしているトークン

- **キーワード**: `def`, `end`, `class`, `if`, `elsif`, `else`, `while`, `until`, `return`, `break`, `next`, `true`, `false`, `nil`
- **識別子**: 変数名、メソッド名（`[a-z_][a-zA-Z0-9_]*`）
- **リテラル**:
  - 整数: `123`, `0`, `-42`
  - 文字列: `"hello"`, `'world'`（エスケープシーケンス対応）
- **演算子**:
  - 算術: `+`, `-`, `*`, `/`, `%`
  - 比較: `==`, `!=`, `<`, `>`, `<=`, `>=`
  - 論理: `&&`, `||`, `and`, `or`
  - ビット: `&`, `|`, `^`, `~`, `<<`, `>>`
- **記号**: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `.`, `:`, `;`

## パーサーの仕組み

パーサー（`ruby_parser.yrl`）は、トークン列を抽象構文木（AST）に変換します。Yeccパーサージェネレータを使用して実装されています。

### サポートしている構文

- **式**:
  - リテラル: 整数、文字列、真偽値、nil
  - 変数参照と代入
  - 二項演算子（演算子の優先順位を正しく処理）
  - 括弧による式のグループ化

- **制御構造**:
  - if/elsif/else文
  - while/until文
  - return/break/next文

- **メソッド**:
  - メソッド定義（`def name(params) ... end`）
  - メソッド呼び出し（`method(args)`）

- **クラス**:
  - クラス定義（`class Name ... end`）

### 演算子の優先順位

パーサーは以下の優先順位でトークンを処理します（下に行くほど優先度が高い）：

1. 代入 (`=`)
2. 論理OR (`or`)
3. 論理AND (`and`)
4. 等価性 (`==`, `!=`)
5. 比較 (`<`, `>`, `<=`, `>=`)
6. ビットOR、XOR (`|`, `^`)
7. ビットAND (`&`)
8. シフト (`<<`, `>>`)
9. 加減算 (`+`, `-`)
10. 乗除算 (`*`, `/`, `%`)
11. ビットNOT (`~`)

### AST構造の例

```erlang
% x = 10
{assign, 1, {var, 1, "x"}, {integer, 1, 10}}

% if x > 5 100 else 200 end
{if_stmt, 1,
  {binary_op, 1, '>', {identifier, 1, "x"}, {integer, 1, 5}},
  [{integer, 1, 100}],
  [],
  {else_clause, 1, [{integer, 1, 200}]}}

% def add(x, y) x + y end
{method_def, 1, "add",
  [{param, 1, "x"}, {param, 1, "y"}],
  [{binary_op, 1, '+', {identifier, 1, "x"}, {identifier, 1, "y"}}]}
```

## トークナイザーとパーサーの実装詳細

### トークナイザーの実装

トークナイザーは状態機械として実装されており、以下の機能があります：

- **行番号の追跡**: エラーメッセージに正確な位置情報を提供
- **コメントの処理**: `#`から行末までをスキップ
- **エスケープシーケンス**: 文字列内の`\n`, `\t`, `\"`, `\'`をサポート
- **複数文字演算子**: `==`, `!=`, `<=`, `>=`, `&&`, `||`, `<<`, `>>`の認識

### パーサーの実装

パーサーはYecc文法ファイル（`ruby_parser.yrl`）から生成されます：

```sh
# パーサーの生成
erlc -o lib/ruby/src lib/ruby/src/ruby_parser.yrl
```

生成されたパーサー（`ruby_parser.erl`）は以下の機能を提供します：

- **構文エラーの検出**: 不正な構文を検出し、エラー位置を報告
- **左結合と右結合**: 演算子の結合性を正しく処理
- **曖昧性の解決**: 優先順位宣言により文法の曖昧性を解決

## 開発者向け情報

### パーサーの再生成

`ruby_parser.yrl`を編集した後は、パーサーを再生成する必要があります：

```sh
make clean
make
```

Makefileが自動的に以下を実行します：
1. `ruby_parser.yrl`から`ruby_parser.erl`を生成
2. 全てのErlangファイルをコンパイル

### 新しいトークンの追加

1. `ruby_tokenizer.erl`にトークン認識ロジックを追加
2. `ruby_parser.yrl`の`Terminals`セクションにトークンを追加
3. 必要に応じて文法規則を追加

### 新しい構文の追加

1. `ruby_parser.yrl`の`Nonterminals`セクションに非終端記号を追加
2. 文法規則を追加
3. 必要に応じて演算子の優先順位を定義
4. `ruby_evaluator.erl`に評価ロジックを追加
