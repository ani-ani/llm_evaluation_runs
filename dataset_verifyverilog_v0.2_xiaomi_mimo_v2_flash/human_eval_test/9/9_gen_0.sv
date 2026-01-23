module rolling_max(
    input clk,
    input rst_n,
    input start,
    input [2:0] array_len,
    input [7:0] input_array [0:7],
    output reg [7:0] result,
    output reg [2:0] index,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] next_index;
    reg [7:0] max_val, next_max_val;
    reg [7:0] next_result;
    reg next_done, next_valid;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'b0;
            max_val <= 8'b0;
            result <= 8'b0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            max_val <= next_max_val;
            result <= next_result;
            done <= next_done;
            valid <= next_valid;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index;
        next_max_val = max_val;
        next_result = result;
        next_done = done;
        next_valid = valid;

        case (state)
            IDLE: begin
                next_index = 3'b0;
                next_done = 1'b0;
                next_valid = 1'b0;
                
                if (start) begin
                    if (array_len == 3'b000) begin
                        // Array length 0, go directly to DONE
                        next_state = DONE;
                        next_done = 1'b1;
                        next_valid = 1'b0;
                    end else begin
                        // Initialize with first element
                        next_state = PROCESSING;
                        next_max_val = input_array[0];
                        next_result = input_array[0];
                        next_index = 3'b0; // First index
                        next_valid = 1'b1;
                    end
                end
            end

            PROCESSING: begin
                // Processing logic
                // current max_val holds the rolling max up to index-1
                // Update with current element
                if (input_array[index] > max_val) begin
                    next_max_val = input_array[index];
                    next_result = input_array[index];
                end else begin
                    next_max_val = max_val;
                    next_result = max_val;
                end

                // Check if we need to increment index or finish
                if (index == array_len - 1'b1) begin
                    // Current element was the last one, transition to DONE
                    next_state = DONE;
                    next_done = 1'b1;
                    next_valid = 1'b0;
                end else begin
                    // Continue processing
                    next_index = index + 1'b1;
                    next_valid = 1'b1;
                    // Load next max_val for comparison in next cycle
                    // But we need to load next element for next comparison
                    // Actually, next_max_val should hold the updated max for next cycle
                    // and next_result is what outputs this cycle
                    // For next cycle, we need to compare with updated max
                    // So we keep next_max_val as updated value
                end
            end

            DONE: begin
                // Stay in DONE state until reset
                next_state = DONE;
                next_done = 1'b1;
                next_valid = 1'b0;
            end

            default: begin
                next_state = IDLE;
                next_index = 3'b0;
                next_max_val = 8'b0;
                next_result = 8'b0;
                next_done = 1'b0;
                next_valid = 1'b0;
            end
        endcase
    end

endmodule
