module month_30days_check (
    input [4:0] month,
    output reg is_30_days
);

    always @(*) begin
        case (month)
            5'd4, 5'd6, 5'd9, 5'd11: is_30_days = 1'b1;
            default: is_30_days = 1'b0;
        endcase
    end

endmodule