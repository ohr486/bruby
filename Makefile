ERL := erl -pa lib/ruby/ebin
Q := @

.PHONY: compile parser erlang clean

default: compile

compile: $(PARSER) erlang

PARSER := lib/ruby/src/ruby_parser.erl

$(PARSER): lib/ruby/src/ruby_parser.yrl
	$(Q) erlc -o $@ $<

erlang: $(PARSER)
	$(Q) cd lib/ruby && mkdir -p ebin && erl -make


clean:
	rm -rf lib/*/ebin
	rm -rf $(PARSER)

