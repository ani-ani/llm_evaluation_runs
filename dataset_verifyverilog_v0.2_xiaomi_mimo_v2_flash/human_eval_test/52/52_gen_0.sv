module below_threshold(
    input [7:0] threshold,
    input [7:0] array [0:7],
    output result
);
    wire [7:0] lt_results;
    
    // Compare each element with threshold
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_comparisons
            assign lt_results[i] = (array[i] < threshold);
        end
    endgenerate
    
    // Result is high only if ALL elements are less than threshold
    assign result = &lt_results;
    
endmodule