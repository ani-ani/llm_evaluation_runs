module LongestSubsequence (
    input [31:0] A [0:7],
    input [31:0] S,
    output reg [3:0] result [0:7]
);
    
    // Prefix sum array: prefix[0] = 0, prefix[j+1] = prefix[j] + A[j]
    wire [31:0] prefix [0:8];
    assign prefix[0] = 32'd0;
    
    // Generate prefix sums
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : prefix_gen
            assign prefix[j + 1] = prefix[j] + A[j];
        end
    endgenerate
    
    // Generate result logic for each index i
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : result_block
            // Calculate K_max for this i
            localparam integer Kmax = (8 - i) / 2;
            
            always_comb begin
                // Default result
                result[i] = 4'd0;
                
                // Check K values in descending order (largest first)
                if (Kmax >= 4) begin
                    if ((prefix[i + 4] - prefix[i] <= S) && (prefix[i + 8] - prefix[i + 4] <= S)) begin
                        result[i] = 4'd8;
                    end
                end
                if (result[i] == 0) begin
                    if (Kmax >= 3) begin
                        if ((prefix[i + 3] - prefix[i] <= S) && (prefix[i + 6] - prefix[i + 3] <= S)) begin
                            result[i] = 4'd6;
                        end
                    end
                end
                if (result[i] == 0) begin
                    if (Kmax >= 2) begin
                        if ((prefix[i + 2] - prefix[i] <= S) && (prefix[i + 4] - prefix[i + 2] <= S)) begin
                            result[i] = 4'd4;
                        end
                    end
                end
                if (result[i] == 0) begin
                    if (Kmax >= 1) begin
                        if ((prefix[i + 1] - prefix[i] <= S) && (prefix[i + 2] - prefix[i + 1] <= S)) begin
                            result[i] = 4'd2;
                        end
                    end
                end
            end
        end
    endgenerate
endmodule