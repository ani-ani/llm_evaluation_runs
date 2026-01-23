module array_overlap (
    input [7:0] array1 [0:7],
    input [7:0] array2 [0:7],
    output reg overlap
);

    integer i, j;
    wire [7:0] match_matrix [0:7][0:7];
    wire [7:0] row_match;

    // Generate all comparisons
    generate
        for (genvar gi = 0; gi < 8; gi = gi + 1) begin : gen_outer
            for (genvar gj = 0; gj < 8; gj = gj + 1) begin : gen_inner
                assign match_matrix[gi][gj] = (array1[gi] == array2[gj]);
            end
        end
    endgenerate

    // OR reduction for each row
    generate
        for (genvar gr = 0; gr < 8; gr = gr + 1) begin : gen_row_or
            assign row_match[gr] = |match_matrix[gr];
        end
    endgenerate

    // Final OR reduction
    always @(*) begin
        overlap = |row_match;
    end

endmodule