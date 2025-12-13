#!/bin/sh

# パーサーのテストツール
# 使い方: ./bin/test_parser.sh "Ruby code here"

if [ -z "$1" ]; then
  echo "Usage: $0 \"Ruby code\""
  echo ""
  echo "Examples:"
  echo "  $0 \"1 + 2\""
  echo "  $0 \"x = 10\""
  echo "  $0 \"def add(x, y); x + y; end\""
  exit 1
fi

erl -pa ./lib/ruby/ebin -noshell -eval "
Code = \"$1\",
io:format(\"~n=== Input Code ===~n~s~n~n\", [Code]),

case ruby_tokenizer:tokenize(Code) of
  {ok, Tokens, _} ->
    io:format(\"=== Tokens ===~n\", []),
    lists:foreach(fun(Token) -> io:format(\"  ~p~n\", [Token]) end, Tokens),

    io:format(\"~n=== Parsing ===~n\", []),
    case ruby_parser:parse(Tokens) of
      {ok, AST} ->
        io:format(\"Success!~n~n\", []),
        io:format(\"=== Abstract Syntax Tree (AST) ===~n\", []),
        io:format(\"~p~n~n\", [AST]);
      {error, {Line, Module, Message}} ->
        io:format(\"Parse error at line ~p:~n\", [Line]),
        io:format(\"  ~s~n~n\", [Module:format_error(Message)])
    end;
  {error, ErrorInfo, Line} ->
    io:format(\"~nTokenize error at line ~p: ~p~n~n\", [Line, ErrorInfo])
end,
halt().
"
