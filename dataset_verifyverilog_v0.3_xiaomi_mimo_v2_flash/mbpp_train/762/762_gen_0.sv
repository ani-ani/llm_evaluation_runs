module month_has_30_days (
    input [3:0] month_num,  // Month number 1-12 (4 bits)
    output reg has_30_days  // High if month has exactly 30 days
);

    // Months with exactly 30 days: 4 (April), 6 (June), 9 (September), 11 (November)
    // Combinational logic using case statement
    always @(*) begin
        case (month_num)
            4'd4:   has_30_days = 1'b1;   // April
            4'd6:   has_30_days = 1'b1;   // June
            4'd9:   has_30_days = 1'b1;   // September
            4'd11:  has_30_days = 1'b1;   // November
            default: has_30_days = 1'b0;  // All other months
        endcase
    end

endmodule