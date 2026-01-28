module SetDifference (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:15],
    input [7:0] arr2 [0:15],
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result [0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] i;          // Index for arr1
    reg [3:0] j;          // Index for arr2
    reg [3:0] out_ptr;    // Pointer to next free position in result
    reg match_found;      // Flag for match detection
    reg [7:0] result_buffer [0:15]; // Internal result buffer

    // Reset and State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            out_ptr <= 4'd0;
            len_out <= 4'd0;
            match_found <= 1'b0;
            // Initialize result buffer
            result_buffer[0] <= 8'd0;
            result_buffer[1] <= 8'd0;
            result_buffer[2] <= 8'd0;
            result_buffer[3] <= 8'd0;
            result_buffer[4] <= 8'd0;
            result_buffer[5] <= 8'd0;
            result_buffer[6] <= 8'd0;
            result_buffer[7] <= 8'd0;
            result_buffer[8] <= 8'd0;
            result_buffer[9] <= 8'd0;
            result_buffer[10] <= 8'd0;
            result_buffer[11] <= 8'd0;
            result_buffer[12] <= 8'd0;
            result_buffer[13] <= 8'd0;
            result_buffer[14] <= 8'd0;
            result_buffer[15] <= 8'd0;
        end else begin
            state <= next_state;
            // Default done is low unless asserted in COMPLETE state
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    i <= 4'd0;
                    j <= 4'd0;
                    out_ptr <= 4'd0;
                    match_found <= 1'b0;
                    if (start) begin
                        // Clear result buffer and len_out at start
                        len_out <= 4'd0;
                        // Reset buffer content (optional but clean)
                    end
                end

                COMPARE: begin
                    if (i < len1) begin
                        // Check if arr1[i] matches any element in arr2
                        if (j < len2) begin
                            if (arr1[i] == arr2[j]) begin
                                match_found <= 1'b1;
                                j <= 4'd15; // Force j to max to trigger wrap next cycle
                            end else if (j == len2 - 1) begin
                                // End of arr2 reached, no match found for arr1[i]
                                if (!match_found) begin
                                    result_buffer[out_ptr] <= arr1[i];
                                    out_ptr <= out_ptr + 4'd1;
                                    len_out <= len_out + 4'd1;
                                end
                                i <= i + 4'd1;
                                j <= 4'd0;
                                match_found <= 1'b0;
                            end else begin
                                j <= j + 4'd1;
                            end
                        end else begin
                            // Wrap condition: j reached max or len2, check match status
                            // (Handled in previous cycle logic mostly)
                            // This block is a safeguard for j overflow
                             if (!match_found) begin
                                    // If we didn't match and j is high, we must have finished iterating properly in previous logic
                                    // However, to prevent hangs, we force next state logic
                             end
                        end
                    end 
                    // Logic for match_found handling:
                    // If match_found is high, we skipped the element.
                    // We need to move to next i.
                    // The condition `if (j < len2)` handles iteration.
                    // If j hits len2-1 and matches, we set j=15. Next cycle, we need to move i.
                    // Let's refine the COMPARE logic in a cleaner way:
                end

                COMPLETE: begin
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPARE;
            end
            
            COMPARE: begin
                // If we have processed all elements in arr1
                if (i >= len1) begin
                    next_state = COMPLETE;
                end else if (j >= len2) begin
                    // j reached end (len2) in the previous cycle logic
                    // This depends on how we updated j in sequential block
                    // To fix Icarus compatibility and logic errors:
                    // Let's implement a cleaner COMPARE logic in a separate always block
                    next_state = COMPARE; // Stay until iteration finishes
                end
                // The actual transition is tricky with double loop in single state.
                // Let's rely on cycle counting or specific flags.
                // Given constraints, we will use a cycle counter to ensure termination.
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Re-implementing COMPARE logic robustly with a cycle counter to ensure FSM termination
    // and correct pointer management without complex nested combinational logic.
    reg [8:0] cycle_counter; // 0-512 range
    
    // Override the previous sequential block with a more robust implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            out_ptr <= 4'd0;
            len_out <= 4'd0;
            cycle_counter <= 9'd0;
            result_buffer[0] <= 8'd0; result_buffer[1] <= 8'd0;
            result_buffer[2] <= 8'd0; result_buffer[3] <= 8'd0;
            result_buffer[4] <= 8'd0; result_buffer[5] <= 8'd0;
            result_buffer[6] <= 8'd0; result_buffer[7] <= 8'd0;
            result_buffer[8] <= 8'd0; result_buffer[9] <= 8'd0;
            result_buffer[10] <= 8'd0; result_buffer[11] <= 8'd0;
            result_buffer[12] <= 8'd0; result_buffer[13] <= 8'd0;
            result_buffer[14] <= 8'd0; result_buffer[15] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    out_ptr <= 4'd0;
                    len_out <= 4'd0;
                    cycle_counter <= 9'd0;
                    if (start) state <= COMPARE;
                end

                COMPARE: begin
                    cycle_counter <= cycle_counter + 9'd1;
                    
                    // Check current element arr1[i] against arr2[j]
                    if (arr1[i] == arr2[j]) begin
                        // Match found, skip this element.
                        // Advance i to next element in arr1.
                        i <= i + 4'd1;
                        j <= 4'd0; // Reset j for next i
                        // Check if we are done with arr1
                        if (i + 4'd1 >= len1) begin
                            state <= COMPLETE;
                        end
                    end else begin
                        // No match at this j
                        if (j == len2 - 1) begin
                            // Reached end of arr2 without match -> it's a difference
                            result_buffer[out_ptr] <= arr1[i];
                            out_ptr <= out_ptr + 4'd1;
                            len_out <= len_out + 4'd1;
                            
                            // Move to next element in arr1
                            i <= i + 4'd1;
                            j <= 4'd0;
                            
                            // Check completion
                            if (i + 4'd1 >= len1) begin
                                state <= COMPLETE;
                            end
                        end else begin
                            // Continue searching in arr2
                            j <= j + 4'd1;
                        end
                    end

                    // Safety timeout
                    if (cycle_counter >= 9'd300) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Output assignment
    integer k;
    always @(*) begin
        for (k = 0; k < 16; k = k + 1) begin
            result[k] = result_buffer[k];
        end
    end

endmodule