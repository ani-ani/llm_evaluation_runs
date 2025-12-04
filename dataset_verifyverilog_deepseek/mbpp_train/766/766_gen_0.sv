module pair_wise (
  input [2:0] size,
  input [31:0] data,
  output [55:0] pairs,
  output [2:0] valid_count
);

  wire [3:0] elem [7:0];
  assign valid_count = size - 1;

  genvar j;
  generate
    for (j=0; j<8; j=j+1) begin : unpack
      assign elem[j] = data[31 - 4*j -: 4];
    end
  endgenerate

  genvar i;
  generate
    for (i=0; i<7; i=i+1) begin : pair_gen
      assign pairs[55 - 8*i -: 8] = (i < valid_count) ? {elem[i], elem[i+1]} : 8'b0;
    end
  endgenerate

endmodule