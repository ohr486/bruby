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
    {23, "Variable shadowing", "x = 100; if true x = 200 end; x"},
    {24, "Binding object creation", "x = 10; y = 20; binding()"},
    {25, "Binding in method", "def get_binding(a, b) c = a + b; binding() end; get_binding(5, 3)"}
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

io:format("~n=== Namespace Management Demo ===~n"),
io:format("~nThe ruby_scope module now supports namespace management for constants.~n"),
io:format("This is the foundation for Ruby constant resolution (A::B::C).~n~n"),

% 名前空間のデモ
io:format("Demo 1: Creating top-level namespace~n"),
TopLevel = ruby_scope:new_namespace(),
io:format("  TopLevel = ruby_scope:new_namespace()~n"),
io:format("  Result: ~p~n~n", [TopLevel]),

io:format("Demo 2: Binding a constant~n"),
PI_Atom = list_to_atom("PI"),
NS1 = ruby_scope:bind_constant(PI_Atom, 3.14159, TopLevel),
io:format("  NS1 = ruby_scope:bind_constant(~p, 3.14159, TopLevel)~n", [PI_Atom]),
{ok, PIValue} = ruby_scope:lookup_constant(PI_Atom, NS1),
io:format("  {ok, ~p} = ruby_scope:lookup_constant(~p, NS1)~n~n", [PIValue, PI_Atom]),

io:format("Demo 3: Creating nested namespaces (A::B::C)~n"),
% A namespace
A_Atom = list_to_atom("A"),
ANS = ruby_scope:new_namespace(A_Atom, NS1),
NS2 = ruby_scope:bind_constant(A_Atom, ANS, NS1),
io:format("  Created namespace A~n"),

% A::B namespace
B_Atom = list_to_atom("B"),
BNS = ruby_scope:new_namespace(B_Atom, ANS),
ANS2 = ruby_scope:bind_constant(B_Atom, BNS, ANS),
NS3 = ruby_scope:bind_constant(A_Atom, ANS2, NS2),
io:format("  Created namespace A::B~n"),

% A::B::VALUE constant
VALUE_Atom = list_to_atom("VALUE"),
BNS2 = ruby_scope:bind_constant(VALUE_Atom, 42, BNS),
ANS3 = ruby_scope:bind_constant(B_Atom, BNS2, ANS2),
NS4 = ruby_scope:bind_constant(A_Atom, ANS3, NS3),
io:format("  Bound constant A::B::VALUE = 42~n"),

% Lookup nested constant
{ok, ConstValue} = ruby_scope:lookup_constant_path([A_Atom, B_Atom, VALUE_Atom], NS4),
io:format("  {ok, ~p} = ruby_scope:lookup_constant_path([~p, ~p, ~p], NS4)~n~n", [ConstValue, A_Atom, B_Atom, VALUE_Atom]),

io:format("Demo 4: Nesting information~n"),
Nesting = ruby_scope:get_nesting(BNS2),
io:format("  Nesting of A::B namespace: ~p~n~n", [Nesting]),

io:format("~n=== Evaluator Test completed ===~n"),
io:format("To try your own code, use:~n"),
io:format("  erl -pa lib/ruby/ebin~n"),
io:format("  ruby_evaluator:eval_string(\"your code here\").~n"),
io:format("~nFor namespace operations:~n"),
io:format("  ruby_scope:new_namespace()~n"),
NameAtom = list_to_atom("Name"),
io:format("  ruby_scope:bind_constant(~p, Value, Namespace)~n", [NameAtom]),
io:format("  ruby_scope:lookup_constant(~p, Namespace)~n", [NameAtom]),
ABC_Atoms = [list_to_atom("A"), list_to_atom("B"), list_to_atom("C")],
io:format("  ruby_scope:lookup_constant_path(~p, Namespace)~n~n", [ABC_Atoms])
' -s init stop
