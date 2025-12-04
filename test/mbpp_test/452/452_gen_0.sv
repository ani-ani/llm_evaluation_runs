module loss_amount_calculator(
  input  signed [15:0] actual_cost,
  input  signed [15:0] sale_amount,
  output signed [15:0] loss_amount
);

  assign loss_amount = (sale_amount > actual_cost) ? (sale_amount - actual_cost) : 16'sb0;

endmodule