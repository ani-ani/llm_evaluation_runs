module height_reassignment (
    input [3:0] row_rank,
    input [3:0] col_rank,
    input [3:0] row_uniques,
    input [3:0] col_uniques,
    output [7:0] min_max_x
);
assign row_rem = row_uniques - row_rank - 1;
assign col_rem = col_uniques - col_rank - 1;
assign max_rank = (row_rank > col_rank) \? row_rank \: col_rank;
assign max_rem = (row_rem > col_rem) \? row_rem \: col_rem;
assign min_max_x = max_rank + max_rem + 1;
endmodule