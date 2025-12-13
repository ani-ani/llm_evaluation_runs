module noprofit_noloss(
  input  [15:0] actual_cost,
  input  [15:0] sale_amount,
  output       result
);

  assign result = (sale_amount == actual_cost) ? 1'b1 : 1'b0;

endmodule