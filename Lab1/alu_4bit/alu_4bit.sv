module alu_4bit (
    input  [2:0] op,
    input  [3:0] A,
    input  [3:0] B,
    output reg [3:0] Y,
    output reg       carry
);

    always @(*) begin
        case (op)
            3'b000: {carry, Y} = A + B;
            3'b001: {carry, Y} = A - B;
            3'b010: {carry, Y} = {1'b0, A & B};
            3'b011: {carry, Y} = {1'b0, A | B};
            3'b100: {carry, Y} = {1'b0, A ^ B};
            3'b101: {carry, Y} = {1'b0, ~A};
            3'b110: {carry, Y} = {1'b0, A};
            3'b111: {carry, Y} = {1'b0, B};
            default: {carry, Y} = 5'b00000;
        endcase
    end

endmodule
