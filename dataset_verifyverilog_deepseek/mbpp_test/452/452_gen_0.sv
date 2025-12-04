module loss_amount_calculator(input signed [15:0] actual_cost, input signed [15:0] sale_amount, output reg signed [15:0] loss_amount);
  always_comb begin
    loss_amount = (sale_amount > actual_cost) ? (sale_amount - actual_cost) : 16'sd0;
  end
endmodule