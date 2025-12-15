%% @doc Ruby Kernel module implementation
%% This module provides built-in methods for Ruby Kernel module.
%% Kernel is mixed into Object, so its methods are available in every Ruby object.
-module(ruby_kernel).

-export([
    % Output methods
    puts/1,
    print/1,
    p/1,
    printf/2,

    % Input methods
    gets/0,
    readline/0,

    % Type conversion methods
    to_integer/1,
    to_float/1,
    to_string/1,
    to_array/1,

    % Object inspection methods
    get_class/1,
    is_a/2,
    kind_of/2,
    respond_to/2,

    % File loading methods (basic implementation)
    require/1,
    load/1,
    require_relative/1,

    % Exception methods (basic implementation)
    raise/1,
    raise/2,
    fail/1,
    fail/2,
    catch_throw/1,
    throw/1,
    throw/2
]).

%%====================================================================
%% Output methods
%%====================================================================

%% @doc puts - prints each argument on a new line
%% Returns nil
-spec puts(term()) -> nil.
puts(Value) when is_list(Value) ->
    % Check if it's a string or a list of values
    case io_lib:printable_list(Value) of
        true ->
            % It's a string
            io:format("~s~n", [Value]),
            nil;
        false ->
            % It's a list of values, print each on a new line
            lists:foreach(fun(V) -> puts(V) end, Value),
            nil
    end;
puts(Value) when is_binary(Value) ->
    io:format("~s~n", [Value]),
    nil;
puts(Value) when is_integer(Value) ->
    io:format("~p~n", [Value]),
    nil;
puts(Value) when is_float(Value) ->
    io:format("~p~n", [Value]),
    nil;
puts(Value) when is_atom(Value) ->
    case Value of
        nil -> io:format("~n", []);
        true -> io:format("true~n", []);
        false -> io:format("false~n", []);
        _ -> io:format("~p~n", [Value])
    end,
    nil;
puts(Value) when is_map(Value) ->
    % Handle Ruby objects
    case maps:get(type, Value, undefined) of
        object ->
            Class = maps:get(class, Value, unknown),
            Id = maps:get(id, Value, 0),
            io:format("#<~p:0x~.16b>~n", [Class, Id]),
            nil;
        _ ->
            io:format("~p~n", [Value]),
            nil
    end;
puts(Value) ->
    io:format("~p~n", [Value]),
    nil.

%% @doc print - prints arguments without newline
%% Returns nil
-spec print(term()) -> nil.
print(Value) when is_list(Value) ->
    case io_lib:printable_list(Value) of
        true ->
            io:format("~s", [Value]),
            nil;
        false ->
            lists:foreach(fun(V) -> print(V) end, Value),
            nil
    end;
print(Value) when is_binary(Value) ->
    io:format("~s", [Value]),
    nil;
print(Value) when is_integer(Value) ->
    io:format("~p", [Value]),
    nil;
print(Value) when is_float(Value) ->
    io:format("~p", [Value]),
    nil;
print(Value) when is_atom(Value) ->
    case Value of
        nil -> io:format("", []);
        true -> io:format("true", []);
        false -> io:format("false", []);
        _ -> io:format("~p", [Value])
    end,
    nil;
print(Value) when is_map(Value) ->
    case maps:get(type, Value, undefined) of
        object ->
            Class = maps:get(class, Value, unknown),
            Id = maps:get(id, Value, 0),
            io:format("#<~p:0x~.16b>", [Class, Id]),
            nil;
        _ ->
            io:format("~p", [Value]),
            nil
    end;
print(Value) ->
    io:format("~p", [Value]),
    nil.

%% @doc p - prints inspect representation of object
%% Returns the value itself
-spec p(term()) -> term().
p(Value) when is_list(Value) ->
    case io_lib:printable_list(Value) of
        true ->
            io:format("\"~s\"~n", [Value]),
            Value;
        false ->
            io:format("~p~n", [Value]),
            Value
    end;
p(Value) when is_binary(Value) ->
    io:format("\"~s\"~n", [Value]),
    Value;
p(Value) ->
    io:format("~p~n", [Value]),
    Value.

%% @doc printf - formatted output
%% Returns nil
-spec printf(string(), list()) -> nil.
printf(Format, Args) when is_list(Format), is_list(Args) ->
    io:format(Format, Args),
    nil;
printf(Format, Args) when is_binary(Format), is_list(Args) ->
    io:format(binary_to_list(Format), Args),
    nil.

%%====================================================================
%% Input methods
%%====================================================================

%% @doc gets - reads a line from standard input
%% Returns the line as a string with newline, or nil on EOF
-spec gets() -> string() | nil.
gets() ->
    case io:get_line("") of
        eof -> nil;
        {error, _} -> nil;
        Line -> Line
    end.

%% @doc readline - reads a line from standard input
%% Returns the line as a string, raises on EOF
-spec readline() -> string() | {error, eof}.
readline() ->
    case io:get_line("") of
        eof -> {error, eof};
        {error, Reason} -> {error, Reason};
        Line ->
            % Remove trailing newline if present
            string:trim(Line, trailing, "\n")
    end.

%%====================================================================
%% Type conversion methods
%%====================================================================

%% @doc Integer - converts value to integer
%% Delegates to ruby_value:to_integer/1
-spec to_integer(term()) -> {ok, integer()} | {error, term()}.
to_integer(Value) ->
    ruby_value:to_integer(Value).

%% @doc Float - converts value to float
%% Delegates to ruby_value:to_float/1
-spec to_float(term()) -> {ok, float()} | {error, term()}.
to_float(Value) ->
    ruby_value:to_float(Value).

%% @doc String - converts value to string
%% Delegates to ruby_value:to_string/1
-spec to_string(term()) -> {ok, string()}.
to_string(Value) ->
    ruby_value:to_string(Value).

%% @doc Array - converts value to array
%% Basic implementation: wraps non-list values in a list
-spec to_array(term()) -> list().
to_array(Value) when is_list(Value) ->
    Value;
to_array(Value) ->
    [Value].

%%====================================================================
%% Object inspection methods
%%====================================================================

%% @doc class - returns the class of an object
-spec get_class(term()) -> atom().
get_class(Value) when is_integer(Value) ->
    'Integer';
get_class(Value) when is_float(Value) ->
    'Float';
get_class(Value) when is_binary(Value) ->
    'String';
get_class(Value) when is_list(Value) ->
    case io_lib:printable_list(Value) of
        true -> 'String';
        false -> 'Array'
    end;
get_class(Value) when is_atom(Value) ->
    case Value of
        nil -> 'NilClass';
        true -> 'TrueClass';
        false -> 'FalseClass';
        _ -> 'Symbol'
    end;
get_class(Value) when is_map(Value) ->
    case maps:get(type, Value, undefined) of
        object ->
            maps:get(class, Value, 'Object');
        binding ->
            'Binding';
        proc ->
            'Proc';
        lambda ->
            'Proc';
        _ ->
            'Object'
    end;
get_class(_Value) ->
    'Object'.

%% @doc is_a? - checks if object is an instance of the given class
%% Considers inheritance chain
-spec is_a(term(), atom()) -> boolean().
is_a(Value, ClassName) when is_map(Value) ->
    case maps:get(type, Value, undefined) of
        object ->
            % Use ruby_object_server for proper inheritance check
            ruby_object_server:is_instance_of(Value, ClassName);
        _ ->
            % For non-object types, check class directly
            get_class(Value) =:= ClassName
    end;
is_a(Value, ClassName) ->
    % For primitive types, check class directly
    get_class(Value) =:= ClassName.

%% @doc kind_of? - alias for is_a?
-spec kind_of(term(), atom()) -> boolean().
kind_of(Value, ClassName) ->
    is_a(Value, ClassName).

%% @doc respond_to? - checks if object responds to a method
%% Basic implementation: checks if method exists in object's class
-spec respond_to(term(), atom()) -> boolean().
respond_to(Value, MethodName) when is_map(Value) ->
    case maps:get(type, Value, undefined) of
        object ->
            Class = maps:get(class, Value, 'Object'),
            case ruby_object_server:lookup_method(Class, MethodName) of
                {ok, _Method} -> true;
                not_found -> false
            end;
        _ ->
            % For non-object maps, return false
            false
    end;
respond_to(_Value, _MethodName) ->
    % For primitive types, we could check built-in methods
    % For now, return false
    false.

%%====================================================================
%% File loading methods
%%====================================================================

%% @doc require - loads a Ruby file once
%% Basic implementation: returns true if file exists, false otherwise
-spec require(string()) -> boolean().
require(Filename) ->
    % TODO: Implement proper require with load tracking
    % For now, just attempt to load the file
    case filelib:is_regular(Filename) of
        true ->
            % File exists, would load it here
            true;
        false ->
            % Try with .rb extension
            FilenameRb = Filename ++ ".rb",
            filelib:is_regular(FilenameRb)
    end.

%% @doc load - loads a Ruby file every time
%% Basic implementation: checks if file exists
-spec load(string()) -> boolean().
load(Filename) ->
    % TODO: Implement proper file loading
    % For now, just check if file exists
    case filelib:is_regular(Filename) of
        true -> true;
        false ->
            FilenameRb = Filename ++ ".rb",
            filelib:is_regular(FilenameRb)
    end.

%% @doc require_relative - loads a Ruby file relative to current file
%% Basic implementation: same as require for now
-spec require_relative(string()) -> boolean().
require_relative(Filename) ->
    % TODO: Implement proper relative path resolution
    require(Filename).

%%====================================================================
%% Exception methods
%%====================================================================

%% @doc raise - raises an exception with a message
-spec raise(term()) -> {error, {exception, term()}}.
raise(Message) ->
    {error, {exception, Message}}.

%% @doc raise - raises an exception of a specific class with a message
-spec raise(atom(), term()) -> {error, {exception, atom(), term()}}.
raise(ExceptionClass, Message) ->
    {error, {exception, ExceptionClass, Message}}.

%% @doc fail - alias for raise
-spec fail(term()) -> {error, {exception, term()}}.
fail(Message) ->
    raise(Message).

%% @doc fail - alias for raise with exception class
-spec fail(atom(), term()) -> {error, {exception, atom(), term()}}.
fail(ExceptionClass, Message) ->
    raise(ExceptionClass, Message).

%% @doc catch - catches a thrown value
%% Basic implementation using Erlang's try/catch
-spec catch_throw(fun(() -> term())) -> term().
catch_throw(Fun) ->
    try
        Fun()
    catch
        throw:Value -> Value
    end.

%% @doc throw - throws a value to be caught by catch
-spec throw(term()) -> no_return().
throw(Value) ->
    erlang:throw(Value).

%% @doc throw - throws a value with a tag to be caught by catch
-spec throw(term(), term()) -> no_return().
throw(Tag, Value) ->
    erlang:throw({Tag, Value}).
