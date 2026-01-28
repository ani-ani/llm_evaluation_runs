module MonthStartDaysCheck (
    input [2:0] day1,
    input [2:0] day2,
    output reg possible
);

    // Calculate difference modulo 7 (unsigned arithmetic)
    // diff = (day2 - day1) % 7
    wire [2:0] diff;
    assign diff = (day2 >= day1) ? (day2 - day1) : (day2 + 3'd7 - day1);

    // Check if diff is in {0, 2, 3}
    always @(*) begin
        case (diff)
            3'd0: possible = 1'b1;
            3'd2: possible = 1'b1;
            3'd3: possible = 1'b1;
            default: possible = 1'b0;
        endcase
    end

endmodule