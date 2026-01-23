module filter_by_substring(
    input [7:0] strings [0:3],
    input [7:0] substring [0:3],
    input [2:0] substring_len,
    output [3:0] mask
);

    reg [3:0] mask_reg;
    integer i, j, k;
    reg match;

    always @(*) begin
        mask_reg = 4'b0;
        
        if (substring_len == 3'b0) begin
            mask_reg = 4'b0;
        end else begin
            for (i = 0; i < 4; i = i + 1) begin
                match = 1'b0;
                for (j = 0; j <= 8 - substring_len; j = j + 1) begin
                    match = 1'b1;
                    for (k = 0; k < substring_len; k = k + 1) begin
                        if (strings[i][j + k] != substring[k]) begin
                            match = 1'b0;
                        end
                    end
                    if (match) begin
                        mask_reg[i] = 1'b1;
                    end
                end
            end
        end
    end

    assign mask = mask_reg;

endmodule