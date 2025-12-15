%% @doc Ruby String class implementation
%% This module provides built-in methods for Ruby String class.
-module(ruby_string).
-compile({no_auto_import,[length/1]}).

-export([
    % Concatenation operations
    concat/2,
    append/2,

    % Splitting operations
    split/1,
    split/2,
    chars/1,

    % Search operations
    index/2,
    index/3,
    rindex/2,
    rindex/3,

    % Substitution operations
    sub/3,
    gsub/3,

    % Case conversion operations
    upcase/1,
    downcase/1,
    capitalize/1,
    swapcase/1,

    % Length and size
    length/1,
    size/1,
    bytesize/1,
    empty/1,

    % Character access
    chr/2,

    % Trimming
    strip/1,
    lstrip/1,
    rstrip/1,
    chomp/1,
    chomp/2,

    % Other methods
    reverse/1,
    to_string/1,
    to_integer/1,
    to_float/1,
    to_atom/1,

    % Comparison
    equal/2,
    compare/2
]).

-type ruby_string() :: binary() | string().
-type ruby_value() :: ruby_string() | integer() | float() | atom().

%% ===================================================================
%% Concatenation Operations
%% ===================================================================

-spec concat(ruby_string(), ruby_string()) -> binary().
concat(S1, S2) when is_binary(S1), is_binary(S2) ->
    <<S1/binary, S2/binary>>;
concat(S1, S2) when is_list(S1), is_list(S2) ->
    list_to_binary(S1 ++ S2);
concat(S1, S2) when is_binary(S1), is_list(S2) ->
    <<S1/binary, (list_to_binary(S2))/binary>>;
concat(S1, S2) when is_list(S1), is_binary(S2) ->
    <<(list_to_binary(S1))/binary, S2/binary>>.

-spec append(ruby_string(), ruby_string()) -> binary().
append(S1, S2) ->
    concat(S1, S2).

%% ===================================================================
%% Splitting Operations
%% ===================================================================

-spec split(ruby_string()) -> [binary()].
split(Str) when is_binary(Str) ->
    binary:split(Str, <<" ">>, [global, trim_all]);
split(Str) when is_list(Str) ->
    split(list_to_binary(Str)).

-spec split(ruby_string(), ruby_string() | binary()) -> [binary()].
split(Str, Delimiter) when is_binary(Str), is_binary(Delimiter) ->
    binary:split(Str, Delimiter, [global]);
split(Str, Delimiter) when is_list(Str), is_binary(Delimiter) ->
    split(list_to_binary(Str), Delimiter);
split(Str, Delimiter) when is_binary(Str), is_list(Delimiter) ->
    split(Str, list_to_binary(Delimiter));
split(Str, Delimiter) when is_list(Str), is_list(Delimiter) ->
    split(list_to_binary(Str), list_to_binary(Delimiter)).

-spec chars(ruby_string()) -> [binary()].
chars(Str) when is_binary(Str) ->
    chars_helper(Str, []);
chars(Str) when is_list(Str) ->
    chars(list_to_binary(Str)).

-spec chars_helper(binary(), [binary()]) -> [binary()].
chars_helper(<<>>, Acc) ->
    lists:reverse(Acc);
chars_helper(<<Char/utf8, Rest/binary>>, Acc) ->
    chars_helper(Rest, [<<Char/utf8>> | Acc]);
chars_helper(<<Byte, Rest/binary>>, Acc) ->
    % Fallback for non-UTF8 bytes
    chars_helper(Rest, [<<Byte>> | Acc]).

%% ===================================================================
%% Search Operations
%% ===================================================================

-spec index(ruby_string(), ruby_string()) -> integer() | nil.
index(Str, Substring) ->
    index(Str, Substring, 0).

-spec index(ruby_string(), ruby_string(), integer()) -> integer() | nil.
index(Str, Substring, Offset) when is_binary(Str), is_binary(Substring) ->
    ByteSize = byte_size(Str),
    ActualOffset = case Offset < 0 of
        true ->
            % Negative offset: count from end
            max(0, ByteSize + Offset);
        false ->
            Offset
    end,
    case ActualOffset >= ByteSize of
        true -> nil;
        false ->
            <<_:ActualOffset/binary, SearchPart/binary>> = Str,
            case binary:match(SearchPart, Substring) of
                {Pos, _Len} -> ActualOffset + Pos;
                nomatch -> nil
            end
    end;
index(Str, Substring, Offset) when is_list(Str) ->
    index(list_to_binary(Str), ensure_binary(Substring), Offset);
index(Str, Substring, Offset) when is_list(Substring) ->
    index(ensure_binary(Str), list_to_binary(Substring), Offset).

-spec rindex(ruby_string(), ruby_string()) -> integer() | nil.
rindex(Str, Substring) ->
    rindex(Str, Substring, -1).

-spec rindex(ruby_string(), ruby_string(), integer()) -> integer() | nil.
rindex(Str, Substring, Offset) when is_binary(Str), is_binary(Substring) ->
    ByteSize = byte_size(Str),
    ActualOffset = case Offset < 0 of
        true -> ByteSize + Offset + 1;
        false -> Offset + 1
    end,
    case ActualOffset =< 0 of
        true -> nil;
        false ->
            SearchLen = min(ActualOffset, ByteSize),
            <<SearchPart:SearchLen/binary, _/binary>> = Str,
            Matches = binary:matches(SearchPart, Substring),
            case Matches of
                [] -> nil;
                _ ->
                    {LastPos, _} = lists:last(Matches),
                    LastPos
            end
    end;
rindex(Str, Substring, Offset) when is_list(Str) ->
    rindex(list_to_binary(Str), ensure_binary(Substring), Offset);
rindex(Str, Substring, Offset) when is_list(Substring) ->
    rindex(ensure_binary(Str), list_to_binary(Substring), Offset).

%% ===================================================================
%% Substitution Operations
%% ===================================================================

-spec sub(ruby_string(), ruby_string(), ruby_string()) -> binary().
sub(Str, Pattern, Replacement) when is_binary(Str), is_binary(Pattern), is_binary(Replacement) ->
    case binary:match(Str, Pattern) of
        {Start, Len} ->
            <<Before:Start/binary, _:Len/binary, After/binary>> = Str,
            <<Before/binary, Replacement/binary, After/binary>>;
        nomatch ->
            Str
    end;
sub(Str, Pattern, Replacement) when is_list(Str) ->
    sub(list_to_binary(Str), ensure_binary(Pattern), ensure_binary(Replacement));
sub(Str, Pattern, Replacement) when is_list(Pattern) ->
    sub(ensure_binary(Str), list_to_binary(Pattern), ensure_binary(Replacement));
sub(Str, Pattern, Replacement) when is_list(Replacement) ->
    sub(ensure_binary(Str), ensure_binary(Pattern), list_to_binary(Replacement)).

-spec gsub(ruby_string(), ruby_string(), ruby_string()) -> binary().
gsub(Str, Pattern, Replacement) when is_binary(Str), is_binary(Pattern), is_binary(Replacement) ->
    gsub_helper(Str, Pattern, Replacement, <<>>);
gsub(Str, Pattern, Replacement) when is_list(Str) ->
    gsub(list_to_binary(Str), ensure_binary(Pattern), ensure_binary(Replacement));
gsub(Str, Pattern, Replacement) when is_list(Pattern) ->
    gsub(ensure_binary(Str), list_to_binary(Pattern), ensure_binary(Replacement));
gsub(Str, Pattern, Replacement) when is_list(Replacement) ->
    gsub(ensure_binary(Str), ensure_binary(Pattern), list_to_binary(Replacement)).

-spec gsub_helper(binary(), binary(), binary(), binary()) -> binary().
gsub_helper(Str, Pattern, Replacement, Acc) ->
    case binary:match(Str, Pattern) of
        {Start, Len} ->
            <<Before:Start/binary, _:Len/binary, After/binary>> = Str,
            NewAcc = <<Acc/binary, Before/binary, Replacement/binary>>,
            gsub_helper(After, Pattern, Replacement, NewAcc);
        nomatch ->
            <<Acc/binary, Str/binary>>
    end.

%% ===================================================================
%% Case Conversion Operations
%% ===================================================================

-spec upcase(ruby_string()) -> binary().
upcase(Str) when is_binary(Str) ->
    list_to_binary(string:uppercase(binary_to_list(Str)));
upcase(Str) when is_list(Str) ->
    upcase(list_to_binary(Str)).

-spec downcase(ruby_string()) -> binary().
downcase(Str) when is_binary(Str) ->
    list_to_binary(string:lowercase(binary_to_list(Str)));
downcase(Str) when is_list(Str) ->
    downcase(list_to_binary(Str)).

-spec capitalize(ruby_string()) -> binary().
capitalize(<<>>) -> <<>>;
capitalize(Str) when is_binary(Str) ->
    case Str of
        <<First/utf8, Rest/binary>> ->
            UpperFirst = list_to_binary(string:uppercase([First])),
            LowerRest = downcase(Rest),
            <<UpperFirst/binary, LowerRest/binary>>;
        <<First, Rest/binary>> ->
            % Fallback for non-UTF8
            UpperFirst = list_to_binary(string:uppercase([First])),
            LowerRest = downcase(Rest),
            <<UpperFirst/binary, LowerRest/binary>>
    end;
capitalize(Str) when is_list(Str) ->
    capitalize(list_to_binary(Str)).

-spec swapcase(ruby_string()) -> binary().
swapcase(Str) when is_binary(Str) ->
    swapcase_helper(Str, <<>>);
swapcase(Str) when is_list(Str) ->
    swapcase(list_to_binary(Str)).

-spec swapcase_helper(binary(), binary()) -> binary().
swapcase_helper(<<>>, Acc) ->
    Acc;
swapcase_helper(<<Char/utf8, Rest/binary>>, Acc) ->
    CharStr = [Char],
    Swapped = case string:uppercase(CharStr) of
        CharStr ->
            % Already uppercase or not a letter, try lowercase
            list_to_binary(string:lowercase(CharStr));
        _ ->
            % Was lowercase, convert to uppercase
            list_to_binary(string:uppercase(CharStr))
    end,
    swapcase_helper(Rest, <<Acc/binary, Swapped/binary>>);
swapcase_helper(<<Byte, Rest/binary>>, Acc) ->
    % Fallback for non-UTF8
    swapcase_helper(Rest, <<Acc/binary, Byte>>).

%% ===================================================================
%% Length and Size Operations
%% ===================================================================

-spec length(ruby_string()) -> integer().
length(Str) when is_binary(Str) ->
    string:length(binary_to_list(Str));
length(Str) when is_list(Str) ->
    erlang:length(Str).

-spec size(ruby_string()) -> integer().
size(Str) ->
    length(Str).

-spec bytesize(ruby_string()) -> integer().
bytesize(Str) when is_binary(Str) ->
    byte_size(Str);
bytesize(Str) when is_list(Str) ->
    erlang:length(Str).

-spec empty(ruby_string()) -> boolean().
empty(<<>>) -> true;
empty([]) -> true;
empty(_) -> false.

%% ===================================================================
%% Character Access
%% ===================================================================

-spec chr(ruby_string(), integer()) -> binary() | nil.
chr(Str, Index) when is_binary(Str) ->
    Chars = chars(Str),
    Len = erlang:length(Chars),
    ActualIndex = case Index < 0 of
        true -> Len + Index;
        false -> Index
    end,
    case ActualIndex >= 0 andalso ActualIndex < Len of
        true -> lists:nth(ActualIndex + 1, Chars);
        false -> nil
    end;
chr(Str, Index) when is_list(Str) ->
    chr(list_to_binary(Str), Index).

%% ===================================================================
%% Trimming Operations
%% ===================================================================

-spec strip(ruby_string()) -> binary().
strip(Str) when is_binary(Str) ->
    list_to_binary(string:trim(binary_to_list(Str)));
strip(Str) when is_list(Str) ->
    strip(list_to_binary(Str)).

-spec lstrip(ruby_string()) -> binary().
lstrip(Str) when is_binary(Str) ->
    list_to_binary(string:trim(binary_to_list(Str), leading));
lstrip(Str) when is_list(Str) ->
    lstrip(list_to_binary(Str)).

-spec rstrip(ruby_string()) -> binary().
rstrip(Str) when is_binary(Str) ->
    list_to_binary(string:trim(binary_to_list(Str), trailing));
rstrip(Str) when is_list(Str) ->
    rstrip(list_to_binary(Str)).

-spec chomp(ruby_string()) -> binary().
chomp(Str) ->
    chomp(Str, <<"\n">>).

-spec chomp(ruby_string(), ruby_string()) -> binary().
chomp(Str, Separator) when is_binary(Str), is_binary(Separator) ->
    SepSize = byte_size(Separator),
    StrSize = byte_size(Str),
    case StrSize >= SepSize of
        true ->
            PrefixSize = StrSize - SepSize,
            case Str of
                <<Prefix:PrefixSize/binary, Separator/binary>> ->
                    Prefix;
                _ ->
                    Str
            end;
        false ->
            Str
    end;
chomp(Str, Separator) when is_list(Str) ->
    chomp(list_to_binary(Str), ensure_binary(Separator));
chomp(Str, Separator) when is_list(Separator) ->
    chomp(ensure_binary(Str), list_to_binary(Separator)).

%% ===================================================================
%% Other Operations
%% ===================================================================

-spec reverse(ruby_string()) -> binary().
reverse(Str) when is_binary(Str) ->
    Chars = chars(Str),
    list_to_binary(lists:reverse([binary_to_list(C) || C <- Chars]));
reverse(Str) when is_list(Str) ->
    reverse(list_to_binary(Str)).

-spec to_string(ruby_value()) -> binary().
to_string(Str) when is_binary(Str) -> Str;
to_string(Str) when is_list(Str) -> list_to_binary(Str);
to_string(Int) when is_integer(Int) -> integer_to_binary(Int);
to_string(Float) when is_float(Float) -> float_to_binary(Float);
to_string(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8).

-spec to_integer(ruby_string()) -> {ok, integer()} | {error, atom()}.
to_integer(Str) when is_binary(Str) ->
    try
        {ok, binary_to_integer(Str)}
    catch
        _:_ -> {error, invalid_integer}
    end;
to_integer(Str) when is_list(Str) ->
    to_integer(list_to_binary(Str)).

-spec to_float(ruby_string()) -> {ok, float()} | {error, atom()}.
to_float(Str) when is_binary(Str) ->
    try
        {ok, binary_to_float(Str)}
    catch
        _:_ ->
            % Try converting to integer first, then to float
            case to_integer(Str) of
                {ok, Int} -> {ok, float(Int)};
                {error, _} -> {error, invalid_float}
            end
    end;
to_float(Str) when is_list(Str) ->
    to_float(list_to_binary(Str)).

-spec to_atom(ruby_string()) -> atom().
to_atom(Str) when is_binary(Str) ->
    binary_to_atom(Str, utf8);
to_atom(Str) when is_list(Str) ->
    list_to_atom(Str).

%% ===================================================================
%% Comparison Operations
%% ===================================================================

-spec equal(ruby_string(), ruby_string()) -> boolean().
equal(S1, S2) when is_binary(S1), is_binary(S2) ->
    S1 =:= S2;
equal(S1, S2) when is_list(S1), is_list(S2) ->
    S1 =:= S2;
equal(S1, S2) when is_binary(S1), is_list(S2) ->
    S1 =:= list_to_binary(S2);
equal(S1, S2) when is_list(S1), is_binary(S2) ->
    list_to_binary(S1) =:= S2.

-spec compare(ruby_string(), ruby_string()) -> -1 | 0 | 1.
compare(S1, S2) when is_binary(S1), is_binary(S2) ->
    if
        S1 < S2 -> -1;
        S1 > S2 -> 1;
        true -> 0
    end;
compare(S1, S2) when is_list(S1) ->
    compare(list_to_binary(S1), ensure_binary(S2));
compare(S1, S2) when is_list(S2) ->
    compare(ensure_binary(S1), list_to_binary(S2)).

%% ===================================================================
%% Helper Functions
%% ===================================================================

-spec ensure_binary(ruby_string()) -> binary().
ensure_binary(Str) when is_binary(Str) -> Str;
ensure_binary(Str) when is_list(Str) -> list_to_binary(Str).
