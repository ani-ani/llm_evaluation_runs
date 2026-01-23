module double_the_difference(
    input [7:0] nums [0:7],
    output reg [15:0] result
);

    integer i;
    wire signed [7:0] sq [0:7];
    wire [15:0] contrib [0:7];

    // Combinational logic to compute squares and contributions
    always @(*) begin
        result = 16'd0;
        for (i = 0; i < 8; i = i + 1) begin
            // Check if non-negative (>= 0) and odd
            if (nums[i][7] == 0 && nums[i][0] == 1) begin
                result = result + (nums[i] * nums[i]);
            end
        end
    end

endmodule