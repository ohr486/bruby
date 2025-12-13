-module(ruby_evaluator).
-export([eval/1, eval/2, eval_string/1, eval_string/2, new_env/0, new_env/1]).

%% ============================================================================
%% 公開API
%% ============================================================================

%% @doc ASTをデフォルト環境で評価
-spec eval(term()) -> {ok, term(), env()} | {error, term()}.
eval(AST) ->
    Env = new_env(),
    eval(AST, Env).

%% @doc ASTを指定された環境で評価
-spec eval(term(), env()) -> {ok, term(), env()} | {error, term()}.
eval(AST, Env) when is_map(Env) ->
    try
        {Value, NewEnv} = eval_node(AST, Env),
        {ok, Value, NewEnv}
    catch
        throw:{ruby_error, Reason} ->
            {error, Reason};
        error:Reason:Stacktrace ->
            {error, {internal_error, Reason, Stacktrace}}
    end.

%% @doc Rubyコード文字列を評価（トークナイザー + パーサー + 評価器の統合）
-spec eval_string(string() | binary()) -> {ok, term(), env()} | {error, term()}.
eval_string(Code) ->
    eval_string(Code, new_env()).

%% @doc Rubyコード文字列を指定環境で評価
-spec eval_string(string() | binary(), env()) -> {ok, term(), env()} | {error, term()}.
eval_string(Code, Env) when is_map(Env) ->
    % トークナイザーでトークン化
    case ruby_tokenizer:tokenize(Code) of
        {ok, Tokens, _Line} ->
            % パーサーでAST化
            case ruby_parser:parse(Tokens) of
                {ok, AST} ->
                    % 評価器で評価
                    eval(AST, Env);
                {error, ParseError} ->
                    {error, {parse_error, ParseError}}
            end;
        {error, TokenError, _Line} ->
            {error, {tokenize_error, TokenError}}
    end.

%% ============================================================================
%% 環境管理
%% ============================================================================

%% 評価環境の型定義
-type env() :: #{
    bindings := #{atom() => term()},    % ローカル変数の束縛
    parent := env() | nil,               % 親スコープ
    return_value := term() | undefined   % return文の値
}.

%% @doc 新しい環境を作成
-spec new_env() -> env().
new_env() ->
    #{
        bindings => #{},
        parent => nil,
        return_value => undefined
    }.

%% @doc 親環境を指定して新しい環境を作成
-spec new_env(env()) -> env().
new_env(ParentEnv) when is_map(ParentEnv) ->
    #{
        bindings => #{},
        parent => ParentEnv,
        return_value => undefined
    }.

%% @doc 変数を環境に束縛
-spec bind_var(atom(), term(), env()) -> env().
bind_var(Name, Value, Env) when is_atom(Name), is_map(Env) ->
    Bindings = maps:get(bindings, Env),
    NewBindings = maps:put(Name, Value, Bindings),
    maps:put(bindings, NewBindings, Env).

%% @doc 変数を環境から検索
-spec lookup_var(atom(), env()) -> {ok, term()} | {error, undefined}.
lookup_var(Name, Env) when is_atom(Name), is_map(Env) ->
    Bindings = maps:get(bindings, Env),
    case maps:find(Name, Bindings) of
        {ok, Value} ->
            {ok, Value};
        error ->
            % 親スコープを検索
            case maps:get(parent, Env) of
                nil ->
                    {error, undefined};
                ParentEnv ->
                    lookup_var(Name, ParentEnv)
            end
    end.

%% ============================================================================
%% ASTノード評価
%% ============================================================================

%% @doc ASTノードを評価（メインディスパッチャ）
-spec eval_node(term(), env()) -> {term(), env()}.

%% プログラム全体（ステートメントのリスト）
eval_node([], Env) ->
    {nil, Env};
eval_node(Stmts, Env) when is_list(Stmts) ->
    eval_stmts(Stmts, Env, nil);

%% リテラル
eval_node({integer, _Line, Value}, Env) ->
    {Value, Env};
eval_node({string, _Line, Value}, Env) ->
    {Value, Env};
eval_node({boolean, _Line, Value}, Env) ->
    {Value, Env};
eval_node({nil, _Line}, Env) ->
    {nil, Env};

%% 変数参照
eval_node({identifier, Line, Name}, Env) ->
    NameAtom = ensure_atom(Name),
    case lookup_var(NameAtom, Env) of
        {ok, Value} ->
            {Value, Env};
        {error, undefined} ->
            throw({ruby_error, {undefined_variable, Line, Name}})
    end;

%% 変数代入
eval_node({assign, _Line, {var, _, VarName}, Expr}, Env) ->
    {Value, Env1} = eval_node(Expr, Env),
    VarNameAtom = ensure_atom(VarName),
    NewEnv = bind_var(VarNameAtom, Value, Env1),
    {Value, NewEnv};

%% 二項演算子
eval_node({binary_op, Line, Op, Left, Right}, Env) ->
    {LeftVal, Env1} = eval_node(Left, Env),
    {RightVal, Env2} = eval_node(Right, Env1),
    Result = eval_binary_op(Op, LeftVal, RightVal, Line),
    {Result, Env2};

%% 単項演算子
eval_node({unary_op, Line, Op, Expr}, Env) ->
    {Val, Env1} = eval_node(Expr, Env),
    Result = eval_unary_op(Op, Val, Line),
    {Result, Env1};

%% メソッド呼び出し（未実装）
eval_node({call, Line, _Name, _Args}, _Env) ->
    throw({ruby_error, {not_implemented, Line, method_call}});

%% メソッド定義（未実装）
eval_node({method_def, Line, _Name, _Params, _Body}, _Env) ->
    throw({ruby_error, {not_implemented, Line, method_def}});

%% クラス定義（未実装）
eval_node({class_def, Line, _Name, _Body}, _Env) ->
    throw({ruby_error, {not_implemented, Line, class_def}});

%% if文
eval_node({if_stmt, _Line, Condition, ThenBody, ElsifClauses, ElseClause}, Env) ->
    {CondVal, Env1} = eval_node(Condition, Env),
    case is_truthy(CondVal) of
        true ->
            eval_stmts(ThenBody, Env1, nil);
        false ->
            eval_elsif_or_else(ElsifClauses, ElseClause, Env1)
    end;

%% while文
eval_node({while_stmt, _Line, Condition, Body}, Env) ->
    eval_while(Condition, Body, Env);

%% until文
eval_node({until_stmt, _Line, Condition, Body}, Env) ->
    eval_until(Condition, Body, Env);

%% return文
eval_node({return, _Line, Expr}, Env) ->
    case Expr of
        nil ->
            NewEnv = maps:put(return_value, nil, Env),
            {nil, NewEnv};
        _ ->
            {Value, Env1} = eval_node(Expr, Env),
            NewEnv = maps:put(return_value, Value, Env1),
            {Value, NewEnv}
    end;

%% break文（未実装）
eval_node({break, Line}, _Env) ->
    throw({ruby_error, {not_implemented, Line, break_stmt}});

%% next文（未実装）
eval_node({next, Line}, _Env) ->
    throw({ruby_error, {not_implemented, Line, next_stmt}});

%% 未知のノード
eval_node(Node, _Env) ->
    throw({ruby_error, {unknown_node, Node}}).

%% ============================================================================
%% ヘルパー関数
%% ============================================================================

%% @doc ステートメントのリストを順次評価
-spec eval_stmts(list(), env(), term()) -> {term(), env()}.
eval_stmts([], Env, LastValue) ->
    {LastValue, Env};
eval_stmts([Stmt | Rest], Env, _LastValue) ->
    % return文が実行されていたら即座に返す
    case maps:get(return_value, Env) of
        undefined ->
            {Value, NewEnv} = eval_node(Stmt, Env),
            eval_stmts(Rest, NewEnv, Value);
        ReturnValue ->
            {ReturnValue, Env}
    end.

%% @doc elsif句とelse句の評価
-spec eval_elsif_or_else(list(), term(), env()) -> {term(), env()}.
eval_elsif_or_else([], [], Env) ->
    {nil, Env};
eval_elsif_or_else([], {else_clause, _Line, ElseBody}, Env) ->
    eval_stmts(ElseBody, Env, nil);
eval_elsif_or_else([{elsif, _Line, Condition, Body} | Rest], ElseClause, Env) ->
    {CondVal, Env1} = eval_node(Condition, Env),
    case is_truthy(CondVal) of
        true ->
            eval_stmts(Body, Env1, nil);
        false ->
            eval_elsif_or_else(Rest, ElseClause, Env1)
    end.

%% @doc while文の評価
-spec eval_while(term(), list(), env()) -> {term(), env()}.
eval_while(Condition, Body, Env) ->
    {CondVal, Env1} = eval_node(Condition, Env),
    case is_truthy(CondVal) of
        true ->
            {_BodyVal, Env2} = eval_stmts(Body, Env1, nil),
            eval_while(Condition, Body, Env2);
        false ->
            {nil, Env1}
    end.

%% @doc until文の評価
-spec eval_until(term(), list(), env()) -> {term(), env()}.
eval_until(Condition, Body, Env) ->
    {CondVal, Env1} = eval_node(Condition, Env),
    case is_truthy(CondVal) of
        true ->
            {nil, Env1};
        false ->
            {_BodyVal, Env2} = eval_stmts(Body, Env1, nil),
            eval_until(Condition, Body, Env2)
    end.

%% @doc 二項演算子の評価
-spec eval_binary_op(atom(), term(), term(), integer()) -> term().
% 算術演算子
eval_binary_op('+', L, R, _Line) when is_number(L), is_number(R) ->
    L + R;
eval_binary_op('-', L, R, _Line) when is_number(L), is_number(R) ->
    L - R;
eval_binary_op('*', L, R, _Line) when is_number(L), is_number(R) ->
    L * R;
eval_binary_op('/', L, R, Line) when is_number(L), is_number(R) ->
    if
        R =:= 0 ->
            throw({ruby_error, {division_by_zero, Line}});
        true ->
            L div R
    end;
eval_binary_op('%', L, R, Line) when is_number(L), is_number(R) ->
    if
        R =:= 0 ->
            throw({ruby_error, {division_by_zero, Line}});
        true ->
            L rem R
    end;

% 比較演算子
eval_binary_op('==', L, R, _Line) ->
    L =:= R;
eval_binary_op('!=', L, R, _Line) ->
    L =/= R;
eval_binary_op('<', L, R, _Line) when is_number(L), is_number(R) ->
    L < R;
eval_binary_op('>', L, R, _Line) when is_number(L), is_number(R) ->
    L > R;
eval_binary_op('<=', L, R, _Line) when is_number(L), is_number(R) ->
    L =< R;
eval_binary_op('>=', L, R, _Line) when is_number(L), is_number(R) ->
    L >= R;

% 論理演算子
eval_binary_op('and', L, R, _Line) ->
    is_truthy(L) andalso is_truthy(R);
eval_binary_op('or', L, R, _Line) ->
    is_truthy(L) orelse is_truthy(R);

% ビット演算子
eval_binary_op('&', L, R, _Line) when is_integer(L), is_integer(R) ->
    L band R;
eval_binary_op('|', L, R, _Line) when is_integer(L), is_integer(R) ->
    L bor R;
eval_binary_op('^', L, R, _Line) when is_integer(L), is_integer(R) ->
    L bxor R;
eval_binary_op('<<', L, R, _Line) when is_integer(L), is_integer(R) ->
    L bsl R;
eval_binary_op('>>', L, R, _Line) when is_integer(L), is_integer(R) ->
    L bsr R;

% 未知の演算子
eval_binary_op(Op, _L, _R, Line) ->
    throw({ruby_error, {unknown_operator, Line, Op}}).

%% @doc 単項演算子の評価
-spec eval_unary_op(atom(), term(), integer()) -> term().
eval_unary_op('~', Val, _Line) when is_integer(Val) ->
    bnot Val;
eval_unary_op(Op, _Val, Line) ->
    throw({ruby_error, {unknown_operator, Line, Op}}).

%% @doc Rubyの真偽値判定（false と nil 以外はすべて真）
-spec is_truthy(term()) -> boolean().
is_truthy(false) -> false;
is_truthy(nil) -> false;
is_truthy(_) -> true.

%% @doc 文字列またはアトムをアトムに変換
-spec ensure_atom(atom() | list() | binary()) -> atom().
ensure_atom(Name) when is_atom(Name) ->
    Name;
ensure_atom(Name) when is_list(Name) ->
    list_to_atom(Name);
ensure_atom(Name) when is_binary(Name) ->
    binary_to_atom(Name, utf8).
