// tb_simple_cache.sv

// Probability weights
`define W_READ_ONLY    45       // weight for read=1, write=0
`define W_WRITE_ONLY   45       // weight for read=0, write=1
`define W_BOTH         5        // weight for read=1, write=1 (simultaneous)
`define W_IDLE         5        // weight for read=0, write=0

module tb_simple_cache;

    // Parameters
    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;
    parameter CACHE_LINES = 16;
    parameter LINE_SIZE   = 4;

    // Derived widths (mirror DUT)
    localparam INDEX_WIDTH  = $clog2(CACHE_LINES);
    localparam OFFSET_WIDTH = $clog2(LINE_SIZE);
    localparam TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;

    // 10% thresholds for bin ranges
    localparam INDEX_MAX    = (1 << INDEX_WIDTH) - 1;
    localparam INDEX_LO     = INDEX_MAX / 10;
    localparam INDEX_HI     = INDEX_MAX - INDEX_LO;

    localparam TAG_MAX      = (1 << TAG_WIDTH) - 1;
    localparam TAG_LO       = TAG_MAX / 10;
    localparam TAG_HI       = TAG_MAX - TAG_LO;

    localparam OFFSET_MAX   = (1 << OFFSET_WIDTH) - 1;
    localparam OFFSET_LO    = OFFSET_MAX / 10;
    localparam OFFSET_HI    = OFFSET_MAX - OFFSET_LO;

    // Transaction class
    class cache_transaction;
        rand bit [ADDR_WIDTH-1:0] addr;
        rand bit [DATA_WIDTH-1:0] data_in;
        rand bit                  rd;
        rand bit                  wr;

        constraint c_op {
            {rd, wr} dist {
                2'b10 := `W_READ_ONLY,
                2'b01 := `W_WRITE_ONLY,
                2'b11 := `W_BOTH,
                2'b00 := `W_IDLE
            };
        }
    endclass

    // DUT signals
    logic clk, reset;
    logic read, write;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic hit;

    // Instantiate DUT
    simple_cache dut (
        .clk(clk), .reset(reset),
        .read(read), .write(write),
        .addr(addr), .data_in(data_in),
        .data_out(data_out), .hit(hit)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Reset
        clk = 0; reset = 1;
        read = 0; write = 0;
        addr = 0; data_in = 0;
        #20 reset = 0;

        // Random stimulus
        begin
            cache_transaction tx = new();
            repeat (200) begin
                @(posedge clk);
                if (!tx.randomize()) $fatal(1, "Randomization failed");
                addr    = tx.addr;
                data_in = tx.data_in;
                read    = tx.rd;
                write   = tx.wr;
            end
        end

        // Directed: write then read-hit to same address
        repeat (20) begin
            @(posedge clk);
            addr = $urandom_range(0,255);
            data_in = $urandom();
            read = 0; write = 1;
            @(posedge clk);
            read = 1; write = 0;
        end

        // Directed: read miss then read hit to same address
        repeat (20) begin
            @(posedge clk);
            addr = $urandom_range(0,255);
            read = 1; write = 0;
            @(posedge clk);
            read = 1; write = 0;
        end

        #50
        $display("TEST FINISHED");
        $finish;
    end

     // Functional coverage
    covergroup cache_cov @(posedge clk);
        option.per_instance = 1;







         // Cover read/write activity
        coverpoint write;
        coverpoint read;
        coverpoint hit;



        cross write, read {
            bins write_only     =   binsof(write) intersect {1} &&
                                    binsof(read) intersect {0};
            bins read_only      =   binsof(write) intersect {0} &&
                                    binsof(read) intersect {1};
            bins both_off       =   binsof(write) intersect {0} &&
                                    binsof(read) intersect {0};
            bins read_over_write =  binsof(write) intersect {1} &&
                                    binsof(read) intersect {1};
            }
        

        cross write, hit {
            bins write_hit  = binsof(write) intersect {1} &&
                              binsof(hit) intersect {1};
            bins write_miss = binsof(write) intersect {1} &&
                              binsof(hit) intersect {0};
            }

        cross read, hit {
            bins read_hit  = binsof(read) intersect {1} &&
                              binsof(hit) intersect {1};
            bins read_miss = binsof(read) intersect {1} &&
                              binsof(hit) intersect {0};
            }

 

        coverpoint dut.tag {
            bins lower_bins = {[0:TAG_LO]};
            bins mid_bins   = {[TAG_LO+1:TAG_HI-1]};
            bins high_bins  = {[TAG_HI:TAG_MAX]};
        }

        coverpoint dut.index {
            bins lower_bins = {[0:INDEX_LO]};
            bins mid_bins   = {[INDEX_LO+1:INDEX_HI-1]};
            bins high_bins  = {[INDEX_HI:INDEX_MAX]};
        }

        coverpoint dut.offset {
            bins lower_bins = {[0:OFFSET_LO]};
            bins mid_bins   = {[OFFSET_LO+1:OFFSET_HI-1]};
            bins high_bins  = {[OFFSET_HI:OFFSET_MAX]};
        }

    endgroup


    cache_cov cov_inst = new();

    
    // 3. Read to a valid line with tag mismatch (replacement)
    property p_read_replace;
        @(posedge clk) disable iff (reset)
            read && !write && dut.valid_array[dut.index] && (dut.tag_array[dut.index] != dut.tag);
    endproperty
    cover property (p_read_replace);

    // 4. Write to a valid line with tag mismatch (replacement)
    property p_write_replace;
        @(posedge clk) disable iff (reset)
            write && !read && dut.valid_array[dut.index] && (dut.tag_array[dut.index] != dut.tag);
    endproperty
    cover property (p_write_replace);

    // 5. Read cold miss (invalid line)
    property p_read_cold_miss;
        @(posedge clk) disable iff (reset)
            read && !write && !dut.valid_array[dut.index];
    endproperty
    cover property (p_read_cold_miss);

    // 6. Write cold miss (invalid line)
    property p_write_cold_miss;
        @(posedge clk) disable iff (reset)
            write && !read && !dut.valid_array[dut.index];
    endproperty
    cover property (p_write_cold_miss);

    // 7. Write then read-hit to same address (data round-trip path)
    property p_write_then_read_hit;
        logic [ADDR_WIDTH-1:0] saved_addr;
        @(posedge clk) disable iff (reset)
            (write && !read, saved_addr = addr) ##1 (read && !write && hit && addr == saved_addr);
    endproperty
    cover property (p_write_then_read_hit);

    // 8. Read miss then read hit to same address (cache fill path)
    property p_read_miss_then_hit;
        logic [ADDR_WIDTH-1:0] saved_addr;
        @(posedge clk) disable iff (reset)
            (read && !hit, saved_addr = addr) ##1 (read && hit && addr == saved_addr);
    endproperty
    cover property (p_read_miss_then_hit);

    // 9. Hit de-asserts (hit goes 1 -> 0, not stuck high)
    property p_hit_deasserts;
        @(posedge clk) disable iff (reset)
            hit ##1 !hit;
    endproperty
    cover property (p_hit_deasserts);

endmodule