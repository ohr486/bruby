-module(test_helper).

-export([test/0]).

test() ->
  io:put_chars("run our irb tests!\n"),
  erlang:halt(0).
