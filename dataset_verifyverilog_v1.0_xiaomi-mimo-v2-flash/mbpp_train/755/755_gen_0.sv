module find_second_smallest (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] arr [0:7],
    input wire [7:0] valid_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SCAN    = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] FINISH  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // State and counter registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] index;  // 0-7 for array elements
    reg [15:0] min_val;
    reg [15:0] second_min_val;
    reg [1:0] valid_count;
    reg [7:0] valid_mask;  // Copy of valid_in for scanning
    reg [15:0] current_val;
    reg found_min;
    reg found_second;

    // Minimum 128 cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'hFFFF;
            done <= 1'b0;
            index <= 4'd0;
            min_val <= 16'hFFFF;
            second_min_val <= 16'hFFFF;
            valid_count <= 2'd0;
            valid_mask <= 8'd0;
            current_val <= 16'd0;
            found_min <= 1'b0;
            found_second <= 1'b0;
            cycle_count <= 8'd0;
            next_state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize variables
                        index <= 4'd0;
                        min_val <= 16'hFFFF;
                        second_min_val <= 16'hFFFF;
                        valid_count <= 2'd0;
                        valid_mask <= valid_in;
                        found_min <= 1'b0;
                        found_second <= 1'b0;
                        next_state <= UPDATE;
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    // Wait for value to be ready
                    if (cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 8'd1;
                        current_val <= arr[index];
                        next_state <= UPDATE;
                        state <= UPDATE;
                    end else begin
                        // Timeout - should not happen with valid input
                        result <= 16'hFFFF;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                UPDATE: begin
                    // Process current value if valid
                    if (valid_mask[index]) begin
                        valid_count <= valid_count + 2'd1;
                        
                        // First valid value found
                        if (!found_min) begin
                            min_val <= current_val;
                            found_min <= 1'b1;
                        end
                        // Second distinct value found
                        else if (!found_second && (current_val != min_val)) begin
                            if (current_val < min_val) begin
                                second_min_val <= min_val;
                                min_val <= current_val;
                            end else begin
                                second_min_val <= current_val;
                            end
                            found_second <= 1'b1;
                        end
                        // Subsequent distinct values
                        else if (found_second) begin
                            // Check for new minimum
                            if (current_val < min_val) begin
                                second_min_val <= min_val;
                                min_val <= current_val;
                            end
                            // Check for new second minimum
                            else if (current_val > min_val && current_val < second_min_val) begin
                                second_min_val <= current_val;
                            end
                        end
                        // Duplicate of min_val - no update needed
                        // Duplicate of second_min_val - no update needed
                    end

                    // Move to next index or finish
                    if (index < 4'd7) begin
                        index <= index + 4'd1;
                        state <= SCAN;
                    end else begin
                        // All elements scanned
                        if (found_second) begin
                            state <= FINISH;
                        end else begin
                            // Less than 2 distinct valid values
                            result <= 16'hFFFF;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                FINISH: begin
                    result <= second_min_val;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule