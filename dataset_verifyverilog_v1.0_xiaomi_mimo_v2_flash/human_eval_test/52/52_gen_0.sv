module below_threshold (
    input [7:0] threshold,
    input [7:0] numbers [0:7],
    output reg result
);
    // Combinational logic to check if all numbers are below threshold
    always @(*) begin
        result = 1'b1;
        // Check each element individually
        if (numbers[0] >= threshold) result = 1'b0;
        if (numbers[1] >= threshold) result = 1'b0;
        if (numbers[2] >= threshold) result = 1'b0;
        if (numbers[3] >= threshold) result = 1'b0;
        if (numbers[4] >= threshold) result = 1'b0;
        if (numbers[5] >= threshold) result = 1'b0;
        if (numbers[6] >= threshold) result = 1'b0;
        if (numbers[7] >= threshold) result = 1'b0;
    end
endmodule