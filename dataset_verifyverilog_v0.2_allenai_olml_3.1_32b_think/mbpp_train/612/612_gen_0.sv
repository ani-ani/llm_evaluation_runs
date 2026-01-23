module array_transpose (
    input [7:0] data_in [0:7][0:1],
    input [2:0] num_pairs,
    output [7:0] col0 [0:7],
    output [7:0] col1 [0:7]
);

always @(*) begin
    for (int i=0; i<8; i++) begin
        col0[i] = (i < num_pairs) ? data_in[i][0] : 8'b0;
        col1[i] = (i < num_pairs) ? data_in[i][1] : 8'b0;
    end
end

endmodule