# =============================================================================
# QuestaSim build/run for the GCD UVM testbench
# =============================================================================
# Uses QuestaSim's built-in UVM (no need to compile uvm_pkg yourself).
# If your Questa does NOT auto-provide UVM, set UVM_HOME to its UVM src tree
# and add  +incdir+$(UVM_HOME)/src  +  $(UVM_HOME)/src/uvm_pkg.sv  to the vlog
# lines below, e.g.:
#   make UVM_HOME="$(dirname $(dirname $(which vlog)))/verilog_src/uvm-1.2"

RTL  = rtl/gcd.sv
TB   = tb/tb_gcd.sv
TOP  = top

# run-time knobs (override on the command line: make run UVM_TEST=... SEED=...)
UVM_TEST ?= gcd_test_smoke
SEED     ?= 1
NUM_TX   ?= 100
SCENARIO ?=
VERB     ?= UVM_MEDIUM

VLOG_FLAGS = -sv -mfcu +acc
COV_FLAGS  = +cover=bcefst

PLUS = +UVM_TESTNAME=$(UVM_TEST) +UVM_VERBOSITY=$(VERB) +NUM_TX=$(NUM_TX)
ifneq ($(SCENARIO),)
PLUS += +SCENARIO=$(SCENARIO)
endif

# ---- default: build + run the smoke test --------------------------------
all: compile run

# ---- compile (no coverage) ----------------------------------------------
compile:
	vlib work
	vlog $(VLOG_FLAGS) $(RTL) $(TB)

# ---- compile with code-coverage instrumentation -------------------------
compile_cov:
	vlib work
	vlog $(VLOG_FLAGS) $(COV_FLAGS) $(RTL) $(TB)

# ---- run (console) ------------------------------------------------------
run:
	vsim -c $(TOP) -sv_seed $(SEED) $(PLUS) -do "run -all; quit -f"

# ---- run with coverage, save a per-test UCDB ----------------------------
run_cov:
	vsim -c -coverage $(TOP) -sv_seed $(SEED) $(PLUS) \
	     -do "coverage save -onexit cov_$(UVM_TEST).ucdb; run -all; quit -f"

# ---- run in GUI ---------------------------------------------------------
gui:
	vsim $(TOP) -sv_seed $(SEED) $(PLUS) -do "run -all"

# ---- merge per-test coverage + text/html report -------------------------
merge:
	vcover merge merged.ucdb cov_*.ucdb
	vcover report -details merged.ucdb > cov_report.txt
	vcover report -html -output cov_html merged.ucdb

# ---- run all three tests (functional, no coverage) ----------------------
test_all: compile
	vsim -c $(TOP) -sv_seed 1  +UVM_TESTNAME=gcd_test_smoke    -do "run -all; quit -f"
	vsim -c $(TOP) -sv_seed 7  +UVM_TESTNAME=gcd_test_directed -do "run -all; quit -f"
	vsim -c $(TOP) -sv_seed 42 +UVM_TESTNAME=gcd_test_random +NUM_TX=1000 -do "run -all; quit -f"

# ---- convenience: full coverage regression over the three tests ---------
regress: compile_cov
	vsim -c -coverage $(TOP) -sv_seed 1  +UVM_TESTNAME=gcd_test_smoke    -do "coverage save -onexit cov_smoke.ucdb; run -all; quit -f"
	vsim -c -coverage $(TOP) -sv_seed 7  +UVM_TESTNAME=gcd_test_directed -do "coverage save -onexit cov_directed.ucdb; run -all; quit -f"
	vsim -c -coverage $(TOP) -sv_seed 42 +UVM_TESTNAME=gcd_test_random +NUM_TX=1000 -do "coverage save -onexit cov_random.ucdb; run -all; quit -f"
	$(MAKE) merge

clean:
	rm -rf work transcript *.wlf *.ucdb cov_report.txt cov_html

.PHONY: all compile compile_cov run run_cov gui merge test_all regress clean
