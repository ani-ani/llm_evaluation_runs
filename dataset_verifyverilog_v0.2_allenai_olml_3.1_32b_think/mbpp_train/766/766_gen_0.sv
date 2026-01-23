module pairwise_consecutive (
    input [7:0][7:0] data_in,
    input [2:0] num_elements,
    output reg [6:0][15:0] pairs_out,
    output reg [2:0] num_pairs
);

assign num_pairs = (num_elements > 1) ? (num_elements - 1) : 0;

assign pairs_out[0] = (num_elements > 1) ? {data_in[0], data_in[1]} : 16'b0;
assign pairs_out[1] = (num_elements > 2) ? {data_in[1], data_in[2]} : 16'b0;
assign pairs_out[2] = (num_elements > 3) ? {data_in[2], data_in[3]} : 16'b0;
assign pairs_out[3] = (num_elements > 4) ? {data_in[3], data_in[4]} : 16'b0;
assign pairs_out[4] = (num_elements > 5) ? {data_in[4], data_in[5]} : 16'b0;
assign pairs_out[5] = (num_elements > 6) ? {data_in[5], data_in[6]} : 16'b0;
assign pairs_out[6] = (num_elements > 7) ? {data_in[6], data_in[7]} : 16'b0;

endmodule