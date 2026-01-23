module filter_odd(
    input      [7:0] nums [0:7],
    output reg [7:0] odd_nums,
    output reg [3:0] count
);

    integer i;

    always @(*) begin
        // Initialize outputs
        odd_nums = 8'b0;
        count = 4'b0;

        // Iterate through the 8 input elements
        for (i = 0; i < 8; i = i + 1) begin
            // Check if the least significant bit (LSB) is 1
            if (nums[i][0] == 1'b1) begin
                odd_nums[i] = 1'b1;
                count = count + 1;
            end
        end
    end

endmodule
