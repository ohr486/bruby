-module(ruby).
-behaviour(application).

-export([start/2, stop/1]).
-export([run_script/0]).

%% callback apis

start(_Type, _Args) -> ok.

stop(_) -> ok.

%% api

run_script() ->
  io:put_chars("exec script").
