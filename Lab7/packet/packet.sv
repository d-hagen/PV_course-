module packet (
    input  wire clk,
    input  wire reset,
    input  wire start_pkt,
    input  wire hdr_done,
    input  wire payload_done,
    input  wire chk_ok,
    input  wire chk_fail,
    input  wire abort,
    output reg  valid_pkt,
    output reg  error_pkt,
    output reg [2:0] state
);

    // State encoding
    localparam IDLE     = 3'd0;
    localparam HEADER   = 3'd1;
    localparam PAYLOAD  = 3'd2;
    localparam CHECKSUM = 3'd3;
    localparam DONE     = 3'd4;

    always @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            valid_pkt <= 0;
            error_pkt <= 0;
        end else begin
            valid_pkt <= 0;
            error_pkt <= 0;
            if (abort) begin
                state <= IDLE;
            end else begin
                case (state)
                    IDLE:    if (start_pkt) state <= HEADER;
                    HEADER:  if (hdr_done)  state <= PAYLOAD;
                    PAYLOAD: if (payload_done) state <= CHECKSUM;
                    CHECKSUM: begin
                        if (chk_ok) begin
                            state     <= DONE;
                            valid_pkt <= 1;
                        end else if (chk_fail) begin
                            state     <= IDLE;
                            error_pkt <= 1;
                        end
                    end
                    DONE:    state <= IDLE;
                    default: state <= IDLE;
                endcase
            end
        end
    end

    // FORMAL STATEMENTS BELOW --------------------------------
    //

    `ifdef FORMAL

        initial assume(reset);


        always @(posedge clk) if (reset) assume(state == IDLE);

        // Track if we are past the first cycle
        logic past_valid;
        always @(posedge clk) past_valid <= 1'b1;


        assume property (@(posedge clk)
            !(chk_ok && chk_fail));



        //STate transistions 

        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && ($past(start_pkt) &&  $past(state) == IDLE)
                |-> state == HEADER);
        
        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && ($past(hdr_done) &&  $past(state) == HEADER)
                |-> state == PAYLOAD);

        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && ($past(payload_done) &&  $past(state) == PAYLOAD)
                |-> state == CHECKSUM);

        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && ($past(chk_ok) &&  $past(state) == CHECKSUM)
                |-> (state == DONE && valid_pkt));

        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && ($past(chk_fail) &&  $past(state) == CHECKSUM)
                |-> (state == IDLE && error_pkt));


        assert property (@(posedge clk) disable iff (reset)
            $past(state) == DONE
                |-> state == IDLE);


        assert property (@(posedge clk)
            $past(reset || abort) |-> state == IDLE);


        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && (!$past(start_pkt) &&  $past(state) == IDLE)
                |-> state == IDLE);
        
        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && (!$past(hdr_done) &&  $past(state) == HEADER)
                |-> state == HEADER);

        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && (!$past(payload_done) &&  $past(state) == PAYLOAD)
                |-> state == PAYLOAD);

        assert property (@(posedge clk) disable iff (reset)
            past_valid && !$past(reset || abort) && !$past(chk_ok) && !$past(chk_fail) && $past(state) == CHECKSUM
                |-> (state == CHECKSUM));



        assert property (@(posedge clk) disable iff (reset)
            !(valid_pkt && error_pkt));

        assert property (@(posedge clk) disable iff (reset)
            valid_pkt |-> $past(state) == CHECKSUM && $past(chk_ok) && !$past(abort));

        assert property (@(posedge clk) disable iff (reset)
            error_pkt |-> $past(state) == CHECKSUM && $past(chk_fail) && !$past(chk_ok) && !$past(abort));

        assert property (@(posedge clk)
            $past(reset) |-> !valid_pkt && !error_pkt);

    `endif

endmodule