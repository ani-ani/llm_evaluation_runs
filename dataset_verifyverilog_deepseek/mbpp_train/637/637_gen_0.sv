module noprofit_noloss(input reg [15:0] actual_cost, sale_amount, output logic result);
  assign result = (sale_amount == actual_cost);
endmodule