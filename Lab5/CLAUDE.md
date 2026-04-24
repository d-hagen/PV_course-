# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lab 5 for the Program Verification (PV) course: **Functional Coverage and Metrics**. Two independent SystemVerilog DUTs (FIFO and direct-mapped cache) with testbenches targeting functional and code coverage using ModelSim/QuestaSim.

## Build and Run Commands

Both `fifo/` and `cache/` have identical Makefile structures. Run from within each subdirectory:

```bash
make library       # Create ModelSim work library
make compile       # Compile with +acc and +cover flags
make run           # Compile and simulate with coverage collection
make report        # Generate text coverage report from .ucb database
make report_html   # Generate HTML coverage report
make clean         # Remove work/, transcripts, coverage files
```

The `run` target chains compile → simulate → coverage save. Use `make report` or `make report_html` after a run to inspect results.

## Architecture

- **`fifo/fifo.sv`** — Parameterized FIFO (WIDTH, DEPTH) with full/empty flags and occupancy counter. Disallows simultaneous read/write.
- **`fifo/tb_fifo.sv`** — Testbench with combinational assertions (write-when-full, read-when-empty), a `covergroup fifo_cov` (full/empty flags, occupancy bins, rd/wr cross-coverage including illegal bins), and a cover property for empty-after-read.
- **`cache/simple_cache.sv`** — Direct-mapped cache (configurable lines, line size, address/data width). Uses tag/valid arrays for hit/miss; simulates memory fetch on miss.
- **`cache/tb_simple_cache.sv`** — Random-stimulus testbench (200 cycles). Coverage statements are a placeholder for student implementation.

## Key Details

- Compilation uses `+cover` to enable all code coverage metrics (statement, branch, condition, expression, FSM, toggle).
- FIFO Makefile uses `-sv_seed 12345` for reproducible simulation; cache uses default seeding.
- Coverage databases are saved as `.ucb` files after simulation.
- This lab builds on Lab3 (assertion-based verification); assertions and coverage coexist in the FIFO testbench.
