-module(test_string).
-export([test/0]).

test() ->
  io:format("~n=== Running Ruby String Tests ===~n"),

  test_concatenation(),
  test_splitting(),
  test_search(),
  test_substitution(),
  test_case_conversion(),
  test_length_and_size(),
  test_character_access(),
  test_trimming(),
  test_other_operations(),
  test_conversion(),
  test_comparison(),

  io:format("All string tests passed!~n"),
  ok.

%% ===================================================================
%% Concatenation Tests
%% ===================================================================

test_concatenation() ->
  io:format("  Testing String concatenation operations...~n"),

  % concat with binary
  <<"hello world">> = ruby_string:concat(<<"hello ">>, <<"world">>),
  <<"foobar">> = ruby_string:concat(<<"foo">>, <<"bar">>),

  % concat with string list
  <<"hello world">> = ruby_string:concat("hello ", "world"),

  % concat mixed
  <<"hello world">> = ruby_string:concat(<<"hello ">>, "world"),
  <<"hello world">> = ruby_string:concat("hello ", <<"world">>),

  % append (alias for concat)
  <<"hello world">> = ruby_string:append(<<"hello ">>, <<"world">>),

  ok.

%% ===================================================================
%% Splitting Tests
%% ===================================================================

test_splitting() ->
  io:format("  Testing String splitting operations...~n"),

  % split with default delimiter (space)
  [<<"hello">>, <<"world">>] = ruby_string:split(<<"hello world">>),
  [<<"a">>, <<"b">>, <<"c">>] = ruby_string:split(<<"a b c">>),

  % split with custom delimiter
  [<<"a">>, <<"b">>, <<"c">>] = ruby_string:split(<<"a,b,c">>, <<",">>),
  [<<"hello">>, <<"world">>] = ruby_string:split(<<"hello-world">>, <<"-">>),
  [<<"foo">>, <<"">>, <<"bar">>] = ruby_string:split(<<"foo::bar">>, <<":">>),

  % split with string list
  [<<"a">>, <<"b">>, <<"c">>] = ruby_string:split("a,b,c", ","),

  % chars - split into individual characters
  [<<"h">>, <<"e">>, <<"l">>, <<"l">>, <<"o">>] = ruby_string:chars(<<"hello">>),
  [<<"a">>, <<"b">>, <<"c">>] = ruby_string:chars(<<"abc">>),
  [] = ruby_string:chars(<<>>),

  % chars with UTF-8
  % TODO: UTF-8 handling needs improvement
  % [<<"あ">>, <<"い">>, <<"う">>] = ruby_string:chars(<<"あいう">>),

  ok.

%% ===================================================================
%% Search Tests
%% ===================================================================

test_search() ->
  io:format("  Testing String search operations...~n"),

  % index - find first occurrence
  0 = ruby_string:index(<<"foo">>, <<"f">>),
  1 = ruby_string:index(<<"foo">>, <<"o">>),
  1 = ruby_string:index(<<"foo">>, <<"oo">>),
  nil = ruby_string:index(<<"foo">>, <<"x">>),

  % index with offset
  1 = ruby_string:index(<<"foo">>, <<"o">>, 0),
  1 = ruby_string:index(<<"foo">>, <<"o">>, 1),
  2 = ruby_string:index(<<"foo">>, <<"o">>, 2),
  nil = ruby_string:index(<<"foo">>, <<"o">>, 3),

  % index with negative offset
  2 = ruby_string:index(<<"foo">>, <<"o">>, -1),
  1 = ruby_string:index(<<"foo">>, <<"o">>, -2),

  % rindex - find last occurrence
  0 = ruby_string:rindex(<<"foo">>, <<"f">>),
  2 = ruby_string:rindex(<<"foo">>, <<"o">>),
  1 = ruby_string:rindex(<<"foo">>, <<"oo">>),
  nil = ruby_string:rindex(<<"foo">>, <<"x">>),

  % rindex with offset
  2 = ruby_string:rindex(<<"foo">>, <<"o">>, 2),
  1 = ruby_string:rindex(<<"foo">>, <<"o">>, 1),
  nil = ruby_string:rindex(<<"foo">>, <<"o">>, 0),

  ok.

%% ===================================================================
%% Substitution Tests
%% ===================================================================

test_substitution() ->
  io:format("  Testing String substitution operations...~n"),

  % sub - replace first occurrence
  <<"fXo">> = ruby_string:sub(<<"foo">>, <<"o">>, <<"X">>),
  <<"hXllo">> = ruby_string:sub(<<"hello">>, <<"e">>, <<"X">>),
  <<"hello">> = ruby_string:sub(<<"hello">>, <<"x">>, <<"X">>),

  % gsub - replace all occurrences
  <<"fXX">> = ruby_string:gsub(<<"foo">>, <<"o">>, <<"X">>),
  <<"heXXo">> = ruby_string:gsub(<<"hello">>, <<"l">>, <<"X">>),
  <<"XXX">> = ruby_string:gsub(<<"aaa">>, <<"a">>, <<"X">>),
  <<"hello">> = ruby_string:gsub(<<"hello">>, <<"x">>, <<"X">>),

  % gsub with empty replacement
  <<"f">> = ruby_string:gsub(<<"foo">>, <<"o">>, <<>>),

  ok.

%% ===================================================================
%% Case Conversion Tests
%% ===================================================================

test_case_conversion() ->
  io:format("  Testing String case conversion operations...~n"),

  % upcase
  <<"HELLO">> = ruby_string:upcase(<<"hello">>),
  <<"ABC">> = ruby_string:upcase(<<"abc">>),
  <<"HELLO WORLD">> = ruby_string:upcase(<<"hello world">>),
  <<"123">> = ruby_string:upcase(<<"123">>),

  % downcase
  <<"hello">> = ruby_string:downcase(<<"HELLO">>),
  <<"abc">> = ruby_string:downcase(<<"ABC">>),
  <<"hello world">> = ruby_string:downcase(<<"HELLO WORLD">>),
  <<"123">> = ruby_string:downcase(<<"123">>),

  % capitalize
  <<"Hello">> = ruby_string:capitalize(<<"hello">>),
  <<"Hello world">> = ruby_string:capitalize(<<"hello world">>),
  <<"Hello">> = ruby_string:capitalize(<<"HELLO">>),
  <<>> = ruby_string:capitalize(<<>>),

  % swapcase
  <<"HELLO">> = ruby_string:swapcase(<<"hello">>),
  <<"hello">> = ruby_string:swapcase(<<"HELLO">>),
  <<"hELLO wORLD">> = ruby_string:swapcase(<<"Hello World">>),

  ok.

%% ===================================================================
%% Length and Size Tests
%% ===================================================================

test_length_and_size() ->
  io:format("  Testing String length and size operations...~n"),

  % length
  5 = ruby_string:length(<<"hello">>),
  0 = ruby_string:length(<<>>),
  11 = ruby_string:length(<<"hello world">>),

  % size (alias for length)
  5 = ruby_string:size(<<"hello">>),
  0 = ruby_string:size(<<>>),

  % bytesize
  5 = ruby_string:bytesize(<<"hello">>),
  0 = ruby_string:bytesize(<<>>),
  % TODO: UTF-8 bytesize test needs encoding fix
  % 9 = ruby_string:bytesize(<<"あいう">>),  % UTF-8: 3 bytes per character

  % empty
  true = ruby_string:empty(<<>>),
  false = ruby_string:empty(<<"hello">>),
  true = ruby_string:empty([]),
  false = ruby_string:empty("hello"),

  ok.

%% ===================================================================
%% Character Access Tests
%% ===================================================================

test_character_access() ->
  io:format("  Testing String character access operations...~n"),

  % chr - access character by index
  <<"h">> = ruby_string:chr(<<"hello">>, 0),
  <<"e">> = ruby_string:chr(<<"hello">>, 1),
  <<"o">> = ruby_string:chr(<<"hello">>, 4),
  nil = ruby_string:chr(<<"hello">>, 5),

  % chr with negative index
  <<"o">> = ruby_string:chr(<<"hello">>, -1),
  <<"l">> = ruby_string:chr(<<"hello">>, -2),
  <<"h">> = ruby_string:chr(<<"hello">>, -5),
  nil = ruby_string:chr(<<"hello">>, -6),

  ok.

%% ===================================================================
%% Trimming Tests
%% ===================================================================

test_trimming() ->
  io:format("  Testing String trimming operations...~n"),

  % strip - remove leading and trailing whitespace
  <<"hello">> = ruby_string:strip(<<"  hello  ">>),
  <<"hello">> = ruby_string:strip(<<"hello">>),
  <<"hello world">> = ruby_string:strip(<<"  hello world  ">>),

  % lstrip - remove leading whitespace
  <<"hello  ">> = ruby_string:lstrip(<<"  hello  ">>),
  <<"hello">> = ruby_string:lstrip(<<"hello">>),

  % rstrip - remove trailing whitespace
  <<"  hello">> = ruby_string:rstrip(<<"  hello  ">>),
  <<"hello">> = ruby_string:rstrip(<<"hello">>),

  % chomp - remove trailing newline
  <<"hello">> = ruby_string:chomp(<<"hello\n">>),
  <<"hello">> = ruby_string:chomp(<<"hello">>),
  <<"hello\nworld">> = ruby_string:chomp(<<"hello\nworld\n">>),

  % chomp with custom separator
  <<"hello">> = ruby_string:chomp(<<"hello world">>, <<" world">>),
  <<"hello">> = ruby_string:chomp(<<"hello">>, <<"x">>),

  ok.

%% ===================================================================
%% Other Operations Tests
%% ===================================================================

test_other_operations() ->
  io:format("  Testing String other operations...~n"),

  % reverse
  <<"olleh">> = ruby_string:reverse(<<"hello">>),
  <<>> = ruby_string:reverse(<<>>),
  <<"cba">> = ruby_string:reverse(<<"abc">>),

  ok.

%% ===================================================================
%% Conversion Tests
%% ===================================================================

test_conversion() ->
  io:format("  Testing String conversion operations...~n"),

  % to_string
  <<"hello">> = ruby_string:to_string(<<"hello">>),
  <<"hello">> = ruby_string:to_string("hello"),
  <<"42">> = ruby_string:to_string(42),
  <<"true">> = ruby_string:to_string(true),

  % to_integer
  {ok, 42} = ruby_string:to_integer(<<"42">>),
  {ok, -100} = ruby_string:to_integer(<<"-100">>),
  {error, invalid_integer} = ruby_string:to_integer(<<"hello">>),

  % to_float
  {ok, 3.14} = ruby_string:to_float(<<"3.14">>),
  {ok, -2.5} = ruby_string:to_float(<<"-2.5">>),
  {ok, 42.0} = ruby_string:to_float(<<"42">>),
  {error, invalid_float} = ruby_string:to_float(<<"hello">>),

  % to_atom
  hello = ruby_string:to_atom(<<"hello">>),
  test = ruby_string:to_atom("test"),

  ok.

%% ===================================================================
%% Comparison Tests
%% ===================================================================

test_comparison() ->
  io:format("  Testing String comparison operations...~n"),

  % equal
  true = ruby_string:equal(<<"hello">>, <<"hello">>),
  false = ruby_string:equal(<<"hello">>, <<"world">>),
  true = ruby_string:equal("hello", "hello"),
  true = ruby_string:equal(<<"hello">>, "hello"),

  % compare
  0 = ruby_string:compare(<<"hello">>, <<"hello">>),
  -1 = ruby_string:compare(<<"abc">>, <<"xyz">>),
  1 = ruby_string:compare(<<"xyz">>, <<"abc">>),

  ok.
