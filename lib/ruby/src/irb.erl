-module(irb).
-export([start/0]).

start() ->
    {ok, _} = application:ensure_all_started(ruby),
    io:start(),
    io:put_chars("start irb."),
    repl_loop().

repl_loop() -> repl_loop().