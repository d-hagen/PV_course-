# =============================================================================
# QuestaSim build/run for the GCD UVM testbench
# =============================================================================

RTL = rtl/gcd.sv
TB  = tb/tb_gcd.sv
TOP = top

# run-time knobs (override on the command line, e.g. make run TEST=random SEED=42)
TEST     ?= smoke        # smoke | directed | random   -> gcd_test_<TEST>
SEED     ?= 1
NUM_TX   ?= 100
SCENARIO ?=
VERB     ?= UVM_MEDIUM

VFLAGS = -sv -mfcu +acc
# +cover enables code coverage metrics
#     (s=stmt, b=branch, c=cond, e=expr, f=fsm, t=toggle)
COV    = +cover=bcefst

PLUS = +UVM_TESTNAME=gcd_test_$(TEST) +UVM_VERBOSITY=$(VERB) +NUM_TX=$(NUM_TX)
ifneq ($(SCENARIO),)
PLUS += +SCENARIO=$(SCENARIO)
endif

# ---- build --------------------------------------------------------------
compile:
	vlib work
	vlog $(VFLAGS) $(RTL) $(TB)

compile_cov:
	vlib work
	vlog $(VFLAGS) $(COV) $(RTL) $(TB)

# ---- run ----------------------------------------------------------------
run: compile
	vsim -c $(TOP) -sv_seed $(SEED) $(PLUS) -do "run -all; quit -f"

gui: compile
	vsim $(TOP) -sv_seed $(SEED) $(PLUS) -do "run -all"

run_cov: compile_cov
	vsim -c -coverage $(TOP) -sv_seed $(SEED) $(PLUS) \
	     -do "coverage save -onexit cov_$(TEST).ucdb; run -all; quit -f"

# ---- coverage regression over the three tests ---------------------------
regress: compile_cov
	vsim -c -coverage $(TOP) -sv_seed 1  +UVM_TESTNAME=gcd_test_smoke    -do "coverage save -onexit cov_smoke.ucdb; run -all; quit -f"
	vsim -c -coverage $(TOP) -sv_seed 7  +UVM_TESTNAME=gcd_test_directed -do "coverage save -onexit cov_directed.ucdb; run -all; quit -f"
	vsim -c -coverage $(TOP) -sv_seed 42 +UVM_TESTNAME=gcd_test_random +NUM_TX=1000 -do "coverage save -onexit cov_random.ucdb; run -all; quit -f"
	$(MAKE) merge

# ---- coverage reports ---------------------------------------------------
merge:
	vcover merge merged.ucdb cov_*.ucdb

cov_report: merge
	vcover report -details merged.ucdb

cov_html: merge
	vcover report -html -output cov_html merged.ucdb
	xdg-open cov_html/index.html

clean:
	rm -rf work transcript *.wlf *.ucdb merged.ucdb cov_html modelsim.ini

.PHONY: compile compile_cov run gui run_cov regress merge cov_report cov_html clean
