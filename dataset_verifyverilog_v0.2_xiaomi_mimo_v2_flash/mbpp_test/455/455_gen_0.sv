module check_month_31_days(
    input [3:0] month,
    output reg has_31_days
);
    always @(*) begin
        case(month)
            4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: has_31_days = 1'b1;
            default: has_31_days = 1'b0;
        endcase
    end
endmodule