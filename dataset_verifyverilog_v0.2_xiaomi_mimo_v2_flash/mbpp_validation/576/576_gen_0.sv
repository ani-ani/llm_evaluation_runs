module sublist_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] main_array [0:7],
    input [7:0] pattern [0:7],
    input [2:0] main_len,
    input [2:0] pattern_len,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] pos_cnt, next_pos_cnt;       // Position in main array
    reg [2:0] idx_cnt, next_idx_cnt;       // Index in pattern
    reg result_reg, next_result;
    reg done_reg, next_done;

    // State registers and output registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_cnt <= 3'b0;
            idx_cnt <= 3'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            pos_cnt <= next_pos_cnt;
            idx_cnt <= next_idx_cnt;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_pos_cnt = pos_cnt;
        next_idx_cnt = idx_cnt;
        next_result = result;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                next_result = 1'b0;
                next_pos_cnt = 3'b0;
                next_idx_cnt = 3'b0;
                if (start) begin
                    // Check for immediate false condition
                    if (pattern_len > main_len || pattern_len == 3'b0 || main_len == 3'b0) begin
                        next_state = DONE;
                        next_result = 1'b0;
                        next_done = 1'b1;
                    end else begin
                        next_state = PROCESSING;
                    end
                end
            end

            PROCESSING: begin
                // Compare current character
                if (main_array[pos_cnt + idx_cnt] == pattern[idx_cnt]) begin
                    // Match found for current index
                    if (idx_cnt == pattern_len - 1) begin
                        // Full pattern matched
                        next_state = DONE;
                        next_result = 1'b1;
                        next_done = 1'b1;
                    end else begin
                        // Continue matching next character in pattern
                        next_idx_cnt = idx_cnt + 1;
                    end
                end else begin
                    // Mismatch at current position
                    // Move to next position in main array
                    next_idx_cnt = 3'b0;
                    if (pos_cnt == main_len - pattern_len) begin
                        // Last position checked, no match found
                        next_state = DONE;
                        next_result = 1'b0;
                        next_done = 1'b1;
                    end else begin
                        next_pos_cnt = pos_cnt + 1;
                    end
                end
            end

            DONE: begin
                // Stay in DONE until reset or start goes low
                // If start is asserted again (and not reset), we should transition to IDLE or restart
                // But typically done stays high until reset
                if (!start) begin
                    // Wait for start to go low before accepting new start
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                next_pos_cnt = 3'b0;
                next_idx_cnt = 3'b0;
                next_result = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule