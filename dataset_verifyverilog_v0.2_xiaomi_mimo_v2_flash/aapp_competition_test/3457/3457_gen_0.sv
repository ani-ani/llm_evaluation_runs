module hopscotch_paths (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] X,
    input [3:0] Y,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MAX_N = 8;
    parameter MOD = 32'd1000000007;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam LOOP_I = 3'b010;
    localparam LOOP_J = 3'b011;
    localparam COMPUTE_SUM = 3'b100;
    localparam DONE = 3'b101;

    // Internal Registers
    reg [2:0] state;
    reg [31:0] dp [0:MAX_N][0:MAX_N];
    
    // Loop and Address Counters
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] ii;
    reg [3:0] jj;
    
    // Accumulator for sum
    reg [31:0] current_sum;
    
    // Helper regs for bounds
    reg [3:0] limit_i;
    reg [3:0] limit_j;

    // State Machine and DP Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            // Initialize dp array (optional, strictly not needed if we clear in INIT)
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Clear DP array and set base case
                    // We use 'i' to iterate through rows to clear them efficiently if needed,
                    // but since we iterate i from 0 in LOOP_I, we can just set dp[0][0] here
                    // and ensure we don't read uninitialized values.
                    // However, to be safe and clean, let's reset the whole array or handle it lazily.
                    // Lazy handling: We only read dp values that have been computed (indices < current i/j).
                    // So we only strictly need dp[0][0] = 1.
                    
                    dp[0][0] <= 1;
                    
                    i <= 0;
                    j <= 0;
                    ii <= 0;
                    jj <= 0;
                    result <= 0;
                    done <= 0;
                    
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    if (i > N) begin
                        state <= DONE;
                    end else begin
                        j <= 0; // Reset j for new row
                        state <= LOOP_J;
                    end
                end

                LOOP_J: begin
                    if (j > N) begin
                        // Finished this row, move to next i
                        i <= i + 1;
                        state <= LOOP_I;
                    end else begin
                        // Compute dp[i][j]
                        if (i == 0 && j == 0) begin
                            // Base case already set in INIT
                            // If N=0, we are done with the cell, but loop continues
                            // If N=0, LOOP_I will immediately go to DONE.
                            // Just move to next cell.
                            j <= j + 1;
                            state <= LOOP_J;
                        end else begin
                            // Initialize sum for this cell
                            current_sum <= 0;
                            
                            // Check if we need to sum (i.e., i>=X and j>=Y)
                            if (i >= X && j >= Y) begin
                                // Prepare for summation loop
                                limit_i <= i - X;
                                limit_j <= j - Y;
                                ii <= 0;
                                jj <= 0;
                                state <= COMPUTE_SUM;
                            end else begin
                                // If conditions not met, dp[i][j] = 0 (implicit as we don't set it)
                                // Actually, if we don't write, it keeps old value which is garbage.
                                // We must explicitly set it to 0 if not covered.
                                dp[i][j] <= 0;
                                j <= j + 1;
                                state <= LOOP_J;
                            end
                        end
                    end
                end

                COMPUTE_SUM: begin
                    // Sum dp[ii][jj] for ii <= limit_i, jj <= limit_j
                    // Add current dp[ii][jj] to sum
                    current_sum <= (current_sum + dp[ii][jj]) % MOD;
                    
                    // Increment indices
                    if (jj < limit_j) begin
                        jj <= jj + 1;
                    end else begin
                        jj <= 0;
                        if (ii < limit_i) begin
                            ii <= ii + 1;
                        end else begin
                            // Summation complete
                            dp[i][j] <= current_sum; // Store final sum (current_sum includes the last add)
                            // Wait one cycle to ensure current_sum is updated? 
                            // Actually, we update current_sum combinationaly or sequentially?
                            // In this sequential block, we update current_sum. 
                            // When ii=limit_i and jj=limit_j, we add dp[limit_i][limit_j].
                            // Next cycle, state moves to LOOP_J. 
                            // But we need to capture the sum including that last addition.
                            // So we need to update dp[i][j] in the cycle AFTER the last addition.
                            // Let's add a buffer cycle or change logic.
                            
                            // Simpler logic: Update dp[i][j] immediately before leaving state.
                            // But if we update dp[i][j] now, we haven't added the last term yet in current_sum.
                            // The term added is dp[ii][jj]. So when ii=limit_i, jj=limit_j, we add it.
                            // current_sum becomes total. 
                            // So we should set dp[i][j] <= (current_sum + dp[ii][jj])
                            // or just let current_sum update and catch it next cycle.
                            // Let's add a small state or do it cleanly.
                            
                            // Correction: We are inside the always block.
                            // current_sum <= current_sum + dp[ii][jj].
                            // So at the end of this cycle, current_sum has the new total.
                            // We want to store this total into dp[i][j].
                            // But if we write dp[i][j] <= current_sum, it takes the OLD current_sum.
                            // We need to write dp[i][j] <= (current_sum + dp[ii][jj]).
                            
                            dp[i][j] <= (current_sum + dp[ii][jj]) % MOD;
                            
                            // Wait one cycle for the write to stabilize or move to next?
                            // If we move to LOOP_J immediately, j increments.
                            // If we want to use dp[i][j] in next iterations, it needs to be available.
                            // Sequential logic update: register updates happen at posedge.
                            // So dp[i][j] becomes valid next cycle.
                            // We should increment j in the next cycle to be safe.
                            // Let's add a dummy state or just hold.
                            // Let's just add a small delay or use a flag.
                            // Or simpler: go to a 'SAVE' state.
                            // Let's just increment j here but add a 1-cycle delay using a flag.
                            // Actually, simpler: 
                            // If we are at the end, we set dp[i][j] and move to LOOP_J.
                            // But dp[i][j] will only be valid in the next cycle.
                            // If the next iteration (i, j+1) needs this value, we are fine if X,Y > 0? 
                            // No, (i, j+1) sums over i', j' <= i-X, j+1-Y. 
                            // It might include i' = i? Only if X=0. If X>=1, it's fine.
                            // Since we iterate i from 0, and sum over i' <= i-X, we never read dp[i][...] to compute dp[i][...].
                            // So we can update dp[i][j] and immediately proceed.
                            // However, we must ensure the value is written to the register file.
                            // In Verilog, non-blocking assignment means it updates next cycle.
                            // So if we set dp[i][j] and immediately go to LOOP_J (setting j <= j+1),
                            // next cycle we are at LOOP_J with new j.
                            // The dp[i][j] is being written. 
                            // If the next state COMPUTE_SUM needs it, it's 1 cycle late.
                            // Given the dependency structure (order of execution), we are safe.
                            
                            state <= LOOP_J;
                            j <= j + 1;
                        end
                    end
                end

                DONE: begin
                    result <= dp[N][N];
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
