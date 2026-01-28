module DigitSumSorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] in_0,
    input wire signed [7:0] in_1,
    input wire signed [7:0] in_2,
    input wire signed [7:0] in_3,
    input wire signed [7:0] in_4,
    input wire signed [7:0] in_5,
    input wire signed [7:0] in_6,
    input wire signed [7:0] in_7,
    output reg signed [7:0] out_0,
    output reg signed [7:0] out_1,
    output reg signed [7:0] out_2,
    output reg signed [7:0] out_3,
    output reg signed [7:0] out_4,
    output reg signed [7:0] out_5,
    output reg signed [7:0] out_6,
    output reg signed [7:0] out_7,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_DIGIT_1 = 3'd1;
    localparam [2:0] CALC_DIGIT_2 = 3'd2;
    localparam [2:0] SORTING   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Registers for input values
    reg signed [7:0] values [0:7];
    reg [4:0] digit_sums [0:7];
    reg [2:0] indices [0:7];

    // Intermediate registers for sorting
    reg signed [7:0] temp_values [0:7];
    reg [4:0] temp_digit_sums [0:7];
    reg [2:0] temp_indices [0:7];

    // Digit sum calculation function
    function [4:0] calculate_digit_sum;
        input signed [7:0] num;
        reg signed [7:0] abs_num;
        reg [4:0] sum;
        begin
            abs_num = (num < 0) ? -num : num;
            sum = 0;
            // Hundreds digit
            if (abs_num >= 100) begin
                sum = sum + abs_num / 100;
                abs_num = abs_num % 100;
            end
            // Tens digit
            if (abs_num >= 10) begin
                sum = sum + abs_num / 10;
                abs_num = abs_num % 10;
            end
            // Units digit
            sum = sum + abs_num;
            calculate_digit_sum = sum;
        end
    endfunction

    // Comparator for sorting
    function [1:0] compare;
        input [4:0] ds_a, ds_b;
        input [2:0] idx_a, idx_b;
        begin
            if (ds_a > ds_b) begin
                compare = 2'd1; // a should come after b
            end else if (ds_a < ds_b) begin
                compare = 2'd2; // a should come before b
            end else begin
                if (idx_a < idx_b) begin
                    compare = 2'd2; // preserve original order
                end else begin
                    compare = 2'd1; // a should come after b
                end
            end
        end
    endfunction

    // Odd-even transposition sort
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all registers
            for (i = 0; i < 8; i = i + 1) begin
                values[i] <= 8'd0;
                digit_sums[i] <= 5'd0;
                indices[i] <= 3'd0;
                temp_values[i] <= 8'd0;
                temp_digit_sums[i] <= 5'd0;
                temp_indices[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load input values
                        values[0] <= in_0;
                        values[1] <= in_1;
                        values[2] <= in_2;
                        values[3] <= in_3;
                        values[4] <= in_4;
                        values[5] <= in_5;
                        values[6] <= in_6;
                        values[7] <= in_7;
                        // Initialize indices
                        for (i = 0; i < 8; i = i + 1) begin
                            indices[i] <= i;
                        end
                        state <= CALC_DIGIT_1;
                    end
                end

                CALC_DIGIT_1: begin
                    // Calculate digit sums for first half
                    digit_sums[0] <= calculate_digit_sum(values[0]);
                    digit_sums[1] <= calculate_digit_sum(values[1]);
                    digit_sums[2] <= calculate_digit_sum(values[2]);
                    digit_sums[3] <= calculate_digit_sum(values[3]);
                    state <= CALC_DIGIT_2;
                end

                CALC_DIGIT_2: begin
                    // Calculate digit sums for second half
                    digit_sums[4] <= calculate_digit_sum(values[4]);
                    digit_sums[5] <= calculate_digit_sum(values[5]);
                    digit_sums[6] <= calculate_digit_sum(values[6]);
                    digit_sums[7] <= calculate_digit_sum(values[7]);
                    // Copy to temp registers for sorting
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_values[i] <= values[i];
                        temp_digit_sums[i] <= digit_sums[i];
                        temp_indices[i] <= indices[i];
                    end
                    state <= SORTING;
                    cycle_count <= 8'd0;
                end

                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Odd-even transposition sort (7 rounds)
                    if (cycle_count < 8'd7) begin
                        // Odd phase
                        for (i = 1; i < 8; i = i + 2) begin
                            if (compare(temp_digit_sums[i-1], temp_digit_sums[i], temp_indices[i-1], temp_indices[i]) == 2'd1) begin
                                // Swap
                                temp_values[i-1] <= values[i];
                                temp_digit_sums[i-1] <= digit_sums[i];
                                temp_indices[i-1] <= indices[i];
                                temp_values[i] <= values[i-1];
                                temp_digit_sums[i] <= digit_sums[i-1];
                                temp_indices[i] <= indices[i-1];
                            end else begin
                                temp_values[i-1] <= values[i-1];
                                temp_digit_sums[i-1] <= digit_sums[i-1];
                                temp_indices[i-1] <= indices[i-1];
                                temp_values[i] <= values[i];
                                temp_digit_sums[i] <= digit_sums[i];
                                temp_indices[i] <= indices[i];
                            end
                        end
                        // Even phase
                        for (i = 2; i < 8; i = i + 2) begin
                            if (compare(temp_digit_sums[i-1], temp_digit_sums[i], temp_indices[i-1], temp_indices[i]) == 2'd1) begin
                                // Swap
                                temp_values[i-1] <= values[i];
                                temp_digit_sums[i-1] <= digit_sums[i];
                                temp_indices[i-1] <= indices[i];
                                temp_values[i] <= values[i-1];
                                temp_digit_sums[i] <= digit_sums[i-1];
                                temp_indices[i] <= indices[i-1];
                            end else begin
                                temp_values[i-1] <= values[i-1];
                                temp_digit_sums[i-1] <= digit_sums[i-1];
                                temp_indices[i-1] <= indices[i-1];
                                temp_values[i] <= values[i];
                                temp_digit_sums[i] <= digit_sums[i];
                                temp_indices[i] <= indices[i];
                            end
                        end
                        // Update values for next iteration
                        for (i = 0; i < 8; i = i + 1) begin
                            values[i] <= temp_values[i];
                            digit_sums[i] <= temp_digit_sums[i];
                            indices[i] <= temp_indices[i];
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Output sorted values
                    out_0 <= values[0];
                    out_1 <= values[1];
                    out_2 <= values[2];
                    out_3 <= values[3];
                    out_4 <= values[4];
                    out_5 <= values[5];
                    out_6 <= values[6];
                    out_7 <= values[7];
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule