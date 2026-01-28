module Month30DaysChecker(
    input [3:0] month_in,
    output is_30_days
);
    assign is_30_days = 
        (month_in == 4'd4) ||
        (month_in == 4'd6) ||
        (month_in == 4'd9) ||
        (month_in == 4'd11);
endmodule