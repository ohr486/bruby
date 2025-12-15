%% @doc Ruby Integer class implementation
%% This module provides built-in methods for Ruby Integer class.
-module(ruby_integer).

-export([
    % Arithmetic operations
    add/2,
    subtract/2,
    multiply/2,
    divide/2,
    modulo/2,
    power/2,
    abs/1,
    negate/1,

    % Comparison operations
    compare/2,
    equal/2,
    not_equal/2,
    less_than/2,
    less_than_or_equal/2,
    greater_than/2,
    greater_than_or_equal/2,

    % Type conversion
    to_integer/1,
    to_float/1,
    to_string/1,
    to_string/2,

    % Other methods
    succ/1,
    pred/1,
    even/1,
    odd/1,
    zero/1,
    positive/1,
    negative/1,

    % Iteration methods
    times/2,
    upto/3,
    downto/3,

    % Bitwise operations
    bitwise_and/2,
    bitwise_or/2,
    bitwise_xor/2,
    bitwise_not/1,
    left_shift/2,
    right_shift/2
]).

-type ruby_integer() :: integer().
-type ruby_value() :: integer() | float() | binary() | atom().

%% ===================================================================
%% Arithmetic Operations
%% ===================================================================

-spec add(ruby_integer(), ruby_value()) -> integer() | float().
add(X, Y) when is_integer(X), is_integer(Y) -> X + Y;
add(X, Y) when is_integer(X), is_float(Y) -> X + Y.

-spec subtract(ruby_integer(), ruby_value()) -> integer() | float().
subtract(X, Y) when is_integer(X), is_integer(Y) -> X - Y;
subtract(X, Y) when is_integer(X), is_float(Y) -> X - Y.

-spec multiply(ruby_integer(), ruby_value()) -> integer() | float().
multiply(X, Y) when is_integer(X), is_integer(Y) -> X * Y;
multiply(X, Y) when is_integer(X), is_float(Y) -> X * Y.

-spec divide(ruby_integer(), ruby_value()) -> integer() | {error, atom()}.
divide(_, 0) -> {error, division_by_zero};
divide(X, Y) when is_integer(X), is_float(Y), Y == 0.0 -> {error, division_by_zero};
divide(X, Y) when is_integer(X), is_integer(Y) -> X div Y;
divide(X, Y) when is_integer(X), is_float(Y) -> trunc(X / Y).

-spec modulo(ruby_integer(), ruby_value()) -> integer() | {error, atom()}.
modulo(_, 0) -> {error, division_by_zero};
modulo(X, Y) when is_integer(X), is_integer(Y) -> X rem Y.

-spec power(ruby_integer(), integer()) -> integer() | float().
power(X, Y) when is_integer(X), is_integer(Y), Y >= 0 ->
    pow_helper(X, Y);
power(X, Y) when is_integer(X), is_integer(Y), Y < 0 ->
    1.0 / pow_helper(X, -Y).

%% Helper for power calculation
-spec pow_helper(integer(), integer()) -> integer().
pow_helper(_, 0) -> 1;
pow_helper(X, 1) -> X;
pow_helper(X, Y) ->
    case Y rem 2 of
        0 ->
            Half = pow_helper(X, Y div 2),
            Half * Half;
        1 ->
            X * pow_helper(X, Y - 1)
    end.

-spec abs(ruby_integer()) -> integer().
abs(X) when is_integer(X) -> erlang:abs(X).

-spec negate(ruby_integer()) -> integer().
negate(X) when is_integer(X) -> -X.

%% ===================================================================
%% Comparison Operations
%% ===================================================================

-spec compare(ruby_integer(), ruby_value()) -> -1 | 0 | 1.
compare(X, Y) when is_integer(X), is_integer(Y) ->
    if
        X < Y -> -1;
        X > Y -> 1;
        true -> 0
    end;
compare(X, Y) when is_integer(X), is_float(Y) ->
    if
        X < Y -> -1;
        X > Y -> 1;
        true -> 0
    end.

-spec equal(ruby_integer(), ruby_value()) -> boolean().
equal(X, Y) when is_integer(X), is_integer(Y) -> X =:= Y;
equal(X, Y) when is_integer(X), is_float(Y) -> X == Y.

-spec not_equal(ruby_integer(), ruby_value()) -> boolean().
not_equal(X, Y) -> not equal(X, Y).

-spec less_than(ruby_integer(), ruby_value()) -> boolean().
less_than(X, Y) when is_integer(X), (is_integer(Y) orelse is_float(Y)) -> X < Y.

-spec less_than_or_equal(ruby_integer(), ruby_value()) -> boolean().
less_than_or_equal(X, Y) when is_integer(X), (is_integer(Y) orelse is_float(Y)) -> X =< Y.

-spec greater_than(ruby_integer(), ruby_value()) -> boolean().
greater_than(X, Y) when is_integer(X), (is_integer(Y) orelse is_float(Y)) -> X > Y.

-spec greater_than_or_equal(ruby_integer(), ruby_value()) -> boolean().
greater_than_or_equal(X, Y) when is_integer(X), (is_integer(Y) orelse is_float(Y)) -> X >= Y.

%% ===================================================================
%% Type Conversion
%% ===================================================================

-spec to_integer(ruby_integer()) -> integer().
to_integer(X) when is_integer(X) -> X.

-spec to_float(ruby_integer()) -> float().
to_float(X) when is_integer(X) -> float(X).

-spec to_string(ruby_integer()) -> binary().
to_string(X) when is_integer(X) ->
    list_to_binary(integer_to_list(X)).

-spec to_string(ruby_integer(), integer()) -> binary().
to_string(X, Base) when is_integer(X), is_integer(Base), Base >= 2, Base =< 36 ->
    list_to_binary(integer_to_list(X, Base)).

%% ===================================================================
%% Other Methods
%% ===================================================================

-spec succ(ruby_integer()) -> integer().
succ(X) when is_integer(X) -> X + 1.

-spec pred(ruby_integer()) -> integer().
pred(X) when is_integer(X) -> X - 1.

-spec even(ruby_integer()) -> boolean().
even(X) when is_integer(X) -> X rem 2 =:= 0.

-spec odd(ruby_integer()) -> boolean().
odd(X) when is_integer(X) -> X rem 2 =/= 0.

-spec zero(ruby_integer()) -> boolean().
zero(X) when is_integer(X) -> X =:= 0.

-spec positive(ruby_integer()) -> boolean().
positive(X) when is_integer(X) -> X > 0.

-spec negative(ruby_integer()) -> boolean().
negative(X) when is_integer(X) -> X < 0.

%% ===================================================================
%% Iteration Methods
%% ===================================================================

-spec times(ruby_integer(), fun((integer()) -> any())) -> ok.
times(N, Fun) when is_integer(N), N >= 0 ->
    times_helper(0, N, Fun).

times_helper(I, N, Fun) when I < N ->
    Fun(I),
    times_helper(I + 1, N, Fun);
times_helper(_, _, _) ->
    ok.

-spec upto(ruby_integer(), integer(), fun((integer()) -> any())) -> ok.
upto(From, To, Fun) when is_integer(From), is_integer(To), From =< To ->
    upto_helper(From, To, Fun);
upto(_, _, _) ->
    ok.

upto_helper(I, To, Fun) when I =< To ->
    Fun(I),
    upto_helper(I + 1, To, Fun);
upto_helper(_, _, _) ->
    ok.

-spec downto(ruby_integer(), integer(), fun((integer()) -> any())) -> ok.
downto(From, To, Fun) when is_integer(From), is_integer(To), From >= To ->
    downto_helper(From, To, Fun);
downto(_, _, _) ->
    ok.

downto_helper(I, To, Fun) when I >= To ->
    Fun(I),
    downto_helper(I - 1, To, Fun);
downto_helper(_, _, _) ->
    ok.

%% ===================================================================
%% Bitwise Operations
%% ===================================================================

-spec bitwise_and(ruby_integer(), integer()) -> integer().
bitwise_and(X, Y) when is_integer(X), is_integer(Y) -> X band Y.

-spec bitwise_or(ruby_integer(), integer()) -> integer().
bitwise_or(X, Y) when is_integer(X), is_integer(Y) -> X bor Y.

-spec bitwise_xor(ruby_integer(), integer()) -> integer().
bitwise_xor(X, Y) when is_integer(X), is_integer(Y) -> X bxor Y.

-spec bitwise_not(ruby_integer()) -> integer().
bitwise_not(X) when is_integer(X) -> bnot X.

-spec left_shift(ruby_integer(), integer()) -> integer().
left_shift(X, Y) when is_integer(X), is_integer(Y) -> X bsl Y.

-spec right_shift(ruby_integer(), integer()) -> integer().
right_shift(X, Y) when is_integer(X), is_integer(Y) -> X bsr Y.
