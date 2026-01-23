module find_first_missing(
    input clk,
    input rst_n,
    input start,
    input [2:0] array_size,
    input [3:0] array_data [0:7],
    output reg [3:0] missing_number,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SEARCH = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] low, next_low;
    reg [3:0] high, next_high;
    reg [3:0] mid;
    reg [2:0] iteration_count, next_iteration_count;
    reg [3:0] next_missing_number;
    reg next_done;

    // State register and synchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            low <= 4'b0;
            high <= 4'b0;
            iteration_count <= 3'b0;
            missing_number <= 4'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            low <= next_low;
            high <= next_high;
            iteration_count <= next_iteration_count;
            missing_number <= next_missing_number;
            done <= next_done;
        end
    end

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_low = low;
        next_high = high;
        next_iteration_count = iteration_count;
        next_missing_number = missing_number;
        next_done = done;

        mid = (low + high) >> 1;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    if (array_size == 3'd0) begin
                        // Edge case: Empty array
                        next_missing_number = 4'd0;
                        next_state = DONE;
                        next_low = 4'd0;
                        next_high = 4'd0;
                        next_iteration_count = 3'd0;
                    end else begin
                        // Initialize binary search
                        next_low = 4'd0;
                        next_high = {1'b0, array_size}; // Zero-extend 3-bit to 4-bit (size is 1-8)
                        next_high = next_high - 1; // High = array_size - 1
                        next_iteration_count = 3'd0;
                        next_state = SEARCH;
                    end
                end
            end

            SEARCH: begin
                if (low <= high && iteration_count < 3'd4) begin // 3 iterations max for 8 elements, added guard
                    // mid calculation: (low + high) >> 1
                    mid = (low + high) >> 1;
                    
                    // Check array[mid] == mid
                    // We need to ensure we don't access out of bounds if array_size is small,
                    // but if low <= high, mid is within [0, array_size-1].
                    // However, we need to be careful if array_size is 0, but we handle that in IDLE.
                    
                    if (array_data[mid] == mid) begin
                        // Missing is in right half
                        next_low = mid + 1;
                        next_high = high;
                    end else begin
                        // Missing is in left half or at mid
                        next_low = low;
                        next_high = mid - 1;
                    end
                    next_iteration_count = iteration_count + 1;
                    next_state = SEARCH;
                end else begin
                    // Loop finished (low > high) or max iterations reached
                    // Result is 'low'
                    next_missing_number = low;
                    next_state = DONE;
                end
            end

            DONE: begin
                // Wait for reset or next start (implicitly handled by state holding)
                // done signal is already high.
                if (start) begin
                    // Restart logic if start is held high or pulsed again
                    if (array_size == 3'd0) begin
                        next_missing_number = 4'd0;
                        next_state = DONE;
                        next_low = 4'd0;
                        next_high = 4'd0;
                        next_iteration_count = 3'd0;
                    end else begin
                        next_low = 4'd0;
                        next_high = {1'b0, array_size} - 1;
                        next_iteration_count = 3'd0;
                        next_state = SEARCH;
                    end
                    next_done = 1'b0;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule