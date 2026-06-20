
`timescale 1ns/1ps
`include "uvm_macros.svh"

`ifndef TB_WIDTH
    `define TB_WIDTH 16
`endif

package gcd_pkg;

    import uvm_pkg::*;

    parameter int unsigned WIDTH = `TB_WIDTH;

    `uvm_analysis_imp_decl(_in)
    `uvm_analysis_imp_decl(_avail)
    `uvm_analysis_imp_decl(_rst)



    // ---- sequence items ----------------------------------------------------
    class gcd_in_tx extends uvm_sequence_item;
        rand bit [WIDTH-1:0]     a_in;
        rand bit [WIDTH-1:0]     b_in;
        rand int unsigned        in_delay; 

        `uvm_object_utils_begin(gcd_in_tx)
            `uvm_field_int(a_in,   UVM_DEFAULT)
            `uvm_field_int(b_in,   UVM_DEFAULT)
            `uvm_field_int(in_delay, UVM_DEFAULT | UVM_DEC)
        `uvm_object_utils_end


        constraint c_pre_delay_reasonable {
            soft in_delay inside {[0:20]};
        }


        function new(string name = "gcd_in_tx");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("a=%0d b=%0d in_delay=%0d", a_in, b_in, in_delay);
        endfunction

    endclass



  
    class gcd_out_tx extends uvm_sequence_item;
        rand bit                ready;        
        rand int unsigned       hold_cycles;  

        `uvm_object_utils_begin(gcd_out_tx)
            `uvm_field_int(ready,       UVM_DEFAULT)
            `uvm_field_int(hold_cycles, UVM_DEFAULT | UVM_DEC)
        `uvm_object_utils_end

        constraint c_hold_reasonable {
            soft hold_cycles inside {[1:20]};
        }

        function new(string name = "gcd_out_tx");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("ready=%0b hold_cycles=%0d", ready, hold_cycles);
        endfunction

    endclass


    class gcd_result_tx extends uvm_sequence_item;
        bit  [WIDTH-1:0]        gcd_out;  
       
        `uvm_object_utils_begin(gcd_result_tx)
            `uvm_field_int(gcd_out, UVM_DEFAULT)
        `uvm_object_utils_end

        function new(string name = "gcd_result_tx");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("result=%0d", gcd_out);
        endfunction


    endclass


    class gcd_rst_tx extends uvm_sequence_item;
        rand int unsigned       assert_cycles;

        `uvm_object_utils_begin(gcd_rst_tx)
            `uvm_field_int(assert_cycles, UVM_DEFAULT | UVM_DEC)
        `uvm_object_utils_end

        constraint c_assert_reasonable {
            soft assert_cycles inside {[1:5]};
        }

        function new(string name = "gcd_rst_tx");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("assert_cycles=%0d", assert_cycles);
        endfunction
    endclass


    // ---- sequences: input side ---------------------------------------------
    class gcd_in_seq_base extends uvm_sequence #(gcd_in_tx);
        `uvm_object_utils(gcd_in_seq_base)

        function new(string name = "gcd_in_seq_base");
            super.new(name);
        endfunction
    endclass

    class gcd_in_seq_random extends gcd_in_seq_base;
        `uvm_object_utils(gcd_in_seq_random)

        int unsigned num_tx = 100;

        function new(string name = "gcd_in_seq_random");
            super.new(name);
        endfunction

        task body();
            bit equal, make_burst;
            int burst = 0;
            int delay;
            repeat (num_tx) begin
                equal      = ($urandom_range(0,19) == 0);
                make_burst = ($urandom_range(0,2)  == 0);
                if (burst == 0) begin
                    if (make_burst) begin
                        burst = $urandom_range(1,8);
                        delay = 0;
                    end
                    else
                        delay = $urandom_range(0,10);
                end
                if (burst > 0 ) begin
                    delay = 0;
                    burst--;
                end

                if (equal)
                    `uvm_do_with(req, {
                        a_in dist { 0 := 5, 1 := 5, [2:255] :/ 30, [256:65534] :/ 40, 65535 := 2 };
                        b_in == a_in;
                        in_delay == delay;
                    })
                else
                    `uvm_do_with(req, {
                        a_in dist { 0 := 5, 1 := 5, [2:255] :/ 30, [256:65534] :/ 40, 65535 := 2 };
                        b_in dist { 0 := 5, 1 := 5, [2:255] :/ 30, [256:65534] :/ 40, 65535 := 2 };
                        in_delay == delay;
                    })
            end
        endtask
    endclass

    
    typedef enum {
        ZERO,         // RQ-M01: gcd(a,0)=a, gcd(0,b)=b, gcd(0,0)=0
        EQUAL,        // RQ-M02: gcd(a,a)=a
        MAX,          // RQ-M03: max-value operands + longest run
        COPRIME,      // RQ-M03: coprime pairs -> gcd=1
        POW2,         // RQ-M03: powers of two
        BACK_TO_BACK, // RQ-T01: consecutive transactions with no idle gap
        BACKPRESSURE, // RQ-H03/H04: back-to-back ops with output back-pressure
                      //             (vseq auto-selects the back-pressure output seq)
        RESET         // RQ-R01/R02: reset asserted mid-RUN (handled by the
                      //             virtual sequence, not the input sequence)
    } dir_scenario_e;

    class gcd_in_seq_directed extends gcd_in_seq_base;
        `uvm_object_utils(gcd_in_seq_directed)

        dir_scenario_e scenario = ZERO;

        function new(string name = "gcd_in_seq_directed");
            super.new(name);
        endfunction

        task body();
            case (scenario)
                ZERO: begin
                    `uvm_do_with(req, { a_in == 0;  b_in == 5;  })  // gcd(0,5)=5
                    `uvm_do_with(req, { a_in == 5;  b_in == 0;  })  // gcd(5,0)=5
                    `uvm_do_with(req, { a_in == 0;  b_in == 0;  })  // gcd(0,0)=0
                end
                EQUAL: begin
                    `uvm_do_with(req, { a_in == 7;  b_in == 7;  })  // gcd(7,7)=7
                    `uvm_do_with(req, { a_in == 1;  b_in == 1;  })  // gcd(1,1)=1
                    `uvm_do_with(req, { a_in == '1; b_in == '1; })  // gcd(MAX,MAX)=MAX
                end
                MAX: begin
                    `uvm_do_with(req, { a_in == '1; b_in == 1; })  // longest run: MAX-1 steps
                    `uvm_do_with(req, { a_in == 1;  b_in == '1;  })
                    `uvm_do_with(req, { a_in == '1; b_in == 2;  })
                end
                COPRIME: begin
                    `uvm_do_with(req, { a_in == 3;  b_in == 5;  })  // gcd=1
                    `uvm_do_with(req, { a_in == 7;  b_in == 9;  })  // gcd=1
                    `uvm_do_with(req, { a_in == 13; b_in == 17; })  // gcd=1
                end
                POW2: begin
                    `uvm_do_with(req, { a_in == 8;  b_in == 16; })  // gcd=8
                    `uvm_do_with(req, { a_in == 4;  b_in == 32; })  // gcd=4
                    `uvm_do_with(req, { a_in == 2;  b_in == 64; })  // gcd=2
                end
                BACK_TO_BACK,
                BACKPRESSURE: begin
                    `uvm_do_with(req, { a_in == 6;  b_in == 9;  in_delay == 0; })
                    `uvm_do_with(req, { a_in == 12; b_in == 8;  in_delay == 0; })
                    `uvm_do_with(req, { a_in == 15; b_in == 5;  in_delay == 0; })
                end
                default:
                    `uvm_error(get_type_name(),
                               $sformatf("unknown directed scenario %0d", scenario))
            endcase
        endtask
    endclass


    class gcd_out_seq_base extends uvm_sequence #(gcd_out_tx);
        `uvm_object_utils(gcd_out_seq_base)
        function new(string name = "gcd_out_seq_base");
            super.new(name);
        endfunction
    endclass

    class gcd_out_seq_always_ready extends gcd_out_seq_base;
        `uvm_object_utils(gcd_out_seq_always_ready)
        function new(string name = "gcd_out_seq_always_ready");
            super.new(name);
        endfunction
        task body();
            forever `uvm_do_with(req, { ready == 1; hold_cycles == 10; })
        endtask
    endclass
    
    class gcd_out_seq_backpressure extends gcd_out_seq_base;
        `uvm_object_utils(gcd_out_seq_backpressure)
        function new(string name = "gcd_out_seq_backpressure");
            super.new(name);
        endfunction
        task body();
            forever begin
                `uvm_do_with(req, { ready == 0; hold_cycles == 3; })  // stall 3 cycles
                `uvm_do_with(req, { ready == 1; hold_cycles == 1; })  // then accept
            end
        endtask
    endclass

    class gcd_out_seq_random extends gcd_out_seq_base;
        `uvm_object_utils(gcd_out_seq_random)
        function new(string name = "gcd_out_seq_random");
            super.new(name);
        endfunction
        task body();
            forever
                `uvm_do_with(req, { ready dist { 1 := 3, 0 := 1 }; })
        endtask
    endclass


    // ---- sequences: reset side ---------------------------------------------
    class gcd_rst_seq_base extends uvm_sequence #(gcd_rst_tx);
        `uvm_object_utils(gcd_rst_seq_base)
        function new(string name = "gcd_rst_seq_base");
            super.new(name);
        endfunction
    endclass

    // single reset pulse (used for power-on and mid-flight resets)
    class gcd_rst_seq_pulse extends gcd_rst_seq_base;
        `uvm_object_utils(gcd_rst_seq_pulse)
        rand int unsigned cycles = 3;
        function new(string name = "gcd_rst_seq_pulse");
            super.new(name);
        endfunction
        task body();
            `uvm_do_with(req, { assert_cycles == cycles; })
        endtask
    endclass

    // ---- drivers -----------------------------------------------------------
    class gcd_in_driver extends uvm_driver #(gcd_in_tx);
        `uvm_component_utils(gcd_in_driver)

        virtual gcd_if.mp_in vif;

        function new(string name = "gcd_in_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_in)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_in_driver")
        endfunction

        task run_phase(uvm_phase phase);
            gcd_in_tx tx;

            vif.cb_in.in_valid <= 0; vif.cb_in.a_in <= 0; vif.cb_in.b_in <= 0;
            wait (vif.rst_n === 1);

            forever begin
                seq_item_port.get_next_item(tx);

                repeat (tx.in_delay) @(vif.cb_in);

                vif.cb_in.in_valid <= 1;
                vif.cb_in.a_in     <= tx.a_in;
                vif.cb_in.b_in     <= tx.b_in;

                `uvm_info("DRV", tx.convert2string(), UVM_MEDIUM)

                do @(vif.cb_in); while (!vif.cb_in.in_ready);

                vif.cb_in.in_valid <= 0;

                seq_item_port.item_done();
            end
        endtask

    endclass

    class gcd_out_driver extends uvm_driver #(gcd_out_tx);
        `uvm_component_utils(gcd_out_driver)

        virtual gcd_if.mp_out vif;

        function new(string name = "gcd_out_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_out)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_out_driver")
        endfunction


        task run_phase(uvm_phase phase);
            gcd_out_tx tx;

            vif.cb_out.out_ready <= 0; 
            wait (vif.rst_n === 1);

            forever begin
                seq_item_port.get_next_item(tx);

                vif.cb_out.out_ready <= tx.ready;

                repeat (tx.hold_cycles) @(vif.cb_out);

                `uvm_info("DRV", tx.convert2string(), UVM_MEDIUM)

                seq_item_port.item_done();
            end
        endtask

    endclass

    class gcd_rst_driver extends uvm_driver #(gcd_rst_tx);
        `uvm_component_utils(gcd_rst_driver)

        virtual gcd_if.mp_rst vif;

        function new(string name = "gcd_rst_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_rst)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_rst_driver")
        endfunction

        task run_phase(uvm_phase phase);
            gcd_rst_tx tx;

            vif.cb_rst.rst_n <= 1'b0;
            repeat (5) @(vif.cb_rst);
            vif.cb_rst.rst_n <= 1'b1;
            @(vif.cb_rst);

            forever begin
                seq_item_port.get_next_item(tx);

                `uvm_info("DRV_RST", tx.convert2string(), UVM_MEDIUM)

                vif.cb_rst.rst_n <= 1'b0;                   // assert
                repeat (tx.assert_cycles) @(vif.cb_rst);
                vif.cb_rst.rst_n <= 1'b1;                   // release
                @(vif.cb_rst);

                seq_item_port.item_done();
            end
        endtask

    endclass


    // ---- monitors ----------------------------------------------------------
    class gcd_in_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_in_monitor)

        virtual gcd_if.mp_mon vif;
        uvm_analysis_port #(gcd_in_tx) analysis_port;

        function new(string name = "gcd_in_monitor", uvm_component parent = null);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_mon)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_in_monitor")
        endfunction

        task run_phase(uvm_phase phase);
            gcd_in_tx tx;

            wait (vif.rst_n === 1'b1);

            forever begin
                @(vif.cb_mon);

                if (vif.cb_mon.in_valid && vif.cb_mon.in_ready) begin
                    tx = gcd_in_tx::type_id::create("tx");
                    tx.a_in = vif.cb_mon.a_in;
                    tx.b_in = vif.cb_mon.b_in;
                    analysis_port.write(tx);
                    `uvm_info("MON_IN", tx.convert2string(), UVM_MEDIUM)
                end
            end
        endtask

    endclass

    class gcd_result_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_result_monitor)

        virtual gcd_if.mp_mon vif;
        uvm_analysis_port #(gcd_result_tx) ap_avail;


        function new(string name = "gcd_result_monitor", uvm_component parent = null);
            super.new(name, parent);
            ap_avail = new("ap_avail", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_mon)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_result_monitor")
        endfunction

        task run_phase(uvm_phase phase);
            gcd_result_tx tx;
            bit prev_valid = 0;
            

            wait (vif.rst_n === 1'b1);

            forever begin
                @(vif.cb_mon);

                if (vif.cb_mon.out_valid &&  !prev_valid ) begin
                    tx = gcd_result_tx::type_id::create("tx");
                    tx.gcd_out = vif.cb_mon.gcd_out;
                    ap_avail.write(tx);
                    `uvm_info("MON_val_out", tx.convert2string(), UVM_MEDIUM)
                end

                prev_valid = vif.cb_mon.out_valid;
            end
        endtask

    endclass

    class gcd_reset_monitor extends uvm_monitor;
        `uvm_component_utils(gcd_reset_monitor)

        virtual gcd_if.mp_mon vif;
        uvm_analysis_port #(bit) analysis_port;

        function new(string name = "gcd_reset_monitor", uvm_component parent = null);
            super.new(name, parent);
            analysis_port = new("analysis_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_mon)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_reset_monitor")
        endfunction

        task run_phase(uvm_phase phase);
            bit prev_rst = 1'b1;

            forever begin
                @(vif.cb_mon);

                if (prev_rst && !vif.rst_n) begin
                    analysis_port.write(1'b1);
                    `uvm_info("MON_RST", "reset asserted", UVM_MEDIUM)
                end

                prev_rst = vif.rst_n;
            end
        endtask

    endclass


    // ---- sequencers --------------------------------------------------------
    class gcd_in_sequencer extends uvm_sequencer #(gcd_in_tx);
        `uvm_component_utils(gcd_in_sequencer)
        function new(string name = "gcd_in_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class gcd_out_sequencer extends uvm_sequencer #(gcd_out_tx);
        `uvm_component_utils(gcd_out_sequencer)
        function new(string name = "gcd_out_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class gcd_rst_sequencer extends uvm_sequencer #(gcd_rst_tx);
        `uvm_component_utils(gcd_rst_sequencer)
        function new(string name = "gcd_rst_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass


    // ---- agents ------------------------------------------------------------
    class gcd_in_agent extends uvm_agent;
        `uvm_component_utils(gcd_in_agent)

        gcd_in_sequencer sqr ;
        gcd_in_driver drv;
        gcd_in_monitor mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = gcd_in_monitor::type_id::create("mon", this);
            sqr = gcd_in_sequencer::type_id::create("sqr", this);
            drv = gcd_in_driver   ::type_id::create("drv", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class gcd_out_agent extends uvm_agent;
        `uvm_component_utils(gcd_out_agent)

        gcd_out_sequencer sqr;
        gcd_out_driver    drv;
        gcd_result_monitor mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = gcd_result_monitor::type_id::create("mon", this);
            sqr = gcd_out_sequencer::type_id::create("sqr", this);
            drv = gcd_out_driver   ::type_id::create("drv", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    class gcd_rst_agent extends uvm_agent;
        `uvm_component_utils(gcd_rst_agent)

        gcd_rst_sequencer sqr;
        gcd_rst_driver    drv;
        gcd_reset_monitor mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = gcd_reset_monitor::type_id::create("mon", this);
            sqr = gcd_rst_sequencer::type_id::create("sqr", this);
            drv = gcd_rst_driver   ::type_id::create("drv", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE)
                drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass


    // ---- virtual sequencer + virtual sequence ------------------------------
    class gcd_virtual_sequencer extends uvm_sequencer;
        `uvm_component_utils(gcd_virtual_sequencer)

        gcd_in_sequencer  in_sqr;
        gcd_out_sequencer out_sqr;
        gcd_rst_sequencer rst_sqr;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class gcd_vseq_base extends uvm_sequence;
        `uvm_object_utils(gcd_vseq_base)
        `uvm_declare_p_sequencer(gcd_virtual_sequencer)

        function new(string name = "gcd_vseq_base");
            super.new(name);
        endfunction
    endclass

    class gcd_vseq_directed extends gcd_vseq_base;
        `uvm_object_utils(gcd_vseq_directed)

        dir_scenario_e scenario = ZERO;

        function new(string name = "gcd_vseq_directed");
            super.new(name);
        endfunction

        task body();
            gcd_out_seq_base out_seq;

            // output behaviour is derived from the scenario: only the
            // BACKPRESSURE scenario applies back-pressure; all others stay ready.
            if (scenario == BACKPRESSURE)
                out_seq = gcd_out_seq_backpressure::type_id::create("out_seq");
            else
                out_seq = gcd_out_seq_always_ready::type_id::create("out_seq");

            fork
                out_seq.start(p_sequencer.out_sqr);  // forever
                begin
                    if (scenario == RESET) run_reset();
                    else                   run_operands();
                end
            join_any
            disable fork;                            // kill the output thread
        endtask

        // operand scenarios: delegate to the directed input sequence
        task run_operands();
            gcd_in_seq_directed in_seq;
            in_seq = gcd_in_seq_directed::type_id::create("in_seq");
            in_seq.scenario = scenario;
            in_seq.start(p_sequencer.in_sqr);
        endtask

        // reset scenario (RQ-R01/R02): drive a tx that enters RUN, assert reset
        // mid-computation, then drive a fresh tx that must handshake right after
        // release. The aborted tx must produce no result (scoreboard drain).
        task run_reset();
            gcd_in_tx         in_item;
            gcd_rst_seq_pulse rst_seq;

            // 1. long-running transaction -> DUT enters RUN and stays there
            `uvm_do_on_with(in_item, p_sequencer.in_sqr,
                            { a_in == 100; b_in == 1; in_delay == 0; })

            // 2. assert reset while the DUT is mid-RUN (input driver is idle now)
            rst_seq = gcd_rst_seq_pulse::type_id::create("rst_seq");
            rst_seq.cycles = 2;
            rst_seq.start(p_sequencer.rst_sqr);

            // 3. fresh transaction on the first edge after release (RQ-R02)
            `uvm_do_on_with(in_item, p_sequencer.in_sqr,
                            { a_in == 6; b_in == 9; in_delay == 0; })
        endtask
    endclass

    class gcd_vseq_random extends gcd_vseq_base;
        `uvm_object_utils(gcd_vseq_random)

        int unsigned num_tx = 100;

        function new(string name = "gcd_vseq_random");
            super.new(name);
        endfunction

        task body();
            gcd_in_seq_random  in_seq;
            gcd_out_seq_random out_seq;

            in_seq  = gcd_in_seq_random ::type_id::create("in_seq");
            out_seq = gcd_out_seq_random::type_id::create("out_seq");
            in_seq.num_tx = num_tx;

            fork
                out_seq.start(p_sequencer.out_sqr);   // random back-pressure, forever
                in_seq.start (p_sequencer.in_sqr);    // num_tx random transactions
            join_any
            disable fork;
        endtask
    endclass


    // ---- scoreboard --------------------------------------------------------
    class gcd_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(gcd_scoreboard)

        uvm_analysis_imp_in    #(gcd_in_tx,     gcd_scoreboard) ap_in;
        uvm_analysis_imp_avail #(gcd_result_tx, gcd_scoreboard) ap_avail;
        uvm_analysis_imp_rst   #(bit,           gcd_scoreboard) ap_rst;

        bit pending;
        bit [WIDTH-1:0] expected;
        int unsigned expected_lat;
        time t_in;
        localparam int unsigned CLK_PERIOD = 10;

        int total_tests = 0;
        int failed_tests = 0;

        
        function new(string name = "gcd_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            ap_in = new("ap_in", this);
            ap_avail = new("ap_avail", this);
            ap_rst = new("ap_rst", this);
        endfunction

       
      
        function bit [WIDTH-1:0] gcd_ref(bit [WIDTH-1:0] a, b);
            while (b != 0) begin
                int temp;
                temp = b;
                b = a % b;
                a = temp;
            end
            return a;
        endfunction

        function int unsigned expected_latency(bit [WIDTH-1:0] a, b);
            bit [WIDTH-1:0] x, y;
            int unsigned n;
            if (a==0 || b==0 || a==b)
                return 1;
            x = a;
            y = b;
            n = 0;
            forever begin
                if (x > y) x = x - y;
                else       y = y - x;
                n++;
                if (x == y) break;
            end
            return 1 + n;
        endfunction


        function void write_in(gcd_in_tx tx);
            if (pending)
                `uvm_error("SCB", $sformatf("new input a=%0d b=%0d while previous result still pending", tx.a_in, tx.b_in))
            else begin
                expected = gcd_ref(tx.a_in, tx.b_in);
                expected_lat = expected_latency(tx.a_in, tx.b_in);
                t_in = $time;
                pending = 1;
            end
        endfunction

        function void write_avail(gcd_result_tx tx);
            int unsigned measured_lat;
            if (!pending) begin
                 `uvm_error("SCB", "result appeared with no pending input")
                return;
            end
            measured_lat = ($time - t_in) / CLK_PERIOD;
            total_tests++;
            if (tx.gcd_out !== expected) begin
                failed_tests++;
                `uvm_error("SCB", $sformatf("expected=%0d observed=%0d", expected, tx.gcd_out))
            end
            if (measured_lat != expected_lat) begin
                failed_tests++;
                `uvm_error("SCB", $sformatf("latency mismatch expected=%0d measured=%0d", expected_lat, measured_lat))
            end
            pending = 0;
        endfunction

        function void write_rst(bit r);
            pending  = 1'b0;
            expected = '0;
        endfunction

         function void report_phase(uvm_phase phase);
            `uvm_info("SCB", $sformatf("Read checks: total=%0d failed=%0d", total_tests, failed_tests), UVM_LOW)
        endfunction
    endclass


    // ---- coverage ----------------------------------------------------------
    class gcd_coverage extends uvm_subscriber #(gcd_in_tx);
        `uvm_component_utils(gcd_coverage)

        virtual gcd_if.mp_mon vif;

        localparam int unsigned VAL_MAX   = (1 << WIDTH) - 1;
        localparam int unsigned WIDTH_LOW = VAL_MAX / 3;
        localparam int unsigned WIDTH_HI  = (VAL_MAX * 2) / 3;

        covergroup gcd_cg;

        in_valid  : coverpoint vif.cb_mon.in_valid;
        out_ready : coverpoint vif.cb_mon.out_ready;
        in_ready  : coverpoint vif.cb_mon.in_ready;
        out_valid : coverpoint vif.cb_mon.out_valid;

        cross in_valid, in_ready{
            bins in_gcd_not_ready           =   binsof(in_valid) intersect {1} &&
                                                binsof(in_ready) intersect {0};
            bins in_input_not_valid         =   binsof(in_valid) intersect {0} &&
                                                binsof(in_ready) intersect {1};
            bins in_input_gcd_not_ready     =   binsof(in_valid) intersect {0} &&
                                                binsof(in_ready) intersect {0};
            bins in_hs_complet              =   binsof(in_valid) intersect {1} &&
                                                binsof(in_ready) intersect {1};
        }


         cross out_ready, out_valid{

            bins out_gcd_not_ready          =   binsof(out_ready) intersect {1} &&
                                                binsof(out_valid) intersect {0};
            bins out_taker_not_valid        =   binsof(out_ready) intersect {0} &&
                                                binsof(out_valid) intersect {1};
            bins out_taker_gcd_not_ready    =   binsof(out_ready) intersect {0} &&
                                                binsof(out_valid) intersect {0};
            bins out_hs_complet             =   binsof(out_ready) intersect {1} &&
                                                binsof(out_valid) intersect {1};
        }

        a_in : coverpoint vif.cb_mon.a_in {
            bins lower_bins = {[0:WIDTH_LOW]};
            bins mid_bins   = {[WIDTH_LOW+1:WIDTH_HI-1]};
            bins high_bins  = {[WIDTH_HI:VAL_MAX]};
            bins zero       = {0};
            bins one        = {1};
            bins max        = {VAL_MAX};
        }

        b_in : coverpoint vif.cb_mon.b_in {
            bins lower_bins = {[0:WIDTH_LOW]};
            bins mid_bins   = {[WIDTH_LOW+1:WIDTH_HI-1]};
            bins high_bins  = {[WIDTH_HI:VAL_MAX]};
            bins zero       = {0};
            bins one        = {1};
            bins max        = {VAL_MAX};
        }

        cross a_in, b_in {
            bins both_low     = binsof(a_in.lower_bins) && binsof(b_in.lower_bins);
            bins both_high    = binsof(a_in.high_bins)  && binsof(b_in.high_bins);
            bins a_low_b_high = binsof(a_in.lower_bins) && binsof(b_in.high_bins);
            bins a_high_b_low = binsof(a_in.high_bins)  && binsof(b_in.lower_bins);
            bins a_zero       = binsof(a_in.zero)       && !binsof(b_in.zero);
            bins b_zero       = !binsof(a_in.zero)      && binsof(b_in.zero);
            bins both_zero    = binsof(a_in.zero)       && binsof(b_in.zero);
        }

        gcd_out : coverpoint vif.cb_mon.gcd_out {
            bins lower_bins = {[0:WIDTH_LOW]};
            bins mid_bins   = {[WIDTH_LOW+1:WIDTH_HI-1]};
            bins high_bins  = {[WIDTH_HI:VAL_MAX]};
            bins zero       = {0};
            bins one        = {1};
            bins max        = {VAL_MAX};
        }

        a_eq_b : coverpoint (vif.cb_mon.a_in == vif.cb_mon.b_in) {
            bins equal     = {1};
            bins not_equal = {0};
        }

        fsm_state : coverpoint (vif.cb_mon.in_ready  ? 2'd0 :
                                vif.cb_mon.out_valid ? 2'd2 : 2'd1) {
            bins idle        = {2'd0};
            bins run         = {2'd1};
            bins done        = {2'd2};
            bins t_idle_run  = (2'd0 => 2'd1);
            bins t_idle_done = (2'd0 => 2'd2);
            bins t_run_done  = (2'd1 => 2'd2);
            bins t_done_idle = (2'd2 => 2'd0);
        }

        endgroup

        bit [1:0] reset_state_q;

        covergroup reset_cg;
            reset_state : coverpoint reset_state_q {
                bins during_idle = {2'd0};
                bins during_run  = {2'd1};
                bins during_done = {2'd2};
            }
        endgroup

        int unsigned stall_len = 0;

        covergroup bp_cg;
            bp_stall : coverpoint stall_len {
                bins none = {0};
                bins one  = {1};
                bins few  = {[2:3]};
                bins many = {[4:$]};
            }
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            gcd_cg   = new();
            reset_cg = new();
            bp_cg    = new();
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual gcd_if.mp_mon)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "Virtual interface not set for gcd_coverage")
        endfunction

        function void write(gcd_in_tx t);
        endfunction

        task run_phase(uvm_phase phase);
            bit prev_rst = 1'b1;
            forever begin
                @(vif.cb_mon);
                gcd_cg.sample();

                if (vif.cb_mon.out_valid && vif.cb_mon.out_ready) begin
                    bp_cg.sample();
                    stall_len = 0;
                end else if (vif.cb_mon.out_valid && !vif.cb_mon.out_ready) begin
                    stall_len++;
                end else begin
                    stall_len = 0;
                end

                if (prev_rst && !vif.rst_n) begin
                    if      (vif.cb_mon.in_ready)  reset_state_q = 2'd0;
                    else if (vif.cb_mon.out_valid) reset_state_q = 2'd2;
                    else                           reset_state_q = 2'd1;
                    reset_cg.sample();
                end
                prev_rst = vif.rst_n;
            end
        endtask



        
    endclass


    // ---- env ---------------------------------------------------------------
    class gcd_env extends uvm_env;
        `uvm_component_utils(gcd_env)

        gcd_in_agent          in_agent;
        gcd_out_agent         out_agent;
        gcd_rst_agent         rst_agent;
        gcd_virtual_sequencer v_sqr;
        gcd_scoreboard        sb;
        gcd_coverage          cov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            in_agent  = gcd_in_agent         ::type_id::create("in_agent",  this);
            out_agent = gcd_out_agent        ::type_id::create("out_agent", this);
            rst_agent = gcd_rst_agent        ::type_id::create("rst_agent", this);
            v_sqr     = gcd_virtual_sequencer::type_id::create("v_sqr",     this);
            sb        = gcd_scoreboard       ::type_id::create("sb",        this);
            cov       = gcd_coverage         ::type_id::create("cov",       this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);

            v_sqr.in_sqr  = in_agent.sqr;
            v_sqr.out_sqr = out_agent.sqr;
            v_sqr.rst_sqr = rst_agent.sqr;

            in_agent.mon.analysis_port.connect(sb.ap_in);
            out_agent.mon.ap_avail.connect(sb.ap_avail);
            rst_agent.mon.analysis_port.connect(sb.ap_rst);

            in_agent.mon.analysis_port.connect(cov.analysis_export);
        endfunction
    endclass


    // ---- tests -------------------------------------------------------------
    class gcd_test_base extends uvm_test;
        `uvm_component_utils(gcd_test_base)

        gcd_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = gcd_env::type_id::create("env", this);
        endfunction
    endclass

    class gcd_test_smoke extends gcd_test_base;
        `uvm_component_utils(gcd_test_smoke)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // map a +SCENARIO string to the enum
        function dir_scenario_e str2scn(string s);
            case (s)
                "zero":         return ZERO;
                "back_to_back": return BACK_TO_BACK;
                default: `uvm_fatal(get_type_name(),
                            $sformatf("unknown +SCENARIO=%s", s))
            endcase
        endfunction

        task run_one(dir_scenario_e scn);
            gcd_vseq_directed vseq;
            vseq = gcd_vseq_directed::type_id::create("vseq");
            vseq.scenario = scn;   // output behaviour is derived from the scenario
            vseq.start(env.v_sqr);
        endtask

        task run_phase(uvm_phase phase);
            string         scn_str;
            dir_scenario_e scn;

            phase.raise_objection(this);

            if ($value$plusargs("SCENARIO=%s", scn_str)) begin
                // run just the requested scenario
                run_one(str2scn(scn_str));
            end
            else begin
                run_one(ZERO);
                run_one(BACK_TO_BACK);
            end

            phase.drop_objection(this);
        endtask
    endclass

    class gcd_test_directed extends gcd_test_base;
        `uvm_component_utils(gcd_test_directed)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // map a +SCENARIO string to the enum
        function dir_scenario_e str2scn(string s);
            case (s)
                "zero":         return ZERO;
                "equal":        return EQUAL;
                "max":          return MAX;
                "coprime":      return COPRIME;
                "pow2":         return POW2;
                "back_to_back": return BACK_TO_BACK;
                "backpressure": return BACKPRESSURE;
                "reset":        return RESET;
                default: `uvm_fatal(get_type_name(),
                            $sformatf("unknown +SCENARIO=%s", s))
            endcase
        endfunction

        task run_one(dir_scenario_e scn);
            gcd_vseq_directed vseq;
            vseq = gcd_vseq_directed::type_id::create("vseq");
            vseq.scenario = scn;   // output behaviour is derived from the scenario
            vseq.start(env.v_sqr);
        endtask

        task run_phase(uvm_phase phase);
            string         scn_str;
            dir_scenario_e scn;

            phase.raise_objection(this);

            if ($value$plusargs("SCENARIO=%s", scn_str)) begin
                // run just the requested scenario
                run_one(str2scn(scn_str));
            end
            else begin
                // run every scenario in a row
                scn = scn.first();
                for (int i = 0; i < scn.num(); i++) begin
                    run_one(scn);
                    scn = scn.next();
                end
            end

            phase.drop_objection(this);
        endtask
    endclass

    class gcd_test_random extends gcd_test_base;
        `uvm_component_utils(gcd_test_random)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            gcd_vseq_random vseq;
            int unsigned     n;

            if (!$value$plusargs("NUM_TX=%d", n))
                n = 100;

            phase.raise_objection(this);
            vseq = gcd_vseq_random::type_id::create("vseq");
            vseq.num_tx = n;
            vseq.start(env.v_sqr);
            phase.drop_objection(this);
        endtask
    endclass

endpackage : gcd_pkg




// =============================================================================
// INTERFACE
// ================================ =============================================
interface gcd_if #(parameter int unsigned WIDTH = `TB_WIDTH)
                 (input logic clk);
    logic                 rst_n = 1'b0;   // interface-owned, driven by the reset
                                          // agent; starts asserted (DUT in reset)
    logic                 in_valid;
    logic                 in_ready;
    logic [WIDTH-1:0]     a_in;
    logic [WIDTH-1:0]     b_in;
    logic                 out_valid;
    logic                 out_ready;
    logic [WIDTH-1:0]     gcd_out;

    // input agent: drives in_valid/a_in/b_in, samples in_ready
    clocking cb_in @(posedge clk);
        default input #1step output #0;
        output in_valid, a_in, b_in;
        input  in_ready;
    endclocking

    // output agent: drives out_ready, samples out_valid/gcd_out
    clocking cb_out @(posedge clk);
        default input #1step output #0;
        output out_ready;
        input  out_valid, gcd_out;
    endclocking

    // monitor: samples every signal, drives nothing
    clocking cb_mon @(posedge clk);
        default input #1step;
        input in_valid, in_ready, a_in, b_in, out_valid, out_ready, gcd_out;
    endclocking

    // reset agent: drives rst_n
    clocking cb_rst @(posedge clk);
        default output #0;
        output rst_n;
    endclocking

    modport mp_in  (clocking cb_in,  input clk, rst_n);
    modport mp_out (clocking cb_out, input clk, rst_n);
    modport mp_mon (clocking cb_mon, input clk, rst_n);
    modport mp_rst (clocking cb_rst, input clk);


endinterface : gcd_if


// =============================================================================
// ASSERTIONS module (bound to DUT)
// =============================================================================
module gcd_assertions #(parameter int unsigned WIDTH = `TB_WIDTH) (
    input logic              clk,
    input logic              rst_n,
    input logic              in_valid,
    input logic              in_ready,
    input logic [WIDTH-1:0]  a_in,
    input logic [WIDTH-1:0]  b_in,
    input logic              out_valid,
    input logic              out_ready,
    input logic [WIDTH-1:0]  gcd_out,
    input logic [1:0]        state,
    input logic [WIDTH-1:0]  a_reg,
    input logic [WIDTH-1:0]  b_reg,
    input logic [WIDTH-1:0]  result_reg,
    input logic [WIDTH-1:0]  a_next,
    input logic [WIDTH-1:0]  b_next
);

    localparam logic [1:0] IDLE = 2'd0;
    localparam logic [1:0] RUN  = 2'd1;
    localparam logic [1:0] DONE = 2'd2;

    

    A_RST_CLEAR : assert property (
      @(posedge clk)
      !rst_n |=> (state == IDLE) && (result_reg == 0) && (gcd_out == 0) && (out_valid == 0)
    ) else $error("reset didnt clear dut state ");

    A_RST_READY : assert property (
      @(posedge clk)
      $rose(rst_n) |-> in_ready
    ) else $error("module not ready on first edge after reset release");

    A_STATE_LEGAL : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      state inside {IDLE, RUN, DONE}
    ) else $error("DUT in illegale internal state");

    A_EARLY_EXIT : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (a_in==0 || b_in == 0 || a_in==b_in ) && (in_valid && in_ready) |-> (state == DONE) && out_valid
    ) else $error("early exit transition not respected");

     A_GENERAL_RUN : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (a_in!==0 && b_in !== 0 && a_in!==b_in ) && (in_valid && in_ready) |=> (state == RUN)
    ) else $error("DUT not transitioning to RUN state on valid input");


     A_RUN_CONVERGE : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (a_next==b_next && state==RUN) |=> (state == DONE)
    ) else $error("DUT state not transitioning to done on a b convergence");

    A_DONE_IDLE : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (state == DONE ) && (out_valid && out_ready) |=> (state == IDLE)
    ) else $error("DUT state not transitioning to IDLE after out handshake");


    A_INRDY_IDLE : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      in_ready == (state == IDLE)
    ) else $error("State not idle when in ready / in_ready not asserted when state IDLE");

    A_OUTVLD_DONE : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      out_valid == (state == DONE)
    ) else $error("State not DONE when out_valid  / out_valid not asserted when state DONE");


    A_RESULT_REG : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      out_valid |-> (result_reg == gcd_out)
    ) else $error("result register doesnt hold gcd_out value");

    A_IN_STABLE : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (!in_ready && in_valid) |=> (a_in == $past(a_in)) && (b_in == $past(b_in))
    ) else $error("a_in/ b_in not stable when stalled (input error not DUT)");

    A_INVLD_HELD : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (!in_ready && in_valid) |=> in_valid
    ) else $error("in_valid not held when waiting for handshake completion (input error not DUT)");

    A_OUT_STABLE : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (out_valid && !out_ready) |=> (gcd_out == $past(gcd_out))
    ) else $error("gcd_out not stable while waiting for out_ready");

    A_OUTVLD_HELD : assert property (
      @(posedge clk)
      disable iff (!rst_n)
      (out_valid && !out_ready) |=> out_valid
    ) else $error("out_ valid not stable while waiting for out_ready");





endmodule : gcd_assertions


bind gcd gcd_assertions u_gcd_asserts (.*);


// =============================================================================
// TOP module
// =============================================================================
module top;
    import uvm_pkg::*;
    import gcd_pkg::*;
    `include "uvm_macros.svh"

    logic clk;

    gcd_if #(.WIDTH(WIDTH)) vif(clk);

    gcd #(.WIDTH(WIDTH)) dut (
        .clk      (clk),
        .rst_n    (vif.rst_n),
        .in_valid (vif.in_valid),
        .in_ready (vif.in_ready),
        .a_in     (vif.a_in),
        .b_in     (vif.b_in),
        .out_valid(vif.out_valid),
        .out_ready(vif.out_ready),
        .gcd_out  (vif.gcd_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        uvm_config_db#(virtual gcd_if.mp_in )::set(null, "uvm_test_top.env.in_agent.drv",  "vif", vif.mp_in );
        uvm_config_db#(virtual gcd_if.mp_out)::set(null, "uvm_test_top.env.out_agent.drv", "vif", vif.mp_out);
        uvm_config_db#(virtual gcd_if.mp_rst)::set(null, "uvm_test_top.env.rst_agent.drv", "vif", vif.mp_rst);
        uvm_config_db#(virtual gcd_if.mp_mon)::set(null, "uvm_test_top.env.*.mon",         "vif", vif.mp_mon);
        uvm_config_db#(virtual gcd_if.mp_mon)::set(null, "uvm_test_top.env.cov",           "vif", vif.mp_mon);
        run_test();
    end
endmodule : top
