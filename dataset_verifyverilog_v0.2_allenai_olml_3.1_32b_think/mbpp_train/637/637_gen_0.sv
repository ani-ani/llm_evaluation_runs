module noprofit_noloss(input [31:0] actual_cost, input [31:0] sale_amount, output result);
    assign result = (actual_cost == sale_amount);
endmodule