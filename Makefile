# ---------- UTILS ----------
Q := @

# ---------- COMMAND ----------
ERL := erl
ERLC := erlc
EMAKE := erl -make
DIALYZER := dialyzer

# ---------- COMMON ----------

.PHONY: compile clean test erlang lint dialyzer plt
.PHONY: compile_ruby test_ruby setup_ruby_dirs erlang_for_ruby
.PHONY: compile_irb test_irb setup_irb_dirs erlang_for_irb
.PHONY: compile_epmd test_epmd setup_epmd_dirs erlang_for_epmd

default: compile

compile: compile_ruby compile_irb compile_epmd
test: test_ruby test_irb test_epmd
ci: compile test lint


# ---------- PRE BUILD RUBY ----------

setup_ruby_dirs:
	$(Q) cd lib/ruby && mkdir -p ebin

RUBY_PARSER := lib/ruby/src/ruby_parser.erl

$(RUBY_PARSER): lib/ruby/src/ruby_parser.yrl
	$(Q) echo ===== build ruby parser
	$(Q) $(ERLC) -o lib/ruby/src $<

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
	$(Q) $(ERL) -noshell -pa lib/ruby/ebin -pa $(TEST_RUBY_EBIN) -s test_helper test

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



# ---------- CLEANUP ----------

clean:
	$(Q) echo ===== cleanup files
	rm -rf lib/*/ebin/
	rm -rf lib/*/test/ebin/
	rm -f erl_crash.dump
	rm -f bin/erl_crash.dump
	rm -rf $(RUBY_PARSER)
	rm -rf lib/**/*.beam
	rm -f .bruby_plt


# ---------- LINT ----------

PLT_FILE := .bruby_plt

plt:
	$(Q) echo ===== creating PLT file for dialyzer
	$(Q) $(DIALYZER) --build_plt --output_plt $(PLT_FILE) \
		--apps kernel stdlib compiler erts || true

dialyzer: compile
	$(Q) echo ===== running dialyzer
	$(Q) if [ ! -f $(PLT_FILE) ]; then \
		echo "PLT file not found. Creating..."; \
		$(MAKE) plt; \
	fi
	$(Q) $(DIALYZER) --plt $(PLT_FILE) \
		-r lib/ruby/ebin lib/irb/ebin lib/epmd/ebin \
		--no_check_plt

LINT_OPTS := -W \
	+warn_unused_vars \
	+warn_export_all \
	+warn_shadow_vars \
	+warn_unused_import \
	+warn_unused_function \
	+warn_bif_clash \
	+warn_unused_record \
	+warn_deprecated_function \
	+warn_obsolete_guard \
	+warn_exported_vars \
	+warn_missing_spec \
	+warn_untyped_record \
	+debug_info

lint: compile
	$(Q) echo ===== running lint checks
	$(Q) echo "Checking ruby application..."
	$(ERLC) $(LINT_OPTS) -I lib/ruby/src -o /tmp lib/ruby/src/*.erl || true
	$(Q) echo "Checking irb application..."
	$(ERLC) $(LINT_OPTS) -I lib/irb/src -o /tmp lib/irb/src/*.erl || true
	$(Q) echo "Checking epmd application..."
	$(ERLC) $(LINT_OPTS) -I lib/epmd/src -o /tmp lib/epmd/src/*.erl || true
	$(Q) echo ===== lint complete
