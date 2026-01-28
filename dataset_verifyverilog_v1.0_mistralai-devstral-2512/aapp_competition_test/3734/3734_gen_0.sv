module DayChecker(
    input [2:0] day1,
    input [2:0] day2,
    output reg possible
);
    reg [2:0] diff;
    always @(*) begin
        diff = (day2 - day1) % 7;
        possible = (diff == 3'd0) || (diff == 3'd2) || (diff == 3'd3);
    end
endmodule