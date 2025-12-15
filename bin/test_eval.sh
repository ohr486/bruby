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
io:format("  ruby_object_server:prepend_module(ClassName, ModuleName)~n~n")
' -s init stop
