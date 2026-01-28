module sale_checker(
    input [15:0] actual_cost,
    input [15:0] sale_amount,
    output equal
);
    assign equal = (sale_amount == actual_cost);
endmodule