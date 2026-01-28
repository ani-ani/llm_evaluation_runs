module loss_amount(
    input [15:0] actual_cost,
    input [15:0] sale_amount,
    output reg [15:0] loss
);
    always @(*) begin
        if (sale_amount > actual_cost)
            loss = sale_amount - actual_cost;
        else
            loss = 16'd0;
    end
endmodule