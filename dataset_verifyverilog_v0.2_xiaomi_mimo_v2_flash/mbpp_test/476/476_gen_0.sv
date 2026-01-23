module big_sum (
    input [2:0] array_size,
    input [7:0] nums [0:7],
    output [7:0] result
);

    // Internal signals for min and max
    reg [7:0] min_val;
    reg [7:0] max_val;

    always @(*) begin
        // Default assignments to avoid latches
        min_val = 8'sd127;   // Maximum positive value for 8-bit signed
        max_val = 8'sd128;   // Minimum negative value for 8-bit signed

        // Initialize min/max with the first valid element if it exists
        // This handles the logic for arrays with size > 0
        if (array_size > 0 && array_size <= 8) begin
            min_val = nums[0];
            max_val = nums[0];
        end

        // Iterate through array based on size
        case (array_size)
            3'd0: begin
                // Edge case: size 0
                min_val = 8'sd0;
                max_val = 8'sd0;
            end
            3'd1: begin
                // Size 1: max equals min
                // No need to update, initialized to nums[0]
            end
            3'd2: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
            end
            3'd3: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
                if (nums[2] < min_val) min_val = nums[2];
                if (nums[2] > max_val) max_val = nums[2];
            end
            3'd4: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
                if (nums[2] < min_val) min_val = nums[2];
                if (nums[2] > max_val) max_val = nums[2];
                if (nums[3] < min_val) min_val = nums[3];
                if (nums[3] > max_val) max_val = nums[3];
            end
            3'd5: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
                if (nums[2] < min_val) min_val = nums[2];
                if (nums[2] > max_val) max_val = nums[2];
                if (nums[3] < min_val) min_val = nums[3];
                if (nums[3] > max_val) max_val = nums[3];
                if (nums[4] < min_val) min_val = nums[4];
                if (nums[4] > max_val) max_val = nums[4];
            end
            3'd6: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
                if (nums[2] < min_val) min_val = nums[2];
                if (nums[2] > max_val) max_val = nums[2];
                if (nums[3] < min_val) min_val = nums[3];
                if (nums[3] > max_val) max_val = nums[3];
                if (nums[4] < min_val) min_val = nums[4];
                if (nums[4] > max_val) max_val = nums[4];
                if (nums[5] < min_val) min_val = nums[5];
                if (nums[5] > max_val) max_val = nums[5];
            end
            3'd7: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
                if (nums[2] < min_val) min_val = nums[2];
                if (nums[2] > max_val) max_val = nums[2];
                if (nums[3] < min_val) min_val = nums[3];
                if (nums[3] > max_val) max_val = nums[3];
                if (nums[4] < min_val) min_val = nums[4];
                if (nums[4] > max_val) max_val = nums[4];
                if (nums[5] < min_val) min_val = nums[5];
                if (nums[5] > max_val) max_val = nums[5];
                if (nums[6] < min_val) min_val = nums[6];
                if (nums[6] > max_val) max_val = nums[6];
            end
            3'd8: begin
                if (nums[1] < min_val) min_val = nums[1];
                if (nums[1] > max_val) max_val = nums[1];
                if (nums[2] < min_val) min_val = nums[2];
                if (nums[2] > max_val) max_val = nums[2];
                if (nums[3] < min_val) min_val = nums[3];
                if (nums[3] > max_val) max_val = nums[3];
                if (nums[4] < min_val) min_val = nums[4];
                if (nums[4] > max_val) max_val = nums[4];
                if (nums[5] < min_val) min_val = nums[5];
                if (nums[5] > max_val) max_val = nums[5];
                if (nums[6] < min_val) min_val = nums[6];
                if (nums[6] > max_val) max_val = nums[6];
                if (nums[7] < min_val) min_val = nums[7];
                if (nums[7] > max_val) max_val = nums[7];
            end
            default: begin
                // Should not occur given array_size is 3 bits (0-7),
                // but included for completeness
                min_val = 8'sd0;
                max_val = 8'sd0;
            end
        endcase
    end

    // Combinational addition
    // Result is 8-bit signed, overflow is acceptable per requirements
    assign result = min_val + max_val;

endmodule