module rearrange_bigger(
    input clk,
    input rst_n,
    input start,
    input [11:0] number_in,
    output reg [11:0] result,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam EXTRACT_DIGITS = 4'd1;
    localparam FIND_PIVOT_2 = 4'd2;
    localparam FIND_PIVOT_1 = 4'd3;
    localparam FIND_PIVOT_0 = 4'd4;
    localparam FIND_MIN_GREATER = 4'd5;
    localparam SWAP_DIGITS = 4'd6;
    localparam SORT_PASS1 = 4'd7;
    localparam SORT_PASS2 = 4'd8;
    localparam COMPOSE_RESULT = 4'd9;
    localparam DONE = 4'd10;

    reg [3:0] state, next_state;
    
    // Digit registers
    reg [7:0] d [2:0]; // d[2]=hundreds, d[1]=tens, d[0]=units
    
    // Pivot finding registers
    reg [1:0] pivot_idx; // Stores the index of the pivot (0, 1, or 2)
    reg pivot_found;
    
    // Min greater finding registers
    reg [7:0] min_greater_val;
    reg [1:0] min_greater_idx;
    reg [1:0] scan_idx;
    
    // Sorting registers
    reg [7:0] temp;
    
    // Counter for cycles
    reg [2:0] cycle_cnt;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = EXTRACT_DIGITS;
                else next_state = IDLE;
            end
            
            EXTRACT_DIGITS: begin
                next_state = FIND_PIVOT_2;
            end
            
            FIND_PIVOT_2: begin
                // Check if d[1] < d[2]
                if (d[1] < d[2]) next_state = DONE; // Found pivot at 1
                else next_state = FIND_PIVOT_1;
            end
            
            FIND_PIVOT_1: begin
                // Check if d[0] < d[1]
                if (d[0] < d[1]) next_state = DONE; // Found pivot at 0
                else next_state = FIND_PIVOT_0;
            end
            
            FIND_PIVOT_0: begin
                // No pivot found (d[0] >= d[1] >= d[2])
                next_state = DONE;
            end
            
            FIND_MIN_GREATER: begin
                // Run for 2 cycles to scan d[2] then d[1]
                if (cycle_cnt < 2'd2) next_state = FIND_MIN_GREATER;
                else next_state = SWAP_DIGITS;
            end
            
            SWAP_DIGITS: begin
                next_state = SORT_PASS1;
            end
            
            SORT_PASS1: begin
                // First bubble sort pass
                next_state = SORT_PASS2;
            end
            
            SORT_PASS2: begin
                // Second bubble sort pass
                next_state = COMPOSE_RESULT;
            end
            
            COMPOSE_RESULT: begin
                next_state = DONE;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 12'd0;
            done <= 1'b0;
            valid <= 1'b0;
            // Reset digit registers
            d[0] <= 8'd0;
            d[1] <= 8'd0;
            d[2] <= 8'd0;
            pivot_idx <= 2'd0;
            pivot_found <= 1'b0;
            min_greater_val <= 8'd0;
            min_greater_idx <= 2'd0;
            scan_idx <= 2'd0;
            cycle_cnt <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                end
                
                EXTRACT_DIGITS: begin
                    // Extract 3 BCD digits from 12-bit input
                    d[2] <= number_in[11:8]; // Hundreds
                    d[1] <= number_in[7:4];  // Tens
                    d[0] <= number_in[3:0];  // Units
                    pivot_found <= 1'b0;
                end
                
                FIND_PIVOT_2: begin
                    // Check d[1] < d[2] - if true, pivot is at index 1
                    if (d[1] < d[2]) begin
                        pivot_idx <= 2'd1;
                        pivot_found <= 1'b1;
                    end else begin
                        pivot_found <= 1'b0;
                    end
                end
                
                FIND_PIVOT_1: begin
                    // Check d[0] < d[1] - if true, pivot is at index 0
                    if (d[0] < d[1]) begin
                        pivot_idx <= 2'd0;
                        pivot_found <= 1'b1;
                    end else begin
                        pivot_found <= 1'b0;
                    end
                end
                
                FIND_PIVOT_0: begin
                    // No pivot found - all digits non-increasing
                    pivot_found <= 1'b0;
                end
                
                FIND_MIN_GREATER: begin
                    if (cycle_cnt == 3'd0) begin
                        // Initialize: set min_greater to d[2], scan_idx to 2
                        // But we need to find smallest digit > d[pivot_idx] in range (pivot_idx+1 to 2)
                        // For pivot at 1, range is 2; for pivot at 0, range is 1,2
                        // Initialize with largest possible values
                        if (pivot_idx == 2'd1) begin
                            // Range: only d[2]
                            if (d[2] > d[1]) begin
                                min_greater_val <= d[2];
                                min_greater_idx <= 2'd2;
                            end else begin
                                // Should not happen if pivot found, but set to safe value
                                min_greater_val <= d[2];
                                min_greater_idx <= 2'd2;
                            end
                        end else begin // pivot_idx == 0
                            // Range: d[1], d[2] - check d[1] first
                            if (d[1] > d[0]) begin
                                min_greater_val <= d[1];
                                min_greater_idx <= 2'd1;
                            end else if (d[2] > d[0]) begin
                                min_greater_val <= d[2];
                                min_greater_idx <= 2'd2;
                            end else begin
                                min_greater_val <= d[2];
                                min_greater_idx <= 2'd2;
                            end
                        end
                        scan_idx <= 2'd2; // Start scanning from index 2
                        cycle_cnt <= 3'd1;
                    end else if (cycle_cnt == 3'd1) begin
                        // For pivot at 1: only one digit to check (d[2]), already done in init
                        // For pivot at 0: check d[2] against current min_greater
                        if (pivot_idx == 2'd0) begin
                            if (d[2] > d[0] && d[2] < min_greater_val) begin
                                min_greater_val <= d[2];
                                min_greater_idx <= 2'd2;
                            end
                        end
                        cycle_cnt <= 3'd2;
                    end else begin
                        cycle_cnt <= 3'd0; // Reset for next use
                    end
                end
                
                SWAP_DIGITS: begin
                    // Swap d[pivot_idx] with d[min_greater_idx]
                    if (pivot_found) begin
                        d[pivot_idx] <= min_greater_val;
                        d[min_greater_idx] <= d[pivot_idx];
                    end
                end
                
                SORT_PASS1: begin
                    // Bubble sort: check (pivot+1) vs (pivot+2) and (pivot+1) vs (pivot+3) if applicable
                    // After swap, we sort the suffix starting from pivot_idx + 1
                    // For 3 elements, max 2 passes needed
                    // Pass 1: compare adjacent pairs in suffix
                    if (pivot_idx == 2'd1) begin
                        // Only one element in suffix (d[2]), nothing to sort
                        // Just skip
                    end else if (pivot_idx == 2'd0) begin
                        // Suffix: d[1], d[2]
                        if (d[1] > d[2]) begin
                            temp <= d[1];
                            d[1] <= d[2];
                            d[2] <= temp; // Note: temp holds old d[1], but we need to swap
                            // Actually, let's use temp correctly
                            d[1] <= d[2];
                            d[2] <= d[1]; // This uses old d[1] value which is correct
                        end
                    end
                    // For pivot_idx 0, we need to ensure d[1] <= d[2]
                    // Wait, the swap above might not work because d[1] is overwritten before d[2] is assigned
                    // Let's redo this carefully
                    // Actually, let's just compare and swap in a simpler way
                end
                
                SORT_PASS2: begin
                    // Second pass (usually not needed for 2 elements, but per requirements)
                    // For pivot 0, we just need d[1] and d[2] sorted
                    // The pass1 logic needs to be corrected
                end
                
                COMPOSE_RESULT: begin
                    result <= {d[2], d[1], d[0]};
                    valid <= 1'b1;
                    done <= 1'b1;
                end
                
                DONE: begin
                    if (!pivot_found) begin
                        result <= 12'hFFF;
                        valid <= 1'b0;
                        done <= 1'b1;
                    end
                    // If pivot found, result is already composed in COMPOSE_RESULT
                    // Wait, state transition goes DONE -> IDLE, so COMPOSE_RESULT must set everything
                    // But if pivot not found, we jump straight to DONE from FIND_PIVOT_0
                end
            endcase
        end
    end
    
    // Corrected Sort Logic (Combinational override for specific states)
    // We need to handle the sorting properly in the sequential logic
    // Let's rewrite the sorting section inside the always block
    
    // Actually, let's restructure the sequential logic to handle the swap and sort correctly
    // The previous code had a flaw in the SWAP_DIGITS and SORT_PASS logic
    
endmodule

// Re-implementation with corrected sorting logic
// The previous code block was getting complex. Let's rewrite the module cleanly.

module rearrange_bigger(
    input clk,
    input rst_n,
    input start,
    input [11:0] number_in,
    output reg [11:0] result,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam EXTRACT = 4'd1;
    localparam FIND_PIVOT_INIT = 4'd2;
    localparam CHECK_PIVOT_1 = 4'd3;
    localparam CHECK_PIVOT_0 = 4'd4;
    localparam FIND_MIN_INIT = 4'd5;
    localparam FIND_MIN_SCAN = 4'd6;
    localparam SWAP = 4'd7;
    localparam SORT = 4'd8;
    localparam COMPOSE = 4'd9;
    localparam REPORT_INVALID = 4'd10;
    localparam REPORT_VALID = 4'd11;

    reg [3:0] state, next_state;
    reg [7:0] d [2:0]; // d[2]=hundreds, d[1]=tens, d[0]=units
    reg [1:0] p_idx;   // Pivot index
    reg [1:0] m_idx;   // Min greater index
    reg [7:0] temp_val;
    reg [1:0] i_cnt;   // Loop counter

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Next state and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 12'd0;
            done <= 1'b0;
            valid <= 1'b0;
            d[0] <= 8'd0; d[1] <= 8'd0; d[2] <= 8'd0;
            p_idx <= 2'd0; m_idx <= 2'd0;
            temp_val <= 8'd0; i_cnt <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        // Extract digits immediately on start or in next state
                        // Let's extract in IDLE transition or EXTRACT state
                        // Requirements say: "EXTRACT_DIGITS: Parse number..."
                    end
                end

                EXTRACT: begin
                    // Decompose 12-bit BCD into 3 digits
                    d[2] <= number_in[11:8];
                    d[1] <= number_in[7:4];
                    d[0] <= number_in[3:0];
                    // Ensure they are valid 0-9 (though input is assumed valid)
                    p_idx <= 2'd0; // Reset pivot
                end

                FIND_PIVOT_INIT: begin
                    // Prepare for check: pivot is rightmost i such that d[i] < d[i+1]
                    // Check d[1] < d[2] first (i=1)
                end

                CHECK_PIVOT_1: begin
                    if (d[1] < d[2]) begin
                        p_idx <= 2'd1;
                        // Skip to finding min greater
                    end else begin
                        // Check d[0] < d[1] (i=0)
                        // This will be handled in next state
                    end
                end

                CHECK_PIVOT_0: begin
                    if (d[0] < d[1]) begin
                        p_idx <= 2'd0;
                    end else begin
                        // No pivot found, result will be invalid
                    end
                end

                FIND_MIN_INIT: begin
                    // Initialize scan for smallest digit > d[p_idx] in range p_idx+1 to 2
                    // We will scan d[2], d[1] (if valid)
                    // Initialize min_greater with d[2] if it is > d[p_idx]
                    // Since we scan from right, we check against current min
                    i_cnt <= 2'd2; // Start scan index
                    // Handle initial min setup based on p_idx
                    // Actually, let's just scan all valid indices
                    // Reset min_greater to max value
                    temp_val <= 8'd15; // Larger than any valid digit
                end

                FIND_MIN_SCAN: begin
                    // Scan loop: check if d[i_cnt] > d[p_idx] && d[i_cnt] < temp_val
                    // i_cnt goes from 2 down to p_idx+1
                    if (i_cnt > p_idx) begin
                        if (d[i_cnt] > d[p_idx] && d[i_cnt] < temp_val) begin
                            temp_val <= d[i_cnt]; // New minimum greater
                            m_idx <= i_cnt;
                        end
                        i_cnt <= i_cnt - 1'b1;
                        // Stay in this state if not done
                        if (i_cnt == p_idx + 1'b1) begin
                            // Last element checked, next state is SWAP
                        end else begin
                            // Stay in this state
                        end
                    end else begin
                        // Finished scanning (logic flow here is tricky in always block)
                        // We will handle the loop control via next_state logic
                    end
                end

                SWAP: begin
                    // Swap d[p_idx] and d[m_idx]
                    d[p_idx] <= temp_val; // temp_val holds the min greater
                    d[m_idx] <= d[p_idx];
                    // Reset counter for sorting loop
                    i_cnt <= 2'd0;
                end

                SORT: begin
                    // Sort the suffix: indices p_idx+1 to 2
                    // Bubble sort: we need to swap adjacent pairs if out of order
                    // Since suffix length is max 2 (indices 1,2) or 1 (index 2)
                    // Just check d[p_idx+1] and d[p_idx+2]
                    if (p_idx < 2'd1 && d[p_idx + 1'b1] > d[p_idx + 2'd2]) begin
                        d[p_idx + 1'b1] <= d[p_idx + 2'd2];
                        d[p_idx + 2'd2] <= d[p_idx + 1'b1];
                    end
                    // Note: For 3 elements total, bubble sort pass is sufficient
                end

                COMPOSE: begin
                    result <= {d[2], d[1], d[0]};
                    valid <= 1'b1;
                    done <= 1'b1;
                end

                REPORT_INVALID: begin
                    result <= 12'hFFF;
                    valid <= 1'b0;
                    done <= 1'b1;
                end

                REPORT_VALID: begin
                    // Done signal already set in COMPOSE
                    // Just wait for IDLE transition
                end
            endcase
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        case (state)
            IDLE: next_state = start ? EXTRACT : IDLE;
            
            EXTRACT: next_state = FIND_PIVOT_INIT;
            
            FIND_PIVOT_INIT: next_state = CHECK_PIVOT_1;
            
            CHECK_PIVOT_1: begin
                if (d[1] < d[2]) next_state = FIND_MIN_INIT; // Pivot at 1
                else next_state = CHECK_PIVOT_0;
            end
            
            CHECK_PIVOT_0: begin
                if (d[0] < d[1]) next_state = FIND_MIN_INIT; // Pivot at 0
                else next_state = REPORT_INVALID; // No pivot
            end
            
            FIND_MIN_INIT: next_state = FIND_MIN_SCAN;
            
            FIND_MIN_SCAN: begin
                // Loop until i_cnt reaches p_idx + 1 (i_cnt goes 2, 1, 0)
                // If p_idx=1, check 2, then done. If p_idx=0, check 2, then 1, then done.
                if (i_cnt > p_idx + 1'b1) begin
                    next_state = FIND_MIN_SCAN;
                end else begin
                    next_state = SWAP;
                end
            end
            
            SWAP: next_state = SORT;
            
            SORT: next_state = COMPOSE;
            
            COMPOSE: next_state = REPORT_VALID;
            
            REPORT_INVALID: next_state = IDLE;
            
            REPORT_VALID: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule

// Simplified Correct Version: The logic above has some complexity in the loop counter.
// Let's use explicit cycle counting for the required latency of 18 cycles.
// This is the most robust way for ASIC design based on the spec.

module rearrange_bigger(
    input clk,
    input rst_n,
    input start,
    input [11:0] number_in,
    output reg [11:0] result,
    output reg done,
    output reg valid
);

    // State machine states
    localparam S_IDLE = 3'd0;
    localparam S_EXTRACT = 3'd1;
    localparam S_PIVOT = 3'd2;
    localparam S_MIN = 3'd3;
    localparam S_SWAP = 3'd4;
    localparam S_SORT = 3'd5;
    localparam S_COMPOSE = 3'd6;
    localparam S_DONE = 3'd7;

    reg [2:0] state;
    reg [7:0] d [2:0]; // Digits
    reg [2:0] cycle;   // Cycle counter for each stage
    reg [1:0] pivot_pos;
    reg [7:0] min_greater;
    reg [1:0] min_idx;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 12'd0;
            done <= 1'b0;
            valid <= 1'b0;
            d[0] <= 8'd0; d[1] <= 8'd0; d[2] <= 8'd0;
            cycle <= 3'd0;
        end else begin
            done <= 1'b0; // Pulse done only in DONE state, or keep high?
            // Spec says "DONE: Set done signal". Pulse or level? Usually pulse or level until next start.
            // Let's pulse high for one cycle.
            
            case (state)
                S_IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        state <= S_EXTRACT;
                        // Parse input immediately
                        d[2] <= number_in[11:8];
                        d[1] <= number_in[7:4];
                        d[0] <= number_in[3:0];
                    end
                end

                S_EXTRACT: begin
                    // Decomposed in IDLE/Transition, just move to PIVOT
                    state <= S_PIVOT;
                    cycle <= 3'd0;
                    pivot_pos <= 2'd0;
                end

                S_PIVOT: begin
                    // Cycle 0: Check d[1] < d[2] (rightmost check)
                    // Cycle 1: Check d[0] < d[1]
                    // Cycle 2: Move to next state
                    if (cycle == 3'd0) begin
                        if (d[1] < d[2]) pivot_pos <= 2'd1; // Found pivot at 1
                        cycle <= 3'd1;
                    end else if (cycle == 3'd1) begin
                        if (d[0] < d[1] && pivot_pos != 2'd1) pivot_pos <= 2'd0; // Found pivot at 0 if not already found
                        cycle <= 3'd2;
                    end else begin
                        // Decision time
                        if (pivot_pos == 2'd1 || (pivot_pos == 2'd0 && d[0] < d[1])) begin
                            state <= S_MIN;
                            cycle <= 3'd0;
                        end else begin
                            state <= S_DONE; // No bigger number
                            // Result will be handled in S_DONE or pre-set here
                            result <= 12'hFFF;
                            valid <= 1'b0;
                            done <= 1'b1;
                        end
                    end
                end

                S_MIN: begin
                    // Find smallest digit > d[pivot_pos] in range (pivot_pos+1 to 2)
                    // Cycle 0: Init
                    // Cycle 1: Compare d[2]
                    // Cycle 2: Compare d[1] (if needed)
                    if (cycle == 3'd0) begin
                        min_greater <= 8'd15; // Max
                        min_idx <= 2'd0;
                        cycle <= 3'd1;
                    end else if (cycle == 3'd1) begin
                        // Check d[2]
                        if (d[2] > d[pivot_pos] && d[2] < min_greater) begin
                            min_greater <= d[2];
                            min_idx <= 2'd2;
                        end
                        cycle <= 3'd2;
                    end else if (cycle == 3'd2) begin
                        // Check d[1] (only if pivot_pos is 0, otherwise range is just 2)
                        if (pivot_pos == 2'd0) begin
                            if (d[1] > d[pivot_pos] && d[1] < min_greater) begin
                                min_greater <= d[1];
                                min_idx <= 2'd1;
                            end
                        end
                        cycle <= 3'd3;
                    end else begin
                        state <= S_SWAP;
                        cycle <= 3'd0;
                    end
                end

                S_SWAP: begin
                    // Swap d[pivot_pos] and d[min_idx]
                    d[pivot_pos] <= min_greater;
                    d[min_idx] <= d[pivot_pos];
                    state <= S_SORT;
                    cycle <= 3'd0;
                end

                S_SORT: begin
                    // Sort digits from pivot_pos + 1 to end
                    // Since max 3 digits, suffix is max length 2
                    // Bubble sort: swap if out of order
                    // Use cycle to ensure we use updated values from SWAP
                    if (cycle == 3'd0) begin
                        // If suffix is at least 2 elements (pivot was 0)
                        if (pivot_pos == 2'd0) begin
                            if (d[1] > d[2]) begin
                                d[1] <= d[2];
                                d[2] <= d[1];
                            end
                        end
                        cycle <= 3'd1;
                    end else if (cycle == 3'd1) begin
                        // Second pass (ensures sorted)
                        if (pivot_pos == 2'd0) begin
                            if (d[1] > d[2]) begin
                                d[1] <= d[2];
                                d[2] <= d[1];
                            end
                        end
                        state <= S_COMPOSE;
                    end
                end

                S_COMPOSE: begin
                    // Compose result
                    result <= {d[2], d[1], d[0]};
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    // Wait for reset or start
                    done <= 1'b0; // Pulse done low
                    if (!start) begin // Wait for start to go low before accepting new
                         // Keep state here or go to IDLE?
                         // Usually go to IDLE
                    end
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
