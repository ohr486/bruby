-module(ruby_tokenizer).
-include("ruby.hrl").
-export([tokenize/1, tokenize/3, tokenize/4]).

tokenize(_List) ->
  {error, empty}.

tokenize(String, Line, Opts) ->
  tokenize(String, Line, 1, Opts).

tokenize(String, Line, Column, #ruby_tokenizer{} = Scope) ->
  tokenize(String, Line, Column, Scope, []).

tokenize(_String, _Line, _Column, #ruby_tokenizer{} = _Scope, _Tokens) ->
  {dummy, tokenizer}.

