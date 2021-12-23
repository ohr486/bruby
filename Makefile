Q := @

# commands
ERL := erl
ERLC := erlc
EMAKE := erl -make

# files
PARSER := lib/ruby/src/ruby_parser.erl
AFILE := lib/ruby/ebin/ruby.app

.PHONY: compile setup_dirs parser erlang clean

default: compile

# ---------- INSTALL ----------

compile: setup_dirs $(PARSER) $(AFILE) erlang

setup_dirs:
	$(Q) echo ===== setup dirs =====
	$(Q) cd lib/ruby && mkdir -p ebin

$(PARSER): lib/ruby/src/ruby_parser.yrl
	$(Q) echo ===== build parser =====
	$(Q) $(ERLC) -o $@ $<

$(AFILE): lib/ruby/src/ruby.app.src
	$(Q) echo ===== build appfile =====
	$(Q) cp $< $(AFILE)

erlang: $(PARSER)
	$(Q) echo ===== compile core =====
	$(Q) cd lib/ruby && $(EMAKE)

# ---------- TEST ----------



# ---------- CLEANUP ----------

clean:
	$(Q) echo ===== cleanup files =====
	rm -rf lib/*/ebin
	rm -rf $(PARSER)
