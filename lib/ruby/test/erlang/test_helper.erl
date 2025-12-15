-module(test_helper).

-export([test/0]).

test() ->
  io:format("~n========================================~n"),
  io:format("Running bruby test suite~n"),
  io:format("========================================~n~n"),

  % テスト実行
  Result = try
    test_tokenizer:test(),
    test_parser:test(),
    test_evaluator:test(),
    test_blocks:test(),
    test_scope:test(),
    test_value:test(),
    test_object:test(),
    test_numeric:test(),
    test_kernel:test(),
    test_string:test(),
    success
  catch
    Error:Reason:Stacktrace ->
      io:format("~n[ERROR] Test failed:~n"),
      io:format("  Error: ~p~n", [Error]),
      io:format("  Reason: ~p~n", [Reason]),
      io:format("  Stacktrace: ~p~n", [Stacktrace]),
      failure
  end,

  io:format("~n========================================~n"),
  case Result of
    success ->
      io:format("All tests passed!~n"),
      io:format("========================================~n~n"),
      erlang:halt(0);
    failure ->
      io:format("Some tests failed!~n"),
      io:format("========================================~n~n"),
      erlang:halt(1)
  end.
