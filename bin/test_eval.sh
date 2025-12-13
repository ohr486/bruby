#!/bin/bash
# bruby Evaluator Test Script

cd "$(dirname "$0")/.."

echo "=== bruby Evaluator Test ==="
echo ""

erl -pa lib/ruby/ebin -noshell -eval '
io:format("~nEnter Ctrl-C to exit~n~n"),

% テスト用のサンプルコード
Demos = [
    {1, "Basic arithmetic", "1 + 2 * 3"},
    {2, "Variables", "x = 10; y = 20; x + y"},
    {3, "If statement", "x = 15; if x > 10 100 else 200 end"},
    {4, "While loop (count to 5)", "i = 0; while i < 5 i = i + 1 end; i"},
    {5, "Fibonacci (10th number)", "a = 0; b = 1; i = 0; while i < 10 temp = a + b; a = b; b = temp; i = i + 1 end; b"},
    {6, "Nested conditions", "x = 7; if x > 5 if x > 10 100 else 50 end else 10 end"},
    {7, "Logical operators", "true and false or true"},
    {8, "Bitwise operations", "12 & 10"},
    {9, "Complex expression", "((10 + 5) * 2 - 6) / 3"},
    {10, "Variable accumulation", "sum = 0; i = 1; while i <= 10 sum = sum + i; i = i + 1 end; sum"}
],

lists:foreach(fun({Num, Name, Code}) ->
    io:format("Test ~p: ~s~n", [Num, Name]),
    io:format("  Code:   ~s~n", [Code]),
    case ruby_evaluator:eval_string(Code) of
        {ok, Result, _Env} ->
            io:format("  Result: ~p~n", [Result]);
        {error, Error} ->
            io:format("  Error:  ~p~n", [Error])
    end,
    io:format("~n"),
    timer:sleep(100)
end, Demos),

io:format("~n=== Test completed ===~n"),
io:format("To try your own code, use:~n"),
io:format("  erl -pa lib/ruby/ebin~n"),
io:format("  ruby_evaluator:eval_string(\"your code here\").~n~n")
' -s init stop
