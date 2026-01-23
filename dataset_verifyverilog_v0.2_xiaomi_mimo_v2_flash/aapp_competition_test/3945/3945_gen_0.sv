module height_reassignment (
    input [3:0] row_rank,
    input [3:0] col_rank,
    input [3:0] row_uniques,
    input [3:0] col_uniques,
    output logic [7:0] min_max_x
);

    logic [3:0] row_rem;
    logic [3:0] col_rem;
    logic [3:0] max_rank;
    logic [3:0] max_rem;
    logic [7:0] sum_inter;

    // Calculate remaining elements
    // row_rem = row_uniques - row_rank - 1
    // col_rem = col_uniques - col_rank - 1
    assign row_rem = row_uniques - row_rank - 1'b1;
    assign col_rem = col_uniques - col_rank - 1'b1;

    // Find max of ranks
    assign max_rank = (row_rank > col_rank) ? row_rank : col_rank;

    // Find max of remaining
    assign max_rem = (row_rem > col_rem) ? row_rem : col_rem;

    // Result = max_rank + max_rem + 1
    // Added logic to handle potential overflow, though 8-bit output is specified
    // max_rank is max 15, max_rem is max 15. 15+15+1 = 31. Fits in 8 bits.
    assign sum_inter = max_rank + max_rem;
    assign min_max_x = sum_inter + 1'b1;

endmodule}