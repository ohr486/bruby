-module(erb).
-export([start/2, stop/1]).
-export([run/0]).
-behaviour(application).

%% callback apis

start(_Type, _Args) -> ok.

stop(_) -> ok.

%% apis

run() ->
  io:put_chars("run erb.\n"),
  erlang:halt(0).
