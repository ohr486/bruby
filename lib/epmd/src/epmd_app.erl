-module(epmd_app).
-behaviour(application).

-export([start/0, start/2, stop/1]).

start() ->
  start(normal, []).

start(normal, Args) ->
  epmd_sup:start_link(Args).

stop(_State) ->
  ok.

