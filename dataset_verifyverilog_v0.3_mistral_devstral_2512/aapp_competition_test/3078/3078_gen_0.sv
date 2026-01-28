module LongestInterestingSubsequence(
    input [31:0] A [0:7],
    input [31:0] S,
    output [3:0] result [0:7]
);

    // Compute prefix sums
    wire [31:0] prefix [0:8];
    assign prefix[0] = 32'd0;
    genvar j;
    generate
        for (j = 0; j < 8; j = j + 1) begin : prefix_gen
            assign prefix[j+1] = prefix[j] + A[j];
        end
    endgenerate

    // Compute results for each starting index
    genvar i, k;
    generate
        for (i = 0; i < 8; i = i + 1) begin : result_gen
            reg [3:0] max_k;
            always @(*) begin
                max_k = 4'd0;
                for (k = 1; k <= (7-i)/2 + 1; k = k + 1) begin : k_loop
                    wire [31:0] sum1 = prefix[i+k] - prefix[i];
                    wire [31:0] sum2 = prefix[i+2*k] - prefix[i+k];
                    if (sum1 <= S && sum2 <= S) begin
                        max_k = 2*k;
                    end
                end
                result[i] = max_k;
            end
        end
    endgenerate

endmodule