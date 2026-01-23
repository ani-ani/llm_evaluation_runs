module loss_amount(
    input [31:0] actual_cost,
    input [31:0] sale_amount,
    output reg [31:0] loss
);
assign loss = (sale_amount > actual_cost) ? sale_amount - actual_cost : 32'h0;
endmodule