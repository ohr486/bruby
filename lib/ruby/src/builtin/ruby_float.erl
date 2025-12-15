%% @doc Ruby Float class implementation
%% This module provides built-in methods for Ruby Float class.
-module(ruby_float).

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

    % Rounding methods
    ceil/1,
    floor/1,
    round/1,
    round/2,
    truncate/1,

    % Query methods
    finite/1,
    infinite/1,
    nan/1,
    zero/1,
    positive/1,
    negative/1
]).

-type ruby_float() :: float().
-type ruby_value() :: integer() | float() | binary() | atom().

%% ===================================================================
%% Arithmetic Operations
%% ===================================================================

-spec add(ruby_float(), ruby_value()) -> float().
add(X, Y) when is_float(X), is_integer(Y) -> X + Y;
add(X, Y) when is_float(X), is_float(Y) -> X + Y.

-spec subtract(ruby_float(), ruby_value()) -> float().
subtract(X, Y) when is_float(X), is_integer(Y) -> X - Y;
subtract(X, Y) when is_float(X), is_float(Y) -> X - Y.

-spec multiply(ruby_float(), ruby_value()) -> float().
multiply(X, Y) when is_float(X), is_integer(Y) -> X * Y;
multiply(X, Y) when is_float(X), is_float(Y) -> X * Y.

-spec divide(ruby_float(), ruby_value()) -> float() | {error, atom()}.
divide(_, 0) -> {error, division_by_zero};
divide(X, Y) when is_float(X), is_float(Y), Y == 0.0 -> {error, division_by_zero};
divide(X, Y) when is_float(X), is_integer(Y) -> X / Y;
divide(X, Y) when is_float(X), is_float(Y) -> X / Y.

-spec modulo(ruby_float(), ruby_value()) -> float() | {error, atom()}.
modulo(_, 0) -> {error, division_by_zero};
modulo(X, Y) when is_float(X), is_float(Y), Y == 0.0 -> {error, division_by_zero};
modulo(X, Y) when is_float(X), is_integer(Y) ->
    X - (erlang:trunc(X / Y) * Y);
modulo(X, Y) when is_float(X), is_float(Y) ->
    X - (erlang:trunc(X / Y) * Y).

-spec power(ruby_float(), ruby_value()) -> float().
power(X, Y) when is_float(X), is_integer(Y) -> math:pow(X, Y);
power(X, Y) when is_float(X), is_float(Y) -> math:pow(X, Y).

-spec abs(ruby_float()) -> float().
abs(X) when is_float(X) -> erlang:abs(X).

-spec negate(ruby_float()) -> float().
negate(X) when is_float(X) -> -X.

%% ===================================================================
%% Comparison Operations
%% ===================================================================

-spec compare(ruby_float(), ruby_value()) -> -1 | 0 | 1.
compare(X, Y) when is_float(X), is_integer(Y) ->
    if
        X < Y -> -1;
        X > Y -> 1;
        true -> 0
    end;
compare(X, Y) when is_float(X), is_float(Y) ->
    if
        X < Y -> -1;
        X > Y -> 1;
        true -> 0
    end.

-spec equal(ruby_float(), ruby_value()) -> boolean().
equal(X, Y) when is_float(X), is_integer(Y) -> X == Y;
equal(X, Y) when is_float(X), is_float(Y) -> X =:= Y.

-spec not_equal(ruby_float(), ruby_value()) -> boolean().
not_equal(X, Y) -> not equal(X, Y).

-spec less_than(ruby_float(), ruby_value()) -> boolean().
less_than(X, Y) when is_float(X), (is_integer(Y) orelse is_float(Y)) -> X < Y.

-spec less_than_or_equal(ruby_float(), ruby_value()) -> boolean().
less_than_or_equal(X, Y) when is_float(X), (is_integer(Y) orelse is_float(Y)) -> X =< Y.

-spec greater_than(ruby_float(), ruby_value()) -> boolean().
greater_than(X, Y) when is_float(X), (is_integer(Y) orelse is_float(Y)) -> X > Y.

-spec greater_than_or_equal(ruby_float(), ruby_value()) -> boolean().
greater_than_or_equal(X, Y) when is_float(X), (is_integer(Y) orelse is_float(Y)) -> X >= Y.

%% ===================================================================
%% Type Conversion
%% ===================================================================

-spec to_integer(ruby_float()) -> integer().
to_integer(X) when is_float(X) -> erlang:trunc(X).

-spec to_float(ruby_float()) -> float().
to_float(X) when is_float(X) -> X.

-spec to_string(ruby_float()) -> binary().
to_string(X) when is_float(X) ->
    list_to_binary(float_to_list(X, [{decimals, 10}, compact])).

%% ===================================================================
%% Rounding Methods
%% ===================================================================

-spec ceil(ruby_float()) -> integer().
ceil(X) when is_float(X) -> erlang:ceil(X).

-spec floor(ruby_float()) -> integer().
floor(X) when is_float(X) -> erlang:floor(X).

-spec round(ruby_float()) -> integer().
round(X) when is_float(X) -> erlang:round(X).

-spec round(ruby_float(), integer()) -> float().
round(X, Precision) when is_float(X), is_integer(Precision) ->
    Multiplier = math:pow(10, Precision),
    erlang:round(X * Multiplier) / Multiplier.

-spec truncate(ruby_float()) -> integer().
truncate(X) when is_float(X) -> erlang:trunc(X).

%% ===================================================================
%% Query Methods
%% ===================================================================

-spec finite(ruby_float()) -> boolean().
finite(X) when is_float(X) ->
    not (is_nan_value(X) orelse is_infinite_value(X)).

-spec infinite(ruby_float()) -> -1 | 0 | 1.
infinite(X) when is_float(X) ->
    case is_infinite_value(X) of
        true ->
            if
                X > 0 -> 1;
                X < 0 -> -1;
                true -> 0
            end;
        false ->
            0
    end.

-spec nan(ruby_float()) -> boolean().
nan(X) when is_float(X) -> is_nan_value(X).

-spec zero(ruby_float()) -> boolean().
zero(X) when is_float(X) -> X == 0.0.

-spec positive(ruby_float()) -> boolean().
positive(X) when is_float(X) -> X > 0.0.

-spec negative(ruby_float()) -> boolean().
negative(X) when is_float(X) -> X < 0.0.

%% ===================================================================
%% Helper Functions
%% ===================================================================

-spec is_nan_value(float()) -> boolean().
is_nan_value(X) when is_float(X) ->
    X /= X.  % NaN is the only value that is not equal to itself

-spec is_infinite_value(float()) -> boolean().
is_infinite_value(X) when is_float(X) ->
    % Check if X is infinity by comparing with a very large number
    (X > 1.0e308) orelse (X < -1.0e308).
