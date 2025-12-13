#!/bin/sh

# トークナイザーのテストツール
# 使い方: ./bin/test_tokenizer "Ruby code here"

if [ -z "$1" ]; then
  echo "Usage: $0 \"Ruby code\""
  echo "Example: $0 \"def foo(x); x + 1; end\""
  exit 1
fi

erl -pa ./lib/ruby/ebin -noshell -eval "
case ruby_tokenizer:tokenize(\"$1\") of
  {ok, Tokens, Line} ->
    io:format(\"~n=== Input ===~n~s~n~n\", [\"$1\"]),
    io:format(\"=== Tokens ===~n\", []),
    lists:foreach(fun(Token) -> io:format(\"  ~p~n\", [Token]) end, Tokens),
    io:format(\"~n=== Summary ===~n\", []),
    io:format(\"Total tokens: ~p~n\", [length(Tokens)]),
    io:format(\"End line: ~p~n~n\", [Line]);
  {error, ErrorInfo, Line} ->
    io:format(\"~nError at line ~p: ~p~n~n\", [Line, ErrorInfo])
end,
halt().
"
