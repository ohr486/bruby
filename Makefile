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
.PHONY: compile_epmd test_epmd setup_epmd_dirs erlang_for_epmd
.PHONY: compile_erb test_erb setup_erb_dirs erlang_for_erb

default: compile

compile: compile_ruby compile_irb compile_epmd compile_erb
test: test_ruby test_irb test_epmd test_erb
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



# ---------- PRE BUILD EPMD ----------

setup_epmd_dirs:
	$(Q) cd lib/epmd && mkdir -p ebin

# ---------- BUILD EPMD ----------

EPMD_APP_FILE := lib/epmd/ebin/epmd.app
EPMD_APP_SRC_FILE := lib/epmd/src/epmd.app.src

compile_epmd: setup_epmd_dirs $(EPMD_APP_FILE) erlang_for_epmd

$(EPMD_APP_FILE): $(EPMD_APP_SRC_FILE)
	$(Q) echo ===== create epmd appfile
	$(Q) cp $< $(EPMD_APP_FILE)

erlang_for_epmd:
	$(Q) cd lib/epmd && $(EMAKE)

# ---------- TEST EPMD ----------

TEST_EPMD_EBIN = lib/epmd/test/ebin
TEST_EPMD_ERL_DIR = lib/epmd/test/erlang
TEST_EPMD_TARGETS = $(addprefix $(TEST_EPMD_EBIN)/, $(addsuffix .beam, $(basename $(notdir $(wildcard $(TEST_EPMD_ERL_DIR)/*.erl)))))

test_epmd: compile_ruby $(TEST_EPMD_TARGETS)
	$(Q) echo ===== run epmd tests
	$(Q) $(ERL) -pa $(TEST_EPMD_EBIN) -s test_helper test

$(TEST_EPMD_EBIN)/%.beam: $(TEST_EPMD_ERL_DIR)/%.erl
	$(Q) mkdir -p $(TEST_EPMD_EBIN)
	$(Q) $(ERLC) -o $(TEST_EPMD_EBIN) $<



# ---------- PRE BUILD ERB ----------

setup_erb_dirs:
	$(Q) cd lib/erb && mkdir -p ebin

# ---------- BUILD ERB ----------

ERB_APP_FILE := lib/erb/ebin/erb.app
ERB_APP_SRC_FILE := lib/erb/src/erb.app.src

compile_erb: setup_erb_dirs $(ERB_APP_FILE) erlang_for_erb

$(ERB_APP_FILE): $(ERB_APP_SRC_FILE)
	$(Q) echo ===== create erb appfile
	$(Q) cp $< $(ERB_APP_FILE)

erlang_for_erb:
	$(Q) cd lib/erb && $(EMAKE)

# ---------- TEST ERB ----------

TEST_ERB_EBIN = lib/erb/test/ebin
TEST_ERB_ERL_DIR = lib/erb/test/erlang
TEST_ERB_TARGETS = $(addprefix $(TEST_ERB_EBIN)/, $(addsuffix .beam, $(basename $(notdir $(wildcard $(TEST_ERB_ERL_DIR)/*.erl)))))

test_erb: compile_ruby $(TEST_ERB_TARGETS)
	$(Q) echo ===== run erb tests
	$(Q) $(ERL) -pa $(TEST_ERB_EBIN) -s test_helper test

$(TEST_ERB_EBIN)/%.beam: $(TEST_ERB_ERL_DIR)/%.erl
	$(Q) mkdir -p $(TEST_ERB_EBIN)
	$(Q) $(ERLC) -o $(TEST_ERB_EBIN) $<



# ---------- CLEANUP ----------

clean:
	$(Q) echo ===== cleanup files
	rm -rf lib/*/ebin/
	rm -rf lib/*/test/ebin/
	rm -f erl_crash.dump
	rm -rf $(RUBY_PARSER)
	rm -rf lib/**/*.beam
