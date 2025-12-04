module adjacent_multiplier(
  input [4:0][7:0] in_tuple,
  output [3:0][15:0] out_tuple
);
  
  genvar i;
  generate
    for (i = 0; i < 4; i = i + 1) begin : mult_gen
      assign out_tuple[i] = in_tuple[i] * in_tuple[i+1];
    end
  endgenerate
  
endmodule