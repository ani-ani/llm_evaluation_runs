module count_element_in_list(
    input clk,
    input rst_n,
    input start,
    input [7:0] target_element,
    input [3:0][3:0][7:0] sublists,
    output reg [1:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [1:0] index; // Iterates 0 to 3 for sublists
    reg [1:0] count_reg;
    reg [1:0] next_count;
    reg [1:0] next_result;
    reg next_done;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 2'b0;
            done <= 1'b0;
            count_reg <= 2'b0;
            index <= 2'b0;
        end else begin
            current_state <= next_state;
            result <= next_result;
            done <= next_done;
            count_reg <= next_count;
            // Maintain index during processing, reset otherwise
            if (next_state == PROCESSING) begin
                if (current_state == PROCESSING)
                    index <= index + 1;
                else
                    index <= 2'b0;
            end else begin
                index <= 2'b0;
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_count = count_reg;
        next_result = result;
        next_done = done;

        // Wire to check match in current sublist
        // sublists[index] accesses the 4-element array
        // We check if target matches any of the 4 elements in parallel
        wire match_found = (target_element == sublists[index][0]) ||
                           (target_element == sublists[index][1]) ||
                           (target_element == sublists[index][2]) ||
                           (target_element == sublists[index][3]);

        case (current_state)
            IDLE: begin
                next_done = 1'b0;
                next_count = 2'b0;
                next_result = 2'b0;
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                // Check current sublist
                // If match found, increment counter
                if (match_found) begin
                    next_count = count_reg + 1;
                end else begin
                    next_count = count_reg;
                end

                // Transition check
                // If index is 3, this is the last iteration (0,1,2,3)
                // After processing index 3, we move to DONE
                if (index == 2'b11) begin
                    next_state = DONE;
                    // Update result immediately with the final count
                    if (match_found)
                        next_result = count_reg + 1;
                    else
                        next_result = count_reg;
                    next_done = 1'b1;
                end else begin
                    next_state = PROCESSING;
                    next_done = 1'b0;
                    next_result = result; // Keep old result
                end
            end

            DONE: begin
                // Wait in DONE state until reset or start goes high again
                // If start is asserted again, transition to PROCESSING
                // Note: Usually done stays high until reset, but requirements say
                // "wait for reset or new start signal". 
                // If start is high, we should probably restart.
                // However, standard practice is to wait for low start first.
                // Let's assume we stay in DONE. 
                // If start is low, stay DONE. If start is high, transition to IDLE/PROCESSING logic?
                // Requirements: "In DONE state, wait for reset or new start signal."
                // Typically means stay here. 
                // To be safe and synthesizeable, let's just hold.
                // If user wants to restart, they assert start. 
                // The state machine logic in IDLE handles start. 
                // So we need to handle start inside DONE if we want to restart without reset.
                // Let's implement: If start is high, go to PROCESSING (resetting counters implicitly in transition logic?)
                // But we need to reset index and count. 
                // Easier: If start is high in DONE, go to IDLE first, then to PROCESSING? 
                // Or just go to PROCESSING and reset internal signals.
                // Let's go to PROCESSING and reset count_reg/ind.
                // Wait, we need to handle the start condition. 
                // The 'start' is edge triggered in IDLE. If we are in DONE, and we want to restart,
                // we usually need to go back to IDLE or assert start again.
                // Let's just stay in DONE. 
                // If reset is the only way out, that's fine. 
                // But "wait for ... new start signal" implies reacting to it.
                // Let's go to IDLE when start is high, but that requires index reset.
                // Better: In DONE, if start is high, next_state = PROCESSING, and next_count = 0, index = 0.

                if (start) begin
                    next_state = PROCESSING;
                    next_count = 2'b0;
                    // Index is reset by the state register logic when entering PROCESSING from non-PROCESSING
                    // So we need to force it into PROCESSING state.
                end else begin
                    next_state = DONE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule