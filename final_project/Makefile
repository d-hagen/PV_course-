# =============================================================================
# QuestaSim build/run for the GCD UVM testbench
# =============================================================================
# UVM: point UVM_HOME at the UVM-1.2 src tree bundled with QuestaSim, e.g.
#   export UVM_HOME=$QUESTA_HOME/verilog_src/uvm-1.2
# (If your Questa is set up to provide UVM automatically, you can drop the
#  uvm_pkg.sv from the vlog line and add -L mtiUvm to vlog/vsim instead.)

UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2

RTL  = rtl/gcd.sv
TB   = tb/tb_gcd.sv
TOP  = top

# run-time knobs (override on the command line: make run UVM_TEST=... SEED=...)
UVM_TEST ?= gcd_test_smoke
SEED     ?= 1
NUM_TX   ?= 100
SCENARIO ?=
VERB     ?= UVM_MEDIUM

VLOG_FLAGS = -sv -mfcu +acc +incdir+$(UVM_HOME)/src
COV_FLAGS  = -cover bcefsx

PLUS = +UVM_TESTNAME=$(UVM_TEST) +UVM_VERBOSITY=$(VERB) +NUM_TX=$(NUM_TX)
ifneq ($(SCENARIO),)
PLUS += +SCENARIO=$(SCENARIO)
endif

# ---- default: build + run the smoke test --------------------------------
all: compile run

# ---- compile (no coverage) ----------------------------------------------
compile:
	vlib work
	vlog $(VLOG_FLAGS) $(UVM_HOME)/src/uvm_pkg.sv $(RTL) $(TB)

# ---- compile with code-coverage instrumentation -------------------------
compile_cov:
	vlib work
	vlog $(VLOG_FLAGS) $(COV_FLAGS) $(UVM_HOME)/src/uvm_pkg.sv $(RTL) $(TB)

# ---- run (console) ------------------------------------------------------
run:
	vsim -c $(TOP) -sv_seed $(SEED) $(PLUS) -do "run -all; quit -f"

# ---- run with coverage, save a per-test UCDB ----------------------------
run_cov:
	vsim -c -coverage $(TOP) -sv_seed $(SEED) $(PLUS) \
	     -do "run -all; coverage save cov_$(UVM_TEST).ucdb; quit -f"

# ---- run in GUI ---------------------------------------------------------
gui:
	vsim $(TOP) -sv_seed $(SEED) $(PLUS) -do "run -all"

# ---- merge per-test coverage + text report ------------------------------
merge:
	vcover merge merged.ucdb cov_*.ucdb
	vcover report -details -output cov_report.txt merged.ucdb
	vcover report -html -htmldir cov_html merged.ucdb

# ---- run all three tests (functional, no coverage) ----------------------
test_all: compile
	vsim -c $(TOP) -sv_seed 1  +UVM_TESTNAME=gcd_test_smoke    -do "run -all; quit -f"
	vsim -c $(TOP) -sv_seed 7  +UVM_TESTNAME=gcd_test_directed -do "run -all; quit -f"
	vsim -c $(TOP) -sv_seed 42 +UVM_TESTNAME=gcd_test_random +NUM_TX=1000 -do "run -all; quit -f"

# ---- convenience: full coverage regression over the three tests ---------
regress: compile_cov
	vsim -c -coverage $(TOP) -sv_seed 1  +UVM_TESTNAME=gcd_test_smoke    -do "run -all; coverage save cov_smoke.ucdb; quit -f"
	vsim -c -coverage $(TOP) -sv_seed 7  +UVM_TESTNAME=gcd_test_directed -do "run -all; coverage save cov_directed.ucdb; quit -f"
	vsim -c -coverage $(TOP) -sv_seed 42 +UVM_TESTNAME=gcd_test_random +NUM_TX=1000 -do "run -all; coverage save cov_random.ucdb; quit -f"
	$(MAKE) merge

clean:
	rm -rf work transcript *.wlf *.ucdb cov_report.txt cov_html

.PHONY: all compile compile_cov run run_cov gui merge test_all regress clean
