`timescale 1ns/1ps

module tb_decode_unit;

  // DUT interface
  reg         clk;
  reg         rst_n;
  reg         instr_valid;
  reg  [15:0] instr;
  wire        decode_done;
  wire [3:0]  opcode, rd, rs, imm;
  wire        hazard_stall;

  // Instantiate DUT
  decode_unit dut (
    .clk(clk),
    .rst_n(rst_n),
    .instr_valid(instr_valid),
    .instr(instr),
    .decode_done(decode_done),
    .opcode(opcode),
    .rd(rd),
    .rs(rs),
    .imm(imm),
    .hazard_stall(hazard_stall)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Directed test sequence
  initial begin
    integer i;

    // Initialize inputs
    rst_n = 0;
    instr_valid = 0;
    instr = 16'h0000;
  
    $display("[%0t] STARTING SIMULATION ...", $time);

    // Apply reset
    #5;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] TEST #1: Reset released, outputs should be 0", $time);

    // Decode instruction without hazard
    instr = 16'h1234; // opcode=1, rd=2, rs=3, imm=4
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    // Wait for decode_done
    repeat (3) @(posedge clk);
    $display("[%0t] TEST #2: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Decode instruction with hazard (rs == last_rd)
    instr = 16'h3A20; // opcode=3, rd=A, rs=2 (matches previous rd), imm=0
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    // Stall should assert
    @(posedge clk);
    $display("[%0t] TEST #3: hazard_stall=%b", $time, hazard_stall);

    // Wait for stall to clear and decode to complete
    repeat (4) @(posedge clk);
    $display("[%0t] TEST #4: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Decode instruction after hazard clears
    instr = 16'h4B21; // opcode=4, rd=B, rs=2 (no hazard with last_rd=A), imm=1
    instr_valid = 1;
    @(posedge clk);
    instr_valid = 0;
    repeat (3) @(posedge clk);
    $display("[%0t] TEST #5: decode_done=%b, opcode=%0h, rd=%0h, rs=%0h, imm=%0h",
             $time, decode_done, opcode, rd, rs, imm);

    // Finish
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  // INSERT ASSERTIONS BELOW


   // ASSERTIONS



    // #1 Decode latency: acceptance leads to decode_done exactly 2 cycles later (no stall)
    assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (instr_valid && !dut.hazard_stall_next) |-> !hazard_stall [*2] ##1 decode_done
    ) else $error("decode_done not asserted 2 cycles after acceptance while no hazards stalled");

    // #2 No decode_done during stall
    assert property (
      @(posedge clk)
      disable iff (!rst_n)
      hazard_stall |-> !decode_done
    ) else $error("decode_done asserted during stall window");

    // #3 Field capture on acceptance
    assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (instr_valid && !dut.hazard_stall_next) |=>
        (opcode == $past(instr[15:12])) &&
        (rd     == $past(instr[11:8]))  &&
        (rs     == $past(instr[7:4]))   &&
        (imm    == $past(instr[3:0]))
    ) else $error("fields not captured correctly on acceptance");

    // #4 Field stability during stall
    assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (instr_valid && hazard_stall) |=>
        (opcode == $past(opcode)) &&
        (rd     == $past(rd))     &&
        (rs     == $past(rs))     &&
        (imm    == $past(imm))
    ) else $error("fields changed during stall");

    // #5 Reset clears all outputs
    assert property (
      @(posedge clk)
      !rst_n |=> !decode_done && (opcode == 0) && (rd == 0) &&
                 (rs == 0) && (imm == 0) && !hazard_stall
    ) else $error("outputs not cleared after reset");

    // #6 Hazard detection: rs of current instr matches rd of previous accepted instr
    assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (instr_valid && (instr[7:4] == dut.last_rd)) |=> hazard_stall
    ) else $error("hazard_stall not asserted when rs matches previous rd");


endmodule