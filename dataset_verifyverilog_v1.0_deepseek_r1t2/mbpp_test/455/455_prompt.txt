module check_monthnumb_number(
    input [3:0] monthnum2,
    output reg has_31_days
);

// Check if month has 31 days
// Month numbers: 1=Jan, 2=Feb, 3=Mar, 4=Apr, 5=May, 6=Jun, 7=Jul, 8=Aug, 9=Sep, 10=Oct, 11=Nov, 12=Dec
// Months with 31 days: 1, 3, 5, 7, 8, 10, 12

always @(*) begin
    case (monthnum2)
        4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: has_31_days = 1'b1;
        default: has_31_days = 1'b0;
    endcase
end

endmodule