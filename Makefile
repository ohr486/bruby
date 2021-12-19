PARSER := lib/ruby/src/rbuy_parser.erl
Q := @

.PHONY: compile parser clean

default: compile

compile: $(PARSER)

$(PARSER): lib/ruby/src/ruby_parser.yrl
	$(Q) erlc -o $@ $<

clean:
	rm -rf $(PARSER)

