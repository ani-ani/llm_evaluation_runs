module index_multiplication (
    input [3:0] num_tuples,
    input [1:0][15:0] tuple_in_1,
    input [1:0][15:0] tuple_in_2,
    output reg [1:0][15:0] result_tuple
);

    always @(*) begin
        result_tuple[0] = tuple_in_1[0] * tuple_in_2[0];
        result_tuple[1] = tuple_in_1[1] * tuple_in_2[1];
    end

endmodule