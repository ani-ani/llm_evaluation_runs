module date_converter(
    input [7:0] date_in [0:9],
    output [7:0] date_out [0:9]
);
    assign date_out[0] = date_in[8];
    assign date_out[1] = date_in[9];
    assign date_out[2] = 8'h2D;
    assign date_out[3] = date_in[5];
    assign date_out[4] = date_in[6];
    assign date_out[5] = 8'h2D;
    assign date_out[6] = date_in[0];
    assign date_out[7] = date_in[1];
    assign date_out[8] = date_in[2];
    assign date_out[9] = date_in[3];
endmodule