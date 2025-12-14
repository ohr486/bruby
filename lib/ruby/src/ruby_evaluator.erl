-module(ruby_evaluator).
-export([eval/1, eval/2, eval_string/1, eval_string/2, new_env/0, new_env/1]).

%% 将来のクラスインスタンス化で使用予定のため警告を抑制
-compile({nowarn_unused_function, [{lookup_class, 2}]}).

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
    methods := #{atom() => method()},    % メソッド定義
    classes := #{atom() => class()},     % クラス定義
    parent := env() | nil,               % 親スコープ
    return_value := term() | undefined,  % return文の値
    current_block := block() | nil       % 現在のブロック（yield用）
}.

%% メソッドの型定義
-type method() :: #{
    name := atom(),
    params := list(),
    body := list(),
    closure_env := env()  % メソッド定義時の環境（クロージャ）
}.

%% ブロック/Procの型定義
-type block() :: #{
    params := list(),
    body := list(),
    closure_env := env(),  % ブロック定義時の環境（クロージャ）
    is_lambda := boolean() % lambdaかどうか
}.

%% クラスの型定義
-type class() :: #{
    name := atom(),
    superclass := atom() | nil,          % 親クラス
    methods := #{atom() => method()},    % クラスのメソッド
    instance_vars := list(atom())        % インスタンス変数のリスト（将来の拡張用）
}.

%% @doc 新しい環境を作成
-spec new_env() -> env().
new_env() ->
    #{
        bindings => #{},
        methods => #{},
        classes => #{},
        parent => nil,
        return_value => undefined,
        current_block => nil
    }.

%% @doc 親環境を指定して新しい環境を作成
-spec new_env(env()) -> env().
new_env(ParentEnv) when is_map(ParentEnv) ->
    #{
        bindings => #{},
        methods => #{},
        classes => #{},
        parent => ParentEnv,
        return_value => undefined,
        current_block => nil
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

%% @doc メソッドを環境に登録
-spec define_method(atom(), list(), list(), env()) -> env().
define_method(Name, Params, Body, Env) when is_atom(Name), is_map(Env) ->
    Methods = maps:get(methods, Env),
    Method = #{
        name => Name,
        params => Params,
        body => Body,
        closure_env => Env
    },
    NewMethods = maps:put(Name, Method, Methods),
    maps:put(methods, NewMethods, Env).

%% @doc メソッドを環境から検索
-spec lookup_method(atom(), env()) -> {ok, method()} | {error, undefined}.
lookup_method(Name, Env) when is_atom(Name), is_map(Env) ->
    Methods = maps:get(methods, Env),
    case maps:find(Name, Methods) of
        {ok, Method} ->
            {ok, Method};
        error ->
            % 親スコープを検索
            case maps:get(parent, Env) of
                nil ->
                    {error, undefined};
                ParentEnv ->
                    lookup_method(Name, ParentEnv)
            end
    end.

%% @doc クラスを環境に登録
-spec define_class(atom(), atom() | nil, #{atom() => method()}, env()) -> env().
define_class(Name, Superclass, Methods, Env) when is_atom(Name), is_map(Env) ->
    Classes = maps:get(classes, Env),
    Class = #{
        name => Name,
        superclass => Superclass,
        methods => Methods,
        instance_vars => []
    },
    NewClasses = maps:put(Name, Class, Classes),
    maps:put(classes, NewClasses, Env).

%% @doc クラスを環境から検索
-spec lookup_class(atom(), env()) -> {ok, class()} | {error, undefined}.
lookup_class(Name, Env) when is_atom(Name), is_map(Env) ->
    Classes = maps:get(classes, Env),
    case maps:find(Name, Classes) of
        {ok, Class} ->
            {ok, Class};
        error ->
            % 親スコープを検索
            case maps:get(parent, Env) of
                nil ->
                    {error, undefined};
                ParentEnv ->
                    lookup_class(Name, ParentEnv)
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

%% メソッド呼び出し（ブロックなし - 後方互換性のため）
eval_node({call, Line, Name, Args}, Env) ->
    eval_node({call, Line, Name, Args, nil}, Env);

%% メソッド呼び出し（ブロック付き）
eval_node({call, Line, Name, Args, BlockAST}, Env) ->
    NameAtom = ensure_atom(Name),
    case lookup_method(NameAtom, Env) of
        {ok, Method} ->
            % 引数を評価
            {ArgValues, Env1} = eval_args(Args, Env, []),
            % ブロックを評価（ASTをブロックオブジェクトに変換）
            Block = case BlockAST of
                nil -> nil;
                _ -> eval_block_ast(BlockAST, Env1, false)
            end,
            % メソッドを呼び出し（ブロックを渡す）
            call_method(Method, ArgValues, Block, Env1, Line);
        {error, undefined} ->
            throw({ruby_error, {undefined_method, Line, Name}})
    end;

%% メソッド定義
eval_node({method_def, _Line, Name, Params, Body}, Env) ->
    NameAtom = ensure_atom(Name),
    % パラメータ名のリストを抽出
    ParamNames = extract_param_names(Params),
    % メソッドを環境に登録
    NewEnv = define_method(NameAtom, ParamNames, Body, Env),
    % メソッド定義はシンボル（アトム）を返す
    {NameAtom, NewEnv};

%% クラス定義
eval_node({class_def, _Line, Name, Body}, Env) ->
    NameAtom = ensure_atom(Name),
    % クラススコープ用の新しい環境を作成（親環境を引き継ぐ）
    ClassEnv = new_env(Env),
    % クラス本体を評価してメソッドを収集
    {_LastValue, ClassEnv1} = eval_stmts(Body, ClassEnv, nil),
    % クラス本体で定義されたメソッドを取得
    ClassMethods = maps:get(methods, ClassEnv1),
    % クラスを環境に登録（継承なし: superclass = nil）
    NewEnv = define_class(NameAtom, nil, ClassMethods, Env),
    % クラス定義はシンボル（アトム）を返す
    {NameAtom, NewEnv};

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

%% yield式
eval_node({yield, Line, Args}, Env) ->
    case maps:get(current_block, Env) of
        nil ->
            throw({ruby_error, {no_block_given, Line}});
        Block ->
            % 引数を評価
            {ArgValues, Env1} = eval_args(Args, Env, []),
            % ブロックを呼び出し
            {Result, BlockEnv} = call_block(Block, ArgValues, Env1, Line),
            % ブロック実行後の環境から変更された変数を現在の環境にマージ
            NewEnv = merge_closure_bindings(BlockEnv, Env1, Block),
            {Result, NewEnv}
    end;

%% block_given?式
eval_node({block_given, _Line}, Env) ->
    HasBlock = maps:get(current_block, Env) =/= nil,
    {HasBlock, Env};

%% Proc.new式
eval_node({proc_new, _Line, BlockAST}, Env) ->
    Block = eval_block_ast(BlockAST, Env, false),
    {Block, Env};

%% lambda式
eval_node({lambda, _Line, BlockAST}, Env) ->
    Lambda = eval_block_ast(BlockAST, Env, true),
    {Lambda, Env};

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

%% @doc パラメータリストからパラメータ名のリストを抽出
-spec extract_param_names(list()) -> list(atom()).
extract_param_names([]) ->
    [];
extract_param_names([{param, _Line, Name} | Rest]) ->
    NameAtom = ensure_atom(Name),
    [NameAtom | extract_param_names(Rest)].

%% @doc 引数リストを順次評価
-spec eval_args(list(), env(), list()) -> {list(), env()}.
eval_args([], Env, AccValues) ->
    {lists:reverse(AccValues), Env};
eval_args([Arg | Rest], Env, AccValues) ->
    {Value, Env1} = eval_node(Arg, Env),
    eval_args(Rest, Env1, [Value | AccValues]).

%% @doc メソッドを呼び出す
-spec call_method(method(), list(), block() | nil, env(), integer()) -> {term(), env()}.
call_method(Method, ArgValues, Block, CallerEnv, Line) ->
    #{
        params := ParamNames,
        body := Body,
        closure_env := ClosureEnv
    } = Method,

    % 引数の数をチェック
    ParamCount = length(ParamNames),
    ArgCount = length(ArgValues),
    if
        ParamCount =/= ArgCount ->
            throw({ruby_error, {wrong_number_of_arguments, Line, ParamCount, ArgCount}});
        true ->
            ok
    end,

    % メソッド実行用の新しい環境を作成（クロージャ環境を親とする）
    MethodEnv = new_env(ClosureEnv),

    % パラメータと引数を束縛
    MethodEnv1 = bind_params(ParamNames, ArgValues, MethodEnv),

    % ブロックを環境に設定
    MethodEnv2 = maps:put(current_block, Block, MethodEnv1),

    % メソッド本体を評価
    {Result, MethodEnv3} = eval_stmts(Body, MethodEnv2, nil),

    % return文が実行されていた場合はその値を返す
    case maps:get(return_value, MethodEnv3) of
        undefined ->
            {Result, CallerEnv};
        ReturnValue ->
            {ReturnValue, CallerEnv}
    end.

%% @doc パラメータと引数を束縛
-spec bind_params(list(atom()), list(), env()) -> env().
bind_params([], [], Env) ->
    Env;
bind_params([ParamName | RestParams], [ArgValue | RestArgs], Env) ->
    Env1 = bind_var(ParamName, ArgValue, Env),
    bind_params(RestParams, RestArgs, Env1).

%% @doc ブロックASTをブロックオブジェクトに変換
-spec eval_block_ast(term(), env(), boolean()) -> block().
eval_block_ast({block, _Line, Params, Body}, Env, IsLambda) ->
    % パラメータ名のリストを抽出
    ParamNames = extract_param_names(Params),
    % ブロックオブジェクトを作成（クロージャとして現在の環境をキャプチャ）
    #{
        params => ParamNames,
        body => Body,
        closure_env => Env,
        is_lambda => IsLambda
    }.

%% @doc ブロックを呼び出す
-spec call_block(block(), list(), env(), integer()) -> {term(), env()}.
call_block(Block, ArgValues, CallerEnv, Line) ->
    #{
        params := ParamNames,
        body := Body,
        closure_env := ClosureEnv,
        is_lambda := IsLambda
    } = Block,

    % lambdaの場合は引数の数を厳密にチェック
    ParamCount = length(ParamNames),
    ArgCount = length(ArgValues),
    if
        IsLambda andalso (ParamCount =/= ArgCount) ->
            throw({ruby_error, {wrong_number_of_arguments, Line, ParamCount, ArgCount}});
        true ->
            ok
    end,

    % ブロック実行用の環境を作成
    % クロージャ環境と呼び出し元環境のbindingsをマージ
    MergedBindings = maps:merge(
        maps:get(bindings, ClosureEnv),
        maps:get(bindings, CallerEnv)
    ),
    BlockEnv = ClosureEnv#{bindings => MergedBindings},

    % パラメータと引数を束縛
    % procの場合は余分な引数は無視、不足分はnilで埋める
    BlockEnv1 = if
        IsLambda ->
            bind_params(ParamNames, ArgValues, BlockEnv);
        true ->
            bind_params_flexible(ParamNames, ArgValues, BlockEnv)
    end,

    % ブロック本体を評価
    {Result, BlockEnv2} = eval_stmts(Body, BlockEnv1, nil),

    {Result, BlockEnv2}.

%% @doc ブロック実行後の変数変更を呼び出し元環境にマージ
-spec merge_closure_bindings(env(), env(), block()) -> env().
merge_closure_bindings(BlockEnv, CallerEnv, Block) ->
    #{closure_env := ClosureEnv} = Block,

    % ブロック実行前のクロージャ環境のバインディング
    OriginalBindings = maps:get(bindings, ClosureEnv),

    % ブロック実行後のバインディング
    BlockBindings = maps:get(bindings, BlockEnv),

    % 呼び出し元のバインディング
    CallerBindings = maps:get(bindings, CallerEnv),

    % クロージャ環境に存在していた変数、または呼び出し元に存在する変数の変更を反映
    UpdatedBindings = maps:fold(
        fun(Key, Value, Acc) ->
            case maps:is_key(Key, OriginalBindings) orelse maps:is_key(Key, CallerBindings) of
                true -> maps:put(Key, Value, Acc);
                false -> Acc
            end
        end,
        CallerBindings,
        BlockBindings
    ),

    CallerEnv#{bindings => UpdatedBindings}.

%% @doc パラメータと引数を柔軟に束縛（proc用）
-spec bind_params_flexible(list(atom()), list(), env()) -> env().
bind_params_flexible([], _Args, Env) ->
    Env;
bind_params_flexible([ParamName | RestParams], [], Env) ->
    % 引数が足りない場合はnilで埋める
    Env1 = bind_var(ParamName, nil, Env),
    bind_params_flexible(RestParams, [], Env1);
bind_params_flexible([ParamName | RestParams], [ArgValue | RestArgs], Env) ->
    Env1 = bind_var(ParamName, ArgValue, Env),
    bind_params_flexible(RestParams, RestArgs, Env1).
