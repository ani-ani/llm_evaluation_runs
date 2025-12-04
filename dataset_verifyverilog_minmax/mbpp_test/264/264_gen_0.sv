module dog_age_calculator(
  input reg [7:0] h_age,
  output wire [10:0] d_age
);
  assign d_age = (h_age <= 8'h02) ? ((h_age * 21) >> 1) : ((4 * h_age) + 13);
endmodule