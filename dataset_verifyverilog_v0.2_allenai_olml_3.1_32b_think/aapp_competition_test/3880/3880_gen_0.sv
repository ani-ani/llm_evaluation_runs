module yaroslav_max_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,  // n from 2 to 100, but array is 2n-1, so max 199 elements. Using 6 bits for n
    input wire signed [15:0] array_in,  // One element at a time, serial input
    input wire array_in_valid,
    output reg [31:0] result,
    output reg done
);

// This module processes a stream of (2n-1) elements
// It computes:
// 1. Sum of absolute values
// 2. Count of negative numbers
// 3. Minimum absolute value
// After all elements processed, it applies the formula:
// - If n is odd: result = sum_abs
// - If n is even: 
//   - If negative_count is even: result = sum_abs
//   - If negative_count is odd: result = sum_abs - (min_abs << 1)

reg [31:0] sum_abs;
reg [7:0] neg_count;
reg [15:0] min_abs;
reg [7:0] elem_count;
reg [7:0] total_expected;

wire signed [15:0] abs_val;
assign abs_val = (array_in < 0) ? -array_in : array_in;

wire is_negative;
assign is_negative = (array_in < 0);

wire [31:0] new_sum;
assign new_sum = sum_abs + abs_val;

wire [15:0] new_min;
assign new_min = (elem_count == 0) ? abs_val : ((abs_val < min_abs) ? abs_val : min_abs);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum_abs <= 0;
        neg_count <= 0;
        min_abs <= 16'h7FFF;
        elem_count <= 0;
        total_expected <= 0;
        result <= 0;
        done <= 0;
    end else begin
        if (start && !done && elem_count == 0) begin
            total_expected <= 2*n - 1;
        end

        if (array_in_valid && elem_count < total_expected) begin
            sum_abs <= new_sum;
            neg_count <= neg_count + is_negative;
            min_abs <= new_min;
            elem_count <= elem_count + 1;
        end

        if (elem_count == total_expected && total_expected != 0 && !done) begin
            // Apply formula
            if (n[0]) begin  // n is odd
                result <= sum_abs;
            end else begin  // n is even
                if (neg_count[0]) begin  // negative_count is odd
                    result <= sum_abs - (min_abs << 1);
                end else begin
                    result <= sum_abs;
                end
            end
            done <= 1;
        end

        if (done && start) begin
            // Reset for next computation
            sum_abs <= 0;
            neg_count <= 0;
            min_abs <= 16'h7FFF;
            elem_count <= 0;
            total_expected <= 0;
            result <= 0;
            done <= 0;
        end
    end
end

endmodule