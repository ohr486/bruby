-module(test_numeric).
-export([test/0]).

test() ->
  io:format("~n=== Running Ruby Numeric Tests ===~n"),

  % Integer tests
  test_integer_arithmetic(),
  test_integer_comparison(),
  test_integer_conversion(),
  test_integer_methods(),
  test_integer_iteration(),
  test_integer_bitwise(),

  % Float tests
  test_float_arithmetic(),
  test_float_comparison(),
  test_float_conversion(),
  test_float_rounding(),
  test_float_query(),

  io:format("All numeric tests passed!~n"),
  ok.

%% ===================================================================
%% Integer Tests
%% ===================================================================

test_integer_arithmetic() ->
  io:format("  Testing Integer arithmetic operations...~n"),

  % Addition
  7 = ruby_integer:add(3, 4),
  7.5 = ruby_integer:add(3, 4.5),

  % Subtraction
  -1 = ruby_integer:subtract(3, 4),
  -1.5 = ruby_integer:subtract(3, 4.5),

  % Multiplication
  12 = ruby_integer:multiply(3, 4),
  13.5 = ruby_integer:multiply(3, 4.5),

  % Division
  2 = ruby_integer:divide(10, 5),
  3 = ruby_integer:divide(10, 3),
  {error, division_by_zero} = ruby_integer:divide(10, 0),

  % Modulo
  1 = ruby_integer:modulo(10, 3),
  0 = ruby_integer:modulo(10, 5),
  {error, division_by_zero} = ruby_integer:modulo(10, 0),

  % Power
  8 = ruby_integer:power(2, 3),
  1 = ruby_integer:power(5, 0),
  0.125 = ruby_integer:power(2, -3),

  % Abs and negate
  5 = ruby_integer:abs(5),
  5 = ruby_integer:abs(-5),
  -5 = ruby_integer:negate(5),
  5 = ruby_integer:negate(-5),

  ok.

test_integer_comparison() ->
  io:format("  Testing Integer comparison operations...~n"),

  % Compare
  -1 = ruby_integer:compare(3, 5),
  0 = ruby_integer:compare(5, 5),
  1 = ruby_integer:compare(7, 5),

  % Equal
  true = ruby_integer:equal(5, 5),
  false = ruby_integer:equal(5, 3),
  true = ruby_integer:equal(5, 5.0),

  % Not equal
  false = ruby_integer:not_equal(5, 5),
  true = ruby_integer:not_equal(5, 3),

  % Less than
  true = ruby_integer:less_than(3, 5),
  false = ruby_integer:less_than(5, 5),
  false = ruby_integer:less_than(7, 5),

  % Less than or equal
  true = ruby_integer:less_than_or_equal(3, 5),
  true = ruby_integer:less_than_or_equal(5, 5),
  false = ruby_integer:less_than_or_equal(7, 5),

  % Greater than
  false = ruby_integer:greater_than(3, 5),
  false = ruby_integer:greater_than(5, 5),
  true = ruby_integer:greater_than(7, 5),

  % Greater than or equal
  false = ruby_integer:greater_than_or_equal(3, 5),
  true = ruby_integer:greater_than_or_equal(5, 5),
  true = ruby_integer:greater_than_or_equal(7, 5),

  ok.

test_integer_conversion() ->
  io:format("  Testing Integer type conversion...~n"),

  % to_integer
  42 = ruby_integer:to_integer(42),

  % to_float
  42.0 = ruby_integer:to_float(42),

  % to_string
  <<"42">> = ruby_integer:to_string(42),
  <<"-100">> = ruby_integer:to_string(-100),
  <<"1010">> = ruby_integer:to_string(10, 2),  % binary
  <<"A">> = ruby_integer:to_string(10, 16),    % hexadecimal

  ok.

test_integer_methods() ->
  io:format("  Testing Integer methods...~n"),

  % succ and pred
  6 = ruby_integer:succ(5),
  4 = ruby_integer:pred(5),

  % even and odd
  true = ruby_integer:even(4),
  false = ruby_integer:even(5),
  false = ruby_integer:odd(4),
  true = ruby_integer:odd(5),

  % zero, positive, negative
  true = ruby_integer:zero(0),
  false = ruby_integer:zero(5),
  true = ruby_integer:positive(5),
  false = ruby_integer:positive(-5),
  false = ruby_integer:negative(5),
  true = ruby_integer:negative(-5),

  ok.

test_integer_iteration() ->
  io:format("  Testing Integer iteration methods...~n"),

  % times
  ok = ruby_integer:times(3, fun(_) -> ok end),

  % upto
  ok = ruby_integer:upto(1, 5, fun(_) -> ok end),

  % downto
  ok = ruby_integer:downto(5, 1, fun(_) -> ok end),

  ok.

test_integer_bitwise() ->
  io:format("  Testing Integer bitwise operations...~n"),

  % bitwise_and
  8 = ruby_integer:bitwise_and(12, 10),  % 1100 & 1010 = 1000

  % bitwise_or
  14 = ruby_integer:bitwise_or(12, 10),  % 1100 | 1010 = 1110

  % bitwise_xor
  6 = ruby_integer:bitwise_xor(12, 10),  % 1100 ^ 1010 = 0110

  % bitwise_not
  -6 = ruby_integer:bitwise_not(5),

  % left_shift
  20 = ruby_integer:left_shift(5, 2),  % 5 << 2 = 20

  % right_shift
  5 = ruby_integer:right_shift(20, 2),  % 20 >> 2 = 5

  ok.

%% ===================================================================
%% Float Tests
%% ===================================================================

test_float_arithmetic() ->
  io:format("  Testing Float arithmetic operations...~n"),

  % Addition
  7.5 = ruby_float:add(3.5, 4.0),
  7.5 = ruby_float:add(3.5, 4),

  % Subtraction
  -0.5 = ruby_float:subtract(3.5, 4.0),
  -0.5 = ruby_float:subtract(3.5, 4),

  % Multiplication
  14.0 = ruby_float:multiply(3.5, 4.0),
  14.0 = ruby_float:multiply(3.5, 4),

  % Division
  2.5 = ruby_float:divide(10.0, 4.0),
  2.5 = ruby_float:divide(10.0, 4),
  {error, division_by_zero} = ruby_float:divide(10.0, 0),

  % Modulo
  1.0 = ruby_float:modulo(10.0, 3.0),
  1.0 = ruby_float:modulo(10.0, 3),
  {error, division_by_zero} = ruby_float:modulo(10.0, 0),

  % Power
  8.0 = ruby_float:power(2.0, 3),
  8.0 = ruby_float:power(2.0, 3.0),

  % Abs and negate
  5.5 = ruby_float:abs(5.5),
  5.5 = ruby_float:abs(-5.5),
  -5.5 = ruby_float:negate(5.5),
  5.5 = ruby_float:negate(-5.5),

  ok.

test_float_comparison() ->
  io:format("  Testing Float comparison operations...~n"),

  % Compare
  -1 = ruby_float:compare(3.5, 5.0),
  0 = ruby_float:compare(5.0, 5.0),
  1 = ruby_float:compare(7.5, 5.0),

  % Equal
  true = ruby_float:equal(5.0, 5.0),
  false = ruby_float:equal(5.0, 3.5),
  true = ruby_float:equal(5.0, 5),

  % Not equal
  false = ruby_float:not_equal(5.0, 5.0),
  true = ruby_float:not_equal(5.0, 3.5),

  % Less than
  true = ruby_float:less_than(3.5, 5.0),
  false = ruby_float:less_than(5.0, 5.0),
  false = ruby_float:less_than(7.5, 5.0),

  % Less than or equal
  true = ruby_float:less_than_or_equal(3.5, 5.0),
  true = ruby_float:less_than_or_equal(5.0, 5.0),
  false = ruby_float:less_than_or_equal(7.5, 5.0),

  % Greater than
  false = ruby_float:greater_than(3.5, 5.0),
  false = ruby_float:greater_than(5.0, 5.0),
  true = ruby_float:greater_than(7.5, 5.0),

  % Greater than or equal
  false = ruby_float:greater_than_or_equal(3.5, 5.0),
  true = ruby_float:greater_than_or_equal(5.0, 5.0),
  true = ruby_float:greater_than_or_equal(7.5, 5.0),

  ok.

test_float_conversion() ->
  io:format("  Testing Float type conversion...~n"),

  % to_integer
  42 = ruby_float:to_integer(42.7),
  -42 = ruby_float:to_integer(-42.7),

  % to_float
  42.5 = ruby_float:to_float(42.5),

  % to_string
  true = is_binary(ruby_float:to_string(42.5)),

  ok.

test_float_rounding() ->
  io:format("  Testing Float rounding methods...~n"),

  % ceil
  43 = ruby_float:ceil(42.3),
  42 = ruby_float:ceil(42.0),

  % floor
  42 = ruby_float:floor(42.7),
  42 = ruby_float:floor(42.0),

  % round
  42 = ruby_float:round(42.4),
  43 = ruby_float:round(42.5),
  42.35 = ruby_float:round(42.345, 2),

  % truncate
  42 = ruby_float:truncate(42.7),
  -42 = ruby_float:truncate(-42.7),

  ok.

test_float_query() ->
  io:format("  Testing Float query methods...~n"),

  % finite
  true = ruby_float:finite(42.5),

  % zero
  true = ruby_float:zero(0.0),
  false = ruby_float:zero(0.1),

  % positive
  true = ruby_float:positive(5.5),
  false = ruby_float:positive(-5.5),

  % negative
  false = ruby_float:negative(5.5),
  true = ruby_float:negative(-5.5),

  ok.
