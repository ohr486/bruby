ERL := erl -pa lib/ruby/ebin
Q := @

PARSER := lib/ruby/src/ruby_parser.erl
AFILE := lib/ruby/ebin/ruby.app

.PHONY: compile setup_dirs parser erlang clean

default: compile

compile: setup_dirs $(PARSER) $(AFILE) erlang

setup_dirs:
	$(Q) cd lib/ruby && mkdir -p ebin

$(PARSER): lib/ruby/src/ruby_parser.yrl
	$(Q) erlc -o $@ $<

$(AFILE): lib/ruby/src/ruby.app.src
	$(Q) cp $< $(AFILE)

erlang: $(PARSER)
	$(Q) cd lib/ruby && erl -make

clean:
	rm -rf lib/*/ebin
	rm -rf $(PARSER)
