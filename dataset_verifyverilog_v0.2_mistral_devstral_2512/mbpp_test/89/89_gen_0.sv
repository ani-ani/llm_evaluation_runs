module closest_num(
    input [7:0] N,
    output [7:0] result
);

    assign result = (N == 8'd0) ? 8'd255 : (N - 8'd1);

endmodule