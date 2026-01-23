module noprofit_noloss(
  input [31:0] actual_cost,
  input [31:0] sale_amount,
  output result
);
  assign result = (actual_cost == sale_amount) ? 1'b1 : 1'b0;
endmodule