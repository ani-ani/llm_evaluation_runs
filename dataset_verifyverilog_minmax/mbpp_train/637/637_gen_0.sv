module noprofit_noloss (
  input [15:0] actual_cost,
  input [15:0] sale_amount,
  output logic result
);
  always_comb begin
    result = (sale_amount == actual_cost);
  end
endmodule