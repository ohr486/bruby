-module(epmd_sup).
-export([init/1, start_link/0]).
-behaviour(supervisor).

init(_) -> ok.

start_link() -> ok.
