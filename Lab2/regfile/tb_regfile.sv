`timescale 1ns/1ps

// ============================================================
// Configuration — edit here
// ============================================================
`define DUT_NAME       regfile_v1  // swap to regfile_v0, regfile_v1, etc.
`define RAND_N         1000     // number of random transactions

// Probability weights (relative, not percentages — they are normalised by the tool)
`define W_RST_LOW      5        // weight for rst_n=0
`define W_RST_HIGH     95       // weight for rst_n=1
`define W_WR_EN        80       // weight for wr_en=1
`define W_NO_WR        20       // weight for wr_en=0
`define W_RD_CONFLICT  10       // weight for forcing rd/rd conflict
`define W_NO_CONFLICT  90       // weight for no forced conflict
// ============================================================


// -- Reference Model --
module reference_RegFile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [4:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire [4:0]  rd_addr1,
    input  wire [4:0]  rd_addr2,
    output wire [15:0] rd_data1,
    output wire [15:0] rd_data2,
    output reg         err
);
    reg  [15:0] regs [0:31];
    wire error;
    assign error = (rd_addr1 == rd_addr2) ||
                   (wr_en && (wr_addr == rd_addr1 || wr_addr == rd_addr2));

    assign rd_data1 = error ? 'x : regs[rd_addr1];
    assign rd_data2 = error ? 'x : regs[rd_addr2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++)
                regs[i] <= '0;
            err <= 1'b0;
        end else begin
            err <= error;
            if (wr_en && !error)
                regs[wr_addr] <= wr_data;
        end
    end
endmodule


// -- Directed Generator --
module directed_generator (
    input  wire clk,
    output reg  rst_n,
    output reg  wr_en,
    output reg  [4:0]  wr_addr,
    output reg  [15:0] wr_data,
    output reg  [4:0]  rd_addr1,
    output reg  [4:0]  rd_addr2,
    output reg  done,
    output int  test_id
);
    int cycle_num = 0;

    task send(
        input reg        rst_n_i,
        input reg        wr_en_i,
        input reg [4:0]  wr_addr_i,
        input reg [15:0] wr_data_i,
        input reg [4:0]  rd_addr1_i,
        input reg [4:0]  rd_addr2_i
    );
        rst_n    = rst_n_i;
        wr_en    = wr_en_i;
        wr_addr  = wr_addr_i;
        wr_data  = wr_data_i;
        rd_addr1 = rd_addr1_i;
        rd_addr2 = rd_addr2_i;
        @(posedge clk); #1;
        cycle_num++;
    endtask

    // write no reset
    task test_write_no_reset();
        test_id++;
        send(1, 1, 5,  16'hABCD, 1,  2);
        send(1, 0, 0,  0,        5,  2);
    endtask

    // write with reset — write 4 registers, then reset, verify all 4 read back as 0
    task test_write_with_reset();
        test_id++;
        send(1, 1, 3,  16'h1234, 1,  2);
        send(1, 1, 7,  16'hABCD, 1,  2);
        send(1, 1, 15, 16'hDEAD, 1,  2);
        send(1, 1, 20, 16'hBEEF, 1,  2);
        send(0, 0, 0,  0,        3,  7);   // assert reset
        send(1, 0, 0,  0,        3,  7);   // regs 3 and 7 must be 0
        send(1, 0, 0,  0,        15, 20);  // regs 15 and 20 must be 0
    endtask

    // read no reset
    task test_read_no_reset();
        test_id++;
        send(1, 1, 10, 16'hDEAD, 1,  2);
        send(1, 1, 20, 16'hBEEF, 1,  2);
        send(1, 0, 0,  0,        10, 20);
    endtask

    // read with reset
    task test_read_with_reset();
        test_id++;
        send(1, 1, 7,  16'hFFFF, 1,  2);
        send(0, 0, 0,  0,        7,  8);
        send(1, 0, 0,  0,        7,  8);
    endtask

    // reset overrides write: rst_n=0 and wr_en=1 simultaneously — write must be suppressed
    task test_reset_overrides_write();
        test_id++;
        send(1, 1, 6,  16'hCAFE, 1,  2);  // write 0xCAFE to reg 6
        send(0, 1, 6,  16'h1234, 6,  2);  // rst_n=0, wr_en=1 — write suppressed, reset active
        send(1, 0, 0,  0,        6,  2);  // read reg 6 — expect 0 (reset), not 0x1234
    endtask

    // error: rd/rd conflict
    task test_err_rd_rd();
        test_id++;
        send(1, 0, 0,  0,        5,  5);
        send(1, 0, 0,  0,        1,  2);
    endtask

    // error: wr/rd conflict port 1
    task test_err_wr_rd1();
        test_id++;
        send(1, 1, 4,  16'hAAAA, 4,  2);
        send(1, 0, 0,  0,        4,  2);  // read reg 4 — verify write was suppressed
    endtask

    // error: wr/rd conflict port 2
    task test_err_wr_rd2();
        test_id++;
        send(1, 1, 8,  16'hBBBB, 1,  8);
        send(1, 0, 0,  0,        1,  8);  // read reg 8 — verify write was suppressed
    endtask

    // error then reset (rd/rd conflict)
    task test_err_rd_rd_with_reset();
        test_id++;
        send(0, 0, 0,  0,        5,  5);  // rd/rd conflict
        send(1, 0, 0,  0,        1,  2);  // reset clears err
    endtask

    // error then reset (wr/rd conflict)
    task test_err_wr_rd_with_reset();
        test_id++;
        send(0, 1, 3,  16'hBEEF, 3,  2);  // wr/rd1 conflict
        send(1, 0, 0,  0,        1,  2);   // reset clears err
        send(1, 0, 0,  0,        3,  2);   // verify err=0, reg 3 not written
        send(0, 1, 7,  16'hCAFE, 1,  7);   // wr/rd2 conflict
        send(1, 0, 0,  0,        1,  2);   // reset clears err
        send(1, 0, 0,  0,        1,  7);   // verify err=0, reg 7 not written
    endtask

    initial begin
        done     = 0;
        test_id  = 0;
        rst_n    = 0;
        wr_en    = 0;
        wr_addr  = 0;
        wr_data  = 0;
        rd_addr1 = 0;
        rd_addr2 = 1;
        @(posedge clk); #1;

        test_write_no_reset();
        test_write_with_reset();
        test_read_no_reset();
        test_read_with_reset();
        test_reset_overrides_write();
        test_err_rd_rd();
        test_err_wr_rd1();
        test_err_wr_rd2();
        test_err_rd_rd_with_reset();
        test_err_wr_rd_with_reset();

        done = 1;
    end
endmodule


// -- Transaction class --
class constraint_Specs;
    rand bit        rst_n;
    rand bit        wr_en;
    rand bit [4:0]  wr_addr;
    rand bit [15:0] wr_data;
    rand bit [4:0]  rd_addr1;
    rand bit [4:0]  rd_addr2;
    rand bit        force_rd_conflict;

    constraint c_rst_n  { rst_n dist {1'b0 := `W_RST_LOW,     1'b1 := `W_RST_HIGH}; }
    constraint c_wr_en  { wr_en dist {1'b1 := `W_WR_EN,       1'b0 := `W_NO_WR};   }

    // 3% all-zeros, 2% all-ones, 95% uniform
    constraint c_wr_data {
        wr_data dist {16'h0000 := 3, 16'hFFFF := 2, [16'h0001:16'hFFFE] :/ 95};
    }

    constraint c_force_conflict_prob { force_rd_conflict dist {1'b1 := `W_RD_CONFLICT, 1'b0 := `W_NO_CONFLICT}; }
    constraint c_rd_addr2            { force_rd_conflict -> (rd_addr2 == rd_addr1); }
endclass


// -- Random Generator --
// starts on posedge start, prints seed for reproducibility
// replay with: vsim +ntb_random_seed=<seed>
module random_generator #(parameter N = 1000)(
    input  wire clk,
    input  wire start,
    output reg  rst_n,
    output reg  wr_en,
    output reg  [4:0]  wr_addr,
    output reg  [15:0] wr_data,
    output reg  [4:0]  rd_addr1,
    output reg  [4:0]  rd_addr2,
    output reg  done
);
    constraint_Specs cspecs;

    initial begin
        done     = 0;
        rst_n    = 1;
        wr_en    = 0;
        wr_addr  = 0;
        wr_data  = 0;
        rd_addr1 = 0;
        rd_addr2 = 1;

        @(posedge start); #1;
        cspecs = new();
        $display("=== random_phase: N=%0d seed=%0d ===", N, $get_initial_random_seed());

        repeat (N) begin
            if (!cspecs.randomize())
                $fatal(1, "Randomization failed");
            rst_n    = cspecs.rst_n;
            wr_en    = cspecs.wr_en;
            wr_addr  = cspecs.wr_addr;
            wr_data  = cspecs.wr_data;
            rd_addr1 = cspecs.rd_addr1;
            rd_addr2 = cspecs.rd_addr2;
            @(posedge clk); #1;
        end

        done = 1;
    end
endmodule


// -- Driver --
// mux between directed/random is done at port connections in tb_regfile
module driver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [4:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire [4:0]  rd_addr1,
    input  wire [4:0]  rd_addr2,
    output wire        rst_n_out,
    output wire        wr_en_out,
    output wire [4:0]  wr_addr_out,
    output wire [15:0] wr_data_out,
    output wire [4:0]  rd_addr1_out,
    output wire [4:0]  rd_addr2_out
);
    assign rst_n_out    = rst_n;
    assign wr_en_out    = wr_en;
    assign wr_addr_out  = wr_addr;
    assign wr_data_out  = wr_data;
    assign rd_addr1_out = rd_addr1;
    assign rd_addr2_out = rd_addr2;
endmodule


// -- Monitor --
module monitor (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [4:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire [4:0]  rd_addr1,
    input  wire [4:0]  rd_addr2,
    input  wire [15:0] dut_rd_data1,
    input  wire [15:0] dut_rd_data2,
    input  wire        dut_err,
    input  wire [15:0] ref_rd_data1,
    input  wire [15:0] ref_rd_data2,
    input  wire        ref_err,
    output reg         out_rst_n,
    output reg         out_wr_en,
    output reg  [4:0]  out_wr_addr,
    output reg  [15:0] out_wr_data,
    output reg  [4:0]  out_rd_addr1,
    output reg  [4:0]  out_rd_addr2,
    output reg  [15:0] out_dut_rd_data1,
    output reg  [15:0] out_dut_rd_data2,
    output reg         out_dut_err,
    output reg  [15:0] out_ref_rd_data1,
    output reg  [15:0] out_ref_rd_data2,
    output reg         out_ref_err,
    output reg         valid
);
    always_ff @(posedge clk) begin
        out_rst_n        <= rst_n;
        out_wr_en        <= wr_en;
        out_wr_addr      <= wr_addr;
        out_wr_data      <= wr_data;
        out_rd_addr1     <= rd_addr1;
        out_rd_addr2     <= rd_addr2;
        out_dut_rd_data1 <= dut_rd_data1;
        out_dut_rd_data2 <= dut_rd_data2;
        out_dut_err      <= dut_err;
        out_ref_rd_data1 <= ref_rd_data1;
        out_ref_rd_data2 <= ref_rd_data2;
        out_ref_err      <= ref_err;
        valid            <= 1'b1;
    end
endmodule


// -- Scoreboard --
module scoreboard (
    input  wire        clk,
    input  wire        valid,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [4:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire [4:0]  rd_addr1,
    input  wire [4:0]  rd_addr2,
    input  wire [15:0] dut_rd_data1,
    input  wire [15:0] dut_rd_data2,
    input  wire        dut_err,
    input  wire [15:0] ref_rd_data1,
    input  wire [15:0] ref_rd_data2,
    input  wire        ref_err,
    input  int         test_id
);
    int pass_count = 0, fail_count = 0;

    int check_num = 0;
    int delayed_tid;
    int prev_tid = -1;

    string test_names [0:10];
    initial begin
        test_names[0]  = "init";
        test_names[1]  = "test_write_no_reset";
        test_names[2]  = "test_write_with_reset";
        test_names[3]  = "test_read_no_reset";
        test_names[4]  = "test_read_with_reset";
        test_names[5]  = "test_reset_overrides_write";
        test_names[6]  = "test_err_rd_rd";
        test_names[7]  = "test_err_wr_rd1";
        test_names[8]  = "test_err_wr_rd2";
        test_names[9]  = "test_err_rd_rd_with_reset";
        test_names[10] = "test_err_wr_rd_with_reset";
    end

    // clocked checks
    bit rd1_ok, rd2_ok, err_ok;

    always_ff @(posedge clk) begin
        delayed_tid <= test_id;

        if (valid) begin
            if (delayed_tid !== prev_tid) begin
                if (delayed_tid >= 1 && delayed_tid <= 10)
                    $display("=== %s ===", test_names[delayed_tid]);
                else
                    $display("=== random_phase ===");
                prev_tid = delayed_tid;
            end
            rd1_ok = (dut_rd_data1 === ref_rd_data1);
            rd2_ok = (dut_rd_data2 === ref_rd_data2);
            err_ok = (dut_err === ref_err);

            if (rd1_ok) pass_count++; else fail_count++;
            if (rd2_ok) pass_count++; else fail_count++;
            if (err_ok) pass_count++; else fail_count++;

            $display("  [check %0d] SEND: rst_n=%0b wr_en=%0b wr_addr=%0d wr_data=0x%0h rd_addr1=%0d rd_addr2=%0d",
                     check_num, rst_n, wr_en, wr_addr, wr_data, rd_addr1, rd_addr2);
            if (rd1_ok && rd2_ok && err_ok)
                $display("    PASS: rd1=0x%0h rd2=0x%0h err=%0b",
                         dut_rd_data1, dut_rd_data2, dut_err);
            else
                $display("    FAIL: DUT rd1=0x%0h rd2=0x%0h err=%0b | expected rd1=0x%0h rd2=0x%0h err=%0b",
                         dut_rd_data1, dut_rd_data2, dut_err, ref_rd_data1, ref_rd_data2, ref_err);

            check_num++;
        end
    end

    final begin
        $display("-----------------------------");
        $display("SCOREBOARD: %0d PASS  %0d FAIL", pass_count, fail_count);
        $display("-----------------------------");
    end
endmodule


// -- Testbench top --
module tb_regfile;

    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;

    wire dir_done, rand_done;
    int  dir_test_id;

    wire        dir_rst_n, dir_wr_en;
    wire [4:0]  dir_wr_addr, dir_rd_addr1, dir_rd_addr2;
    wire [15:0] dir_wr_data;

    directed_generator dir_gen (
        .clk      (clk),
        .rst_n    (dir_rst_n),
        .wr_en    (dir_wr_en),
        .wr_addr  (dir_wr_addr),
        .wr_data  (dir_wr_data),
        .rd_addr1 (dir_rd_addr1),
        .rd_addr2 (dir_rd_addr2),
        .done     (dir_done),
        .test_id  (dir_test_id)
    );

    wire        rand_rst_n, rand_wr_en;
    wire [4:0]  rand_wr_addr, rand_rd_addr1, rand_rd_addr2;
    wire [15:0] rand_wr_data;

    random_generator #(.N(`RAND_N)) rand_gen (
        .clk      (clk),
        .start    (dir_done),
        .rst_n    (rand_rst_n),
        .wr_en    (rand_wr_en),
        .wr_addr  (rand_wr_addr),
        .wr_data  (rand_wr_data),
        .rd_addr1 (rand_rd_addr1),
        .rd_addr2 (rand_rd_addr2),
        .done     (rand_done)
    );

    wire        rst_n, wr_en;
    wire [4:0]  wr_addr, rd_addr1, rd_addr2;
    wire [15:0] wr_data;

    driver drv (
        .clk         (clk),
        .rst_n       (dir_done ? rand_rst_n    : dir_rst_n),
        .wr_en       (dir_done ? rand_wr_en    : dir_wr_en),
        .wr_addr     (dir_done ? rand_wr_addr  : dir_wr_addr),
        .wr_data     (dir_done ? rand_wr_data  : dir_wr_data),
        .rd_addr1    (dir_done ? rand_rd_addr1 : dir_rd_addr1),
        .rd_addr2    (dir_done ? rand_rd_addr2 : dir_rd_addr2),
        .rst_n_out   (rst_n),
        .wr_en_out   (wr_en),
        .wr_addr_out (wr_addr),
        .wr_data_out (wr_data),
        .rd_addr1_out(rd_addr1),
        .rd_addr2_out(rd_addr2)
    );

    wire [15:0] dut_rd_data1, dut_rd_data2;
    wire        dut_err;

    `DUT_NAME dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .wr_addr  (wr_addr),
        .wr_data  (wr_data),
        .rd_addr1 (rd_addr1),
        .rd_addr2 (rd_addr2),
        .rd_data1 (dut_rd_data1),
        .rd_data2 (dut_rd_data2),
        .err      (dut_err)
    );

    wire [15:0] ref_rd_data1, ref_rd_data2;
    wire        ref_err;

    reference_RegFile ref_model (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .wr_addr  (wr_addr),
        .wr_data  (wr_data),
        .rd_addr1 (rd_addr1),
        .rd_addr2 (rd_addr2),
        .rd_data1 (ref_rd_data1),
        .rd_data2 (ref_rd_data2),
        .err      (ref_err)
    );

    // -- Monitor --
    wire [15:0] mon_dut_rd_data1, mon_dut_rd_data2, mon_ref_rd_data1, mon_ref_rd_data2;
    wire        mon_dut_err, mon_ref_err, mon_valid;
    wire        mon_rst_n, mon_wr_en;
    wire [4:0]  mon_wr_addr, mon_rd_addr1, mon_rd_addr2;
    wire [15:0] mon_wr_data;

    monitor mon (
        .clk              (clk),
        .rst_n            (rst_n),
        .wr_en            (wr_en),
        .wr_addr          (wr_addr),
        .wr_data          (wr_data),
        .rd_addr1         (rd_addr1),
        .rd_addr2         (rd_addr2),
        .dut_rd_data1     (dut_rd_data1),
        .dut_rd_data2     (dut_rd_data2),
        .dut_err          (dut_err),
        .ref_rd_data1     (ref_rd_data1),
        .ref_rd_data2     (ref_rd_data2),
        .ref_err          (ref_err),
        .out_rst_n        (mon_rst_n),
        .out_wr_en        (mon_wr_en),
        .out_wr_addr      (mon_wr_addr),
        .out_wr_data      (mon_wr_data),
        .out_rd_addr1     (mon_rd_addr1),
        .out_rd_addr2     (mon_rd_addr2),
        .out_dut_rd_data1 (mon_dut_rd_data1),
        .out_dut_rd_data2 (mon_dut_rd_data2),
        .out_dut_err      (mon_dut_err),
        .out_ref_rd_data1 (mon_ref_rd_data1),
        .out_ref_rd_data2 (mon_ref_rd_data2),
        .out_ref_err      (mon_ref_err),
        .valid            (mon_valid)
    );

    // -- Scoreboard --
    scoreboard sb (
        .clk               (clk),
        .valid             (mon_valid),
        .rst_n             (mon_rst_n),
        .wr_en             (mon_wr_en),
        .wr_addr           (mon_wr_addr),
        .wr_data           (mon_wr_data),
        .rd_addr1          (mon_rd_addr1),
        .rd_addr2          (mon_rd_addr2),
        .dut_rd_data1      (mon_dut_rd_data1),
        .dut_rd_data2      (mon_dut_rd_data2),
        .dut_err           (mon_dut_err),
        .ref_rd_data1      (mon_ref_rd_data1),
        .ref_rd_data2      (mon_ref_rd_data2),
        .ref_err           (mon_ref_err),
        .test_id           (dir_test_id)
    );

    always @(posedge rand_done) #1 $finish;

endmodule
