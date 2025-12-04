module even_checker (
  input reg [7:0] n,
  output logic is_even
);
  assign is_even = (n ^ 8'h01) == (n + 8'h01);
endmodule