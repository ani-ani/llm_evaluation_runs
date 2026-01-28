module pairs_sum_to_zero(
    input [7:0] data_in [0:7],
    input [2:0] length,
    output reg result
);
    // Internal signals for signed comparison
    reg found_pair;
    integer i, j;
    
    always @(*) begin
        found_pair = 1'b0;
        
        // Iterate through all pairs
        for (i = 0; i < 8; i = i + 1) begin
            for (j = i + 1; j < 8; j = j + 1) begin
                // Check if both indices are within valid range
                if ((i < length) && (j < length)) begin
                    // Check if sum equals zero (signed addition)
                    if (data_in[i] + data_in[j] == 8'sd0) begin
                        found_pair = 1'b1;
                    end
                end
            end
        end
        
        result = found_pair;
    end
endmodule