# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Lab 3 for a Program Verification (PV) course. The lab focuses on **assertion-based verification** of a simple processor front-end (fetch + decode pipeline stages) using SystemVerilog assertions (SVA).

## Build & Run

Each unit lives in its own directory under `front_end/` with an identical Makefile structure (ModelSim/QuestaSim):

```sh
# From front_end/fetch/ or front_end/decode/:
make library   # create ModelSim work library
make compile   # compile DUT (.v) and testbench (.sv)
make run       # compile then run simulation headless
make clean     # remove work/, transcript, wlf
```

The `run` target depends on `compile`, so `make run` is the single command to build and simulate.

## Architecture

Two pipeline stages, each a standalone Verilog module with a SystemVerilog testbench:

- **fetch_unit** (`front_end/fetch/`) — PC logic + instruction memory. Inputs: `pc_en`, `branch_en`, `branch_addr`. Outputs: `instr`. Memory is initialized to `mem[i] = i`. PC increments by 2.
- **decode_unit** (`front_end/decode/`) — 2-cycle decode latency with RAW hazard detection (`last_rd == rs`). Splits 16-bit instruction into `{opcode[15:12], rd[11:8], rs[7:4], imm[3:0]}`. `decode_done` pulses after 2 cycles if no stall.

The units are **not integrated** — each testbench drives its DUT independently.

## Assertions

Assertions are written inline at the bottom of each `tb_*.sv` file (not in separate bind modules).

- **fetch_unit**: 6 assertions fully implemented (reset, branch, pc_en, hold, mem consistency, PC range).
- **decode_unit**: 2 of 7 assertions implemented. `assertion_plan.md` tracks the full plan with SV sketches for the remaining TODOs (#3 field capture, #5 field stability, #6 reset, #7 hazard detection).

When writing SVA for this project: use `disable iff (!rst_n)` for non-reset assertions, access internal DUT signals via `dut.<signal>`, and use concurrent (`assert property`) not immediate assertions.
