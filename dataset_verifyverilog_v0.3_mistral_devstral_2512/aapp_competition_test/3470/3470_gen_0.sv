module minesweeper_safe #(
    parameter MAX_N = 1000,
    parameter MAX_REDS = 4*MAX_N + 4  // 4004 for MAX_N=1000
)(
    input wire [9:0] n,                // n in range 1..1000
    output wire [MAX_REDS-1:0] safe_mask, // one-hot mask of safe cells
    output wire [11:0] safe_count      // number of safe cells
);

// Combinational logic to compute safe_mask and safe_count
integer i;
reg [MAX_REDS-1:0] mask_reg;
reg [11:0] count_reg;

always @(*) begin
    mask_reg = 0;
    count_reg = 0;
    if (n == 1) begin
        mask_reg = 0;
        count_reg = 0;
    end else begin
        // Iterate over all red cell indices (0-based)
        for (i = 0; i < 4*n + 4; i = i + 1) begin
            // Cell number = i+1
            if (((i+1) & 1) == (n & 1)) begin
                mask_reg[i] = 1;
                count_reg = count_reg + 1;
            end
        end
    end
end

assign safe_mask = mask_reg;
assign safe_count = count_reg;

endmodule