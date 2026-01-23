module common_element(
    input [7:0] list1 [0:4],
    input [7:0] list2 [0:4],
    output result
);

    // Internal wire to store comparison results
    wire [24:0] comp_results;

    // Generate 25 comparisons using generate block
    genvar i, j;
    generate
        for (i = 0; i < 5; i = i + 1) begin : outer_loop
            for (j = 0; j < 5; j = j + 1) begin : inner_loop
                assign comp_results[i * 5 + j] = (list1[i] == list2[j]);
            end
        end
    endgenerate

    // OR-reduce all comparison results
    assign result = |comp_results;

endmodule