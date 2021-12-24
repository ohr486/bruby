-module(test_helper).

-export([test/0]).

test() ->
  io:put_chars("run our tests!"),
  erlang:halt(0).
