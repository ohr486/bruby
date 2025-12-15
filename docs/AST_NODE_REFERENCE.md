# bruby AST ノードリファレンス

このドキュメントは、brubyで使用されるASTノードタイプの完全なリファレンスです。

## 共通構造

すべてのASTノードは以下の共通フィールドを持ちます：

```erlang
#{
    type := atom(),              % ノードタイプ
    location := #location{},     % 位置情報
    metadata => metadata()       % メタデータ（オプション）
}
```

### location レコード

```erlang
-record(location, {
    line :: pos_integer(),           % 行番号（1始まり）
    column :: pos_integer(),         % カラム位置（1始まり）
    start_offset :: non_neg_integer(), % ファイル先頭からのバイトオフセット
    end_offset :: non_neg_integer(),   % 終了位置のバイトオフセット
    file :: binary() | undefined       % ファイル名（オプション）
}).
```

### metadata マップ

```erlang
-type metadata() :: #{
    comments => [comment()],      % 関連するコメント
    source => binary(),           % 元のソーステキスト
    annotations => map()          % 任意のアノテーション
}.
```

## リテラルノード

### integer - 整数リテラル

```erlang
#{
    type := integer,
    location := #location{},
    value := integer(),
    metadata => metadata()
}
```

**例:**
```ruby
42
-10
1000000
```

**生成:**
```erlang
ruby_ast:new_integer(42, Location).
```

### float - 浮動小数点リテラル

```erlang
#{
    type := float,
    location := #location{},
    value := float(),
    metadata => metadata()
}
```

**例:**
```ruby
3.14
-0.5
1.0e10
```

### string - 文字列リテラル

```erlang
#{
    type := string,
    location := #location{},
    value := binary() | string(),
    metadata => metadata()
}
```

**例:**
```ruby
"hello"
'world'
"multi\nline"
```

### boolean - 真偽値リテラル

```erlang
#{
    type := boolean,
    location := #location{},
    value := boolean(),
    metadata => metadata()
}
```

**例:**
```ruby
true
false
```

### nil - nil値

```erlang
#{
    type := nil,
    location := #location{},
    metadata => metadata()
}
```

**例:**
```ruby
nil
```

### symbol - シンボルリテラル（将来実装）

```erlang
#{
    type := symbol,
    location := #location{},
    value := atom(),
    metadata => metadata()
}
```

**例:**
```ruby
:foo
:bar
:"with spaces"
```

## 変数ノード

### var - 変数参照

```erlang
#{
    type := var,
    location := #location{},
    name := atom(),
    metadata => metadata()
}
```

**例:**
```ruby
x
foo
my_variable
```

### identifier - 識別子

```erlang
#{
    type := identifier,
    location := #location{},
    name := atom(),
    metadata => metadata()
}
```

**例:**
```ruby
my_method
SomeClass
CONSTANT
```

### assign - 変数代入

```erlang
#{
    type := assign,
    location := #location{},
    var := var_node(),
    expr := ast_node(),
    metadata => metadata()
}
```

**例:**
```ruby
x = 42
name = "Ruby"
result = calculate()
```

## 演算ノード

### binary_op - 二項演算

```erlang
#{
    type := binary_op,
    location := #location{},
    op := atom(),           % '+', '-', '*', '/', '%', '==', '!=', etc.
    left := ast_node(),
    right := ast_node(),
    metadata => metadata()
}
```

**サポートされる演算子:**
- 算術: `+`, `-`, `*`, `/`, `%`
- 比較: `==`, `!=`, `<`, `>`, `<=`, `>=`
- 論理: `and`, `or`, `&&`, `||`
- ビット: `&`, `|`, `^`, `<<`, `>>`

**例:**
```ruby
1 + 2
x * y
a == b
```

### unary_op - 単項演算

```erlang
#{
    type := unary_op,
    location := #location{},
    op := atom(),           % '~', '!', '-', '+', 'not'
    operand := ast_node(),
    metadata => metadata()
}
```

**例:**
```ruby
-x
!flag
~bits
```

## 制御フローノード

### if_stmt - if文

```erlang
#{
    type := if_stmt,
    location := #location{},
    condition := ast_node(),
    then_stmts := [ast_node()],
    elsif_clauses := [elsif_clause()],
    else_stmts := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
if x > 0
  puts "positive"
elsif x < 0
  puts "negative"
else
  puts "zero"
end
```

### elsif_clause - elsif節

```erlang
#{
    type := elsif,
    location := #location{},
    condition := ast_node(),
    stmts := [ast_node()],
    metadata => metadata()
}
```

### while_stmt - while文

```erlang
#{
    type := while_stmt,
    location := #location{},
    condition := ast_node(),
    stmts := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
while x < 10
  x = x + 1
end
```

### until_stmt - until文

```erlang
#{
    type := until_stmt,
    location := #location{},
    condition := ast_node(),
    stmts := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
until x >= 10
  x = x + 1
end
```

### return - return文

```erlang
#{
    type := return,
    location := #location{},
    value := ast_node() | nil,
    metadata => metadata()
}
```

**例:**
```ruby
return
return 42
return x + y
```

### break - break文

```erlang
#{
    type := break,
    location := #location{},
    metadata => metadata()
}
```

### next - next文

```erlang
#{
    type := next,
    location := #location{},
    metadata => metadata()
}
```

## メソッド関連ノード

### method_def - メソッド定義

```erlang
#{
    type := method_def,
    location := #location{},
    name := atom(),
    params := [param()],
    body := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
def add(a, b)
  a + b
end

def greet(name)
  puts "Hello, #{name}!"
end
```

### param - パラメータ

```erlang
#{
    type := param,
    location := #location{},
    name := atom(),
    metadata => metadata()
}
```

### call - メソッド呼び出し

```erlang
#{
    type := call,
    location := #location{},
    name := atom(),
    args := [ast_node()],
    block := block_node() | nil,
    metadata => metadata()
}
```

**例:**
```ruby
puts("Hello")
add(1, 2)
each { |x| puts x }
```

## クラス関連ノード

### class_def - クラス定義

```erlang
#{
    type := class_def,
    location := #location{},
    name := atom(),
    superclass := atom() | nil,
    body := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
class Person
  def initialize(name)
    @name = name
  end
end

class Student < Person
end
```

## ブロック関連ノード

### block - ブロック

```erlang
#{
    type := block,
    location := #location{},
    params := [param()],
    body := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
{ |x| puts x }

do |x, y|
  puts x + y
end
```

### yield - yield式

```erlang
#{
    type := yield,
    location := #location{},
    args := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
yield
yield(1, 2)
```

### block_given - block_given?

```erlang
#{
    type := block_given,
    location := #location{},
    metadata => metadata()
}
```

**例:**
```ruby
if block_given?
  yield
end
```

### proc_new - Proc.new / proc

```erlang
#{
    type := proc_new,
    location := #location{},
    block := block_node(),
    metadata => metadata()
}
```

**例:**
```ruby
proc { |x| x + 1 }
Proc.new { puts "hello" }
```

### lambda - lambda

```erlang
#{
    type := lambda,
    location := #location{},
    block := block_node(),
    metadata => metadata()
}
```

**例:**
```ruby
lambda { |x| x * 2 }
->(x) { x * 2 }
```

## コレクション（将来実装）

### array - 配列リテラル

```erlang
#{
    type := array,
    location := #location{},
    elements := [ast_node()],
    metadata => metadata()
}
```

**例:**
```ruby
[1, 2, 3]
["a", "b", "c"]
[]
```

### hash - ハッシュリテラル

```erlang
#{
    type := hash,
    location := #location{},
    pairs := [{ast_node(), ast_node()}],
    metadata => metadata()
}
```

**例:**
```ruby
{a: 1, b: 2}
{"key" => "value"}
{}
```

### range - 範囲

```erlang
#{
    type := range,
    location := #location{},
    start := ast_node(),
    'end' := ast_node(),
    exclusive := boolean(),
    metadata => metadata()
}
```

**例:**
```ruby
1..10     # inclusive
1...10    # exclusive
```

## 特殊ノード

### program - プログラム全体

```erlang
#{
    type := program,
    location := #location{},
    stmts := [ast_node()],
    metadata => metadata()
}
```

プログラム全体を表すルートノード。

### statements - 文のリスト

```erlang
#{
    type := statements,
    location := #location{},
    stmts := [ast_node()],
    metadata => metadata()
}
```

複数の文をグループ化したノード。

## ノードの使用例

### 基本的な式

**Rubyコード:**
```ruby
x = 10
y = 20
x + y
```

**AST:**
```erlang
#{
    type => statements,
    location => #location{line = 1, column = 1},
    stmts => [
        #{
            type => assign,
            location => #location{line = 1, column = 1},
            var => #{type => var, location => ..., name => x},
            expr => #{type => integer, location => ..., value => 10}
        },
        #{
            type => assign,
            location => #location{line = 2, column = 1},
            var => #{type => var, location => ..., name => y},
            expr => #{type => integer, location => ..., value => 20}
        },
        #{
            type => binary_op,
            location => #location{line = 3, column = 1},
            op => '+',
            left => #{type => identifier, location => ..., name => x},
            right => #{type => identifier, location => ..., name => y}
        }
    ]
}
```

### メソッド定義

**Rubyコード:**
```ruby
def greet(name)
  puts "Hello, #{name}!"
end
```

**AST:**
```erlang
#{
    type => method_def,
    location => #location{line = 1, column = 1},
    name => greet,
    params => [
        #{type => param, location => ..., name => name}
    ],
    body => [
        #{
            type => call,
            location => #location{line = 2, column = 3},
            name => puts,
            args => [
                #{type => string, location => ..., value => <<"Hello, ...">>}
            ],
            block => nil
        }
    ]
}
```

### 制御フロー

**Rubyコード:**
```ruby
if x > 0
  puts "positive"
else
  puts "negative"
end
```

**AST:**
```erlang
#{
    type => if_stmt,
    location => #location{line = 1, column = 1},
    condition => #{
        type => binary_op,
        location => #location{line = 1, column = 4},
        op => '>',
        left => #{type => identifier, location => ..., name => x},
        right => #{type => integer, location => ..., value => 0}
    },
    then_stmts => [
        #{
            type => call,
            location => #location{line = 2, column = 3},
            name => puts,
            args => [#{type => string, value => <<"positive">>}],
            block => nil
        }
    ],
    elsif_clauses => [],
    else_stmts => [
        #{
            type => call,
            location => #location{line = 4, column = 3},
            name => puts,
            args => [#{type => string, value => <<"negative">>}],
            block => nil
        }
    ]
}
```

## ノードの走査例

### すべてのリテラル値を収集

```erlang
collect_literals(AST) ->
    ruby_ast:fold(
        fun(Node, Acc) ->
            case ruby_ast:get_type(Node) of
                integer -> [ruby_ast:get_value(Node) | Acc];
                string -> [ruby_ast:get_value(Node) | Acc];
                boolean -> [ruby_ast:get_value(Node) | Acc];
                _ -> Acc
            end
        end,
        [],
        AST
    ).
```

### すべての変数名を収集

```erlang
collect_variable_names(AST) ->
    ruby_ast:fold(
        fun(Node, Acc) ->
            case ruby_ast:get_type(Node) of
                var -> [ruby_ast:get_name(Node) | Acc];
                identifier -> [ruby_ast:get_name(Node) | Acc];
                _ -> Acc
            end
        end,
        [],
        AST
    ).
```

### AST内のすべてのノードをカウント

```erlang
count_nodes(AST) ->
    ruby_ast:fold(
        fun(_Node, Count) -> Count + 1 end,
        0,
        AST
    ).
```

## まとめ

このリファレンスは、brubyのAST実装が進むにつれて更新されます。各ノードタイプには、対応する生成関数、検査関数、変換関数が`ruby_ast`モジュールで提供される予定です。
