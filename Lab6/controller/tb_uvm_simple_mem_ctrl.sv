`timescale 1ns/1ps
`include "uvm_macros.svh"

interface mem_ctrl_if #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);
    // Master 0 (CPU)
    logic [ADDR_WIDTH-1:0] addr0;
    logic [DATA_WIDTH-1:0] wdata0;
    logic [DATA_WIDTH-1:0] rdata0;
    logic                  we0;
    logic                  req0;
    logic                  gnt0;

    // Master 1 (DMA)
    logic [ADDR_WIDTH-1:0] addr1;
    logic [DATA_WIDTH-1:0] wdata1;
    logic [DATA_WIDTH-1:0] rdata1;
    logic                  we1;
    logic                  req1;
    logic                  gnt1;
endinterface

package controller_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 32;

    class ctrl_transaction extends uvm_sequence_item;
        `uvm_object_utils(ctrl_transaction)
        rand bit use_m0; // whether master0 participates in this transaction
        rand bit is_write0;
        rand logic [ADDR_WIDTH-1:0] addr0;
        rand logic [DATA_WIDTH-1:0] data0;

        rand bit use_m1; // whether master1 participates in this transaction
        rand bit is_write1;
        rand logic [ADDR_WIDTH-1:0] addr1;
        rand logic [DATA_WIDTH-1:0] data1;

        rand int unsigned delay_cycles;

        function new(string name = "ctrl_transaction");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("M0[use=%0b we=%0b addr=%0h data=%0h] M1[use=%0b we=%0b addr=%0h data=%0h] delay=%0d",                                                    
              use_m0, is_write0, addr0, data0,
              use_m1, is_write1, addr1, data1,                                      
              delay_cycles);          
        endfunction

    endclass

    class ctrl_sequencer extends uvm_sequencer #(ctrl_transaction);
        `uvm_component_utils(ctrl_sequencer)
        //mailbox replacment
        //no additional code needed ?

        function new(string name = "ctrl_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class ctrl_driver extends uvm_driver #(ctrl_transaction);
        `uvm_component_utils(ctrl_driver)
        // rpelace tb_driver

        virtual mem_ctrl_if vif;

        function new(string name = "ctrl_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual mem_ctrl_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for ctrl_driver")
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_transaction tx;

            forever begin
                seq_item_port.get_next_item(tx);

                // Apply delay before driving
                if (tx.delay_cycles > 0)
                    repeat (tx.delay_cycles) @(posedge vif.clk);

                // Drive negedge - posedege bakc and forth following tb 

                // Assert both masters' reqs on the same negedge if requested
                @(negedge vif.clk);
                if (tx.use_m0) begin
                    vif.addr0  = tx.addr0;
                    vif.wdata0 = tx.data0;
                    vif.we0    = tx.is_write0;
                    vif.req0   = 1;
                end
                if (tx.use_m1) begin
                    vif.addr1  = tx.addr1;
                    vif.wdata1 = tx.data1;
                    vif.we1    = tx.is_write1;
                    vif.req1   = 1;
                end
                
                // Log when both are asserted (concurrent)
                `uvm_info("DRV", tx.convert2string(), UVM_MEDIUM)

                // Capture cycle
                @(posedge vif.clk);

                // Release both on the next negedge
                @(negedge vif.clk);
                if (tx.use_m0) begin
                    vif.req0   = 0;
                    vif.we0    = 0;
                    vif.addr0  = '0;
                    vif.wdata0 = '0;
                end
                if (tx.use_m1) begin
                    vif.req1   = 0;
                    vif.we1    = 0;
                    vif.addr1  = '0;
                    vif.wdata1 = '0;
                end

                // After issuing the transaction, let it settle a bit
                @(posedge vif.clk);

                seq_item_port.item_done();
            end
        endtask
    endclass

    class ctrl_monitor extends uvm_monitor;
        `uvm_component_utils(ctrl_monitor)
        // replace tb_monitor
        virtual mem_ctrl_if vif;
        uvm_analysis_port #(ctrl_transaction) analysis_port;

        function new(string name="ctrl_monitor", uvm_component parent=null);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual mem_ctrl_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for ctrl_monitor")
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_transaction trans;
            bit any_write;
            bit any_read;
            forever begin
                @(posedge vif.clk);

                if (vif.req1 && vif.req0) begin
                    `uvm_info("MON", $sformatf("Concurrent requests detected: req0 (addr=%0d we=%b) req1 (addr=%0d we=%b)", vif.addr0, vif.we0, vif.addr1, vif.we1), UVM_MEDIUM)
                end

                any_write = 0;
                any_read = 0;
                
                trans = ctrl_transaction::type_id::create("trans");   

                if (vif.gnt0 && vif.we0) begin
                    trans.use_m0 = 1;
                    trans.is_write0 = 1;
                    trans.addr0 = vif.addr0;
                    trans.data0 = vif.wdata0;
                    any_write = 1;
                end
                if (vif.gnt1 && vif.we1) begin
                    trans.use_m1 = 1;
                    trans.is_write1 = 1;
                    trans.addr1 = vif.addr1;
                    trans.data1 = vif.wdata1;
                    any_write = 1;
                end

                if (any_write) begin
                    analysis_port.write(trans); // Publish
                    `uvm_info("MON", $sformatf("WRITE event (use_m0=%b use_m1=%b)", trans.use_m0, trans.use_m1), UVM_MEDIUM)
                end

                trans = ctrl_transaction::type_id::create("trans");   

                if (vif.gnt0 && !vif.we0) begin
                    trans.use_m0 = 1;
                    trans.is_write0 = 0;
                    trans.addr0 = vif.addr0;
                    trans.data0 = vif.rdata0;
                    any_read = 1;
                end
                if (vif.gnt1 && !vif.we1) begin
                    trans.use_m1 = 1;
                    trans.is_write1 = 0;
                    trans.addr1 = vif.addr1;
                    trans.data1 = vif.rdata1;
                    any_read = 1;
                end
                if (any_read) begin
                    analysis_port.write(trans); // Publish
                    `uvm_info("MON", $sformatf("READ event (use_m0=%b use_m1=%b)", trans.use_m0, trans.use_m1), UVM_MEDIUM)
                end

            end

        endtask

    endclass

    class ctrl_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(ctrl_scoreboard)
        //replace checker

        uvm_analysis_imp #(ctrl_transaction, ctrl_scoreboard) analysis_export;

        // Golden memory
        logic [DATA_WIDTH-1:0] ref_mem[2**ADDR_WIDTH];
        int total_tests = 0;
        int failed_tests = 0;

        function new(string name = "ctrl_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            analysis_export = new("analysis_export", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            // Initialize golden memory
            for (int i = 0; i < 2**ADDR_WIDTH; i++) ref_mem[i] = '0;
        endfunction

        function void write(ctrl_transaction trans);
            if (trans.use_m0) begin
                if (trans.is_write0) begin
                    ref_mem[trans.addr0] = trans.data0;
                    `uvm_info("SCB", $sformatf("WRITE MASTER0 addr=%0d data=0x%0h", trans.addr0, trans.data0), UVM_MEDIUM)
                end else begin
                    total_tests++;
                    if (trans.data0 !== ref_mem[trans.addr0]) begin
                        failed_tests++;
                        `uvm_error("SCB", $sformatf("READ MASTER0 addr=%0d expected=0x%0h observed=0x%0h", trans.addr0, ref_mem[trans.addr0], trans.data0))
                    end else begin
                        `uvm_info("SCB", $sformatf("READ MASTER0 addr=%0d value OK 0x%0h", trans.addr0, trans.data0), UVM_MEDIUM)
                    end
                end
            end
            // Process master1
            if (trans.use_m1) begin
                if (trans.is_write1) begin
                    ref_mem[trans.addr1] = trans.data1;
                    `uvm_info("SCB", $sformatf("WRITE MASTER1 addr=%0d data=0x%0h", trans.addr1, trans.data1), UVM_MEDIUM)
                end else begin
                    total_tests++;
                    if (trans.data1 !== ref_mem[trans.addr1]) begin
                        failed_tests++;
                        `uvm_error("SCB", $sformatf("READ MASTER1 addr=%0d expected=0x%0h observed=0x%0h", trans.addr1, ref_mem[trans.addr1], trans.data1))
                    end else begin
                        `uvm_info("SCB", $sformatf("READ MASTER1 addr=%0d value OK 0x%0h", trans.addr1, trans.data1), UVM_MEDIUM)
                    end
                end
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SCB", $sformatf("Read checks: total=%0d failed=%0d", total_tests, failed_tests), UVM_LOW)
        endfunction
    endclass

    class ctrl_agent extends uvm_agent;
        `uvm_component_utils(ctrl_agent)
        // group sequencer +driver + monitor 


        ctrl_sequencer sqr ;
        ctrl_driver drv;
        ctrl_monitor mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sqr = ctrl_sequencer::type_id::create("sqr", this);
            drv = ctrl_driver::type_id::create("drv", this);
            mon = ctrl_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class ctrl_env extends uvm_env;
        `uvm_component_utils(ctrl_env)
        //create agent and scoreboard , connect monitor to scoreboard
        ctrl_agent agent;
        ctrl_scoreboard sb;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction


        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = ctrl_agent::type_id::create("agent", this);
            sb   = ctrl_scoreboard::type_id::create("sb", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.analysis_port.connect(sb.analysis_export);
        endfunction
        
    endclass

    class ctrl_directed_seq extends uvm_sequence #(ctrl_transaction);
        `uvm_object_utils(ctrl_directed_seq)

        function new(string name = "ctrl_directed_seq");
            super.new(name);
        endfunction

        virtual task body();
            ctrl_transaction tx;

            // M0 (CPU): write then read back, addresses 0-7
            for (int a = 0; a < 8; a++) begin
                tx = ctrl_transaction::type_id::create("tx");
                start_item(tx);
                tx.use_m0    = 1;   tx.is_write0 = 1;
                tx.addr0     = a;   tx.data0     = (a * 16) + 100;
                tx.use_m1    = 0;   tx.is_write1 = 0;
                tx.addr1     = 0;   tx.data1     = 0;
                tx.delay_cycles = $urandom_range(1, 3);
                finish_item(tx);

                tx = ctrl_transaction::type_id::create("tx");
                start_item(tx);
                tx.use_m0    = 1;   tx.is_write0 = 0;
                tx.addr0     = a;   tx.data0     = 0;
                tx.use_m1    = 0;   tx.is_write1 = 0;
                tx.addr1     = 0;   tx.data1     = 0;
                tx.delay_cycles = $urandom_range(1, 3);
                finish_item(tx);
            end

            // M1 (DMA): write then read back, addresses 8-15
            for (int a = 8; a < 16; a++) begin
                tx = ctrl_transaction::type_id::create("tx");
                start_item(tx);
                tx.use_m0    = 0;   tx.is_write0 = 0;
                tx.addr0     = 0;   tx.data0     = 0;
                tx.use_m1    = 1;   tx.is_write1 = 1;
                tx.addr1     = a;   tx.data1     = (a * 16) + 200;
                tx.delay_cycles = $urandom_range(1, 3);
                finish_item(tx);

                tx = ctrl_transaction::type_id::create("tx");
                start_item(tx);
                tx.use_m0    = 0;   tx.is_write0 = 0;
                tx.addr0     = 0;   tx.data0     = 0;
                tx.use_m1    = 1;   tx.is_write1 = 0;
                tx.addr1     = a;   tx.data1     = 0;
                tx.delay_cycles = $urandom_range(1, 3);
                finish_item(tx);
            end
        endtask
    endclass

    class ctrl_contention_seq extends uvm_sequence #(ctrl_transaction);
        `uvm_object_utils(ctrl_contention_seq)

        function new(string name = "ctrl_contention_seq");
            super.new(name);
        endfunction

        virtual task body();
            ctrl_transaction tx;

            // Both masters simultaneously, addresses 16-17
            for (int a = 16; a < 18; a++) begin
                // Simultaneous write                                                     
                tx = ctrl_transaction::type_id::create("tx");
                start_item(tx);                                                           
                tx.use_m0 = 1; tx.is_write0 = 1; tx.addr0 = a; tx.data0 = (a * 16) + 300;
                tx.use_m1 = 1; tx.is_write1 = 1; tx.addr1 = a; tx.data1 = (a * 16) + 400; 
                tx.delay_cycles = 0;                                                      
                finish_item(tx);                                                          
                                                                                            
                // Simultaneous read back                                                 
                tx = ctrl_transaction::type_id::create("tx");                             
                start_item(tx);                                                           
                tx.use_m0 = 1; tx.is_write0 = 0; tx.addr0 = a; tx.data0 = 0;
                tx.use_m1 = 1; tx.is_write1 = 0; tx.addr1 = a; tx.data1 = 0;              
                tx.delay_cycles = 1;                                                    
                finish_item(tx);                                                          
            end              
            
        endtask
    endclass

    class ctrl_random_seq extends uvm_sequence #(ctrl_transaction);
        `uvm_object_utils(ctrl_random_seq)

        function new(string name = "ctrl_random_seq");
            super.new(name);
        endfunction

        virtual task body();
            ctrl_transaction tx;
            repeat (30) begin
                tx = ctrl_transaction::type_id::create("tx");                             
                start_item(tx);                                                           
                assert(tx.randomize() with { use_m0 || use_m1; delay_cycles inside {[0:2]}; });
                finish_item(tx);    
            end
        endtask
         // gerator ranom tests
    endclass

    class ctrl_directed_test extends uvm_test;
        `uvm_component_utils(ctrl_directed_test)
        // put all together - run directed test

        ctrl_env env;

        function new(string name = "ctrl_directed_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction


        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ctrl_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_directed_seq seq;
            super.run_phase(phase);
            seq = ctrl_directed_seq::type_id::create("dir_seq");
            phase.raise_objection(this);
            seq.start(env.agent.sqr);  // Run sequence in sequencer
            phase.drop_objection(this);
        endtask
    endclass

    class ctrl_contention_test extends uvm_test;
        `uvm_component_utils(ctrl_contention_test)
        // put all together - run directed test

        ctrl_env env;

        function new(string name = "ctrl_contention_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction


        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ctrl_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_contention_seq seq;
            super.run_phase(phase);
            seq = ctrl_contention_seq::type_id::create("cont_seq");
            phase.raise_objection(this);
            seq.start(env.agent.sqr);  // Run sequence in sequencer
            phase.drop_objection(this);
        endtask
        // put all together - run contention test
    endclass

    class ctrl_random_test extends uvm_test;
        `uvm_component_utils(ctrl_random_test)

        ctrl_env env;

        function new(string name = "ctrl_random_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction


        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ctrl_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            ctrl_random_seq seq;
            super.run_phase(phase);
            seq = ctrl_random_seq::type_id::create("rand_seq");
            phase.raise_objection(this);
            seq.start(env.agent.sqr);  // Run sequence in sequencer
            phase.drop_objection(this);
        endtask
        // put all together - run random test

    endclass

    class ctrl_full_test extends uvm_test;
        `uvm_component_utils(ctrl_full_test)

        ctrl_env env;

        function new(string name = "ctrl_full_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction


        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = ctrl_env::type_id::create("env", this);
        endfunction


        task run_phase(uvm_phase phase);
            ctrl_directed_seq   dir_seq;
            ctrl_contention_seq cont_seq;
            ctrl_random_seq     rand_seq;
            super.run_phase(phase);
            phase.raise_objection(this);
            dir_seq  = ctrl_directed_seq::type_id::create("dir_seq");             
            dir_seq.start(env.agent.sqr);              
            cont_seq = ctrl_contention_seq::type_id::create("cont_seq");          
            cont_seq.start(env.agent.sqr);                                        
            rand_seq = ctrl_random_seq::type_id::create("rand_seq");
            rand_seq.start(env.agent.sqr);                                        
            phase.drop_objection(this);                                           
        endtask  
        // put all together - run random test
    endclass

endpackage : controller_pkg

module tb_uvm_simple_mem_ctrl;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import controller_pkg::*;

    // Clock and reset signals
    logic clk;
    logic rst_n;

    mem_ctrl_if #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) vif(clk, rst_n);

    simple_mem_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .addr0  (vif.addr0),
        .wdata0 (vif.wdata0),
        .rdata0 (vif.rdata0),
        .we0    (vif.we0),
        .req0   (vif.req0),
        .gnt0   (vif.gnt0),
        .addr1  (vif.addr1),
        .wdata1 (vif.wdata1),
        .rdata1 (vif.rdata1),
        .we1    (vif.we1),
        .req1   (vif.req1),
        .gnt1   (vif.gnt1)
    );

    //Clock generation 
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //Reset generation 
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    initial begin
        uvm_config_db#(virtual mem_ctrl_if)::set(null, "*", "vif", vif);
        run_test();
    end

endmodule : tb_uvm_simple_mem_ctrl
