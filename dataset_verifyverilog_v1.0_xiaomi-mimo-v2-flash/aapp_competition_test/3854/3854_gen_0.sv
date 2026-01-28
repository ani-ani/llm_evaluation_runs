module subset_subsets (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [8:0] k_in,
    input [8:0] coin_i,
    output reg done,
    output reg [4:0] result_count,
    output reg [8:0] result_x [0:31]
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] n_reg;
    reg [8:0] k_reg;
    reg [8:0] coins [0:15]; // ROM for coin values
    reg [3:0] load_ptr;
    reg [3:0] compute_i;
    reg [8:0] compute_s;
    reg [8:0] output_ptr;
    reg [4:0] output_count;
    reg [8:0] output_idx;
    
    // DP RAM: 512 entries of 512-bit bitset
    reg [511:0] dp_ram [0:511];
    reg [511:0] dp_ram_read;
    
    // Cycle counter for safety
    reg [9:0] cycle_counter;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = (load_ptr >= n_reg) ? COMPUTE : LOAD;
            COMPUTE: next_state = (compute_i >= n_reg) ? OUTPUT : COMPUTE;
            OUTPUT: next_state = (output_ptr > k_reg) ? IDLE : OUTPUT;
            default: next_state = IDLE;
        endcase
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 5'd0;
            load_ptr <= 4'd0;
            compute_i <= 4'd0;
            compute_s <= 9'd0;
            output_ptr <= 9'd0;
            output_count <= 5'd0;
            output_idx <= 9'd0;
            cycle_counter <= 10'd0;
            n_reg <= 4'd0;
            k_reg <= 9'd0;
            // Initialize dp_ram[0] = 1
            dp_ram[0] <= 512'd0;
            dp_ram[0][0] <= 1'b1;
            // Initialize all result_x to 0
            result_x[0] <= 9'd0; result_x[1] <= 9'd0; result_x[2] <= 9'd0; result_x[3] <= 9'd0;
            result_x[4] <= 9'd0; result_x[5] <= 9'd0; result_x[6] <= 9'd0; result_x[7] <= 9'd0;
            result_x[8] <= 9'd0; result_x[9] <= 9'd0; result_x[10] <= 9'd0; result_x[11] <= 9'd0;
            result_x[12] <= 9'd0; result_x[13] <= 9'd0; result_x[14] <= 9'd0; result_x[15] <= 9'd0;
            result_x[16] <= 9'd0; result_x[17] <= 9'd0; result_x[18] <= 9'd0; result_x[19] <= 9'd0;
            result_x[20] <= 9'd0; result_x[21] <= 9'd0; result_x[22] <= 9'd0; result_x[23] <= 9'd0;
            result_x[24] <= 9'd0; result_x[25] <= 9'd0; result_x[26] <= 9'd0; result_x[27] <= 9'd0;
            result_x[28] <= 9'd0; result_x[29] <= 9'd0; result_x[30] <= 9'd0; result_x[31] <= 9'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            if (cycle_counter < MAX_CYCLES)
                cycle_counter <= cycle_counter + 10'd1;
            else
                state <= IDLE; // Safety timeout

            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        load_ptr <= 4'd0;
                        cycle_counter <= 10'd0;
                        // Reset dp_ram (only index 0 is needed initially, others will be overwritten)
                        dp_ram[0] <= 512'd0;
                        dp_ram[0][0] <= 1'b1;
                        result_count <= 5'd0;
                        // Reset result array
                        result_x[0] <= 9'd0; result_x[1] <= 9'd0; result_x[2] <= 9'd0; result_x[3] <= 9'd0;
                        result_x[4] <= 9'd0; result_x[5] <= 9'd0; result_x[6] <= 9'd0; result_x[7] <= 9'd0;
                        result_x[8] <= 9'd0; result_x[9] <= 9'd0; result_x[10] <= 9'd0; result_x[11] <= 9'd0;
                        result_x[12] <= 9'd0; result_x[13] <= 9'd0; result_x[14] <= 9'd0; result_x[15] <= 9'd0;
                        result_x[16] <= 9'd0; result_x[17] <= 9'd0; result_x[18] <= 9'd0; result_x[19] <= 9'd0;
                        result_x[20] <= 9'd0; result_x[21] <= 9'd0; result_x[22] <= 9'd0; result_x[23] <= 9'd0;
                        result_x[24] <= 9'd0; result_x[25] <= 9'd0; result_x[26] <= 9'd0; result_x[27] <= 9'd0;
                        result_x[28] <= 9'd0; result_x[29] <= 9'd0; result_x[30] <= 9'd0; result_x[31] <= 9'd0;
                    end
                end

                LOAD: begin
                    coins[load_ptr] <= coin_i;
                    load_ptr <= load_ptr + 4'd1;
                end

                COMPUTE: begin
                    // Loop i from 0 to n-1
                    // Loop s from k down to coins[i]
                    // dp[s] = dp[s] | (dp[s-c] << c)
                    
                    // We need to read dp_ram[compute_s - coins[compute_i]] and dp_ram[compute_s]
                    // Since compute_s decrements, we can read directly.
                    // Result is written back to dp_ram[compute_s]
                    
                    // Read access handled by logic below (compute_s is index)
                    // Write access:
                    // Need to handle combinational update logic or register it.
                    // Given constraints, let's do register updates.
                    
                    // To avoid combinational loops on large RAM, we update dp_ram[compute_s] based on prev values.
                    // Since compute_s goes downwards, dp[s-c] is already updated for this coin i if we went s-c >= s?
                    // Wait, s-c < s. Since we go downwards, s-c is already processed in this iteration? 
                    // NO. We need the OLD dp[s-c] (from previous coin i-1).
                    // Since we overwrite dp in place, and s-c < s, s-c is to the left.
                    // If we loop s from k down to c, then s-c < s. 
                    // s-c is smaller. Since we loop down, s-c is NOT yet visited in this iteration if s-c > s.
                    // s-c is smaller index. s-c < s. Since we loop down (k -> c), we visit s first, then s-c.
                    // So dp[s-c] is still the value from previous iteration (coin i-1). Correct.
                    // 
                    // One cycle per update:
                    // Read dp_ram[compute_s] and dp_ram[compute_s - coins[compute_i]].
                    // Calculate new value.
                    // Write back to dp_ram[compute_s].
                    
                    // Logic for transitioning s:
                    if (compute_s == coins[compute_i]) begin
                        // Done with this s loop
                        if (compute_i < n_reg - 4'd1) begin
                            compute_i <= compute_i + 4'd1;
                            compute_s <= k_reg;
                        end else begin
                            // Done with all coins
                            // Transition happens in next_state logic
                        end
                    end else begin
                        compute_s <= compute_s - 9'd1;
                    end
                    
                    // Update RAM if valid
                    if (compute_s >= coins[compute_i]) begin
                        // dp[compute_s] = dp[compute_s] | (dp[compute_s - c] << c)
                        // dp[compute_s - c] is read from RAM asynchronously (or registered)
                        // We assume read happens combinational from dp_ram.
                        // To be safe with synthesis, we read from dp_ram based on address.
                        // However, Verilog arrays are synchronous read usually (or we force it).
                        // Let's assume asynchronous read for now, but often RAM is synchronous.
                        // If RAM is synchronous, we need a pipelined read. 
                        // Given the constraints, let's try direct read/write.
                        // Address compute_s.
                        // Data in: dp_ram[compute_s] | (dp_ram[compute_s - coins[compute_i]] << coins[compute_i])
                        // Wait, if we use dp_ram as memory, we shouldn't index it twice in same cycle.
                        // Let's use explicit read signals.
                    end
                end

                OUTPUT: begin
                    // Scan dp[k_reg] from 0 to k_reg.
                    // If bit set, store in result_x[output_count] if count < 32.
                    // output_ptr is the bit index.
                    // We check dp_ram[k_reg][output_ptr].
                    // Since dp_ram is 512x512, read access is needed.
                    // We need to read dp_ram[k_reg].
                    // We can cache it or read every cycle.
                    
                    // To save logic, we read dp_ram[k_reg] once at start of OUTPUT or use it directly.
                    // Since OUTPUT state logic is simple:
                    if (output_ptr <= k_reg) begin
                        // Check bit
                        if (dp_ram[k_reg][output_ptr]) begin
                            if (output_count < 5'd32) begin
                                result_x[output_count] <= output_ptr;
                                output_count <= output_count + 5'd1;
                            end
                        end
                        output_ptr <= output_ptr + 9'd1;
                    end
                    
                    if (output_ptr > k_reg) begin
                        done <= 1'b1;
                        result_count <= output_count;
                    end
                end
            endcase

            // Special handling for COMPUTE state to update RAM
            // This needs to happen based on the compute_s value set in the COMPUTE block above.
            // We cannot put the RAM write in the same case block easily because compute_s changes.
            // We will add a separate combinational block for RAM write enable logic, or handle it here.
            // Since we are inside sequential block, we update dp_ram based on values from previous cycle.
            
            // Wait, the logic inside COMPUTE updates compute_s for the NEXT cycle.
            // So to compute dp for cycle N, we use compute_s of cycle N.
            // We need to read dp_ram[compute_s] and dp_ram[compute_s - c] at cycle N.
            // Then write result to dp_ram[compute_s] at cycle N+1.
            // This introduces a 1-cycle delay. 
            // To avoid delay, we use combinational read inside the always block if possible.
            // Verilog arrays in synthesis are often synchronous read. 
            // If we want to update in same cycle, we need to use dp_ram[compute_s] in the expression.
            // But compute_s changes every cycle.
            // Let's assume synchronous RAM. We update based on the 'previous' compute_s.
            // 
            // Revised COMPUTE logic:
            // We effectively have a pipeline.
            // But to keep it simple and correct:
            // We will read dp_ram synchronously in the previous cycle, or use the array directly in the combinational update.
            // If the synthesis tool supports it, we can read/modify/write to the array in one cycle.
            // However, Icarus Verilog might not support that easily for synthesis.
            // 
            // Let's try: The read and write address are distinct or same?
            // We read from s-c and s. We write to s.
            // If we do this in combinational logic:
            // reg [511:0] new_dp_val;
            // new_dp_val = dp_ram[compute_s] | (dp_ram[compute_s - coins[compute_i]] << coins[compute_i]);
            // dp_ram[compute_s] <= new_dp_val;
            // This is risky for inference (blocking vs non-blocking on same array).
            // 
            // Safer approach: Compute logic is purely combinational based on current state.
            // Update dp_ram in the sequential block.
            // Since we need the OLD value of dp[s] and dp[s-c], and we write to dp[s].
            // Since s decreases, s-c < s. 
            // If we loop downwards, s-c is to the LEFT (smaller index).
            // We will visit s first, then s-c.
            // So dp[s-c] is NOT yet updated in this iteration (it was updated in previous iteration i-1).
            // So reading dp[s-c] is correct.
            // Reading dp[s] gives the old value.
            // Writing dp[s] overwrites it.
            // 
            // The issue is: Can we read and write to the same array in one cycle?
            // Yes, if we use non-blocking assignment correctly.
            // dp_ram[compute_s] <= dp_ram[compute_s] | (dp_ram[compute_s - coins[compute_i]] << coins[compute_i]);
            // This is valid Verilog. 
            // However, `dp_ram[compute_s]` on the RHS and LHS are the same bit select.
            // This creates a dependency.
            // 
            // Let's stick to the standard RAM inference pattern:
            // Read address is (compute_s - coins[compute_i]).
            // Write address is compute_s.
            // Since compute_s != compute_s - coins[compute_i] (unless coin=0, but coins > 0).
            // Wait, if coin_i > 0, then compute_s - c != compute_s.
            // So addresses are distinct. This is good.
            // We also need to OR with dp_ram[compute_s] itself? 
            // Yes, `dp[s] = dp[s] | ...`
            // So we need the current value of dp[s] as well.
            // 
            // Solution: Read dp_ram[compute_s] and dp_ram[compute_s-c] synchronously.
            // But synchronous read means we need the address stable for a cycle.
            // compute_s changes every cycle.
            // So we need a pipeline register.
            // 
            // Given the small size (512 cycles) and constraints, let's try to force single-cycle logic.
            // We will use a combinational read for dp_ram.
            // NOTE: This assumes the synthesis tool treats dp_ram as a combinational array.
            // For FPGA inference, this is often okay if it's small enough (LUTRAM).
            // 
            // Let's declare a helper variable to hold the new value.
        end
    end

    // Combinational RAM update logic for Compute State
    // This separates the read/modify/write logic from the state transitions.
    reg [511:0] dp_new_val;
    reg [511:0] dp_old_val;
    reg [511:0] dp_subset_val;
    
    always @(*) begin
        // Defaults
        dp_new_val = dp_ram[compute_s];
        dp_old_val = dp_ram[compute_s];
        dp_subset_val = dp_ram[compute_s - coins[compute_i]];
        
        if (state == COMPUTE && compute_s >= coins[compute_i]) begin
            // dp[compute_s] = dp[compute_s] | (dp[compute_s - coins[compute_i]] << coins[compute_i])
            // Note: coins[compute_i] is 9-bit. Shift amount must be valid (0-511).
            // Since coins are 9-bit and sums are <= 500, this is safe.
            // We must handle shift of 512-bit vector by variable amount.
            // Verilog supports this.
            dp_new_val = dp_old_val | (dp_subset_val << coins[compute_i]);
        end
    end

    // Update RAM in sequential block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main FSM block
        end else begin
            if (state == COMPUTE && compute_s >= coins[compute_i]) begin
                dp_ram[compute_s] <= dp_new_val;
            end
        end
    end

endmodule