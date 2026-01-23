module loss_amount (
  input [31:0] actual_cost,
  input [31:0] sale_amount,
  output [31:0] loss
);

  assign loss = (sale_amount > actual_cost) ? (sale_amount - actual_cost) : 32'h00000000;

endmodule