module first_repeated_char (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_count,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam READING = 2'b01;
    localparam PROCESSING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [2:0] rd_ptr;       // Pointer for reading characters (0 to char_count-1)
    reg [2:0] proc_idx;     // Outer index for processing
    reg [2:0] proc_sub_idx; // Inner index for comparison
    reg [7:0] char_storage [0:7]; // Storage for up to 8 characters
    reg [7:0] next_result;
    reg [2:0] limit;        // Stored limit of characters

    // State Register and Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'h00;
            done <= 1'b0;
            rd_ptr <= 3'b0;
            proc_idx <= 3'b0;
            proc_sub_idx <= 3'b0;
            limit <= 3'b0;
        end else begin
            state <= next_state;
            result <= next_result;
            
            // Counter and Index Management
            case (state)
                IDLE: begin
                    if (start) begin
                        rd_ptr <= 3'b0;
                        proc_idx <= 3'b0;
                        proc_sub_idx <= 3'b0;
                        limit <= char_count;
                        done <= 1'b0;
                    end
                end
                READING: begin
                    if (rd_ptr < limit) begin
                        char_storage[rd_ptr] <= char_in;
                        rd_ptr <= rd_ptr + 1;
                    end
                end
                PROCESSING: begin
                    // Inner loop runs faster than outer loop to meet latency requirements
                    // State stays in PROCESSING until all checks are done
                    if (proc_idx < limit) begin
                        if (proc_sub_idx < proc_idx) begin
                            proc_sub_idx <= proc_sub_idx + 1;
                        end else begin
                            proc_sub_idx <= 3'b0;
                            proc_idx <= proc_idx + 1;
                        end
                    end
                end
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        next_result = result;

        case (state)
            IDLE: begin
                if (start) begin
                    next_result = 8'h00; // Reset result
                    if (char_count > 0)
                        next_state = READING;
                    else
                        next_state = DONE; // Handle empty string immediately
                end
            end

            READING: begin
                // Wait for reading to complete. 
                // Note: We check (rd_ptr + 1 == limit) or use a dedicated loaded signal, 
                // but here we rely on the register update in always block.
                // Since rd_ptr updates on posedge, we check if the *next* increment finishes.
                // Ideally, we check if we just loaded the last char.
                if (rd_ptr == (limit - 1'b1)) begin
                    // Last char is being loaded this cycle, next cycle we start processing
                    next_state = PROCESSING;
                end
                // If start was 0 length, handled in IDLE
            end

            PROCESSING: begin
                // Check if duplicate found in current comparison
                // proc_sub_idx < proc_idx is the range we are checking currently
                // proc_idx is the 'current' char, proc_sub_idx is the 'previous' char being compared
                // We need to check if char_storage[proc_idx] == char_storage[proc_sub_idx]
                // The always block increments proc_sub_idx. So we look at current values.
                
                // Edge case: If limit is 0 or 1, we skip this state (handled in IDLE)
                
                if (limit <= 1) begin
                     next_state = DONE;
                end else if (proc_idx < limit) begin
                    // Logic:
                    // 1. If a match is found at the current indices, go to DONE immediately.
                    // 2. If iteration finishes (proc_idx increments beyond limit-1), go to DONE.
                    
                    // We need to compare char_storage[proc_idx] vs char_storage[proc_sub_idx]
                    // This comparison happens combinationally based on current register values.
                    
                    if (char_storage[proc_idx] == char_storage[proc_sub_idx]) begin
                        next_state = DONE;
                        next_result = char_storage[proc_idx];
                    end else if (proc_sub_idx == proc_idx) begin
                        // This is the end of the inner loop for this proc_idx (the check vs itself)
                        // Since proc_sub_idx increments to proc_idx, if we didn't match earlier, 
                        // we move to next proc_idx in the next cycle.
                        // We need to detect if we are at the very end of the entire process.
                        // The always block updates proc_idx to proc_idx+1 when proc_sub_idx == proc_idx.
                        // So if proc_idx was limit-1 and we finish inner loop, we are done.
                        if (proc_idx == (limit - 1'b1)) begin
                            next_state = DONE;
                        end
                    end
                end else begin
                    // Fallback if we somehow enter with proc_idx >= limit
                    next_state = DONE;
                end
            end

            DONE: begin
                // Stay in DONE until reset or start (implicitly handled by IDLE start condition,
                // but usually we need to exit DONE. Simple behavior: stay until reset or start goes low then high?)
                // Standard practice: wait for start to go low before accepting new start.
                if (!start) begin
                     // Stay in DONE or go to IDLE? Usually wait for start to go low.
                     // Let's remain in DONE until start is low, then transition to IDLE is handled in IDLE logic.
                     // Actually, typical FSM returns to IDLE when reset or after work. 
                     // Let's stay in DONE, and transition to IDLE only on reset or if we detect start low then high (handled in IDLE)
                     // But strictly, we should probably hold DONE high.
                     // To allow re-triggering: Transition to IDLE only when start is low? 
                     // Let's keep it simple: Remain DONE until reset.
                     // If we want to re-trigger: We check `start` in IDLE. If we are in DONE, and start goes low, we don't change state.
                     // If start goes high again, we must be in IDLE. So we need to leave DONE.
                     // Let's leave DONE when start goes low.
                     // If start is still high, we stay DONE.
                     // If start goes low, next_state = IDLE.
                     next_state = IDLE;
                end
            end
        endcase
        
        // Optimization: If proc_sub_idx == proc_idx, we are finishing the check for current char.
        // The assignment logic in 'always' block updates pointers.
        // The comparison logic above must handle the state transition timing correctly.
    end

endmodule
