module dog_age_calculator(
  input  [7:0]  h_age,
  output [10:0] d_age
);

  assign d_age = (h_age <= 8'd2) ? ((h_age * 11'd21) >> 1) : ((4 * h_age) + 11'd13);

endmodule