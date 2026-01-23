module minesweeper_safe(
    input [2:0] n,
    output [3:0] count,
    output [15:0] safe_mask
);

    // For n=1: 8 cells (all corners), safe=0
    // For n=2: 12 cells, safe=0 (all corners)
    // For n=3: 16 cells, even indices are safe
    // Indices are 1-based. safe_mask bit i corresponds to cell i+1.
    
    // Initialize to avoid latches
    reg [15:0] mask_temp;
    reg [3:0] cnt_temp;

    always @(*) begin
        case (n)
            3'd1, 3'd2: begin
                // n=1: 8 cells, corners
                // n=2: 12 cells, corners
                mask_temp = 16'h0000;
                cnt_temp = 4'd0;
            end
            3'd3: begin
                // n=3: 16 cells, even indices 2,4,...,16 are safe
                // Bits: 1,2,3,4... -> 0,1,2,3...
                // Even 1-based indices correspond to odd 0-based bit positions (1,3,5,7,9,11,13,15)
                // Wait, cell 2 is index 1. Cell 16 is index 15.
                // Pattern is 1010... -> 0xAAAA
                mask_temp = 16'hAAAA;
                cnt_temp = 4'd8;
            end
            default: begin
                // Handle other cases (0, 4-7) as safe=0
                mask_temp = 16'h0000;
                cnt_temp = 4'd0;
            end
        endcase
    end

    assign safe_mask = mask_temp;
    assign count = cnt_temp;

endmodule