-module(test_helper).

-export([test/0]).

test() ->
  io:put_chars("run our erb tests!\n"),
  erlang:halt(0).
