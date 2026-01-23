module month_has_30_days (
    input [3:0] month_num,  // Month number 1-12 (4 bits)
    output has_30_days       // High if month has exactly 30 days
);

    // Months with exactly 30 days: 4 (April), 6 (June), 9 (September), 11 (November)
    // Combinational logic
    assign has_30_days = (month_num == 4'd4) || (month_num == 4'd6) || 
                         (month_num == 4'd9) || (month_num == 4'd11);

endmodule