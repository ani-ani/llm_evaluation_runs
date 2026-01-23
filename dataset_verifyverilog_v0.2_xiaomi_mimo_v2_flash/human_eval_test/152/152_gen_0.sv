module compare_arrays (
    input [7:0] scores_i,
    input [7:0] guesses_i,
    input [2:0] index,
    output reg [7:0] diff_o
);

    // Internal wires for selected elements
    wire signed [7:0] score_sel;
    wire signed [7:0] guess_sel;
    wire signed [7:0] diff_signed;
    wire signed [7:0] neg_diff;

    // Since the inputs are provided as single 8-bit vectors, 
    // the 'index' input implies selecting a bit or slice from them if they were arrays.
    // However, the interface shows single 8-bit inputs. 
    // Assuming the description implies we are processing the full 8-bit inputs 
    // (or that index is a don't-care for single-value processing based on the provided ports).
    // We compute the absolute difference of the full 8-bit inputs provided.

    assign score_sel = $signed(scores_i);
    assign guess_sel = $signed(guesses_i);

    // Step 1: Calculate signed difference
    assign diff_signed = score_sel - guess_sel;

    // Step 2: Handle negative result (negate for absolute value)
    // If MSB is 1 (negative), negate; otherwise keep as is.
    assign neg_diff = -diff_signed;

    // Step 3: Output selection
    always @(*) begin
        if (diff_signed < 0)
            diff_o = neg_diff[7:0];
        else
            diff_o = diff_signed[7:0];
    end

endmodule