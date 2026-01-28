module MonthHas30Days (
    input [3:0] month_in,
    output reg is_30_days
);

    // Combinational logic to check if month has 30 days
    always @(*) begin
        // Default output to 0 for invalid inputs and other months
        is_30_days = 1'b0;
        
        // Check for months with 30 days: April (4), June (6), September (9), November (11)
        case (month_in)
            4'd4,   // April
            4'd6,   // June
            4'd9,   // September
            4'd11: begin  // November
                is_30_days = 1'b1;
            end
            default: begin
                // All other values (0-3, 5, 7-8, 10, 12-15) output 0
                is_30_days = 1'b0;
            end
        endcase
    end

endmodule