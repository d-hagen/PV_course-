`timescale 1ns/1ps
`include "alu_4bit"

module alu_compare_4bit (
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


module alu_4bit_tb;

    reg  [2:0] _op;
    reg  [3:0] _A;
    reg  [3:0] _B;

    wire [3:0] _Y;
    wire       _carry;

    wire [3:0] _Y_cmp;
    wire       _carry_cmp;

    integer op_i, a, b;
    integer i;
    integer errors;

    integer y_mismatch      [0:7];
    integer carry_mismatch  [0:7];
    integer joined_mismatch [0:7];

    reg [63:0] op_name;

    alu_4bit dut (
        .A(_A),
        .B(_B),
        .op(_op),
        .Y(_Y),
        .carry(_carry)
    );

    alu_compare_4bit ref_model (
        .A(_A),
        .B(_B),
        .op(_op),
        .Y(_Y_cmp),
        .carry(_carry_cmp)
    );

    initial begin
        $dumpfile("alu_4bit.vcd");
        $dumpvars(0, alu_4bit_tb);

        errors = 0;

        for (i = 0; i < 8; i = i + 1) begin
            y_mismatch[i]      = 0;
            carry_mismatch[i]  = 0;
            joined_mismatch[i] = 0;
        end

        for (op_i = 0; op_i < 8; op_i = op_i + 1) begin
            case (op_i)
                0: op_name = "ADD";
                1: op_name = "SUB";
                2: op_name = "AND";
                3: op_name = "OR";
                4: op_name = "XOR";
                5: op_name = "NOT A";
                6: op_name = "PASS A";
                7: op_name = "PASS B";
            endcase

            $display("\n-------- %s (%03b) --------", op_name, op_i[2:0]);

            // Pass 1: print all FAILs
            for (a = 0; a < 16; a = a + 1) begin
                for (b = 0; b < 16; b = b + 1) begin
                    _op = op_i[2:0];
                    _A  = a[3:0];
                    _B  = b[3:0];

                    #1;

                    if ((_Y !== _Y_cmp) || (_carry !== _carry_cmp)) begin
                        errors = errors + 1;

                        if ((_Y !== _Y_cmp) && (_carry !== _carry_cmp)) begin
                            joined_mismatch[op_i] = joined_mismatch[op_i] + 1;
                            $display("FAIL (Y+carry) A=%b B=%b -> DUT: Y=%b carry=%b  Ref: Y=%b carry=%b",
                                     _A, _B, _Y, _carry, _Y_cmp, _carry_cmp);
                        end
                        else if (_Y !== _Y_cmp) begin
                            y_mismatch[op_i] = y_mismatch[op_i] + 1;
                            $display("FAIL (Y only)  A=%b B=%b -> DUT: Y=%b          Ref: Y=%b",
                                     _A, _B, _Y, _Y_cmp);
                        end
                        else begin
                            carry_mismatch[op_i] = carry_mismatch[op_i] + 1;
                            $display("FAIL (carry)   A=%b B=%b -> DUT: carry=%b      Ref: carry=%b  Y=%b",
                                     _A, _B, _carry, _carry_cmp, _Y);
                        end
                    end
                end
            end

            // Pass 2: if this opcode had errors, print all PASSes
            if (y_mismatch[op_i] + carry_mismatch[op_i] + joined_mismatch[op_i] > 0) begin
                $display("--- Correct combinations ---");
                for (a = 0; a < 16; a = a + 1) begin
                    for (b = 0; b < 16; b = b + 1) begin
                        _op = op_i[2:0];
                        _A  = a[3:0];
                        _B  = b[3:0];

                        #1;

                        if ((_Y === _Y_cmp) && (_carry === _carry_cmp)) begin
                            $display("PASS           A=%b B=%b -> Y=%b carry=%b",
                                     _A, _B, _Y, _carry);
                        end
                    end
                end
            end
        end

        if (errors == 0) begin
            $display("All combinations matched.");
        end
        else begin
            $display("\n================ FINAL SUMMARY ================\n");

            for (i = 0; i < 8; i = i + 1) begin
                case (i)
                    0: op_name = "Add";
                    1: op_name = "Sub";
                    2: op_name = "AND";
                    3: op_name = "OR";
                    4: op_name = "XOR";
                    5: op_name = "NOT A";
                    6: op_name = "PASS A";
                    7: op_name = "PASS B";
                endcase

                $display("%s (%03b) :", op_name, i[2:0]);
                $display("Y mismatch      : %0d", y_mismatch[i]);
                $display("Carry mismatch  : %0d", carry_mismatch[i]);
                $display("Joined mismatch : %0d\n", joined_mismatch[i]);
            end

            $display("Total mismatches: %0d", errors);
        end

        $finish;
    end

endmodule