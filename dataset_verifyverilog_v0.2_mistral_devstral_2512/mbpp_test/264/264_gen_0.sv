module dog_age_calculator (
  input [7:0] human_age,
  output [31:0] dog_age
);

  wire [31:0] age_leq_2 = (human_age <= 2) ? (human_age * 32'h000A8000) : (32'h00150000 + (human_age - 2) * 32'h00040000);

  assign dog_age = age_leq_2;

endmodule