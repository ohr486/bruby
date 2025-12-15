-module(test_blocks).
-export([test/0]).

test() ->
  io:format("~n=== Running Block/Proc Tests ===~n"),

  % テスト実行
  test_block_with_yield(),
  test_block_given(),
  test_proc_new(),
  test_lambda(),
  test_closure(),

  io:format("~n=== All Block/Proc Tests Passed ===~n"),
  ok.

%% テストヘルパー
assert_eval(Code, Expected, TestName) ->
  case ruby_evaluator:eval_string(Code) of
    {ok, Result, _Env} ->
      case Result =:= Expected of
        true ->
          io:format("  [PASS] ~s~n", [TestName]);
        false ->
          io:format("  [FAIL] ~s~n", [TestName]),
          io:format("    Code:     ~s~n", [Code]),
          io:format("    Expected: ~p~n", [Expected]),
          io:format("    Actual:   ~p~n", [Result]),
          erlang:error({assertion_failed, TestName})
      end;
    {error, Reason} ->
      io:format("  [FAIL] ~s~n", [TestName]),
      io:format("    Code:  ~s~n", [Code]),
      io:format("    Error: ~p~n", [Reason]),
      erlang:error({eval_error, TestName, Reason})
  end.

%% 個別テスト

test_block_with_yield() ->
  % yieldが呼ばれることを確認（戻り値をテスト）
  Code1 = "def with_value() yield(42) end; with_value() { |v| v * 2 }",
  assert_eval(Code1, 84, "yield returns block result"),

  % yieldに複数の引数を渡す
  Code2 = "def add_nums() yield(3, 4) end; add_nums() { |a, b| a + b }",
  assert_eval(Code2, 7, "yield with multiple arguments"),

  % ブロックパラメータの処理
  Code3 = "def transform(n) yield(n) end; transform(10) { |x| x * 3 }",
  assert_eval(Code3, 30, "yield with parameter transformation"),

  % do...endブロック
  Code4 = "def compute() yield end; compute() do 99 end",
  assert_eval(Code4, 99, "do...end block"),

  ok.

test_block_given() ->
  % block_given?がtrueを返す
  Code1 = "def check() if block_given? 1 else 0 end end; check() { }",
  assert_eval(Code1, 1, "block_given? returns true"),

  % block_given?がfalseを返す
  Code2 = "def check() if block_given? 1 else 0 end end; check()",
  assert_eval(Code2, 0, "block_given? returns false"),

  ok.

test_proc_new() ->
  % Proc.newがProcオブジェクトを返すことを確認
  Code1 = "proc { |x| x * 2 }",
  case ruby_evaluator:eval_string(Code1) of
    {ok, Result, _Env} when is_map(Result) ->
      % Procオブジェクトはマップで、is_lambda => false
      case maps:get(is_lambda, Result, undefined) of
        false ->
          io:format("  [PASS] proc returns Proc object~n");
        _ ->
          io:format("  [FAIL] proc should return Proc object with is_lambda=false~n"),
          erlang:error({assertion_failed, "proc returns Proc object"})
      end;
    {error, Reason} ->
      io:format("  [FAIL] proc creation failed~n"),
      io:format("    Error: ~p~n", [Reason]),
      erlang:error({eval_error, "proc creation", Reason})
  end,

  % Procはパラメータを持つ
  Code2 = "proc { |a, b| a + b }",
  case ruby_evaluator:eval_string(Code2) of
    {ok, Result2, _} when is_map(Result2) ->
      Params = maps:get(params, Result2, []),
      case length(Params) of
        2 -> io:format("  [PASS] proc captures parameters~n");
        _ ->
          io:format("  [FAIL] proc should capture 2 parameters~n"),
          erlang:error({assertion_failed, "proc captures parameters"})
      end;
    _ ->
      io:format("  [FAIL] proc with parameters failed~n"),
      erlang:error({assertion_failed, "proc with parameters"})
  end,

  ok.

test_lambda() ->
  % Lambdaがlambdaオブジェクトを返すことを確認
  Code1 = "lambda { |x| x * 2 }",
  case ruby_evaluator:eval_string(Code1) of
    {ok, Result, _Env} when is_map(Result) ->
      % Lambdaオブジェクトはマップで、is_lambda => true
      case maps:get(is_lambda, Result, undefined) of
        true ->
          io:format("  [PASS] lambda returns Lambda object~n");
        _ ->
          io:format("  [FAIL] lambda should return Lambda object with is_lambda=true~n"),
          erlang:error({assertion_failed, "lambda returns Lambda object"})
      end;
    {error, Reason} ->
      io:format("  [FAIL] lambda creation failed~n"),
      io:format("    Error: ~p~n", [Reason]),
      erlang:error({eval_error, "lambda creation", Reason})
  end,

  % Lambdaもパラメータを持つ
  Code2 = "lambda { |a, b, c| a + b + c }",
  case ruby_evaluator:eval_string(Code2) of
    {ok, Result2, _} when is_map(Result2) ->
      Params = maps:get(params, Result2, []),
      case length(Params) of
        3 -> io:format("  [PASS] lambda captures parameters~n");
        _ ->
          io:format("  [FAIL] lambda should capture 3 parameters~n"),
          erlang:error({assertion_failed, "lambda captures parameters"})
      end;
    _ ->
      io:format("  [FAIL] lambda with parameters failed~n"),
      erlang:error({assertion_failed, "lambda with parameters"})
  end,

  ok.

test_closure() ->
  % クロージャ: ブロックは定義時の環境をキャプチャする
  Code1 = "def make_adder(n) lambda { |x| x + n } end; add5 = make_adder(5); add5",
  % lambda自体が返されるので、今は評価できないが、定義は成功するはず
  case ruby_evaluator:eval_string(Code1) of
    {ok, Result, _Env} when is_map(Result) ->
      % クロージャ環境がキャプチャされているか確認
      case maps:get(closure_env, Result, undefined) of
        ClosureEnv when is_map(ClosureEnv) ->
          % 環境がマップ形式でキャプチャされている
          io:format("  [PASS] closure definition~n"),
          io:format("  [PASS] closure captures environment~n");
        undefined ->
          io:format("  [FAIL] closure should capture environment~n"),
          erlang:error({assertion_failed, "closure captures environment"});
        Other ->
          io:format("  [FAIL] unexpected closure_env format: ~p~n", [Other]),
          erlang:error({assertion_failed, "closure env format"})
      end;
    {error, Reason} ->
      io:format("  [FAIL] closure definition~n"),
      io:format("    Error: ~p~n", [Reason]),
      erlang:error({eval_error, "closure definition", Reason})
  end,

  % 複数の変数をキャプチャするクロージャ
  Code2 = "x = 10; y = 20; lambda { |z| x + y + z }",
  case ruby_evaluator:eval_string(Code2) of
    {ok, Result2, _} when is_map(Result2) ->
      case maps:get(closure_env, Result2, undefined) of
        ClosureEnv2 when is_map(ClosureEnv2) ->
          io:format("  [PASS] closure captures multiple variables~n");
        undefined ->
          io:format("  [FAIL] closure should capture multiple variables~n"),
          erlang:error({assertion_failed, "closure captures multiple variables"});
        _ ->
          io:format("  [FAIL] unexpected closure_env format~n"),
          erlang:error({assertion_failed, "closure env format"})
      end;
    {error, Reason2} ->
      io:format("  [FAIL] closure with multiple variables failed: ~p~n", [Reason2]),
      erlang:error({eval_error, "closure with multiple variables", Reason2})
  end,

  ok.
