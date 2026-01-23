module inversion_counter(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    input [7:0] C,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE = 3'b100;
    localparam SWAP = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // DP Storage
    // dp_prev stores the (n-1) row
    // dp_curr stores the n row
    reg [31:0] dp_prev [0:255];
    reg [31:0] dp_curr [0:255];

    // Control Registers
    reg [4:0] n_cnt;       // Current n (1 to N)
    reg [7:0] c_cnt;       // Current c (0 to C)
    reg [7:0] i_cnt;       // Inner loop counter for summation
    
    // Accumulator for summation
    reg [31:0] sum_acc;
    
    // Temp storage for min(c, n-1)
    reg [7:0] limit;

    // Constants
    localparam MOD = 32'd1000000007;

    // State Transition Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = COMPUTE;
            COMPUTE: begin
                // Logic for computing state transitions
                if (n_cnt > N) begin
                    next_state = DONE;
                end else if (c_cnt > C) begin
                    next_state = SWAP; // Finished current row, need to swap
                end else if (i_cnt <= limit) begin
                    next_state = COMPUTE; // Continue summation
                end else begin
                    next_state = COMPUTE; // Move to next c (handled in sequential logic by incrementing c_cnt)
                end
            end
            SWAP: next_state = COMPUTE;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            n_cnt <= 5'd1;
            c_cnt <= 8'd0;
            i_cnt <= 8'd0;
            sum_acc <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 0;
                        n_cnt <= 5'd1;
                        c_cnt <= 8'd0;
                    end
                end

                INIT: begin
                    // Initialize dp_prev[0] = 1, rest = 0
                    // Since we cannot clear 256 registers in one cycle easily without block RAM behavior,
                    // we rely on valid logic or reset values. 
                    // For this design, we will write to specific indices.
                    // We can do a small loop or rely on the fact that dp_curr is written to in COMPUTE.
                    // Let's write dp_prev[0] = 1.
                    // To clear others, we can assume they start at 0 (FPGA default) or reset them in IDLE/INIT if needed.
                    // Since N and C are small, we can do a quick clear loop or just write 0s to specific cells as we go.
                    // To be safe and clean, let's treat INIT as start of compute loop prep.
                    // Actually, standard DP implementation: we need to clear dp_curr before use.
                    // We will handle clearing inside the loop or rely on the fact we overwrite valid entries.
                    // Optimization: We only access indices 0..C. 
                    // Let's set specific flags.
                    // We will set dp_prev[0] = 1 here.
                end

                COMPUTE: begin
                    if (n_cnt <= N) begin
                        if (c_cnt <= C) begin
                            if (i_cnt <= limit) begin
                                // Summation step
                                sum_acc <= sum_acc + dp_prev[c_cnt - i_cnt];
                                i_cnt <= i_cnt + 1'b1;
                            end else begin
                                // Finished sum for this c
                                // Apply Modulo: Since sum_acc can be large, we need to mod it.
                                // We do modulo update here.
                                dp_curr[c_cnt] <= sum_acc % MOD;
                                
                                // Reset accumulator for next c
                                sum_acc <= 0;
                                i_cnt <= 0;
                                
                                // Move to next c
                                c_cnt <= c_cnt + 1'b1;
                            end
                        end else begin
                            // Finished c loop for current n
                            // Wait for SWAP state to handle swap
                            // But since SWAP is a separate state, we stay here until transition triggers swap
                        end
                    end
                end
                
                SWAP: begin
                    // Swap pointers (conceptually). Since we use arrays, we just copy logic.
                    // To save area or time, we usually just swap which array is Prev and which is Curr.
                    // But Verilog arrays are static. We can swap pointers or copy.
                    // Copying 256 words is slow (256 cycles). 
                    // Optimization: Use pointers or just overwrite dp_prev.
                    // Let's perform a fast copy or simply assign pointer logic if supported.
                    // Since we can't have dynamic pointer assignment for registers in standard Verilog easily without a read index,
                    // we will assume a state that copies dp_curr to dp_prev.
                    // Given the latency budget (10000 cycles) and max C (256), copying takes 256 cycles.
                    // This is acceptable. Total cycles approx: N * (C + Copy) = 16 * (256 + 256) = 8192 cycles.
                    
                    // However, we can optimize by doing the copy in parallel or using a shadow register.
                    // Let's implement the copy efficiently.
                    // Wait, we are in a single cycle state SWAP? No, we need to iterate.
                    // Let's modify the state machine to include a COPY state or do it in SWAP state with a counter.
                    // Let's modify SWAP to be a loop.
                    
                    // Re-evaluating state machine for SWAP:
                    // We can use 'c_cnt' as the copy index.
                    if (c_cnt <= C) begin
                        dp_prev[c_cnt] <= dp_curr[c_cnt];
                        c_cnt <= c_cnt + 1'b1;
                    end else begin
                        // Copy done. Prepare for next n.
                        c_cnt <= 8'd0; 
                        n_cnt <= n_cnt + 1'b1;
                    end
                end

                DONE: begin
                    result <= dp_prev[C];
                    done <= 1;
                end
            endcase
            
            // Special handling for INIT to set dp_prev[0] = 1 and clear dp_curr valid range
            if (state == INIT) begin
                dp_prev[0] <= 32'd1;
                // We can clear dp_prev for indices > 0 if needed, but algorithm writes to dp_curr.
                // dp_curr will be written to. We should ensure dp_curr[0] is 0 initially.
                // Actually, the logic `sum_acc <= dp_prev[c_cnt - i_cnt]` relies on dp_prev.
                // dp_curr values are only written, not read (until swapped).
                // So we don't strictly need to clear dp_curr.
            end
            
            // Correction for COMPUTE state's `limit` calculation and `i_cnt` reset logic.
            // The `limit` depends on c_cnt and n_cnt. It should be updated when c_cnt changes.
            // Since `limit` is a combinational function of c and n, we can calculate it in always_comb.
            // But we need it stable during the summation loop.
            // So we should load it into a register at the start of the c loop.
            // Let's add a state to initialize the c loop or do it in SWAP.
            // Actually, in the SWAP state above, we reset c_cnt to 0. 
            // We can load `limit` there. But limit changes with c_cnt.
            // The limit for the summation is min(c_cnt, n_cnt-1). 
            // It depends on c_cnt, which increments. So we can update it every c iteration.
        end
    end

    // Combinational logic for 'limit' and flow control
    always @(*) begin
        if (state == COMPUTE) begin
            if (n_cnt > N) begin
                // Done with all n, transition to DONE is handled by next_state logic, but we need to ensure it triggers
            end
        end
    end
    
    // Helper logic for the SWAP/COPY state modification.
    // The SWAP state logic above assumes c_cnt increments. 
    // However, the previous COMPUTE state leaves c_cnt at C+1. 
    // SWAP resets c_cnt to 0 to start copying.
    // But we need to exit SWAP when copy is done.
    // So the SWAP state logic needs to be: if (c_cnt <= C) copy else next_n.
    
    // Revised SWAP logic inside the sequential block:
    // if (state == SWAP) begin
    //   if (c_cnt <= C) ...
    //   else ...
    // end
    
    // We need to calculate limit for the summation loop.
    // limit = (c_cnt < (n_cnt - 1)) ? c_cnt : (n_cnt - 1);
    // Since c_cnt and n_cnt change, we should update limit register at the start of the c loop.
    // We can update limit in the state transition from SWAP to COMPUTE (when c_cnt is 0) or inside COMPUTE.
    
    // Let's add a logic to update limit.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            limit <= 0;
        end else if (state == SWAP && c_cnt > C) begin
            // About to start next n (or first n after init)
            // But n_cnt increments AFTER copy is done.
            // So when we leave SWAP, n_cnt is the NEW n.
            // So we calculate limit for the upcoming n (which is the one we just copied into dp_prev).
            // Wait, in SWAP, we copy dp_curr to dp_prev. dp_curr was for n-1. dp_prev becomes n-1.
            // Then we increment n_cnt. So dp_prev is n-1, n_cnt is n.
            // The loop computes dp_curr for n_cnt.
            // The summation limit is min(c, n_cnt-1).
            // So we can precompute limit for n_cnt at the end of SWAP.
            // However, inside the c loop, limit depends on c.
            // We can calculate limit = (c_cnt < (n_cnt - 1)) ? c_cnt : (n_cnt - 1);
            // This is dynamic per c.
        end
    end

    // Registers for specific sub-states
    reg [31:0] temp_sum;
    reg [7:0] copy_idx;

    // We will use the state variable to encode the sub-states for COMPUTE.
    // Let's use a binary encoding for states.
    // IDLE (0), INIT (1), PREP_C (2), SUM_LOOP (3), STORE (4), SWAP (5), DONE (6)

    // We need to handle the SWAP and COPY logic carefully.
    // Instead of a separate SWAP state that takes 256 cycles, we can double buffer.
    // We have dp_prev and dp_curr arrays.
    // To save cycles, we can swap pointers in logic, but Verilog synthesis for FPGAs/ASICs usually copies.
    // Or, we can maintain a 'valid' flag.
    // The most standard synthesizable way without external memory is to copy.
    // Given 16 * 256 = 4096 cycles for DP, plus 16 * 256 = 4096 for copies -> 8192 cycles.
    // This is well under 10000 cycles.

    // Let's refine the sequential logic with sub-states.

    // We will reset `i_cnt` to 0, `temp_sum` to 0 in PREP_C.

    // REVISED SEQUENTIAL BLOCK FOR EFFICIENCY AND CORRECTNESS:

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            // Reset pointers/counters
            n_cnt <= 5'd1;
            c_cnt <= 8'd0;
            i_cnt <= 8'd0;
            copy_idx <= 8'd0;
            temp_sum <= 0;
            // We don't need to reset arrays fully, we just overwrite valid data.
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                        n_cnt <= 5'd1; // Target n
                        c_cnt <= 8'd0; // Target c
                    end
                end

                INIT: begin
                    // Initialize dp_prev[0] = 1
                    // We assume other entries are 0 or will be overwritten.
                    // Since we can only write one value per cycle, we write the essential one.
                    dp_prev[0] <= 32'd1;
                    state <= PREP_C;
                    i_cnt <= 0;
                    temp_sum <= 0;
                end

                PREP_C: begin
                    // Prepare for the summation loop for current c_cnt
                    // Check if we are done with current n
                    if (c_cnt > C) begin
                        // Finished all c for this n, proceed to SWAP
                        copy_idx <= 8'd0; // Reset copy index
                        state <= SWAP;
                    end else begin
                        // Start summation
                        // i_cnt starts at 0.
                        // Check limit immediately in SUM_LOOP or here.
                        // Let's compute limit for this c.
                        // limit = min(c_cnt, n_cnt - 1).
                        // Since n_cnt is the target n, and we are computing for n_cnt,
                        // the number of terms is n_cnt. But indices are 0 to n-1 (total n terms).
                        // Wait, formula: dp[n][c] = sum(dp[n-1][c-i]) for i=0 to min(c, n-1).
                        // The count of terms is min(c, n-1) - 0 + 1 = min(c, n-1) + 1.
                        // So i goes from 0 to min(c, n-1).

                        // If c_cnt == 0, min(0, n-1) = 0. i=0. One term.
                        // If c_cnt > 0, check if c_cnt < n_cnt.

                        // Let's determine the end condition for i_cnt.
                        // i_end = min(c_cnt, n_cnt - 1).
                        // We will handle the boundary check in the SUM_LOOP state.
                        // But we need to know when to stop.
                        // Let's just enter SUM_LOOP.
                        state <= SUM_LOOP;
                    end
                end

                SUM_LOOP: begin
                    // We need to know if i_cnt is valid to add.
                    // Condition: i_cnt <= min(c_cnt, n_cnt - 1).
                    // Let's call this limit L.

                    if (i_cnt <= c_cnt && i_cnt < n_cnt) begin
                        // i_cnt is valid (since n_cnt is max 16, c_cnt is max 256, check n_cnt first for speed?)
                        // Actually, if i_cnt < n_cnt, we can access dp_prev if c_cnt - i_cnt >= 0.
                        // c_cnt - i_cnt is always >= 0 because i_cnt <= c_cnt is the other condition.
                        // Wait, if c_cnt < n_cnt, then min(c, n-1) = c. So i goes 0 to c.
                        // If c_cnt >= n_cnt, then min(c, n-1) = n-1. So i goes 0 to n-1.

                        // So valid range for i is: 0 <= i <= c_cnt AND i < n_cnt.

                        if (i_cnt <= c_cnt && i_cnt < n_cnt) begin
                            temp_sum <= temp_sum + dp_prev[c_cnt - i_cnt];
                            i_cnt <= i_cnt + 1;
                            // Stay in SUM_LOOP
                        end else begin
                            // i_cnt exceeded limit, move to STORE
                            state <= STORE;
                        end
                    end else begin
                         // Should not happen if logic is correct, but safe fallback
                         state <= STORE;
                    end
                end

                STORE: begin
                    // Save result to dp_curr
                    dp_curr[c_cnt] <= temp_sum % MOD;
                    // Reset temp_sum
                    temp_sum <= 0;
                    // Move to next c
                    c_cnt <= c_cnt + 1;
                    // Reset i for next iteration
                    i_cnt <= 0;
                    // Go back to PREP_C to check loop bounds
                    state <= PREP_C;
                end

                SWAP: begin
                    // Copy dp_curr to dp_prev for indices 0 to C
                    // Use copy_idx
                    if (copy_idx <= C) begin
                        dp_prev[copy_idx] <= dp_curr[copy_idx];
                        copy_idx <= copy_idx + 1;
                    end else begin
                        // Copy finished. Next n.
                        if (n_cnt >= N) begin
                            // All n processed
                            state <= DONE;
                        end else begin
                            n_cnt <= n_cnt + 1;
                            c_cnt <= 0; // Reset for next row computation
                            i_cnt <= 0;
                            state <= PREP_C; // Start next row
                        end
                    end
                end

                DONE: begin
                    // Output result
                    result <= dp_prev[C]; // After final swap, dp_prev holds the row for N
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
            endcase
        end
    end
endmodule