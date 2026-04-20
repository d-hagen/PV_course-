`timescale 1ns/1ps

module tb_fetch_unit;

  // DUT interface signals
  reg         clk;
  reg         rst_n;
  reg         pc_en;
  reg         branch_en;
  reg  [7:0]  branch_addr;
  wire [15:0] instr;

  // Instantiate DUT
  fetch_unit dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .pc_en      (pc_en),
    .branch_en  (branch_en),
    .branch_addr(branch_addr),
    .instr      (instr)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  // Directed test sequence
  initial begin
    integer i;
  
    // Initialize inputs
    clk         = 0;
    rst_n       = 0;
    pc_en       = 0;
    branch_en   = 0;
    branch_addr = 8'h00;

    $display("[%0t] STARTING SIMULATION ...", $time);

    // Apply reset
    #5;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    $display("[%0t] TEST #1: Reset released, pc should be 0, instr=%0d", $time, instr);

    // Sequential pc increments
    pc_en = 1;
    for (i = 1; i <= 4; i = i + 1) begin
      @(posedge clk);
      $display("[%0t] TEST #%1d: pc increment, pc=%0h, instr=%0d", $time, i, dut.pc, instr);
    end
    pc_en = 0;

    // Branch test
    branch_addr = 8'h10;
    branch_en   = 1;
    @(posedge clk);
    branch_en   = 0;
    $display("[%0t] TEST #5: Branch taken to addr=0x%0h, pc=%0h, instr=%0d", $time, branch_addr, dut.pc, instr);

    // Branch priority over pc_en
    branch_addr = 8'h20;
    pc_en       = 1;
    branch_en   = 1;
    @(posedge clk);
    branch_en   = 0;
    pc_en       = 0;
    $display("[%0t] TEST #6: Branch priority test, pc should be 0x20, instr=%0d", $time, instr);

    // No control signals
    @(posedge clk);
    $display("[%0t] TEST #7: No control active, pc=%0h, instr=%0d", $time, dut.pc, instr);

    // End simulationss
    #20;
    $display("[%0t] TEST COMPLETE.", $time);
    $finish;
  end

  // ASSERTIONS


  assert property (
    @(posedge clk) !rst_n |=> (instr == 16'h0000 && dut.pc == 0)
  ) else $error("PC not 0 after reset");                 
  

  assert property (
    @(posedge clk)
    disable iff (!rst_n)
    (branch_en) |=> (dut.pc == $past(branch_addr))
  ) else $error("PC doesnt set to branch adress after branch_en (no reset)");               

  assert property (
    @(posedge clk)
    disable iff (!rst_n)
    (!branch_en && pc_en) |=> (dut.pc == $past(dut.pc + 2))
  ) else $error("PC doesnt incremented by 2 after pc_en (no branch & reset)");

  assert property (
    @(posedge clk)
    disable iff (!rst_n)
    (!branch_en && !pc_en) |=> (dut.pc == $past(dut.pc))
  ) else $error("PC does not hold its value when no control signal is active");

  assert property (
    @(posedge clk)
    disable iff (!rst_n)
    instr == dut.mem[dut.pc]
  ) else $error(" instr != mem[PC]");

  assert property (
    @(posedge clk)
    dut.pc <= 8'hFF
  ) else $error("PC out of range");

endmodule