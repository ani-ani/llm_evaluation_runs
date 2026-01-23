module sum_odd_even_pos (
  input [7:0][7:0] data,
  input [2:0] length,
  output [9:0] result
);

  wire [9:0] sum = 10'b0;
  genvar i;

  generate
    for (i = 0; i < 8; i = i + 1) begin : sum_loop
      wire is_even_pos = (i[0] == 0);
      wire is_odd_val = (data[i][0] == 1);
      wire is_valid = (i < length);
      wire [9:0] add_term = (is_valid && is_even_pos && is_odd_val) ? {2'b0, data[i]} : 10'b0;
      assign sum = sum + add_term;
    end
  endgenerate

  assign result = sum;

endmodule