module longest_interesting_subsequence(
    input clk,
    input rst_n,
    input start,
    input [7:0] A [0:15],
    input [31:0] S,
    output reg [7:0] result [0:15],
    output reg done
);

    // State definition
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] i, next_i; // Start position index (0-15)
    reg [3:0] K, next_K; // Half length (1-8)
    reg [7:0] max_len, next_max_len; // Max valid length for current i
    reg [7:0] result_idx, next_result_idx; // Index to store result
    
    // Combinational logic for sum calculations
    // K is 1..8. Indices must be valid (i + K - 1 <= 15, i + 2K - 1 <= 15)
    wire [31:0] sum1, sum2;
    wire valid_indices;
    
    assign valid_indices = (i + K <= 16) && (i + 2*K <= 16);
    
    // Sum of first K elements: A[i] ... A[i+K-1]
    assign sum1 = 
        (K == 1) ? A[i] :
        (K == 2) ? A[i] + A[i+1] :
        (K == 3) ? A[i] + A[i+1] + A[i+2] :
        (K == 4) ? A[i] + A[i+1] + A[i+2] + A[i+3] :
        (K == 5) ? A[i] + A[i+1] + A[i+2] + A[i+3] + A[i+4] :
        (K == 6) ? A[i] + A[i+1] + A[i+2] + A[i+3] + A[i+4] + A[i+5] :
        (K == 7) ? A[i] + A[i+1] + A[i+2] + A[i+3] + A[i+4] + A[i+5] + A[i+6] :
        (K == 8) ? A[i] + A[i+1] + A[i+2] + A[i+3] + A[i+4] + A[i+5] + A[i+6] + A[i+7] :
        32'd0;

    // Sum of last K elements: A[i+K] ... A[i+2K-1]
    assign sum2 = 
        (K == 1) ? A[i+1] :
        (K == 2) ? A[i+2] + A[i+3] :
        (K == 3) ? A[i+3] + A[i+4] + A[i+5] :
        (K == 4) ? A[i+4] + A[i+5] + A[i+6] + A[i+7] :
        (K == 5) ? A[i+5] + A[i+6] + A[i+7] + A[i+8] + A[i+9] :
        (K == 6) ? A[i+6] + A[i+7] + A[i+8] + A[i+9] + A[i+10] + A[i+11] :
        (K == 7) ? A[i+7] + A[i+8] + A[i+9] + A[i+10] + A[i+11] + A[i+12] + A[i+13] :
        (K == 8) ? A[i+8] + A[i+9] + A[i+10] + A[i+11] + A[i+12] + A[i+13] + A[i+14] + A[i+15] :
        32'd0;

    // Next state logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_K = K;
        next_max_len = max_len;
        next_result_idx = result_idx;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    next_i = 0;
                    next_K = 8; // Start with largest K for the first start position
                    next_max_len = 0;
                    next_result_idx = 0;
                end
            end
            
            COMPUTE: begin
                // Check if current K is valid (indices in range)
                if (i + 2*K <= 16) begin
                    // Check interesting condition
                    if (valid_indices && sum1 <= S && sum2 <= S) begin
                        // Found a valid sequence. Since we scan K from 8 down to 1,
                        // this is the maximum valid K for this start position.
                        next_max_len = 2*K;
                        // Move to next start position
                        next_result_idx = result_idx + 1;
                        next_i = i + 1;
                        next_K = 8;
                        next_max_len = 0;
                        // Check if all start positions processed
                        if (result_idx == 15) begin // i becomes 16 effectively, but result_idx logic is cleaner
                             // Wait, if result_idx goes 0->15, that's 16 elements. 
                             // When we are computing for i=15, result_idx is 15.
                             // If we finish i=15, next_result_idx becomes 16. 
                             // Actually, let's keep result_idx as the index to write to.
                             // Initially 0. When i=0 is done, we write to 0, then result_idx becomes 1.
                             // So when result_idx becomes 16, we are done.
                             if (next_i == 16) begin
                                next_state = DONE;
                             end
                        end else if (next_i == 16) begin // i wraps to 16 after processing i=15
                            next_state = DONE;
                        end
                    end else begin
                        // Not valid for current K, try smaller K
                        if (K > 1) begin
                            next_K = K - 1;
                        end else begin
                            // K=1 checked and failed (or indices invalid), store 0 and move to next i
                            next_max_len = 0;
                            next_result_idx = result_idx + 1;
                            next_i = i + 1;
                            next_K = 8;
                            // Check if done
                            if (next_i == 16) begin
                                next_state = DONE;
                            end
                        end
                    end
                end else begin
                    // Indices out of bounds for this K (too large for end of array)
                    // Try smaller K
                    if (K > 1) begin
                        next_K = K - 1;
                    end else begin
                        // K=1 is out of bounds? Only if i > 14. 
                        // If i=15, 2*K=2 > 16? No. 15+2=17 > 16. Yes out of bounds.
                        // So for i=15, K=1 fails bounds check.
                        // We fall here. Store 0.
                        next_max_len = 0;
                        next_result_idx = result_idx + 1;
                        next_i = i + 1;
                        next_K = 8;
                        if (next_i == 16) next_state = DONE;
                    end
                end
            end
            
            DONE: begin
                // Hold state until reset or new start
                // Handled by default assignments above
            end
        endcase
    end

    // Sequential logic
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            K <= 8;
            max_len <= 0;
            result_idx <= 0;
            done <= 0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                result[idx] <= 0;
            end
        end else begin
            state <= next_state;
            i <= next_i;
            K <= next_K;
            max_len <= next_max_len;
            result_idx <= next_result_idx;
            
            if (state == COMPUTE && next_state != COMPUTE) begin
                // We are leaving COMPUTE state. 
                // If next_state is DONE, we need to write the last result.
                // If next_state is still COMPUTE (logic above handles transitions), 
                // we actually write the result for the finished 'i' here.
                // Wait, the logic in ALWAYS(*) sets next_result_idx = result_idx + 1 when a row is done.
                // So the row just finished corresponds to current result_idx (before increment).
                // But wait, we also set next_i = i + 1.
                // Let's look at the transition:
                // i=0, K=8. Check. If valid:
                // next_max_len = 16. next_result_idx = 1. next_i = 1.
                // We need to write max_len to result[0].
                // We can write it now.
                result[result_idx] <= max_len;
            end
            
            if (state == COMPUTE && next_state == DONE) begin
                // Special case: Transition to DONE from COMPUTE.
                // This happens when we process the last item (i=15) or wrap up.
                // We need to write the result for the last item.
                // However, the previous condition (state == COMPUTE && next_state != COMPUTE) 
                // also triggers for DONE.
                // So it handles it.
            end
            
            if (next_state == DONE) begin
                done <= 1;
            end else if (next_state == IDLE && state != IDLE) begin
                // Resetting done when going back to IDLE (if logic allowed, but here we stay in DONE)
            end else if (next_state == IDLE && start) begin
                 done <= 0; // Clear done when starting new
            end else if (state == IDLE) begin
                 done <= 0;
            end
            
            // Fix for the sequential logic:
            // We need to capture the 'max_len' for the specific 'i' when it is decided.
            // The decision happens in the cycle where we check K and determine validity.
            // In the FSM logic above:
            // If valid, we set next_max_len = 2*K, and next_i = i+1.
            // If invalid and K>1, we set next_K = K-1.
            // If invalid and K=1, we set next_i = i+1, next_max_len = 0.
            // So 'max_len' holds the correct value ONLY when we are about to increment 'i'.
            // We should write to 'result' array whenever we increment 'i'.
            // 
            // Revised write logic:
            // Write 'max_len' to 'result[i]' when (next_i != i).
            // 
            // However, result array is indexed by 'i' (the old i).
            // So: if (next_state == COMPUTE && next_i != i) result[i] <= max_len;
            // Note: If next_state == DONE, we don't write to result (array is full).
        end
    end
    
    // Adjusted write enable for result array
    // We write to result[i] when we finish processing start position i.
    // This happens when next_i increments (i + 1).
    // We must ensure we don't write out of bounds.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled in main block
        end else begin
            if (state == COMPUTE && next_state == COMPUTE && next_i != i) begin
                // We are incrementing i, so we are done with current i.
                // Store the found max length.
                result[i] <= max_len;
            end
            // If transitioning to DONE, we might have finished the last item.
            // But if we transition to DONE, next_state != COMPUTE.
            // The FSM logic above for transition to DONE sets next_i = 16 (or wraps), 
            // and effectively we are done with i=15.
            // Does the FSM logic trigger the increment?
            // Yes, in the 'valid' case for i=15:
            // next_i = 16, next_result_idx = 16.
            // In the 'invalid' case for i=15:
            // next_i = 16, next_result_idx = 16.
            // So we need to capture the result for i=15.
            // The condition 'state == COMPUTE && next_i != i' handles this if next_state == DONE is not explicitly blocked.
            // But my next_state logic for DONE sets next_state = DONE, so the above condition `next_state == COMPUTE` fails.
            // We need a separate condition for transition to DONE.
            
            if (state == COMPUTE && next_state == DONE) begin
                result[i] <= max_len; // Write the last result
            end
        end
    end

endmodule
