-module(ruby_tokenizer).
-include("ruby.hrl").
-export([tokenize/1, tokenize/3, tokenize/4]).

%% @doc トークナイズのエントリーポイント（文字列のみ）
tokenize(String) when is_list(String) ->
  tokenize(String, 1, #ruby_tokenizer{});
tokenize(String) when is_binary(String) ->
  tokenize(binary_to_list(String), 1, #ruby_tokenizer{}).

%% @doc トークナイズのエントリーポイント（行番号と状態指定）
tokenize(String, Line, Opts) ->
  tokenize(String, Line, 1, Opts).

%% @doc トークナイズのメイン処理
tokenize(String, Line, Column, #ruby_tokenizer{} = Scope) ->
  tokenize(String, Line, Column, Scope, []).

%% @doc 内部トークナイズ処理
%% 空文字列の場合、トークンリストを逆順にして返す
tokenize([], Line, _Column, _Scope, Tokens) ->
  {ok, lists:reverse(Tokens), Line};

%% 空白文字をスキップ
tokenize([C | Rest], Line, Column, Scope, Tokens) when C =:= $\s; C =:= $\t ->
  tokenize(Rest, Line, Column + 1, Scope, Tokens);

%% 改行文字を処理
tokenize([$\r, $\n | Rest], Line, _Column, Scope, Tokens) ->
  tokenize(Rest, Line + 1, 1, Scope, Tokens);
tokenize([$\n | Rest], Line, _Column, Scope, Tokens) ->
  tokenize(Rest, Line + 1, 1, Scope, Tokens);
tokenize([$\r | Rest], Line, _Column, Scope, Tokens) ->
  tokenize(Rest, Line + 1, 1, Scope, Tokens);

%% コメント（#から行末まで）
tokenize([$# | Rest], Line, Column, Scope, Tokens) ->
  {_, NewRest, NewLine} = skip_comment(Rest, Line),
  tokenize(NewRest, NewLine, Column, Scope, Tokens);

%% 識別子とキーワード
tokenize([C | _] = String, Line, Column, Scope, Tokens)
    when (C >= $a andalso C =< $z) orelse
         (C >= $A andalso C =< $Z) orelse
         C =:= $_ ->
  {Identifier, Rest} = scan_identifier(String, []),
  Token = identifier_or_keyword(Identifier, Line),
  tokenize(Rest, Line, Column + length(Identifier), Scope, [Token | Tokens]);

%% 数値リテラル
tokenize([C | _] = String, Line, Column, Scope, Tokens) when C >= $0 andalso C =< $9 ->
  {Number, Rest} = scan_number(String, []),
  Token = {tINTEGER, Line, list_to_integer(Number)},
  tokenize(Rest, Line, Column + length(Number), Scope, [Token | Tokens]);

%% 文字列リテラル（ダブルクォート）
tokenize([$" | Rest], Line, Column, Scope, Tokens) ->
  case scan_string(Rest, [], $") of
    {ok, String, NewRest} ->
      Token = {tSTRING, Line, String},
      tokenize(NewRest, Line, Column + length(String) + 2, Scope, [Token | Tokens]);
    {error, Reason} ->
      {error, {Line, ?MODULE, Reason}, Line}
  end;

%% 文字列リテラル（シングルクォート）
tokenize([$' | Rest], Line, Column, Scope, Tokens) ->
  case scan_string(Rest, [], $') of
    {ok, String, NewRest} ->
      Token = {tSTRING, Line, String},
      tokenize(NewRest, Line, Column + length(String) + 2, Scope, [Token | Tokens]);
    {error, Reason} ->
      {error, {Line, ?MODULE, Reason}, Line}
  end;

%% 2文字演算子
tokenize("==" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tEQ, Line} | Tokens]);
tokenize("!=" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tNE, Line} | Tokens]);
tokenize("<=" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tLE, Line} | Tokens]);
tokenize(">=" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tGE, Line} | Tokens]);
tokenize("&&" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tAND, Line} | Tokens]);
tokenize("||" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tOR, Line} | Tokens]);
tokenize("<<" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tLSHIFT, Line} | Tokens]);
tokenize(">>" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tRSHIFT, Line} | Tokens]);
tokenize("=>" ++ Rest, Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 2, Scope, [{tASSOC, Line} | Tokens]);

%% 1文字演算子と区切り文字
tokenize([$+ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'+', Line} | Tokens]);
tokenize([$- | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'-', Line} | Tokens]);
tokenize([$* | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'*', Line} | Tokens]);
tokenize([$/ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'/', Line} | Tokens]);
tokenize([$% | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'%', Line} | Tokens]);
tokenize([$= | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'=', Line} | Tokens]);
tokenize([$< | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'<', Line} | Tokens]);
tokenize([$> | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'>', Line} | Tokens]);
tokenize([$! | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'!', Line} | Tokens]);
tokenize([$( | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'(', Line} | Tokens]);
tokenize([$) | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{')', Line} | Tokens]);
tokenize([$[ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'[', Line} | Tokens]);
tokenize([$] | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{']', Line} | Tokens]);
tokenize([${ | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'{', Line} | Tokens]);
tokenize([$} | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'}', Line} | Tokens]);
tokenize([$, | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{',', Line} | Tokens]);
tokenize([$. | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{'.', Line} | Tokens]);
tokenize([$: | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{':', Line} | Tokens]);
tokenize([$; | Rest], Line, Column, Scope, Tokens) ->
  tokenize(Rest, Line, Column + 1, Scope, [{';', Line} | Tokens]);

%% 未知の文字
tokenize([C | Rest], Line, Column, Scope, Tokens) ->
  Warning = {Line, ?MODULE, {unknown_character, C}},
  NewScope = Scope#ruby_tokenizer{warnings = [Warning | Scope#ruby_tokenizer.warnings]},
  tokenize(Rest, Line, Column + 1, NewScope, Tokens).

%% ========================================
%% ヘルパー関数
%% ========================================

%% @doc コメントをスキップ（行末まで）
skip_comment([], Line) ->
  {[], [], Line};
skip_comment([$\n | Rest], Line) ->
  {[], Rest, Line + 1};
skip_comment([$\r, $\n | Rest], Line) ->
  {[], Rest, Line + 1};
skip_comment([$\r | Rest], Line) ->
  {[], Rest, Line + 1};
skip_comment([_ | Rest], Line) ->
  skip_comment(Rest, Line).

%% @doc 識別子をスキャン
scan_identifier([], Acc) ->
  {lists:reverse(Acc), []};
scan_identifier([C | Rest], Acc)
    when (C >= $a andalso C =< $z) orelse
         (C >= $A andalso C =< $Z) orelse
         (C >= $0 andalso C =< $9) orelse
         C =:= $_ orelse C =:= $? orelse C =:= $! ->
  scan_identifier(Rest, [C | Acc]);
scan_identifier(String, Acc) ->
  {lists:reverse(Acc), String}.

%% @doc 数値をスキャン（整数のみ）
scan_number([], Acc) ->
  {lists:reverse(Acc), []};
scan_number([C | Rest], Acc) when C >= $0 andalso C =< $9 ->
  scan_number(Rest, [C | Acc]);
scan_number(String, Acc) ->
  {lists:reverse(Acc), String}.

%% @doc 文字列をスキャン
scan_string([], _Acc, _Quote) ->
  {error, unterminated_string};
scan_string([Quote | Rest], Acc, Quote) ->
  {ok, lists:reverse(Acc), Rest};
scan_string([$\\, C | Rest], Acc, Quote) ->
  % エスケープ文字の処理
  EscapedChar = case C of
    $n -> $\n;
    $t -> $\t;
    $r -> $\r;
    $\\ -> $\\;
    $" -> $";
    $' -> $';
    _ -> C
  end,
  scan_string(Rest, [EscapedChar | Acc], Quote);
scan_string([C | Rest], Acc, Quote) ->
  scan_string(Rest, [C | Acc], Quote).

%% @doc 識別子がキーワードかどうかを判定
identifier_or_keyword("def", Line) -> {tDEF, Line};
identifier_or_keyword("end", Line) -> {tEND, Line};
identifier_or_keyword("class", Line) -> {tCLASS, Line};
identifier_or_keyword("module", Line) -> {tMODULE, Line};
identifier_or_keyword("if", Line) -> {tIF, Line};
identifier_or_keyword("elsif", Line) -> {tELSIF, Line};
identifier_or_keyword("else", Line) -> {tELSE, Line};
identifier_or_keyword("unless", Line) -> {tUNLESS, Line};
identifier_or_keyword("while", Line) -> {tWHILE, Line};
identifier_or_keyword("until", Line) -> {tUNTIL, Line};
identifier_or_keyword("for", Line) -> {tFOR, Line};
identifier_or_keyword("in", Line) -> {tIN, Line};
identifier_or_keyword("do", Line) -> {tDO, Line};
identifier_or_keyword("return", Line) -> {tRETURN, Line};
identifier_or_keyword("yield", Line) -> {tYIELD, Line};
identifier_or_keyword("break", Line) -> {tBREAK, Line};
identifier_or_keyword("next", Line) -> {tNEXT, Line};
identifier_or_keyword("redo", Line) -> {tREDO, Line};
identifier_or_keyword("retry", Line) -> {tRETRY, Line};
identifier_or_keyword("rescue", Line) -> {tRESCUE, Line};
identifier_or_keyword("ensure", Line) -> {tENSURE, Line};
identifier_or_keyword("raise", Line) -> {tRAISE, Line};
identifier_or_keyword("begin", Line) -> {tBEGIN, Line};
identifier_or_keyword("case", Line) -> {tCASE, Line};
identifier_or_keyword("when", Line) -> {tWHEN, Line};
identifier_or_keyword("then", Line) -> {tTHEN, Line};
identifier_or_keyword("and", Line) -> {tAND, Line};
identifier_or_keyword("or", Line) -> {tOR, Line};
identifier_or_keyword("not", Line) -> {tNOT, Line};
identifier_or_keyword("true", Line) -> {tTRUE, Line};
identifier_or_keyword("false", Line) -> {tFALSE, Line};
identifier_or_keyword("nil", Line) -> {tNIL, Line};
identifier_or_keyword("self", Line) -> {tSELF, Line};
identifier_or_keyword("super", Line) -> {tSUPER, Line};
identifier_or_keyword(Identifier, Line) -> {tIDENTIFIER, Line, Identifier}.

