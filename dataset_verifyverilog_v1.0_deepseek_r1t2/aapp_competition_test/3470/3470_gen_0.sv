module minesweeper_safe #(
    parameter MAX_N = 1000,
    parameter MAX_REDS = 4*MAX_N + 4
)(
    input wire [9:0] n,
    output wire [MAX_REDS-1:0] safe_mask,
    output wire [11:0] safe_count
);

reg [MAX_REDS-1:0] mask_reg;
reg [11:0] count_reg;

integer i;
always @(*) begin
    mask_reg = {MAX_REDS{1'b0}};
    count_reg = 12'd0;
    if (n == 10'd1) begin
        // No safe cells when n=1
        mask_reg = {MAX_REDS{1'b0}};
        count_reg = 12'd0;
    end else begin
        for (i = 0; i < (4 * n + 4); i = i + 1) begin
            if ((i+1) % 2 == n[0]) begin
                mask_reg[i] = 1'b1;
                count_reg = count_reg + 12'd1;
            end
        end
    end
end

assign safe_mask = mask_reg;
assign safe_count = count_reg;

endmodule