module compare_equal (
    input [15:0] actual_cost,
    input [15:0] sale_amount,
    output reg equal
);

always @(*) begin
    equal = (sale_amount == actual_cost);
end

endmodule