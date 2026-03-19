# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hardware verification coursework (Semester 2 PV) — a 4-bit ALU implemented and verified in SystemVerilog.

## Simulation Commands

### iverilog (free, recommended)
```bash
cd Lab1/alu_4bit
iverilog -g2012 -o alu_tb alu_4bit_tb.sv alu_4bit.sv
vvp alu_tb
```

### With waveform output (EPWave / GTKWave)
Add to `alu_4bit_tb.sv` inside `initial begin`:
```systemverilog
$dumpfile("alu_4bit.vcd");
$dumpvars(0, alu_4bit_tb);
```
Then open the generated `.vcd` file in GTKWave or EPWave.

### QuestaSim / ModelSim
```bash
vlog alu_4bit_tb.sv alu_4bit.sv
vsim -c alu_4bit_tb -do "run -all; quit"
```

## Project Structure

- `Lab1/alu_4bit/alu_4bit_tb.sv` — testbench with reference model (`alu_compare_4bit`) and DUT instantiation
- `Lab1/alu_4bit/alu_4bit.sv` — ALU implementation (the DUT)
- `Lab1/alu_4bit/work/` — ModelSim compiled artifacts (generated, don't edit)

## Architecture

The testbench uses **reference model comparison**: both the DUT (`alu_4bit`) and a known-good behavioral model (`alu_compare_4bit`) receive identical inputs; outputs are compared and mismatches reported per operation.

**ALU operations (3-bit opcode):**
| op    | Operation |
|-------|-----------|
| 3'b000 | ADD (with carry) |
| 3'b001 | SUB (with borrow) |
| 3'b010 | AND |
| 3'b011 | OR |
| 3'b100 | XOR |
| 3'b101 | NOT A |
| 3'b110 | PASS A |
| 3'b111 | PASS B |

**Test coverage:** Exhaustive — 8 ops × 16 A values × 16 B values = 2,048 vectors.

**Mismatch reporting:** Per-operation counters for Y-only, carry-only, and combined mismatches.

## Key Notes

- The `include "alu_4bit"` in the TB has no extension — pass both files explicitly to iverilog rather than relying on the include
- The `alu_compare_4bit` reference model lives inside `alu_4bit_tb.sv`, not a separate file
- `work/` directory is ModelSim's compiled library — regenerated automatically on `vlog`
