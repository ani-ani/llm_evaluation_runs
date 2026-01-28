module unsorted_array_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] n,
    output reg [7:0] result_arr [0:7],
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] CHECK_SORT = 3'd3;
    localparam [2:0] UPDATE_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] temp_arr [0:7];
    reg [2:0] pos_idx;
    reg [3:0] digit_val;
    reg [2:0] check_idx;
    reg unsorted_flag;
    reg [7:0] original_val;
    reg [7:0] modified_val;
    reg [7:0] temp_result [0:7];
    reg found_flag;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                result_arr[i] <= 8'd0;
                temp_arr[i] <= 8'd0;
                temp_result[i] <= 8'd0;
            end
            pos_idx <= 3'd0;
            digit_val <= 4'd0;
            check_idx <= 3'd0;
            unsorted_flag <= 1'b0;
            original_val <= 8'd0;
            modified_val <= 8'd0;
            found_flag <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    found_flag <= 1'b0;
                    cycle_counter <= 8'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        result_arr[i] <= 8'd0;
                        temp_arr[i] <= 8'd0;
                        temp_result[i] <= 8'd0;
                    end
                    if (start) begin
                        next_state <= SETUP;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SETUP: begin
                    // Copy input array to temp_arr
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_arr[i] <= arr[i];
                    end
                    pos_idx <= 3'd0;
                    digit_val <= 4'd0;
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                PROCESS: begin
                    // Check if we've processed all positions
                    if (pos_idx >= n[2:0]) begin
                        next_state <= FINISH;
                    end else begin
                        // Get original value
                        original_val <= temp_arr[pos_idx];
                        // Try modifying LSB digit
                        if (digit_val <= 4'd9) begin
                            // Calculate modified value
                            // Remove LSB digit: original_val / 10 * 10
                            // Add new digit
                            modified_val <= ((original_val / 8'd10) * 8'd10) + {4'd0, digit_val};
                            check_idx <= 3'd0;
                            unsorted_flag <= 1'b0;
                            cycle_counter <= cycle_counter + 8'd1;
                            if (cycle_counter >= MAX_CYCLES) begin
                                next_state <= FINISH;
                            end else begin
                                next_state <= CHECK_SORT;
                            end
                        end else begin
                            // Move to next position
                            digit_val <= 4'd0;
                            pos_idx <= pos_idx + 3'd1;
                            next_state <= PROCESS;
                        end
                    end
                end

                CHECK_SORT: begin
                    // Check if candidate array is unsorted
                    if (check_idx < n[2:0] - 3'd1) begin
                        // Compare adjacent elements
                        if (check_idx == pos_idx) begin
                            // Use modified value
                            if (modified_val > temp_arr[check_idx + 3'd1]) begin
                                unsorted_flag <= 1'b1;
                            end
                        end else if (check_idx + 3'd1 == pos_idx) begin
                            // Compare with modified value on right
                            if (temp_arr[check_idx] > modified_val) begin
                                unsorted_flag <= 1'b1;
                            end
                        end else begin
                            // Normal comparison
                            if (temp_arr[check_idx] > temp_arr[check_idx + 3'd1]) begin
                                unsorted_flag <= 1'b1;
                            end
                        end
                        check_idx <= check_idx + 3'd1;
                        cycle_counter <= cycle_counter + 8'd1;
                        if (cycle_counter >= MAX_CYCLES) begin
                            next_state <= FINISH;
                        end else begin
                            next_state <= CHECK_SORT;
                        end
                    end else begin
                        // Finished checking all pairs
                        if (unsorted_flag && !found_flag) begin
                            next_state <= UPDATE_RESULT;
                        end else begin
                            // Try next digit value
                            digit_val <= digit_val + 4'd1;
                            next_state <= PROCESS;
                        end
                    end
                end

                UPDATE_RESULT: begin
                    // Build result array with modification
                    found_flag <= 1'b1;
                    valid <= 1'b1;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i == pos_idx) begin
                            result_arr[i] <= modified_val;
                            temp_result[i] <= modified_val;
                        end else begin
                            result_arr[i] <= temp_arr[i];
                            temp_result[i] <= temp_arr[i];
                        end
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!found_flag) begin
                        valid <= 1'b0;
                        // Keep result_arr as original
                        for (i = 0; i < 8; i = i + 1) begin
                            result_arr[i] <= temp_arr[i];
                        end
                    end
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule