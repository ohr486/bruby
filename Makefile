# ---------- UTILS ----------
Q := @

# ---------- COMMAND ----------
ERL := erl
ERLC := erlc
EMAKE := erl -make

# ---------- COMMON ----------

.PHONY: compile clean test erlang
.PHONY: compile_ruby test_ruby setup_ruby_dirs erlang_for_ruby
.PHONY: compile_irb test_irb setup_irb_dirs erlang_for_irb

default: compile

compile: compile_ruby compile_irb
test: test_ruby test_irb
ci: compile test


# ---------- PRE BUILD RUBY ----------

setup_ruby_dirs:
	$(Q) cd lib/ruby && mkdir -p ebin

RUBY_PARSER := lib/ruby/src/ruby_parser.erl

$(RUBY_PARSER): lib/ruby/src/ruby_parser.yrl
	$(Q) echo ===== build ruby parser
	$(Q) $(ERLC) -o $@ $<

# ---------- BUILD RUBY ----------

RUBY_APP_FILE := lib/ruby/ebin/ruby.app
RUBY_APP_SRC_FILE := lib/ruby/src/ruby.app.src

compile_ruby: setup_ruby_dirs $(RUBY_PARSER) $(RUBY_APP_FILE) erlang_for_ruby

$(RUBY_APP_FILE): $(RUBY_APP_SRC_FILE)
	$(Q) echo ===== create ruby appfile
	$(Q) cp $< $(RUBY_APP_FILE)

erlang_for_ruby: $(RUBY_PARSER)
	$(Q) cd lib/ruby && $(EMAKE)

# ---------- TEST RUBY ----------

TEST_RUBY_EBIN = lib/ruby/test/ebin
TEST_RUBY_ERL_DIR = lib/ruby/test/erlang
TEST_RUBY_TARGETS = $(addprefix $(TEST_RUBY_EBIN)/, $(addsuffix .beam, $(basename $(notdir $(wildcard $(TEST_RUBY_ERL_DIR)/*.erl)))))

test_ruby: compile_ruby $(TEST_RUBY_TARGETS)
	$(Q) echo ===== run ruby tests
	$(Q) $(ERL) -pa $(TEST_RUBY_EBIN) -s test_helper test

$(TEST_RUBY_EBIN)/%.beam: $(TEST_RUBY_ERL_DIR)/%.erl
	$(Q) mkdir -p $(TEST_RUBY_EBIN)
	$(Q) $(ERLC) -o $(TEST_RUBY_EBIN) $<



# ---------- PRE BUILD IRB ----------

setup_irb_dirs:
	$(Q) cd lib/irb && mkdir -p ebin

# ---------- BUILD IRB ----------

IRB_APP_FILE := lib/irb/ebin/irb.app
IRB_APP_SRC_FILE := lib/irb/src/irb.app.src

compile_irb: setup_irb_dirs $(IRB_APP_FILE) erlang_for_irb

$(IRB_APP_FILE): $(IRB_APP_SRC_FILE)
	$(Q) echo ===== create irb appfile
	$(Q) cp $< $(IRB_APP_FILE)

erlang_for_irb:
	$(Q) cd lib/irb && $(EMAKE)



# ---------- TEST IRB ----------

TEST_IRB_EBIN = lib/irb/test/ebin
TEST_IRB_ERL_DIR = lib/irb/test/erlang
TEST_IRB_TARGETS = $(addprefix $(TEST_IRB_EBIN)/, $(addsuffix .beam, $(basename $(notdir $(wildcard $(TEST_IRB_ERL_DIR)/*.erl)))))

test_irb: compile_irb $(TEST_IRB_TARGETS)
	$(Q) echo ===== run irb tests
	$(Q) $(ERL) -pa $(TEST_IRB_EBIN) -s test_helper test

$(TEST_IRB_EBIN)/%.beam: $(TEST_IRB_ERL_DIR)/%.erl
	$(Q) mkdir -p $(TEST_IRB_EBIN)
	$(Q) $(ERLC) -o $(TEST_IRB_EBIN) $<



# ---------- CLEANUP ----------

clean:
	$(Q) echo ===== cleanup files
	rm -rf lib/*/ebin/
	rm -rf lib/*/test/ebin/
	rm -f erl_crash.dump
	rm -rf $(RUBY_PARSER)
	rm -rf lib/**/*.beam
