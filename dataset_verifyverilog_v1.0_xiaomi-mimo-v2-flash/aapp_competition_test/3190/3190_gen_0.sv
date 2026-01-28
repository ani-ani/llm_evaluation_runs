module CountSubarrays (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] addr_in,
    input wire [15:0] data_in,
    input wire we,
    input wire [15:0] p_in,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] CALC_IDLE  = 3'd2;
    localparam [2:0] CALC_LOOP  = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers and memory
    reg [15:0] data_mem [0:15];           // 16x16-bit memory for input data
    reg [31:0] prefix_sum [0:16];         // 17x32-bit prefix sum array
    reg [15:0] p_reg;                     // Registered P value
    
    // Loop counters and state variables
    reg [3:0] i_idx;                      // Outer loop index (0 to 15)
    reg [3:0] j_idx;                      // Inner loop index (i to 15)
    reg [3:0] load_cnt;                   // Counter for loading data
    reg [31:0] acc_count;                 // Accumulator for result
    
    // FSM State registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Cycle counter to prevent infinite loops (max ~256 for calc + 16 for load)
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd500;
    
    // Computation registers
    reg [31:0] sub_sum;                   // sum[j+1] - sum[i]
    reg [31:0] threshold_val;             // P * (j - i + 1)
    reg [4:0] len;                        // Length of subarray (1 to 16)
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                if (load_cnt == 4'd15)
                    next_state = CALC_IDLE;
                else
                    next_state = LOAD;
            end
            
            CALC_IDLE: begin
                // Start calculation immediately after loading
                next_state = CALC_LOOP;
            end
            
            CALC_LOOP: begin
                // Loop logic handled in sequential block
                // State transitions based on loop completion
                if (i_idx == 4'd15 && j_idx == 4'd15) begin
                    // Last iteration complete
                    next_state = FINISH;
                end else begin
                    next_state = CALC_LOOP;
                end
            end
            
            FINISH: begin
                // Return to idle after one cycle
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            load_cnt <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            acc_count <= 32'd0;
            cycle_count <= 10'd0;
            sub_sum <= 32'd0;
            threshold_val <= 32'd0;
            len <= 5'd0;
            p_reg <= 16'd0;
            
            // Reset prefix sum array (individual element assignment)
            prefix_sum[0] <= 32'd0;
            prefix_sum[1] <= 32'd0;
            prefix_sum[2] <= 32'd0;
            prefix_sum[3] <= 32'd0;
            prefix_sum[4] <= 32'd0;
            prefix_sum[5] <= 32'd0;
            prefix_sum[6] <= 32'd0;
            prefix_sum[7] <= 32'd0;
            prefix_sum[8] <= 32'd0;
            prefix_sum[9] <= 32'd0;
            prefix_sum[10] <= 32'd0;
            prefix_sum[11] <= 32'd0;
            prefix_sum[12] <= 32'd0;
            prefix_sum[13] <= 32'd0;
            prefix_sum[14] <= 32'd0;
            prefix_sum[15] <= 32'd0;
            prefix_sum[16] <= 32'd0;
            
        end else begin
            // Default values
            done <= 1'b0;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for loading
                        load_cnt <= 4'd0;
                        p_reg <= p_in;
                        acc_count <= 32'd0;
                        i_idx <= 4'd0;
                        j_idx <= 4'd0;
                        cycle_count <= 10'd0;
                        prefix_sum[0] <= 32'd0; // S[0] = 0
                    end
                end
                
                LOAD: begin
                    if (we) begin
                        data_mem[addr_in] <= data_in;
                    end
                    load_cnt <= load_cnt + 4'd1;
                    
                    // Calculate prefix sum on the fly
                    // S[k] = S[k-1] + data[k-1]
                    // data index is load_cnt (0 to 15)
                    // prefix sum index is load_cnt + 1 (1 to 16)
                    if (load_cnt < 4'd16) begin
                        prefix_sum[load_cnt + 4'd1] <= prefix_sum[load_cnt] + {16'd0, data_mem[load_cnt]};
                    end
                end
                
                CALC_IDLE: begin
                    // One cycle delay to ensure prefix sums are ready
                    // Registers already initialized
                end
                
                CALC_LOOP: begin
                    // Check cycle count for safety
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        cycle_count <= cycle_count + 10'd1;
                        
                        // Calculate subarray sum: sum[j+1] - sum[i]
                        // Use previously calculated prefix sums
                        sub_sum <= prefix_sum[j_idx + 4'd1] - prefix_sum[i_idx];
                        
                        // Calculate length
                        len <= j_idx - i_idx + 5'd1;
                        
                        // Calculate threshold: P * len
                        // p_reg is 16-bit, len is up to 5-bit (0-16)
                        // Result fits in 21 bits, stored in 32-bit
                        threshold_val <= p_reg * len;
                        
                        // Check condition (after a cycle for calculation)
                        // We need to compare in the next cycle or use combinational logic
                        // Since we're in a state machine, we'll check on next iteration
                        
                        // Increment counter if condition met
                        // We use the values calculated in previous cycle
                        // To avoid this complexity, we calculate and check in same state
                        // but need to be careful about pipeline
                        
                        // Actually, let's do it properly:
                        // In this cycle, we compute. But we need to know if we should increment.
                        // We can use combinational logic based on current i, j
                        // But simpler: calculate everything in this cycle and check next cycle
                        // However, that doubles cycle count. 
                        // Better: Use combinational calc logic for immediate check
                        
                        // For now, let's assume the calc happens and we check logic below
                        // We will move to next (i,j) pair
                        
                        // Update counters for next iteration
                        if (j_idx < 4'd15) begin
                            j_idx <= j_idx + 4'd1;
                        end else begin
                            j_idx <= i_idx + 4'd1; // Reset j to i+1 for next i
                            i_idx <= i_idx + 4'd1;
                        end
                    end
                end
                
                FINISH: begin
                    // Update result with final count
                    result <= acc_count;
                    done <= 1'b1;
                end
            endcase
            
            // Combinational increment logic integrated into sequential block
            // Since we move pointers at the end of CALC_LOOP, we need to check condition
            // for the (i_idx, j_idx) pair we just processed.
            // Wait, that logic was messy. Let's refine the CALC_LOOP logic.
            
            // Correction for CALC_LOOP:
            // We want to process (i, j). 
            // 1. Calculate sum and threshold.
            // 2. Check condition.
            // 3. Increment count if true.
            // 4. Advance (i, j).
            // All in one state per pair.
            
            // Re-implementing CALC_LOOP part:
            if (state == CALC_LOOP && next_state == CALC_LOOP) begin
                // This block executes during CALC_LOOP state
                
                // Calculate values for CURRENT (i_idx, j_idx)
                sub_sum <= prefix_sum[j_idx + 4'd1] - prefix_sum[i_idx];
                len <= j_idx - i_idx + 5'd1;
                threshold_val <= p_reg * (j_idx - i_idx + 5'd1);
                
                // Check condition: if sub_sum >= threshold_val
                // Use the values currently in registers (from previous cycle)
                // Or use combinational logic. To avoid timing loops with state change,
                // we'll rely on the values computed in the PREVIOUS iteration of this state
                // OR we compute fresh and compare.
                
                // Let's rely on the values computed in the PREVIOUS cycle (or initial entry).
                // Actually, entering CALC_LOOP for the first time (from CALC_IDLE), values are 0.
                // So we need a specific check for the current pair.
                
                // Let's use a combinational signal for the condition check to avoid dependency
                // on registered values for the CURRENT pair.
                // However, complex combinational logic is discouraged if not necessary.
                
                // Alternative: Calculate in state A, Check/Inc in state B.
                // But 256 iterations -> 512 cycles. Acceptable for 100MHz clock.
                // Let's stick to 1 state per iteration for efficiency.
                
                // We will calculate SUBSUM and THRESHOLD for CURRENT (i,j) in this cycle
                // and compare them immediately using combinational logic.
                // But we are in an always block. We can't assign and read in same cycle sequentially.
                // We must rely on combinational logic for the comparison.
            end
        end
    end
    
    // Combinational logic for condition check in CALC_LOOP
    wire [31:0] current_sub_sum;
    wire [31:0] current_threshold;
    wire [31:0] current_len_wire;
    wire condition_met;
    
    assign current_len_wire = j_idx - i_idx + 5'd1;
    assign current_sub_sum = prefix_sum[j_idx + 4'd1] - prefix_sum[i_idx];
    assign current_threshold = p_reg * current_len_wire;
    assign condition_met = (current_sub_sum >= current_threshold);
    
    // We need to handle the increment of acc_count based on condition_met
    // But condition_met is combinational.
    // We can't easily do acc_count <= acc_count + 1 inside the always block based on it
    // without triggering a race condition or infinite loop if not careful.
    
    // Refined Approach for CALC_LOOP:
    // We split CALC_LOOP into two sub-states implicitly or use a flag.
    // Actually, simpler: Just update acc_count in the always block.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == CALC_LOOP) begin
                // We are processing (i_idx, j_idx) this cycle.
                // We compare the values computed from the current i, j.
                // Since current_sub_sum is combinational, it updates immediately.
                // We can check it and update acc_count.
                
                if (condition_met) begin
                    acc_count <= acc_count + 32'd1;
                end
                
                // Advance counters logic must be here to be sequential
                // We need to be careful not to advance if we just started the state.
                // Actually, the logic to advance pointers should be here.
                
                // Check if we are done with this state (last pair)
                // We advance pointers AFTER processing current pair.
                // But we need to know if we should stay in this state or move to next.
                // This is handled by next_state logic, but pointer update needs to be handled here.
                
                // Pointer Update Logic:
                // If we are NOT at the end, advance j (or i if j reached end)
                // If we ARE at the end, next_state will be FINISH (or IDLE via FINISH).
                
                // Wait, if next_state is FINISH, we shouldn't advance pointers.
                // So we only advance if next_state == CALC_LOOP.
                
                if (next_state == CALC_LOOP) begin
                    if (j_idx < 4'd15) begin
                        j_idx <= j_idx + 4'd1;
                    end else begin
                        j_idx <= i_idx + 4'd1;
                        i_idx <= i_idx + 4'd1;
                    end
                end
            end
        end
    end

endmodule