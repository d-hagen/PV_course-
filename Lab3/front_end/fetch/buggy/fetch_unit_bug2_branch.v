// BUG 2: Branch doesn't take priority over pc_en → triggers assertion #2 (branch priority)
module fetch_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_en,
    input  wire        branch_en,
    input  wire [7:0]  branch_addr,
    output reg  [15:0] instr
);

    reg [7:0] pc;
    reg [7:0] next_pc;
    reg [15:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = i;
    end

    always @* begin
        if (pc_en)                // BUG: pc_en checked first, branch no longer has priority
            next_pc = pc + 2;
        else if (branch_en)
            next_pc = branch_addr;
        else
            next_pc = pc;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            pc    <= 8'h00;
            instr <= mem[8'h00];
        end else begin
            pc    <= next_pc;
            instr <= mem[next_pc];
        end
    end

endmodule
