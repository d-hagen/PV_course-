
## Verification Plan: Register File

### 1. DUT Overview

The DUT is a simple Register file with  32 entries, each 16 bits wide . It has1 write port and 2 read ports. Additionally it also includeserror detection for Write Read conflicts and Read  Read conflicts (both reads ports same adress). A reset wire reset the register to base state wth all register set to 0 and error flag also set to 0.

| Signal   | Direction | Width | Description |
|---|---|---:|---|
| `wr_en`   | Input  | 1  | Write enable |
| `wr_addr` | Input  | 5  | Write address |
| `wr_data` | Input  | 16 | Write data |
| `rd_addr1`| Input  | 5  | Read port 1 address |
| `rd_addr2`| Input  | 5  | Read port 2 address |
| `clk`     | Input  | 1  | Clock signal |
| `rst_n`   | Input  | 1  | Active-low synchronous reset |
| `rd_data1`| Output | 16 | Read port 1 output data |
| `rd_data2`| Output | 16 | Read port 2 output data |
| `err`     | Output | 1  | Error flag (registered — reflects previous cycle) |


### 2. Features to Verify & Test Strategy per Feature

| Feature | Description | Test Strategy |
|---|---|---|
| **Reset** | | |
| Reset clears all registers | `rst_n=0` → all registers read as `0` on next rising edge | Write known data to several registers, assert reset, read back all written registers and verify 0 |
| Reset clears `err` | `rst_n=0` → `err` is cleared to `0` on next rising edge | Force `err=1` via illegal condition, then assert reset |
| Reset overrides write | If `rst_n=0` and `wr_en=1` simultaneously, write is suppressed | Drive `wr_en=1`, `wr_data=nonzero`, `rst_n=0` on same cycle |
| **Write** | | |
| Synchronous write | Data appears in register on the rising edge after `wr_en=1` | Write to an address; read it back on the following cycle |
| Correct write address | Only the addressed register is updated | Verified by random tests via reference model comparison |
| Correct write data | Register stores exactly the driven value | Write constrained-random `wr_data` values to random addresses |
| Write enable control | No write occurs when `wr_en=0` | Drive `wr_en=0` with valid `wr_addr`/`wr_data`; then read; also covered by random tests |
| **Read** | | |
| Combinational read update | `rd_data` changes immediately when `rd_addr` changes, no clock needed | Change `rd_addr` mid-cycle; observe `rd_data` without a clock edge |
| Correct read address | Each port reads only its addressed register | Write distinct values to two addresses; read both simultaneously |
| Correct read value | Read data matches what was last written | Write then read back a range of values |
| **Error** | | |
| `err` on rd/wr conflict | `err` asserts one cycle after `wr_en && (wr_addr==rd_addr1 \|\| wr_addr==rd_addr2)` | Drive conflict on each read port separately; follow each with a clean cycle |
| `err` on rd/rd conflict | `err` asserts one cycle after `rd_addr1==rd_addr2` | Drive equal read addresses, then unequal; random tests apply weighted probability of conflict |
| Write suppressed on error | When illegal condition is live, write does not occur on current rising edge | Trigger conflict while `wr_en=1`; verified implicitly via reference model comparison |
| Read outputs X on error | `rd_data1` and `rd_data2` go to `X` combinationally when illegal condition is present | Trigger conflict; verify `rd_data` goes to X combinationally |
| <br><br>`err` de-asserts after conflict resolves | <br><br>`err` returns to `0` the cycle after the illegal condition is removed | <br><br>Assert illegal condition for one cycle, then remove it; verify `err` goes low on following edge |

### 3. Testbench Architecture

* **Reference model** — behavioral `reference_RegFile` in SV; driven with identical inputs as DUT; produces expected `rd_data1`, `rd_data2`, and `err`

* **Directed generator** — runs first; covers all features listed in Section 2

* **Constrained-random generator** — starts after directed phase completes (`dir_done`); runs 1000 transactions with:
    * 5% `rst_n=0`, 95% `rst_n=1`
    * 80% `wr_en=1`, 20% `wr_en=0`
    * 3% all-zeros write data, 2% all-ones, 95% uniform random
    * 10% forced `rd_addr1 == rd_addr2` (rd/rd conflict), 90% free

* **Driver** — muxes directed/random stimulus onto DUT and reference model inputs; switches to random on `dir_done`

* **Monitor** — combinational pass-through of all DUT and reference signals; provides a `valid` flag (registered, high after first posedge) to gate scoreboard checks during initialization

* **Scoreboard** — performs two levels of checking per cycle:
    1. **Combinational read check** — between clock edges check whenever a read address changes, compares DUT `rd_data` against the reference  1 ns after clock cycle start.  This catches DUTs which reads are not combinational
    2. **Clocked check** — clocked check on each posedge: compares `rd_data1`, `rd_data2`, `err` between DUT and reference;

### 4. Coverage Goals

Directed phase — each scenario exercised at least once (not on all registers) - total 10 test:
* All 4 error types triggered: rd/rd conflict, wr/rd port 1, wr/rd port 2, err cleared by reset
* Reset verified on at least 4 distinct registers
* Both read ports coverd independently

Randomized phase — 1000 transactions:
* Write addresses spread across the full range (0–31)
* `wr_data=0x0000` and `wr_data=0xFFFF` each hit
* rd/rd conflict hit ~100 times 
* wr/rd conflict hit 33+ times (99%+ probability of exceeding 33)
* `wr_en=0` cycles ~200 times — verifies no phantom writes

Not covered exhaustively: 
* not all 32 registers are written and read back in directed tests 
* no cross-coverage between error type × register address × data value × write enable 



### 5. Bug Table

| Design | Bugs |
|---|---|
| **regfile_v0** | None — passes all tests |
| **regfile_v1** | rd/rd conflict not detected: no X on read ports, `err` stays 0 |
| **regfile_v2** | Error handling delayed by one cycle (except `err` flag): X outputs appear one cycle late (on both rd/rd and wr/rd conflicts), and wr/rd conflict blocks the write on the next cycle instead of the current one |
| **regfile_v3** | wr/rd conflict does not suppress the write: register is updated despite the conflict |


## Other
**Total amount of tests**: 10 direct + 1 randommized

10 directed to go through the specific cases at least once and visually easy to detect errors. This is generated by the directed_generator. 

Then 1 randomized test with 1000 transactions to expend the coverage and test more scenerios registers etc. then the directed. Generated by the random_generator. 


**Time to run** :

As a clock cycle is around 10ns and total cyles are made up of the 32 cycles for the directed test and the 1000 cycles of the constraint randomized test. Therefore the total run time is around ~10 320 ns. 


**AI Usage**

* Report formating/ wording
* print statments 

<br>

* syntax help 
* code clean up 
* coding help (e.g. move vaiables to top, wire intiilazation in the final tb_regfile module - mostly to avoid repetative writing tasks)

**Time spend on assignment**

Around 5-10 hours (excluding lab)

Note: I often work/code on the side of doing something else so its hard to track how much time I actually spent on coding tasks etc. 

## Clocking Blocks 

Clocking blocks allow for specifying the timing of signals repsective to their clock. They allow for delaying the chnage on input and output wires.  This can help with avoiding race conditions aswell as sampleing after clock edges. Often used in interfaces they can help with organizing and simplify interface timings and allow for a centralized overview of the tb timings.


In my test bench instead of using a clocking block to prevent race condition between the refrence models and presumable DUT always_ff @(posedge clk) and the send task from my driver, I used @(posedge clk); #1; to delay the changes on the wires by 1ns. Alternativly I could have included a Clocking block in the driver to delay its outputs by 1ns to achive the same result. As this is a quite small testbench this approach works, however if the code gets larger and a bit more complex using proper clocking blocks will likly be a better approach to avoid reptative timing managment which can likly (I imagine) lead to clocking errors hard to find and debug. 
<br><br>




