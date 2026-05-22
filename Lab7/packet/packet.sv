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

`endif

endmodule