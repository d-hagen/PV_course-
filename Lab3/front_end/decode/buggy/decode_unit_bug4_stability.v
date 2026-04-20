// BUG 4: Fields overwritten during stall → triggers assertion #4 (field stability)
module decode_unit #(
    parameter REG_COUNT = 16
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        instr_valid,
    input  wire [15:0] instr,
    output reg         decode_done,
    output reg  [3:0]  opcode,
    output reg  [3:0]  rd,
    output reg  [3:0]  rs,
    output reg  [3:0]  imm,
    output reg         hazard_stall
);

    reg [1:0] decode_counter;
    reg [3:0] last_rd;
    wire      hazard_stall_next;

    assign hazard_stall_next = (last_rd == instr[7:4]) && instr_valid;

    always @(posedge clk) begin
        if (!rst_n) begin
            decode_done    <= 1'b0;
            hazard_stall   <= 1'b0;
            decode_counter <= 2'b00;
            opcode         <= 4'h0;
            rd             <= 4'h0;
            rs             <= 4'h0;
            imm            <= 4'h0;
            last_rd        <= 4'h0;
        end else begin
            decode_done <= 1'b0;
            hazard_stall <= hazard_stall_next;

            // BUG: captures fields even during stall (removed !hazard_stall_next guard)
            if (instr_valid) begin
                decode_counter <= 2'b10;
                opcode         <= instr[15:12];
                rd             <= instr[11:8];
                rs             <= instr[7:4];
                imm            <= instr[3:0];
                last_rd        <= instr[11:8];
            end

            if (decode_counter != 0 && !hazard_stall) begin
                decode_counter <= decode_counter - 1;
                if (decode_counter == 1)
                    decode_done <= 1'b1;
            end
        end
    end

endmodule
