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

io:format("~n=== Ruby Value Module Demo ===~n"),
io:format("~nThe ruby_value module provides type checking, type conversion, and equality operations.~n~n"),

% 型チェックのデモ
io:format("Demo 1: Type checking~n"),
io:format("  ruby_value:is_ruby_integer(42) = ~p~n", [ruby_value:is_ruby_integer(42)]),
io:format("  ruby_value:is_ruby_string(\"hello\") = ~p~n", [ruby_value:is_ruby_string("hello")]),
io:format("  ruby_value:is_ruby_nil(nil) = ~p~n", [ruby_value:is_ruby_nil(nil)]),
io:format("  ruby_value:is_ruby_number(3.14) = ~p~n~n", [ruby_value:is_ruby_number(3.14)]),

% 型変換のデモ
io:format("Demo 2: Type conversion~n"),
{ok, Int1} = ruby_value:to_integer("42"),
io:format("  ruby_value:to_integer(\"42\") = {ok, ~p}~n", [Int1]),
{ok, Str1} = ruby_value:to_string(123),
io:format("  ruby_value:to_string(123) = {ok, \"~s\"}~n", [Str1]),
{ok, Float1} = ruby_value:to_float("3.14"),
io:format("  ruby_value:to_float(\"3.14\") = {ok, ~p}~n~n", [Float1]),

% 等価性チェックのデモ
io:format("Demo 3: Equality checking~n"),
io:format("  ruby_value:equal(42, 42) = ~p~n", [ruby_value:equal(42, 42)]),
io:format("  ruby_value:equal(42, 42.0) = ~p  (== allows numeric type coercion)~n", [ruby_value:equal(42, 42.0)]),
io:format("  ruby_value:eql(42, 42) = ~p~n", [ruby_value:eql(42, 42)]),
io:format("  ruby_value:eql(42, 42.0) = ~p  (eql? requires same type)~n", [ruby_value:eql(42, 42.0)]),
io:format("  ruby_value:identical(42, 42) = ~p~n~n", [ruby_value:identical(42, 42)]),

io:format("~n=== Object System Demo ===~n"),
io:format("~nThe ruby_object_server module provides the complete object model for bruby.~n"),
io:format("This includes Object, Class, and Module base classes, object ID management,~n"),
io:format("instance variable management, and metaprogramming foundation (method tables,~n"),
io:format("method lookup, method dispatch, method cache, attr_accessor/reader/writer,~n"),
io:format("define_method, send, and method_missing).~n~n"),

% rubyアプリケーションを起動（ruby_object_serverを含む）
application:ensure_all_started(ruby),

% オブジェクトシステムのデモ
io:format("Demo 1: Creating a new object~n"),
MyClassAtom0 = list_to_atom("MyClass"),
{ok, Obj1} = ruby_object_server:new_instance(MyClassAtom0),
io:format("  {ok, Obj1} = ruby_object_server:new_instance(MyClass)~n"),
{ok, ObjClass1} = ruby_object_server:get_class(Obj1),
io:format("  {ok, ~p} = ruby_object_server:get_class(Obj1)~n", [ObjClass1]),
{ok, ObjId1} = ruby_object_server:get_object_id(Obj1),
io:format("  {ok, ~p} = ruby_object_server:get_object_id(Obj1)~n~n", [ObjId1]),

io:format("Demo 2: Setting instance variables~n"),
NameAtom2 = list_to_atom("@name"),
AgeAtom = list_to_atom("@age"),
Obj2 = ruby_object_server:set_instance_var(Obj1, NameAtom2, "Alice"),
Obj3 = ruby_object_server:set_instance_var(Obj2, AgeAtom, 30),
io:format("  Obj2 = ruby_object_server:set_instance_var(Obj1, ~p, \"Alice\")~n", [NameAtom2]),
io:format("  Obj3 = ruby_object_server:set_instance_var(Obj2, ~p, 30)~n~n", [AgeAtom]),

io:format("Demo 3: Getting instance variables~n"),
{ok, NameValue} = ruby_object_server:get_instance_var(Obj3, NameAtom2),
{ok, AgeValue} = ruby_object_server:get_instance_var(Obj3, AgeAtom),
io:format("  {ok, \"~s\"} = ruby_object_server:get_instance_var(Obj3, ~p)~n", [NameValue, NameAtom2]),
io:format("  {ok, ~p} = ruby_object_server:get_instance_var(Obj3, ~p)~n~n", [AgeValue, AgeAtom]),

io:format("Demo 4: Getting all instance variables~n"),
{ok, AllVars} = ruby_object_server:get_instance_vars(Obj3),
io:format("  {ok, ~p} = ruby_object_server:get_instance_vars(Obj3)~n~n", [AllVars]),

io:format("Demo 5: Base classes~n"),
ObjectClass = ruby_object_server:object_class(),
ClassClass = ruby_object_server:class_class(),
ModuleClass = ruby_object_server:module_class(),
io:format("  Object class: ~p~n", [ObjectClass]),
io:format("  Class class:  ~p~n", [ClassClass]),
io:format("  Module class: ~p~n~n", [ModuleClass]),

io:format("Demo 6: Instance check~n"),
MyClassAtom = list_to_atom("MyClass"),
OtherClassAtom = list_to_atom("OtherClass"),
IsInstance = ruby_object_server:is_instance_of(Obj3, MyClassAtom),
NotInstance = ruby_object_server:is_instance_of(Obj3, OtherClassAtom),
io:format("  ruby_object_server:is_instance_of(Obj3, MyClass) = ~p~n", [IsInstance]),
io:format("  ruby_object_server:is_instance_of(Obj3, OtherClass) = ~p~n~n", [NotInstance]),

io:format("~n=== Metaprogramming Foundation Demo ===~n"),
io:format("~nDemonstrating method tables, method lookup, method cache, and dynamic method definition.~n~n"),

% Demo 7: Method table management
io:format("Demo 7: Method table management~n"),
PersonAtom = list_to_atom("Person"),
GreetMethod = #{
    name => greet,
    params => [],
    body => "Hello from method table!",
    closure_env => nil
},
ok = ruby_object_server:define_class_method(PersonAtom, greet, GreetMethod),
io:format("  Defined greet method on Person class~n"),
{ok, _Method} = ruby_object_server:lookup_method(PersonAtom, greet),
io:format("  Successfully looked up greet method~n"),
{ok, Methods7} = ruby_object_server:get_class_methods(PersonAtom),
io:format("  Person class has ~p methods~n~n", [maps:size(Methods7)]),

% Demo 8: attr_accessor
io:format("Demo 8: attr_accessor~n"),
ProductAtom = list_to_atom("Product"),
ok = ruby_object_server:attr_accessor(ProductAtom, [name, price]),
io:format("  Created attr_accessor for :name and :price on Product~n"),
{ok, ProductMethods} = ruby_object_server:get_class_methods(ProductAtom),
io:format("  Product class now has ~p methods (name, name=, price, price=)~n~n", [maps:size(ProductMethods)]),

% Demo 9: attr_reader
io:format("Demo 9: attr_reader~n"),
BookAtom = list_to_atom("Book"),
ok = ruby_object_server:attr_reader(BookAtom, [title, author]),
io:format("  Created attr_reader for :title and :author on Book~n"),
{ok, BookMethods} = ruby_object_server:get_class_methods(BookAtom),
io:format("  Book class now has ~p methods (title, author - read only)~n~n", [maps:size(BookMethods)]),

% Demo 10: attr_writer
io:format("Demo 10: attr_writer~n"),
ConfigAtom = list_to_atom("Config"),
ok = ruby_object_server:attr_writer(ConfigAtom, [debug, verbose]),
io:format("  Created attr_writer for :debug and :verbose on Config~n"),
{ok, ConfigMethods} = ruby_object_server:get_class_methods(ConfigAtom),
io:format("  Config class now has ~p methods (debug=, verbose= - write only)~n~n", [maps:size(ConfigMethods)]),

% Demo 11: define_method
io:format("Demo 11: define_method~n"),
CalculatorAtom = list_to_atom("Calculator"),
AddMethod = #{
    name => add,
    params => [a, b],
    body => {add_op, {var, a}, {var, b}},
    closure_env => nil
},
ok = ruby_object_server:define_method(CalculatorAtom, add, [a, b], {add_op, {var, a}, {var, b}}),
io:format("  Dynamically defined add method on Calculator~n"),
{ok, _AddMethod} = ruby_object_server:lookup_method(CalculatorAtom, add),
io:format("  Successfully looked up dynamically defined add method~n~n"),

% Demo 12: method_missing
io:format("Demo 12: method_missing~n"),
DynamicAtom = list_to_atom("DynamicClass"),
MissingHandler = #{
    name => method_missing,
    params => [method_name, args],
    body => "Method not found handler",
    closure_env => nil
},
ok = ruby_object_server:set_method_missing(DynamicAtom, method_missing, MissingHandler),
io:format("  Set method_missing handler on DynamicClass~n"),
HasMissing = ruby_object_server:has_method_missing(DynamicAtom),
io:format("  DynamicClass has method_missing: ~p~n~n", [HasMissing]),

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
io:format("  ruby_scope:lookup_constant_path(~p, Namespace)~n", [ABC_Atoms]),
io:format("~nFor value operations:~n"),
io:format("  ruby_value:is_ruby_integer(42)~n"),
io:format("  ruby_value:to_string(Value)~n"),
io:format("  ruby_value:equal(Value1, Value2)~n"),
io:format("~nFor object system operations:~n"),
io:format("  {ok, Obj} = ruby_object_server:new_instance(MyClass)~n"),
io:format("  ruby_object_server:set_instance_var(Obj, Name, Value)~n"),
io:format("  ruby_object_server:get_instance_var(Obj, Name)~n"),
io:format("  ruby_object_server:get_class(Obj)~n"),
io:format("  ruby_object_server:get_object_id(Obj)~n"),
io:format("~nFor metaprogramming operations:~n"),
io:format("  ruby_object_server:define_class_method(MyClass, method_name, MethodDef)~n"),
io:format("  ruby_object_server:lookup_method(MyClass, method_name)~n"),
io:format("  ruby_object_server:get_class_methods(MyClass)~n"),
io:format("  ruby_object_server:attr_accessor(MyClass, [attr1, attr2])~n"),
io:format("  ruby_object_server:attr_reader(MyClass, [attr])~n"),
io:format("  ruby_object_server:attr_writer(MyClass, [attr])~n"),
io:format("  ruby_object_server:define_method(MyClass, name, params, body)~n"),
io:format("  ruby_object_server:method_send(obj, method_name, args, env)~n"),
io:format("  ruby_object_server:set_method_missing(MyClass, handler)~n~n"),

io:format("~n=== Inheritance and Mixin Demo ===~n"),
io:format("~nThe ruby_object_server module now supports inheritance and mixins.~n"),
io:format("This includes superclass, ancestors, include, and prepend.~n~n"),

% 継承のデモ
io:format("Demo 1: Class inheritance~n"),
AnimalAtom = list_to_atom("Animal"),
DogAtom = list_to_atom("Dog"),
ok = ruby_object_server:register_class(AnimalAtom, nil),
ok = ruby_object_server:register_class(DogAtom, AnimalAtom),
io:format("  Registered classes: Animal (parent), Dog (child)~n"),
{ok, SuperClass} = ruby_object_server:get_superclass(DogAtom),
io:format("  Dog.superclass = ~p~n~n", [SuperClass]),

io:format("Demo 2: Ancestors chain~n"),
{ok, DogAncestors} = ruby_object_server:get_ancestors(DogAtom),
io:format("  Dog.ancestors = ~p~n~n", [DogAncestors]),

% モジュールのinclude
io:format("Demo 3: Module include~n"),
WalkableAtom = list_to_atom("Walkable"),
ok = ruby_object_server:register_module(WalkableAtom),
ok = ruby_object_server:include_module(DogAtom, WalkableAtom),
io:format("  Dog.include(Walkable)~n"),
{ok, DogAncestors2} = ruby_object_server:get_ancestors(DogAtom),
io:format("  Dog.ancestors = ~p~n~n", [DogAncestors2]),

% モジュールのprepend
io:format("Demo 4: Module prepend~n"),
RunnableAtom = list_to_atom("Runnable"),
ok = ruby_object_server:register_module(RunnableAtom),
ok = ruby_object_server:prepend_module(DogAtom, RunnableAtom),
io:format("  Dog.prepend(Runnable)~n"),
{ok, DogAncestors3} = ruby_object_server:get_ancestors(DogAtom),
io:format("  Dog.ancestors = ~p~n", [DogAncestors3]),
io:format("  (Note: Runnable comes before Dog due to prepend)~n~n"),

% メソッド探索のデモ
io:format("Demo 5: Method lookup with inheritance~n"),
BaseAtom = list_to_atom("Base"),
DerivedAtom = list_to_atom("Derived"),
ok = ruby_object_server:register_class(BaseAtom, nil),
ok = ruby_object_server:register_class(DerivedAtom, BaseAtom),
BaseMethod = #{name => base_method, params => [], body => "from base", closure_env => nil},
ok = ruby_object_server:define_class_method(BaseAtom, base_method, BaseMethod),
{ok, Found} = ruby_object_server:lookup_method(DerivedAtom, base_method),
io:format("  Defined base_method in Base class~n"),
io:format("  Derived.lookup_method(:base_method) found: ~p~n~n", [Found]),

% is_instance_of のデモ
io:format("Demo 6: Instance check with inheritance~n"),
MammalAtom = list_to_atom("Mammal"),
CatAtom = list_to_atom("Cat"),
ok = ruby_object_server:register_class(MammalAtom, nil),
ok = ruby_object_server:register_class(CatAtom, MammalAtom),
{ok, CatObj} = ruby_object_server:new_instance(CatAtom),
IsCat = ruby_object_server:is_instance_of(CatObj, CatAtom),
IsMammal = ruby_object_server:is_instance_of(CatObj, MammalAtom),
BasicObjectAtom = list_to_atom("BasicObject"),
IsBasicObject = ruby_object_server:is_instance_of(CatObj, BasicObjectAtom),
io:format("  Created Cat instance~n"),
io:format("  is_instance_of(obj, Cat) = ~p~n", [IsCat]),
io:format("  is_instance_of(obj, Mammal) = ~p  (parent class)~n", [IsMammal]),
io:format("  is_instance_of(obj, BasicObject) = ~p  (ancestor)~n~n", [IsBasicObject]),

io:format("~nFor inheritance and mixin operations:~n"),
io:format("  ruby_object_server:register_class(ClassName, Superclass)~n"),
io:format("  ruby_object_server:register_module(ModuleName)~n"),
io:format("  ruby_object_server:get_superclass(ClassName)~n"),
io:format("  ruby_object_server:get_ancestors(ClassName)~n"),
io:format("  ruby_object_server:include_module(ClassName, ModuleName)~n"),
io:format("  ruby_object_server:prepend_module(ClassName, ModuleName)~n~n"),

io:format("~n=== Numeric Classes Demo ===~n"),
io:format("~nThe ruby_integer and ruby_float modules provide built-in methods for numeric types.~n~n"),

% Integer クラスのデモ
io:format("Demo 1: Integer arithmetic operations~n"),
IntAdd = ruby_integer:add(3, 4),
IntSub = ruby_integer:subtract(10, 3),
IntMul = ruby_integer:multiply(4, 5),
IntDiv = ruby_integer:divide(20, 4),
IntMod = ruby_integer:modulo(17, 5),
IntPow = ruby_integer:power(2, 3),
io:format("  3 + 4 = ~p~n", [IntAdd]),
io:format("  10 - 3 = ~p~n", [IntSub]),
io:format("  4 * 5 = ~p~n", [IntMul]),
io:format("  20 / 4 = ~p~n", [IntDiv]),
io:format("  17 %% 5 = ~p~n", [IntMod]),
io:format("  2 ** 3 = ~p~n~n", [IntPow]),

io:format("Demo 2: Integer comparison operations~n"),
IntCmp1 = ruby_integer:compare(3, 5),
IntCmp2 = ruby_integer:compare(5, 5),
IntCmp3 = ruby_integer:compare(7, 5),
IntEq = ruby_integer:equal(5, 5),
IntLt = ruby_integer:less_than(3, 5),
io:format("  3 <=> 5 = ~p~n", [IntCmp1]),
io:format("  5 <=> 5 = ~p~n", [IntCmp2]),
io:format("  7 <=> 5 = ~p~n", [IntCmp3]),
io:format("  5 == 5 = ~p~n", [IntEq]),
io:format("  3 < 5 = ~p~n~n", [IntLt]),

io:format("Demo 3: Integer type conversion~n"),
IntToFloat = ruby_integer:to_float(42),
IntToString = ruby_integer:to_string(42),
IntToBinary = ruby_integer:to_string(10, 2),
IntToHex = ruby_integer:to_string(255, 16),
io:format("  42.to_f = ~p~n", [IntToFloat]),
io:format("  42.to_s = ~s~n", [IntToString]),
io:format("  10.to_s(2) = ~s  (binary)~n", [IntToBinary]),
io:format("  255.to_s(16) = ~s  (hexadecimal)~n~n", [IntToHex]),

io:format("Demo 4: Integer utility methods~n"),
IntSucc = ruby_integer:succ(5),
IntPred = ruby_integer:pred(5),
IntEven = ruby_integer:even(4),
IntOdd = ruby_integer:odd(5),
IntAbs = ruby_integer:abs(-10),
io:format("  5.succ = ~p~n", [IntSucc]),
io:format("  5.pred = ~p~n", [IntPred]),
io:format("  4.even? = ~p~n", [IntEven]),
io:format("  5.odd? = ~p~n", [IntOdd]),
io:format("  -10.abs = ~p~n~n", [IntAbs]),

io:format("Demo 5: Integer bitwise operations~n"),
IntAnd = ruby_integer:bitwise_and(12, 10),
IntOr = ruby_integer:bitwise_or(12, 10),
IntXor = ruby_integer:bitwise_xor(12, 10),
IntLshift = ruby_integer:left_shift(5, 2),
IntRshift = ruby_integer:right_shift(20, 2),
io:format("  12 & 10 = ~p  (1100 & 1010 = 1000)~n", [IntAnd]),
io:format("  12 | 10 = ~p  (1100 | 1010 = 1110)~n", [IntOr]),
io:format("  12 ^ 10 = ~p  (1100 ^ 1010 = 0110)~n", [IntXor]),
io:format("  5 << 2 = ~p~n", [IntLshift]),
io:format("  20 >> 2 = ~p~n~n", [IntRshift]),

% Float クラスのデモ
io:format("Demo 6: Float arithmetic operations~n"),
FloatAdd = ruby_float:add(3.5, 4.0),
FloatSub = ruby_float:subtract(10.0, 3.5),
FloatMul = ruby_float:multiply(3.5, 4.0),
FloatDiv = ruby_float:divide(10.0, 4.0),
FloatMod = ruby_float:modulo(10.5, 3.0),
FloatPow = ruby_float:power(2.0, 3),
io:format("  3.5 + 4.0 = ~p~n", [FloatAdd]),
io:format("  10.0 - 3.5 = ~p~n", [FloatSub]),
io:format("  3.5 * 4.0 = ~p~n", [FloatMul]),
io:format("  10.0 / 4.0 = ~p~n", [FloatDiv]),
io:format("  10.5 %% 3.0 = ~p~n", [FloatMod]),
io:format("  2.0 ** 3 = ~p~n~n", [FloatPow]),

io:format("Demo 7: Float rounding methods~n"),
FloatCeil = ruby_float:ceil(42.3),
FloatFloor = ruby_float:floor(42.7),
FloatRound = ruby_float:round(42.5),
FloatRound2 = ruby_float:round(42.345, 2),
FloatTrunc = ruby_float:truncate(42.7),
io:format("  42.3.ceil = ~p~n", [FloatCeil]),
io:format("  42.7.floor = ~p~n", [FloatFloor]),
io:format("  42.5.round = ~p~n", [FloatRound]),
io:format("  42.345.round(2) = ~p~n", [FloatRound2]),
io:format("  42.7.truncate = ~p~n~n", [FloatTrunc]),

io:format("Demo 8: Float type conversion~n"),
FloatToInt = ruby_float:to_integer(42.7),
FloatToString = ruby_float:to_string(3.14159),
io:format("  42.7.to_i = ~p~n", [FloatToInt]),
io:format("  3.14159.to_s = ~s~n~n", [FloatToString]),

io:format("~nFor numeric class operations:~n"),
io:format("  ruby_integer:add(3, 4)~n"),
io:format("  ruby_integer:power(2, 3)~n"),
io:format("  ruby_integer:to_string(42, 16)~n"),
io:format("  ruby_integer:times(5, Fun)~n"),
io:format("  ruby_float:add(3.5, 4.0)~n"),
io:format("  ruby_float:round(42.345, 2)~n"),
io:format("  ruby_float:ceil(42.3)~n~n"),

io:format("~n=== Kernel Module Demo ===~n"),
io:format("~nThe ruby_kernel module provides built-in methods for Ruby Kernel module.~n"),
io:format("Kernel is mixed into Object, so its methods are available in every Ruby object.~n~n"),

% 出力メソッドのデモ
io:format("Demo 1: Output methods~n"),
io:format("  ruby_kernel:puts(42):~n    "),
ruby_kernel:puts(42),
io:format("  ruby_kernel:print(\\\"Hello \\\"):~n    "),
ruby_kernel:print("Hello "),
ruby_kernel:print("World"),
io:format("~n"),
io:format("  ruby_kernel:p(\\\"test\\\"):~n    "),
PResult = ruby_kernel:p("test"),
io:format("    (returns: ~p)~n", [PResult]),
io:format("  ruby_kernel:printf(\\\"Number: ~~p~~n\\\", [100]):~n    "),
ruby_kernel:printf("Number: ~p~n", [100]),
io:format("~n"),

% 型変換メソッドのデモ
io:format("Demo 2: Type conversion methods~n"),
{ok, KInt1} = ruby_kernel:to_integer("42"),
io:format("  ruby_kernel:to_integer(\\\"42\\\") = {ok, ~p}~n", [KInt1]),
{ok, KFloat1} = ruby_kernel:to_float("3.14"),
io:format("  ruby_kernel:to_float(\\\"3.14\\\") = {ok, ~p}~n", [KFloat1]),
{ok, KStr1} = ruby_kernel:to_string(123),
io:format("  ruby_kernel:to_string(123) = {ok, \\\"~s\\\"}~n", [KStr1]),
KArr1 = ruby_kernel:to_array(42),
io:format("  ruby_kernel:to_array(42) = ~p~n~n", [KArr1]),

% オブジェクト検査メソッドのデモ
io:format("Demo 3: Object inspection methods~n"),
KClass1 = ruby_kernel:get_class(42),
io:format("  ruby_kernel:get_class(42) = ~p~n", [KClass1]),
KClass2 = ruby_kernel:get_class(3.14),
io:format("  ruby_kernel:get_class(3.14) = ~p~n", [KClass2]),
KClass3 = ruby_kernel:get_class("hello"),
io:format("  ruby_kernel:get_class(\\\"hello\\\") = ~p~n", [KClass3]),
KClass4 = ruby_kernel:get_class(nil),
io:format("  ruby_kernel:get_class(nil) = ~p~n", [KClass4]),
KClass5 = ruby_kernel:get_class(true),
io:format("  ruby_kernel:get_class(true) = ~p~n~n", [KClass5]),

% is_a? のデモ
IntegerAtom = list_to_atom("Integer"),
FloatAtom = list_to_atom("Float"),
StringAtom = list_to_atom("String"),
io:format("Demo 4: is_a? method~n"),
KIsA1 = ruby_kernel:is_a(42, IntegerAtom),
io:format("  ruby_kernel:is_a(42, 'Integer') = ~p~n", [KIsA1]),
KIsA2 = ruby_kernel:is_a(42, FloatAtom),
io:format("  ruby_kernel:is_a(42, 'Float') = ~p~n", [KIsA2]),
KIsA3 = ruby_kernel:is_a("hello", StringAtom),
io:format("  ruby_kernel:is_a(\\\"hello\\\", 'String') = ~p~n~n", [KIsA3]),

% is_a? with inheritance
VehicleAtom = list_to_atom("Vehicle"),
CarAtom = list_to_atom("Car"),
ok = ruby_object_server:register_class(VehicleAtom, nil),
ok = ruby_object_server:register_class(CarAtom, VehicleAtom),
{ok, CarObj} = ruby_object_server:new_instance(CarAtom),
KIsA4 = ruby_kernel:is_a(CarObj, CarAtom),
KIsA5 = ruby_kernel:is_a(CarObj, VehicleAtom),
io:format("  With inheritance:~n"),
io:format("    car_obj.is_a?('Car') = ~p~n", [KIsA4]),
io:format("    car_obj.is_a?('Vehicle') = ~p  (parent class)~n~n", [KIsA5]),

% respond_to? のデモ
io:format("Demo 5: respond_to? method~n"),
ok = ruby_object_server:define_class_method(
    CarAtom,
    drive,
    #{name => drive, params => [], body => "Driving...", closure_env => nil}
),
KResponds1 = ruby_kernel:respond_to(CarObj, drive),
KResponds2 = ruby_kernel:respond_to(CarObj, fly),
io:format("  car_obj.respond_to?(:drive) = ~p~n", [KResponds1]),
io:format("  car_obj.respond_to?(:fly) = ~p~n~n", [KResponds2]),

% 例外メソッドのデモ
RuntimeErrorAtom = list_to_atom("RuntimeError"),
io:format("Demo 6: Exception methods~n"),
KRaise1 = ruby_kernel:raise("Error message"),
io:format("  ruby_kernel:raise(\\\"Error message\\\") = ~p~n", [KRaise1]),
KRaise2 = ruby_kernel:raise(RuntimeErrorAtom, "Runtime error"),
io:format("  ruby_kernel:raise('RuntimeError', \\\"Runtime error\\\") = ~p~n~n", [KRaise2]),

% catch/throw のデモ
io:format("Demo 7: catch/throw~n"),
KCatch1 = ruby_kernel:catch_throw(fun() -> ruby_kernel:throw(42) end),
io:format("  catch_throw(fun() -> throw(42) end) = ~p~n", [KCatch1]),
KCatch2 = ruby_kernel:catch_throw(fun() -> ruby_kernel:throw(symbol, "value") end),
io:format("  catch_throw(fun() -> throw(symbol, \\\"value\\\") end) = ~p~n", [KCatch2]),
KCatch3 = ruby_kernel:catch_throw(fun() -> 99 end),
io:format("  catch_throw(fun() -> 99 end) = ~p  (no throw)~n~n", [KCatch3]),

io:format("~nFor Kernel module operations:~n"),
io:format("  ruby_kernel:puts(\\\"text\\\")~n"),
io:format("  ruby_kernel:print(\\\"text\\\")~n"),
io:format("  ruby_kernel:p(value)~n"),
io:format("  ruby_kernel:printf(\\\"format\\\", [args])~n"),
io:format("  ruby_kernel:to_integer(\\\"42\\\")~n"),
io:format("  ruby_kernel:to_float(\\\"3.14\\\")~n"),
io:format("  ruby_kernel:to_string(123)~n"),
io:format("  ruby_kernel:to_array(value)~n"),
io:format("  ruby_kernel:get_class(value)~n"),
io:format("  ruby_kernel:is_a(obj, 'ClassName')~n"),
io:format("  ruby_kernel:kind_of(obj, 'ClassName')~n"),
io:format("  ruby_kernel:respond_to(obj, method_name)~n"),
io:format("  ruby_kernel:raise(\\\"message\\\")~n"),
io:format("  ruby_kernel:catch_throw(fun)~n~n")
' -s init stop
