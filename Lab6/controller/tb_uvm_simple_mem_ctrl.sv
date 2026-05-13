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
            return $sformat("M0[use=%0b we=%0b addr=%0h data=%0h] M1[use=%0b we=%0b addr=%0h data=%0h] delay=%0d",                                                    
              use_m0, is_write0, addr0, data0,
              use_m1, is_write1, addr1, data1,                                      
              delay_cycles);          
        endfunction

    endclass

    class ctrl_sequencer extends uvm_sequencer #(ctrl_transaction);
        `uvm_component_utils(ctrl_sequencer)
        //mailbox replacment
        //no additional code needed ?
    endclass

    class ctrl_driver extends uvm_driver #(ctrl_transaction);
        `uvm_component_utils(ctrl_driver)
        // rpelace tb_driver
    endclass

    class ctrl_monitor extends uvm_monitor;
        `uvm_component_utils(ctrl_monitor)
        // replace tb_monitor
    endclass

    class ctrl_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(ctrl_scoreboard)
        //replace checker 
    endclass

    class ctrl_agent extends uvm_agent;
        `uvm_component_utils(ctrl_agent)
        // group sequencer +driver + monitor 
    endclass

    class ctrl_env extends uvm_env;
        `uvm_component_utils(ctrl_env)
        //create agent and scoreboard , connect monitor to scoreboard
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
    endclass

    class ctrl_contention_test extends uvm_test;
        `uvm_component_utils(ctrl_contention_test)
        // put all together - run contention test
    endclass

    class ctrl_random_test extends uvm_test;
        `uvm_component_utils(ctrl_random_test)
        // put all together - run random test

    endclass

    class ctrl_full_test extends uvm_test;
        `uvm_component_utils(ctrl_full_test)
        // put all together - run random test
    endclass

endpackage : controller_pkg

module tb_uvm_simple_mem_ctrl;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import controller_pkg::*;

    initial begin
        run_test();
    end

endmodule : tb_uvm_simple_mem_ctrl
