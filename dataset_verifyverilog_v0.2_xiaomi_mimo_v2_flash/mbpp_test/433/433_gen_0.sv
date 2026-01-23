module check_greater (
    input [7:0] number,
    input [7:0] arr [0:7],
    output result
);

    wire [7:0] comp_results;
    
    // Generate 8 comparators in parallel
    generate
        genvar i;
        for (i = 0; i < 8; i = i + 1) begin : gen_comparators
            assign comp_results[i] = (number > arr[i]);
        end
    endgenerate
    
    // Combine all comparisons with AND tree
    assign result = &comp_results;

endmodule
