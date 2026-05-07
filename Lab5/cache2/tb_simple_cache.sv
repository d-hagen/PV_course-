// tb_simple_cache.sv
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

    // Count of currently valid cache lines
    logic [$clog2(CACHE_LINES):0] valid_count;
    always_comb begin
        valid_count = 0;
        for (int i = 0; i < CACHE_LINES; i++)
            valid_count += dut.valid_array[i];
    end

    initial begin
        // Reset
        clk = 0; reset = 1;
        read = 0; write = 0;
        addr = 0; data_in = 0;
        #20 reset = 0;

        // Random stimulus (cache 2 style: simple $urandom_range / $urandom)
        repeat (200) begin
            @(posedge clk);
            addr = $urandom_range(0,255);
            if ($urandom_range(0,1)) begin
                read = 1; write = 0;
            end else begin
                read = 0; write = 1;
                data_in = $urandom();
            end
        end

        // ADD ADDITIONAL STIMULUS AS NEEDED HERE

        #50
        $display("TEST FINISHED");
        $finish;
    end

    // Functional coverage (from original cache tb)
    covergroup cache_cov @(posedge clk);
        option.per_instance = 1;

        // Cover read/write activity
        coverpoint write;
        coverpoint read;
        coverpoint hit;

        cross write, read {
            bins write_only      = binsof(write) intersect {1} &&
                                   binsof(read) intersect {0};
            bins read_only       = binsof(write) intersect {0} &&
                                   binsof(read) intersect {1};
            bins both_off        = binsof(write) intersect {0} &&
                                   binsof(read) intersect {0};
            bins read_over_write = binsof(write) intersect {1} &&
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

        cp_index: coverpoint dut.index {
            bins lower_bins = {[0:INDEX_LO]};
            bins mid_bins   = {[INDEX_LO+1:INDEX_HI-1]};
            bins high_bins  = {[INDEX_HI:INDEX_MAX]};
        }

        // Cache fill level: cold, partially loaded, fully loaded
        coverpoint valid_count {
            bins cold         = {0};
            bins partial      = {[1:CACHE_LINES-1]};
            bins fully_loaded = {CACHE_LINES};
        }

        // Hit/miss spread across index ranges
        cross cp_index, hit {
            bins index_low_hit   = binsof(cp_index) intersect {[0:INDEX_LO]}    && binsof(hit) intersect {1};
            bins index_low_miss  = binsof(cp_index) intersect {[0:INDEX_LO]}    && binsof(hit) intersect {0};
            bins index_mid_hit   = binsof(cp_index) intersect {[INDEX_LO+1:INDEX_HI-1]} && binsof(hit) intersect {1};
            bins index_mid_miss  = binsof(cp_index) intersect {[INDEX_LO+1:INDEX_HI-1]} && binsof(hit) intersect {0};
            bins index_high_hit  = binsof(cp_index) intersect {[INDEX_HI:INDEX_MAX]}    && binsof(hit) intersect {1};
            bins index_high_miss = binsof(cp_index) intersect {[INDEX_HI:INDEX_MAX]}    && binsof(hit) intersect {0};
        }

        coverpoint dut.offset {
            bins lower_bins = {[0:OFFSET_LO]};
            bins mid_bins   = {[OFFSET_LO+1:OFFSET_HI-1]};
            bins high_bins  = {[OFFSET_HI:OFFSET_MAX]};
        }

    endgroup

    cache_cov cov_inst = new();

    // Cover properties (from original cache tb)

    // Read to a valid line with tag mismatch (replacement)
    property p_read_replace;
        @(posedge clk) disable iff (reset)
            read && !write && dut.valid_array[dut.index] && (dut.tag_array[dut.index] != dut.tag);
    endproperty
    cover property (p_read_replace);

    // Write to a valid line with tag mismatch (replacement)
    property p_write_replace;
        @(posedge clk) disable iff (reset)
            write && !read && dut.valid_array[dut.index] && (dut.tag_array[dut.index] != dut.tag);
    endproperty
    cover property (p_write_replace);

    // Read cold miss (invalid line)
    property p_read_cold_miss;
        @(posedge clk) disable iff (reset)
            read && !write && !dut.valid_array[dut.index];
    endproperty
    cover property (p_read_cold_miss);

    // Write cold miss (invalid line)
    property p_write_cold_miss;
        @(posedge clk) disable iff (reset)
            write && !read && !dut.valid_array[dut.index];
    endproperty
    cover property (p_write_cold_miss);

    // Write then read-hit to same address (data round-trip path)
    property p_write_then_read_hit;
        logic [ADDR_WIDTH-1:0] saved_addr;
        @(posedge clk) disable iff (reset)
            (write && !read, saved_addr = addr) ##[1:$] (read && !write && hit && addr == saved_addr);
    endproperty
    cover property (p_write_then_read_hit);

    // Read miss then read hit to same address (cache fill path)
    property p_read_miss_then_hit;
        logic [ADDR_WIDTH-1:0] saved_addr;
        @(posedge clk) disable iff (reset)
            (read && !hit, saved_addr = addr) ##[1:$] (read && hit && addr == saved_addr);
    endproperty
    cover property (p_read_miss_then_hit);

    // Hit de-asserts (hit goes 1 -> 0, not stuck high)
    property p_hit_deasserts;
        @(posedge clk) disable iff (reset)
            hit ##1 !hit;
    endproperty
    cover property (p_hit_deasserts);

endmodule
