-module(ruby).
-export([start/2, stop/1]).
-export([run_script/0]).
-behaviour(application).

%% callback apis

start(_Type, _Args) -> ok.

stop(_) -> ok.

%% apis

run_script() ->
  io:put_chars("exec script").
