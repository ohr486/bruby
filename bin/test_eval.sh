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
    {10, "Variable accumulation", "sum = 0; i = 1; while i <= 10 sum = sum + i; i = i + 1 end; sum"},
    {11, "Method definition and call", "def add(x, y) x + y end; add(3, 4)"},
    {12, "Method with local variable", "def compute(x) y = 10; x + y end; compute(5)"},
    {13, "Method calling method", "def double(x) x * 2 end; def quadruple(x) double(double(x)) end; quadruple(3)"},
    {14, "Method with return", "def check(x) if x > 10 return 999 end; 1 end; check(15)"},
    {15, "Method with expression arg", "def triple(x) x * 3 end; triple(2 + 3)"},
    {16, "Block with yield", "def greet() yield end; greet() { 42 }"},
    {17, "Yield with argument", "def with_value() yield(10) end; with_value() { |n| n * 2 }"},
    {18, "Yield with multiple args", "def add_nums() yield(3, 4) end; add_nums() { |a, b| a + b }"},
    {19, "Block with do...end", "def compute() yield end; compute() do 99 end"},
    {20, "block_given? (with block)", "def check() if block_given? 1 else 0 end end; check() { }"},
    {21, "block_given? (without block)", "def check() if block_given? 1 else 0 end end; check()"},
    {22, "Nested scope (method)", "x = 10; def foo() x = 20; x end; foo()"},
    {23, "Variable shadowing", "x = 100; if true x = 200 end; x"}
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
