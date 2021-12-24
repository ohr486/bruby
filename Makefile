# ---------- utils ----------
Q := @

# ---------- commands ----------
ERL := erl
ERLC := erlc
EMAKE := erl -make

.PHONY: compile setup_dirs parser erlang clean test

default: compile

# ---------- INSTALL ----------

PARSER := lib/ruby/src/ruby_parser.erl
AFILE := lib/ruby/ebin/ruby.app

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

TEST_EBIN = lib/ruby/test/ebin
TEST_ERL_DIR = lib/ruby/test/erlang
TEST_TARGETS = $(addprefix $(TEST_EBIN)/, $(addsuffix .beam, $(basename $(notdir $(wildcard $(TEST_ERL_DIR)/*.erl)))))

test: compile $(TEST_TARGETS)
	$(Q) echo ===== run tests =====
	$(Q) $(ERL) -pa $(TEST_EBIN) -s test_helper test

$(TEST_EBIN)/%.beam: $(TEST_ERL_DIR)/%.erl
	$(Q) echo ===== compile for test: $< =====
	$(Q) mkdir -p $(TEST_EBIN)
	$(Q) $(ERLC) -o $(TEST_EBIN) $<

# ---------- CLEANUP ----------

clean:
	$(Q) echo ===== cleanup files =====
	rm -rf lib/*/ebin/
	rm -rf lib/*/test/ebin/
	rm -f erl_crush.dump
	rm -rf $(PARSER)
