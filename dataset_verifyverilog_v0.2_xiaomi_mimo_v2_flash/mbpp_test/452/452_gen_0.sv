module loss_amount (
    input  [31:0] actual_cost,
    input  [31:0] sale_amount,
    output [31:0] loss
);

    // Combinational logic to calculate loss
    // loss = (sale_amount > actual_cost) ? (sale_amount - actual_cost) : 0
    // Q16.16 format

    assign loss = (sale_amount > actual_cost) ? (sale_amount - actual_cost) : 32'd0;

endmodule