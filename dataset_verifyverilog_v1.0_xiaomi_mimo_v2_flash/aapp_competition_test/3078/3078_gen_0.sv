module longest_interesting_subsequence (
    input [31:0] A [0:7],
    input [31:0] S,
    output reg [3:0] result [0:7]
);
    // Parameters
    localparam N = 8;
    localparam DATA_WIDTH = 32;
    localparam RESULT_WIDTH = 4;
    
    // Combinational logic for prefix sums
    reg [DATA_WIDTH-1:0] prefix [0:N]; // prefix[0] = 0, prefix[i] = sum of A[0..i-1]
    integer i, j, k;
    reg [DATA_WIDTH-1:0] sum1, sum2;
    reg valid;
    
    always @(*) begin
        // Compute prefix sums
        prefix[0] = 32'd0;
        for (i = 0; i < N; i = i + 1) begin
            prefix[i+1] = prefix[i] + A[i];
        end
        
        // For each starting index i
        for (i = 0; i < N; i = i + 1) begin
            result[i] = 4'd0;
            // Kmax = floor((N-i)/2)
            // We need to find largest K where 1 <= K <= Kmax
            // Iterate K from largest to smallest
            for (k = ((N - i) >> 1); k >= 1; k = k - 1) begin
                // Check if this K is valid
                // sum1 = sum(A[i .. i+K-1]) = prefix[i+K] - prefix[i]
                // sum2 = sum(A[i+K .. i+2K-1]) = prefix[i+2K] - prefix[i+K]
                sum1 = prefix[i + k] - prefix[i];
                sum2 = prefix[i + 2*k] - prefix[i + k];
                valid = (sum1 <= S) && (sum2 <= S);
                
                // If valid, set result and break (using flag)
                if (valid) begin
                    result[i] = k[3:0] << 1; // 2*K
                    break; // Exit inner loop for this i
                end
            end
        end
    end
endmodule