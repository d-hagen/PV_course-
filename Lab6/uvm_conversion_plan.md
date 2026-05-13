# UVM Testbench Conversion Plan: `tb_uvm_simple_mem_ctrl.sv`

---

## What the existing TB contains

| Existing element | How implemented |
|---|---|
| Transaction type | `trx_t` packed struct with M0+M1 combined fields |
| Generator | Task in module — pushes to `trx_mb` mailbox |
| Driver | Task in module — pops from `trx_mb`, drives both ports |
| Monitor | Task in module — samples posedge, pushes to `evt_mb` |
| Checker | Task in module — pops from `evt_mb`, compares vs golden ref_mem |
| Synchronisation | Manual: semaphore, `driver_done` flag, `checker_done` flag |
| Clock/Reset | `initial` blocks in module |

Everything is ad-hoc, tightly coupled inside one module. The goal is to restructure into UVM without changing the underlying stimulus/checking logic.

---

## Design decisions

**One agent or two?**
The DUT has two master ports. However the existing TB drives them as a *single combined transaction* (one `trx_t` covering both M0 and M1 simultaneously). The contention tests rely on asserting both ports in the exact same clock cycle. Splitting into two separate agents would require a virtual sequencer to coordinate timing — adding complexity with no functional gain for this lab. **Decision: one active agent, one combined transaction class.**

**Multiple sequences?**
Yes. The generator has three distinct test phases. Splitting into three sequences lets each test class select only what it needs, and demonstrates the UVM test/sequence decoupling the lab asks about. **Decision: three sequences — directed, contention, random.**

**Multiple environments?**
No. There is one DUT with one consistent verification topology. A second env would add no value here.

---

## File structure

Everything goes in one file `tb_uvm_simple_mem_ctrl.sv` per the lab requirement, structured as:

```
`timescale 1ns/1ps
`include "uvm_macros.svh"

interface mem_ctrl_if(...);  // virtual interface

package controller_pkg;
  import uvm_pkg::*;
  // [1]  ctrl_transaction
  // [2]  ctrl_sequencer
  // [3]  ctrl_driver
  // [4]  ctrl_monitor
  // [5]  ctrl_scoreboard
  // [6]  ctrl_agent
  // [7]  ctrl_env
  // [8]  ctrl_directed_seq
  // [9]  ctrl_contention_seq
  // [10] ctrl_random_seq
  // [11] ctrl_directed_test
  // [12] ctrl_random_test
  // [13] ctrl_full_test
endpackage

module tb_uvm_simple_mem_ctrl;
  import uvm_pkg::*;
  import controller_pkg::*;
  // clock + reset
  // interface instantiation
  // DUT instantiation
  // initial: config_db set vif, run_test()
endmodule
```

---

## Component-by-component plan

### `mem_ctrl_if` — virtual interface

- Parameterised with `ADDR_WIDTH=8`, `DATA_WIDTH=32`
- Input ports: `clk`, `rst_n`
- All DUT signals as `logic`: `addr0/1`, `wdata0/1`, `rdata0/1`, `we0/1`, `req0/1`, `gnt0/1`
- Used as `virtual mem_ctrl_if` inside driver and monitor
- Passed top-down via `uvm_config_db#(virtual mem_ctrl_if)::set/get` with key `"vif"`

---

### `ctrl_transaction extends uvm_sequence_item`

`` `uvm_object_utils(ctrl_transaction) ``

Maps directly from the existing `trx_t` struct. Fields:

| Field | Type | Notes |
|---|---|---|
| `use_m0` | `rand bit` | master 0 participates |
| `is_write0` | `rand bit` | |
| `addr0` | `rand bit [7:0]` | |
| `data0` | `rand bit [31:0]` | |
| `use_m1` | `rand bit` | master 1 participates |
| `is_write1` | `rand bit` | |
| `addr1` | `rand bit [7:0]` | |
| `data1` | `rand bit [31:0]` | |
| `delay_cycles` | `rand int` | constrained ≥ 0 |

Add `constraint c_delay { delay_cycles inside {[0:3]}; }` and `convert2string()`.

**No `is_end` field** — UVM phases handle simulation termination via objections, not sentinel transactions.

---

### `ctrl_sequencer extends uvm_sequencer#(ctrl_transaction)`

`` `uvm_component_utils(ctrl_sequencer) ``

Standard pass-through. Only needs `new()`. No custom logic.

---

### `ctrl_driver extends uvm_driver#(ctrl_transaction)`

`` `uvm_component_utils(ctrl_driver) ``

**`build_phase`:** retrieve `virtual mem_ctrl_if vif` from `uvm_config_db`. Fatal if not found.

**`run_phase`:** forever loop — maps from existing `tb_driver` task:
1. `seq_item_port.get_next_item(req)` — get transaction from sequencer
2. If `delay_cycles > 0`, wait that many `@(posedge clk)`
3. Drive on `@(negedge clk)`: set `addr0/1`, `wdata0/1`, `we0/1`, `req0/1` via the vif
4. `@(posedge clk)` — capture cycle
5. `@(negedge clk)` — deassert all driven signals
6. `repeat(1) @(posedge clk)` — settle time
7. `seq_item_port.item_done()` — release item to sequencer

**Key UVM change:** no mailbox — the sequencer/driver handshake replaces `trx_mb`.

---

### `ctrl_monitor extends uvm_monitor`

`` `uvm_component_utils(ctrl_monitor) ``

**Declare:** `uvm_analysis_port#(ctrl_transaction) analysis_port`

**`build_phase`:** create `analysis_port`, retrieve `vif` from config_db.

**`run_phase`:** maps from existing `tb_monitor` task — forever loop:
1. `@(posedge clk)` — sample
2. Skip if `!vif.rst_n`
3. Check for concurrent requests (log with `` `uvm_info ``)
4. **Write detection:** if `gnt0 && we0` or `gnt1 && we1` → build a `ctrl_transaction` with write fields set → `analysis_port.write(tr)`
5. **Read detection:** if `gnt0 && !we0` or `gnt1 && !we1` → build a `ctrl_transaction` with read fields + captured `rdata` → `analysis_port.write(tr)`

**Key UVM change:** no `evt_mb` mailbox — `analysis_port.write()` replaces it.

---

### `ctrl_scoreboard extends uvm_scoreboard`

`` `uvm_component_utils(ctrl_scoreboard) ``

**Declare:** `uvm_analysis_imp#(ctrl_transaction, ctrl_scoreboard) analysis_export`

Internal state: `logic [31:0] ref_mem[256]`, `int total_checks`, `int failed_checks`

**`build_phase`:** create `analysis_export`, initialise `ref_mem` to zero.

**`function void write(ctrl_transaction tr)`:** maps from existing `tb_checker` task:
- If M0 write: `ref_mem[tr.addr0] = tr.data0`
- If M0 read: compare `tr.data0` vs `ref_mem[tr.addr0]`, increment counters
- Same logic for M1
- Use `` `uvm_info `` / `` `uvm_error `` instead of `$display`

**`report_phase`:** print total/failed summary. Use `` `uvm_fatal `` if `failed_checks > 0`.

**Key UVM change:** no manual done flags — `write()` is called by TLM automatically; `report_phase` runs after `run_phase` completes.

---

### `ctrl_agent extends uvm_agent`

`` `uvm_component_utils(ctrl_agent) ``

Members: `ctrl_sequencer seqr`, `ctrl_driver drv`, `ctrl_monitor mon`

**`build_phase`:** create all three via `type_id::create()`. The monitor is always created. Only create `seqr` and `drv` if `get_is_active() == UVM_ACTIVE`.

**`connect_phase`:** `drv.seq_item_port.connect(seqr.seq_item_export)`

---

### `ctrl_env extends uvm_env`

`` `uvm_component_utils(ctrl_env) ``

Members: `ctrl_agent agent`, `ctrl_scoreboard scoreboard`

**`build_phase`:** `agent = ctrl_agent::type_id::create("agent", this)`, same for scoreboard.

**`connect_phase`:** `agent.mon.analysis_port.connect(scoreboard.analysis_export)`

---

## Sequences

### `ctrl_directed_seq extends uvm_sequence#(ctrl_transaction)`

`` `uvm_object_utils(ctrl_directed_seq) ``

**`body()`:** maps the first two loops from `tb_generator`:
- Loop `addr 0..7`: create tx, set `use_m0=1, is_write0=1`, specific addr/data → `start_item / finish_item`; then a read-back tx
- Loop `addr 8..15`: same pattern but `use_m1=1`

### `ctrl_contention_seq extends uvm_sequence#(ctrl_transaction)`

`` `uvm_object_utils(ctrl_contention_seq) ``

**`body()`:** maps the contention loop `addr 16..17`: creates tx with `use_m0=1, use_m1=1`, simultaneous writes then simultaneous reads.

### `ctrl_random_seq extends uvm_sequence#(ctrl_transaction)`

`` `uvm_object_utils(ctrl_random_seq) ``

Member: `int num_items = 30`

**`body()`:** loop `num_items` times — `tx = ctrl_transaction::type_id::create("tx")`, `start_item(tx)`, `assert(tx.randomize())`, `finish_item(tx)`. The pick randomisation (0 = M0 only, 1 = M1 only, 2 = both) is handled via randomize-with constraints.

---

## Tests

### `ctrl_directed_test extends uvm_test`

`` `uvm_component_utils(ctrl_directed_test) ``

**`build_phase`:** create `env` via `ctrl_env::type_id::create("env", this)`.

**`run_phase`:** raise objection; create and run `ctrl_directed_seq` on `env.agent.seqr`; drop objection.

### `ctrl_random_test extends uvm_test`

`` `uvm_component_utils(ctrl_random_test) ``

Same structure. Runs `ctrl_random_seq`. Reads `num_items` from `uvm_config_db` or `+num_items` plusarg to allow command-line control.

### `ctrl_full_test extends uvm_test`

`` `uvm_component_utils(ctrl_full_test) ``

Runs all three sequences in order: directed → contention → random.

---

## Component hierarchy diagram

```
uvm_test_top  (ctrl_full_test | ctrl_directed_test | ctrl_random_test)
└── env  (ctrl_env)
    ├── agent  (ctrl_agent)  [ACTIVE]
    │   ├── seqr  (ctrl_sequencer)
    │   │     ↑  seq.start(seqr) from test run_phase
    │   ├── drv  (ctrl_driver)
    │   │     drv.seq_item_port  ←→  seqr.seq_item_export
    │   └── mon  (ctrl_monitor)
    │         mon.analysis_port  ──────────────────────┐
    └── scoreboard  (ctrl_scoreboard)                  │
          scoreboard.analysis_export  ←────────────────┘
```

---

## Communication flow

```
Sequence body()
  → start_item / finish_item
      → ctrl_sequencer  (handshake)
          → ctrl_driver run_phase  (get_next_item / item_done)
              → virtual interface  (pin-level: req, addr, wdata, we)
                  → DUT  (simple_mem_ctrl)
                      → virtual interface  (gnt, rdata)
                          → ctrl_monitor run_phase  (sample signals)
                              → analysis_port.write(tr)
                                  → ctrl_scoreboard.write(tr)
                                      → golden ref_mem comparison
                                          → report_phase: PASS / FAIL summary
```

---

## Top-level module skeleton

```sv
module tb_uvm_simple_mem_ctrl;
  import uvm_pkg::*;
  import controller_pkg::*;

  parameter ADDR_WIDTH = 8;
  parameter DATA_WIDTH = 32;

  logic clk, rst_n;

  initial begin clk = 0; forever #5 clk = ~clk; end
  initial begin rst_n = 0; #20; rst_n = 1; end

  mem_ctrl_if vif(.clk(clk), .rst_n(rst_n));

  simple_mem_ctrl #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) dut (
    .clk(clk), .rst_n(rst_n),
    .addr0(vif.addr0), .wdata0(vif.wdata0), .rdata0(vif.rdata0),
    .we0(vif.we0),     .req0(vif.req0),     .gnt0(vif.gnt0),
    .addr1(vif.addr1), .wdata1(vif.wdata1), .rdata1(vif.rdata1),
    .we1(vif.we1),     .req1(vif.req1),     .gnt1(vif.gnt1)
  );

  initial begin
    uvm_config_db#(virtual mem_ctrl_if)::set(null, "uvm_test_top.*", "vif", vif);
    run_test();  // reads +UVM_TESTNAME from command line
  end
endmodule
```

---

## Example command lines (QuestaSim)

```bash
# 1. Compile both files
vlog simple_mem_ctrl.sv tb_uvm_simple_mem_ctrl.sv

# 2. Directed deterministic test (M0/M1 single-master + contention)
vsim tb_uvm_simple_mem_ctrl \
  +UVM_TESTNAME=ctrl_directed_test \
  +UVM_VERBOSITY=UVM_MEDIUM \
  -do "run -all; quit"

# 3. Random test, high verbosity, 100 random transactions
vsim tb_uvm_simple_mem_ctrl \
  +UVM_TESTNAME=ctrl_random_test \
  +UVM_VERBOSITY=UVM_HIGH \
  +num_items=100 \
  -do "run -all; quit"

# 4. Full test suite (directed + contention + random), low verbosity
vsim tb_uvm_simple_mem_ctrl \
  +UVM_TESTNAME=ctrl_full_test \
  +UVM_VERBOSITY=UVM_LOW \
  -do "run -all; quit"
```

---

## Summary of changes from original TB

| Original | UVM replacement |
|---|---|
| `trx_t` struct | `ctrl_transaction extends uvm_sequence_item` |
| `trx_mb` mailbox | sequencer/driver TLM handshake |
| `evt_mb` mailbox | `uvm_analysis_port` → `uvm_analysis_imp` |
| `tb_generator()` task | `ctrl_*_seq extends uvm_sequence` (`body()`) |
| `tb_driver()` task | `ctrl_driver.run_phase()` |
| `tb_monitor()` task | `ctrl_monitor.run_phase()` |
| `tb_checker()` task | `ctrl_scoreboard.write()` + `report_phase()` |
| `driver_done` / `checker_done` flags | `phase.raise/drop_objection()` |
| `semaphore gen_done_sem` | eliminated — UVM phases handle it |
| `$display` prints | `` `uvm_info `` / `` `uvm_error `` macros |
| `$finish` | automatic after all objections dropped |
| Direct signal access in tasks | `virtual mem_ctrl_if` via `uvm_config_db` |
