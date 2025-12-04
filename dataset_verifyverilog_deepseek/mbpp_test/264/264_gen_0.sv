module dog_age_calculator(input [7:0] h_age, output [10:0] d_age);
  assign d_age = (h_age <= 2) ? ((h_age * 21) >> 1) : (4 * h_age + 13);
endmodule