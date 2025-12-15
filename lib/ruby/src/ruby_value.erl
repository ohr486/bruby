%% @doc Ruby値の表現と操作
%%
%% このモジュールはRubyの値をErlang上で表現し、型チェック、型変換、
%% 等価性チェックなどの基本的な操作を提供します。
%%
%% ## Ruby値のErlang表現
%%
%% brubyではRuby値を以下のようにErlangの型で表現します：
%%
%% - **整数値**: Erlangの整数型 (integer())
%%   例: 42, -100, 0
%%
%% - **浮動小数点数**: Erlangの浮動小数点型 (float())
%%   例: 3.14, -0.5, 1.0e10
%%
%% - **文字列**: Erlangの文字列リスト (string()) またはバイナリ (binary())
%%   例: "hello", <<"world">>
%%
%% - **シンボル**: Erlangのアトム (atom())
%%   例: symbol, 'Symbol', 'my_symbol'
%%
%% - **真偽値**: Erlangのアトム true | false
%%   例: true, false
%%
%% - **nil**: Erlangのアトム nil
%%   例: nil
%%
%% - **オブジェクト**: マップ形式 #{type => object, class => atom(), ...}
%%   例: #{type => object, class => 'MyClass', instance_vars => #{}}
%%
%% この設計により、Erlangのネイティブな型の効率性を保ちつつ、
%% 将来のオブジェクトシステムの拡張にも対応できます。
%%
%% ## 使用例
%%
%% ```erlang
%% % 型チェック
%% true = ruby_value:is_ruby_integer(42),
%% true = ruby_value:is_ruby_string("hello"),
%% true = ruby_value:is_ruby_nil(nil),
%%
%% % 型変換
%% {ok, 42} = ruby_value:to_integer("42"),
%% {ok, "123"} = ruby_value:to_string(123),
%% {ok, 3.14} = ruby_value:to_float("3.14"),
%%
%% % 等価性チェック（Rubyの==）
%% true = ruby_value:equal(42, 42),
%% true = ruby_value:equal(42, 42.0),  % 数値は型を超えて等しい
%%
%% % 厳密な等価性（Rubyのeql?）
%% true = ruby_value:eql(42, 42),
%% false = ruby_value:eql(42, 42.0),  % 型が異なる
%%
%% % オブジェクトの同一性（Rubyのequal?）
%% Obj1 = #{type => object, id => 1},
%% Obj2 = #{type => object, id => 2},
%% false = ruby_value:identical(Obj1, Obj2).
%% ```
%%
%% @author bruby development team
%% @version 1.0.0

-module(ruby_value).

%% 型チェック関数
-export([
    is_ruby_integer/1,
    is_ruby_float/1,
    is_ruby_number/1,
    is_ruby_string/1,
    is_ruby_symbol/1,
    is_ruby_boolean/1,
    is_ruby_nil/1,
    is_ruby_object/1,
    is_truthy/1
]).

%% 型変換関数
-export([
    to_integer/1,
    to_float/1,
    to_string/1,
    to_symbol/1,
    to_boolean/1
]).

%% 等価性チェック関数
-export([
    equal/2,
    eql/2,
    identical/2
]).

%% オブジェクト操作
-export([
    new_object/2,
    get_object_class/1,
    get_object_id/1
]).

%% ============================================================================
%% 型定義
%% ============================================================================

%% Ruby値の型定義
-type ruby_value() :: ruby_integer()
                    | ruby_float()
                    | ruby_string()
                    | ruby_symbol()
                    | ruby_boolean()
                    | ruby_nil()
                    | ruby_object().

-type ruby_integer() :: integer().
-type ruby_float() :: float().
-type ruby_number() :: ruby_integer() | ruby_float().
-type ruby_string() :: string() | binary().
-type ruby_symbol() :: atom().
-type ruby_boolean() :: true | false.
-type ruby_nil() :: nil.
-type ruby_object() :: #{
    type := object,
    class := atom(),
    id := integer(),
    instance_vars => #{atom() => ruby_value()}
}.

-export_type([
    ruby_value/0,
    ruby_integer/0,
    ruby_float/0,
    ruby_number/0,
    ruby_string/0,
    ruby_symbol/0,
    ruby_boolean/0,
    ruby_nil/0,
    ruby_object/0
]).

%% ============================================================================
%% 型チェック関数
%% ============================================================================

%% @doc 整数値かどうかをチェック
-spec is_ruby_integer(term()) -> boolean().
is_ruby_integer(Value) when is_integer(Value) -> true;
is_ruby_integer(_) -> false.

%% @doc 浮動小数点数かどうかをチェック
-spec is_ruby_float(term()) -> boolean().
is_ruby_float(Value) when is_float(Value) -> true;
is_ruby_float(_) -> false.

%% @doc 数値（整数または浮動小数点数）かどうかをチェック
-spec is_ruby_number(term()) -> boolean().
is_ruby_number(Value) when is_number(Value) -> true;
is_ruby_number(_) -> false.

%% @doc 文字列かどうかをチェック
-spec is_ruby_string(term()) -> boolean().
is_ruby_string(Value) when is_list(Value) ->
    % 文字列は文字（整数）のリスト
    lists:all(fun(C) -> is_integer(C) andalso C >= 0 end, Value);
is_ruby_string(Value) when is_binary(Value) -> true;
is_ruby_string(_) -> false.

%% @doc シンボルかどうかをチェック
%%
%% シンボルはErlangのアトムとして表現されます。
%% ただし、true, false, nilはシンボルとしてではなく、
%% それぞれ真偽値、nil値として扱われます。
-spec is_ruby_symbol(term()) -> boolean().
is_ruby_symbol(Value) when is_atom(Value) ->
    % true, false, nilはシンボルではない
    Value =/= true andalso Value =/= false andalso Value =/= nil;
is_ruby_symbol(_) -> false.

%% @doc 真偽値（true または false）かどうかをチェック
-spec is_ruby_boolean(term()) -> boolean().
is_ruby_boolean(true) -> true;
is_ruby_boolean(false) -> true;
is_ruby_boolean(_) -> false.

%% @doc nil値かどうかをチェック
-spec is_ruby_nil(term()) -> boolean().
is_ruby_nil(nil) -> true;
is_ruby_nil(_) -> false.

%% @doc Rubyオブジェクトかどうかをチェック
-spec is_ruby_object(term()) -> boolean().
is_ruby_object(#{type := object}) -> true;
is_ruby_object(_) -> false.

%% @doc Rubyの真偽値判定（false と nil 以外はすべて真）
%%
%% Rubyでは、false と nil のみが偽として扱われ、
%% それ以外の値（0、空文字列、空配列を含む）はすべて真として扱われます。
-spec is_truthy(term()) -> boolean().
is_truthy(false) -> false;
is_truthy(nil) -> false;
is_truthy(_) -> true.

%% ============================================================================
%% 型変換関数
%% ============================================================================

%% @doc 値を整数に変換
%%
%% サポートされる変換：
%% - 整数 → そのまま返す
%% - 浮動小数点数 → 整数に切り捨て
%% - 文字列 → パースして整数に変換
%% - true → 1
%% - false/nil → 0
%%
%% それ以外の値は変換できません。
-spec to_integer(term()) -> {ok, integer()} | {error, cannot_convert}.
to_integer(Value) when is_integer(Value) ->
    {ok, Value};
to_integer(Value) when is_float(Value) ->
    {ok, trunc(Value)};
to_integer(Value) when is_list(Value) ->
    try
        {ok, list_to_integer(Value)}
    catch
        _:_ -> {error, cannot_convert}
    end;
to_integer(Value) when is_binary(Value) ->
    try
        {ok, binary_to_integer(Value)}
    catch
        _:_ -> {error, cannot_convert}
    end;
to_integer(true) ->
    {ok, 1};
to_integer(false) ->
    {ok, 0};
to_integer(nil) ->
    {ok, 0};
to_integer(_) ->
    {error, cannot_convert}.

%% @doc 値を浮動小数点数に変換
%%
%% サポートされる変換：
%% - 浮動小数点数 → そのまま返す
%% - 整数 → 浮動小数点数に変換
%% - 文字列 → パースして浮動小数点数に変換
%%
%% それ以外の値は変換できません。
-spec to_float(term()) -> {ok, float()} | {error, cannot_convert}.
to_float(Value) when is_float(Value) ->
    {ok, Value};
to_float(Value) when is_integer(Value) ->
    {ok, float(Value)};
to_float(Value) when is_list(Value) ->
    try
        {ok, list_to_float(Value)}
    catch
        _:_ ->
            % 整数形式の文字列の可能性もある
            try
                {ok, float(list_to_integer(Value))}
            catch
                _:_ -> {error, cannot_convert}
            end
    end;
to_float(Value) when is_binary(Value) ->
    try
        {ok, binary_to_float(Value)}
    catch
        _:_ ->
            % 整数形式のバイナリの可能性もある
            try
                {ok, float(binary_to_integer(Value))}
            catch
                _:_ -> {error, cannot_convert}
            end
    end;
to_float(_) ->
    {error, cannot_convert}.

%% @doc 値を文字列に変換
%%
%% すべての値を文字列に変換できます。
%% 表現は可能な限りRubyの.to_sメソッドの動作に近づけます。
-spec to_string(term()) -> {ok, string()}.
to_string(Value) when is_list(Value) ->
    {ok, Value};
to_string(Value) when is_binary(Value) ->
    {ok, binary_to_list(Value)};
to_string(Value) when is_integer(Value) ->
    {ok, integer_to_list(Value)};
to_string(Value) when is_float(Value) ->
    % Rubyの浮動小数点数の文字列表現に合わせる
    Str = float_to_list(Value, [{decimals, 10}, compact]),
    {ok, Str};
to_string(true) ->
    {ok, "true"};
to_string(false) ->
    {ok, "false"};
to_string(nil) ->
    {ok, ""};
to_string(Value) when is_atom(Value) ->
    % シンボルの場合
    {ok, atom_to_list(Value)};
to_string(#{type := object, class := Class}) ->
    % オブジェクトの場合
    {ok, "#<" ++ atom_to_list(Class) ++ ">"};
to_string(Value) when is_map(Value) ->
    % その他のマップ（Proc, Lambdaなど）
    case maps:get(is_lambda, Value, undefined) of
        true -> {ok, "#<Proc(lambda)>"};
        false -> {ok, "#<Proc>"};
        undefined -> {ok, "#<Object>"}
    end;
to_string(_Value) ->
    % その他の値（リストでない複雑な構造など）
    {ok, "#<Object>"}.

%% @doc 値をシンボル（アトム）に変換
%%
%% サポートされる変換：
%% - アトム → そのまま返す
%% - 文字列 → アトムに変換
%% - 整数 → 文字列経由でアトムに変換
%%
%% それ以外の値は変換できません。
-spec to_symbol(term()) -> {ok, atom()} | {error, cannot_convert}.
to_symbol(Value) when is_atom(Value) ->
    {ok, Value};
to_symbol(Value) when is_list(Value) ->
    try
        {ok, list_to_atom(Value)}
    catch
        _:_ -> {error, cannot_convert}
    end;
to_symbol(Value) when is_binary(Value) ->
    try
        {ok, binary_to_atom(Value, utf8)}
    catch
        _:_ -> {error, cannot_convert}
    end;
to_symbol(Value) when is_integer(Value) ->
    try
        {ok, list_to_atom(integer_to_list(Value))}
    catch
        _:_ -> {error, cannot_convert}
    end;
to_symbol(_) ->
    {error, cannot_convert}.

%% @doc 値を真偽値に変換
%%
%% Rubyの真偽値変換ルールに従います：
%% - false, nil → false
%% - それ以外 → true
-spec to_boolean(term()) -> {ok, boolean()}.
to_boolean(false) -> {ok, false};
to_boolean(nil) -> {ok, false};
to_boolean(_) -> {ok, true}.

%% ============================================================================
%% 等価性チェック関数
%% ============================================================================

%% @doc 値の等価性をチェック（Rubyの==演算子）
%%
%% Rubyの==は型変換を伴う等価性チェックです。
%% 特に数値型では、整数と浮動小数点数が等しいとみなされます。
%%
%% 例：
%% - 42 == 42.0 → true（数値は型を超えて比較）
%% - "hello" == "hello" → true
%% - true == true → true
%% - nil == nil → true
-spec equal(term(), term()) -> boolean().
equal(Value1, Value2) when is_number(Value1), is_number(Value2) ->
    % 数値型は型を超えて比較
    Value1 == Value2;
equal(Value1, Value2) ->
    % その他の型は厳密に比較
    Value1 =:= Value2.

%% @doc 型と値の等価性をチェック（Rubyのeql?メソッド）
%%
%% Rubyのeql?は型も含めた厳密な等価性チェックです。
%% 整数と浮動小数点数は型が異なるため等しくありません。
%%
%% 例：
%% - 42 eql? 42.0 → false（型が異なる）
%% - 42 eql? 42 → true
%% - "hello" eql? "hello" → true
-spec eql(term(), term()) -> boolean().
eql(Value1, Value2) ->
    % 型と値の両方が一致する必要がある
    Value1 =:= Value2.

%% @doc オブジェクトの同一性をチェック（Rubyのequal?メソッド）
%%
%% Rubyのequal?はオブジェクトの同一性（同じオブジェクトかどうか）を
%% チェックします。Erlangでは、オブジェクトIDを使用して判定します。
%%
%% 基本型（整数、シンボルなど）は値が等しければ同一とみなされます。
%%
%% 例：
%% - 42.equal?(42) → true（整数は値が同じなら同一）
%% - "hello".equal?("hello") → false（文字列は別オブジェクト）
%% - obj1.equal?(obj2) → false（異なるオブジェクト）
-spec identical(term(), term()) -> boolean().
identical(Value1, Value2) when is_number(Value1), is_number(Value2) ->
    % 数値は値が等しければ同一
    Value1 =:= Value2;
identical(Value1, Value2) when is_atom(Value1), is_atom(Value2) ->
    % アトム（シンボル、true, false, nil）は値が等しければ同一
    Value1 =:= Value2;
identical(#{type := object, id := Id1}, #{type := object, id := Id2}) ->
    % オブジェクトはIDで同一性を判定
    Id1 =:= Id2;
identical(Value1, Value2) ->
    % その他の型（文字列、リスト、マップなど）は参照比較
    % Erlangでは不変データ構造なので、構造的等価性で判定
    Value1 =:= Value2.

%% ============================================================================
%% オブジェクト操作
%% ============================================================================

%% オブジェクトID生成用カウンター（将来的にはETSやプロセスで管理）
-define(INITIAL_OBJECT_ID, 1).

%% @doc 新しいRubyオブジェクトを作成
%%
%% クラス名とオブジェクトIDを指定して新しいオブジェクトを作成します。
%% インスタンス変数は空の状態で初期化されます。
%%
%% パラメータ：
%%   - ClassName: クラス名（アトム）
%%   - ObjectId: オブジェクトID（整数）
%%
%% 戻り値：
%%   - Rubyオブジェクト（ruby_object型）
-spec new_object(atom(), integer()) -> ruby_object().
new_object(ClassName, ObjectId) when is_atom(ClassName), is_integer(ObjectId) ->
    #{
        type => object,
        class => ClassName,
        id => ObjectId,
        instance_vars => #{}
    }.

%% @doc オブジェクトのクラス名を取得
%%
%% パラメータ：
%%   - Object: Rubyオブジェクト
%%
%% 戻り値：
%%   - {ok, ClassName}: クラス名
%%   - {error, not_an_object}: オブジェクトでない場合
-spec get_object_class(term()) -> {ok, atom()} | {error, not_an_object}.
get_object_class(#{type := object, class := ClassName}) ->
    {ok, ClassName};
get_object_class(_) ->
    {error, not_an_object}.

%% @doc オブジェクトのIDを取得
%%
%% パラメータ：
%%   - Object: Rubyオブジェクト
%%
%% 戻り値：
%%   - {ok, ObjectId}: オブジェクトID
%%   - {error, not_an_object}: オブジェクトでない場合
-spec get_object_id(term()) -> {ok, integer()} | {error, not_an_object}.
get_object_id(#{type := object, id := ObjectId}) ->
    {ok, ObjectId};
get_object_id(_) ->
    {error, not_an_object}.
