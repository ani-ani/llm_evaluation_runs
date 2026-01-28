module minesweeper_safe (
    input wire [9:0] n,
    output reg [4003:0] safe_mask,
    output reg [11:0] safe_count
);

    integer i;
    reg [11:0] count_temp;
    reg [4003:0] mask_temp;

    always @(*) begin
        mask_temp = 4004'd0;
        count_temp = 12'd0;
        
        if (n == 10'd1) begin
            mask_temp = 4004'd0;
            count_temp = 12'd0;
        end else begin
            for (i = 0; i < 4004; i = i + 1) begin
                if (i < 4 * n + 4) begin
                    if (((i + 1) & 1) == (n & 1)) begin
                        mask_temp[i] = 1'b1;
                        count_temp = count_temp + 12'd1;
                    end
                end
            end
        end
        
        safe_mask = mask_temp;
        safe_count = count_temp;
    end

endmodule