module positive_ratio (
    input [7:0] data_in,
    input [2:0] index,
    input valid,
    output reg [31:0] result,
    output reg result_valid
);

    reg [3:0] count;
    
    always @(*) begin
        // Default values
        result = 32'b0;
        result_valid = 1'b0;
        
        // Accumulate count based on index and validity
        if (valid) begin
            if (data_in > 8'sd0) begin
                count = 4'd1;
            end else begin
                count = 4'd0;
            end
            
            // Calculate result at last index (7)
            if (index == 3'd7) begin
                // For Q16.16: result = (count / 8) * 65536
                // Which simplifies to: count * 8192 = count << 13
                result = {16'b0, count, 13'b0}; // count << 13
                result_valid = 1'b1;
            end
        end
    end

endmodule
