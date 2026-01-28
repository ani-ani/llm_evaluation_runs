module pentagon_perimeter(
    input [15:0] side,
    output reg [15:0] perimeter
);
    wire [17:0] side_times_4;
    wire [17:0] side_extended;
    wire [17:0] result_extended;

    assign side_extended = {2'b00, side};
    assign side_times_4 = {side, 2'b00};
    assign result_extended = side_times_4 + side_extended;

    always @(*) begin
        perimeter = result_extended[15:0];
    end
endmodule