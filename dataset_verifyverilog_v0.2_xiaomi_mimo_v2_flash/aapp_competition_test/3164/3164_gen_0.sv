module find_max_even_pairs(
    input [7:0] n_i,
    input [7:0][7:0] arr_i,
    output reg [7:0] max_length
);

    integer i, j, k, idx;
    reg [7:0] length;
    reg valid;
    reg [7:0] count [0:255];
    reg [7:0] val;
    
    always @(*) begin
        max_length = 8'd0;
        
        // Handle edge case for n_i = 0
        if (n_i == 8'd0) begin
            max_length = 8'd0;
            return;
        end
        
        // Iterate through all possible start indices
        for (i = 0; i < n_i; i = i + 1) begin
            // Iterate through all possible end indices
            for (j = i; j < n_i; j = j + 1) begin
                length = j - i + 1;
                
                // Only check lengths that can potentially improve max_length
                if (length <= max_length) begin
                    continue;
                end
                
                // Initialize count array for current sub-array
                for (k = 0; k < 256; k = k + 1) begin
                    count[k] = 8'd0;
                end
                
                // Count frequencies in sub-array [i, j]
                for (k = i; k <= j; k = k + 1) begin
                    val = arr_i[k];
                    count[val] = count[val] + 1;
                end
                
                // Check if all frequencies are exactly 2
                valid = 1'b1;
                for (k = i; k <= j; k = k + 1) begin
                    val = arr_i[k];
                    if (count[val] != 8'd2) begin
                        valid = 1'b0;
                        break;
                    end
                end
                
                // If valid, update max_length
                if (valid) begin
                    max_length = length;
                end
            end
        end
    end

endmodule
}