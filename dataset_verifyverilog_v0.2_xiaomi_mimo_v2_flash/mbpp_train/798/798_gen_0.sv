module array_sum (
    input clk,
    input rst_n,
    input start,
    input [2:0] array_length,
    input [7:0] array_data [7:0],
    output reg [15:0] result,
    output reg done
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        LOAD = 2'b01,
        PROCESSING = 2'b10,
        DONE = 2'b11
    } state_t;
    
    reg [1:0] current_state, next_state;
    reg [2:0] index_counter, next_index_counter;
    reg [15:0] accumulator, next_accumulator;
    reg [3:0] delay_counter, next_delay_counter;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index_counter <= 3'b0;
            accumulator <= 16'b0;
            delay_counter <= 4'b0;
            result <= 16'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            index_counter <= next_index_counter;
            accumulator <= next_accumulator;
            delay_counter <= next_delay_counter;
            
            // Update result and done in DONE state
            if (current_state == DONE) begin
                result <= accumulator;
                done <= 1'b1;
            end else if (current_state == IDLE) begin
                result <= 16'b0;
                done <= 1'b0;
            end else if (current_state == LOAD) begin
                done <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_index_counter = index_counter;
        next_accumulator = accumulator;
        next_delay_counter = delay_counter;

        case (current_state)
            IDLE: begin
                next_index_counter = 3'b0;
                next_accumulator = 16'b0;
                next_delay_counter = 4'b0;
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                next_index_counter = 3'b0;
                next_accumulator = 16'b0;
                next_delay_counter = 4'b0;
                next_state = PROCESSING;
            end

            PROCESSING: begin
                if (index_counter < array_length) begin
                    // Accumulate element at current index
                    next_accumulator = accumulator + array_data[index_counter];
                    next_index_counter = index_counter + 1'b1;
                    next_state = PROCESSING;
                end else begin
                    // All elements processed, move to delay counting
                    next_delay_counter = delay_counter + 1'b1;
                    if (delay_counter >= 1) begin
                        // We need 2 cycles of delay after processing completes
                        // 1st cycle: delay_counter becomes 1 (after last add)
                        // 2nd cycle: delay_counter becomes 2, then go to DONE
                        next_state = DONE;
                    end else begin
                        next_state = PROCESSING;
                    end
                end
            end

            DONE: begin
                // Hold done high and result stable
                // Stay in DONE until reset or start goes low then high again
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: begin
                next_state = IDLE;
                next_index_counter = 3'b0;
                next_accumulator = 16'b0;
                next_delay_counter = 4'b0;
            end
        endcase
    end

endmodule