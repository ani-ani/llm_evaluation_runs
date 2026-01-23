module marble_insertion_dp (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [2:0] K,
    input [7:0] marble_colors [0:15],
    output reg [7:0] min_insertions,
    output reg done
);

    // Parameters
    parameter MAX_N = 16;
    parameter MAX_K = 5;
    parameter IDLE = 3'b000;
    parameter INIT_DP = 3'b001;
    parameter COMPUTE_DP = 3'b010;
    parameter FIND_RESULT = 3'b011;
    parameter DONE = 3'b100;

    // Registers and Wires
    reg [2:0] state;
    reg [2:0] next_state;
    
    // DP Table: 16x16 array of 8-bit values
    reg [7:0] dp [0:15][0:15];
    
    // Loop counters and temporary variables
    reg [3:0] len;       // Length of subarray (1 to N)
    reg [3:0] i;         // Start index
    reg [3:0] j;         // End index
    reg [3:0] k;         // Split index
    reg [7:0] cost_split;
    reg [7:0] cost_merge;
    reg [7:0] min_val;
    
    // Helper variables for specific conditions
    reg [7:0] temp_sum;

    // State Machine Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT_DP;
                else next_state = IDLE;
            end
            INIT_DP: begin
                // Initialize loop for length 1, then move to compute
                next_state = COMPUTE_DP;
            end
            COMPUTE_DP: begin
                // Handled by counters inside sequential logic block for simplicity in synthesis flow
                // We will transition to FIND_RESULT when all lengths are processed
                // However, to ensure FSM is clean, we stay in COMPUTE_DP until a 'computation_done' flag is set internally
                // Since we need strict cycle counting or internal done signal, we will manage transitions in the sequential block
                next_state = FIND_RESULT; // Placeholder, actually handled by counters below
            end
            FIND_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE; // Go back to idle after one cycle of done
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath and Control Logic
    // We use a single always block for better control over the multi-cycle operation
    // Counters for DP loops
    reg [3:0] len_reg;
    reg [3:0] i_reg;
    reg [3:0] k_reg;
    reg [1:0] phase; // Sub-phase inside states
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_insertions <= 8'h0;
            done <= 1'b0;
            len_reg <= 4'd1;
            i_reg <= 4'd0;
            k_reg <= 4'd0;
            phase <= 2'b00;
            // Initialize DP array to 0 to avoid latches
            // In real synthesis, reset logic for array is complex. 
            // We rely on valid initialization in INIT_DP state or writing only valid values.
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_DP;
                        len_reg <= 4'd1;
                        i_reg <= 4'd0;
                        k_reg <= 4'd0;
                        phase <= 2'b00;
                    end
                end

                INIT_DP: begin
                    // Initialize DP[i][i] = 1 (base case, single marble always needs 1 insertion if K>1, 
                    // or 0 if K==1, but K>=2. If we have 1 marble, we need K-1 more to vanish if K>1). 
                    // Wait, spec says: cost = max(0, K-(j-i+1)). For length 1: K-1.
                    // Actually, let's follow the spec's base case logic.
                    // Base case: if arr[i]==arr[j] (true for length 1), cost = max(0, K-(j-i+1)).
                    // So dp[i][i] = K - 1.
                    
                    // Since we cannot loop efficiently in one cycle without unrolling for 16 entries,
                    // we use a counter to initialize.
                    if (i_reg < N) begin
                        dp[i_reg][i_reg] <= (K > 1) ? (K - 1) : 0;
                        i_reg <= i_reg + 1;
                    end else begin
                        state <= COMPUTE_DP;
                        len_reg <= 4'd2; // Start with length 2
                        i_reg <= 4'd0;
                        k_reg <= 4'd0;
                        phase <= 2'b00;
                    end
                end

                COMPUTE_DP: begin
                    // We iterate: len (2 to N), i (0 to N-len), k (i to j-1)
                    // This is complex to flatten. We will simulate loops using the state variable.
                    
                    if (len_reg <= N) begin
                        if (i_reg <= N - len_reg) begin
                            // Calculate j
                            j = i_reg + len_reg - 1; // j is a wire/reg combination
                            
                            // Main computation phases
                            case (phase)
                                2'b00: begin
                                    // Initial setup for DP[i][j]
                                    // Check special merge case: arr[i] == arr[j] (using marble_colors)
                                    if (marble_colors[i_reg] == marble_colors[j]) begin
                                        if (len_reg >= K) begin
                                            dp[i_reg][j] <= 8'd0; // Already valid group
                                        end else begin
                                            // We need to wait to see if middle can be eliminated fully.
                                            // If len < K, we need K - len insertions to complete the group,
                                            // UNLESS the middle part (i+1 to j-1) can be eliminated and we just fill.
                                            // The DP logic says: if we eliminate middle (cost dp[i+1][j-1]),
                                            // we need max(0, K - 2 - (j-i-1)) insertions.
                                            // Note: dp[i+1][j-1] might be large if it can't be eliminated efficiently.
                                            // But if it IS eliminated (say to 0), we just need K - len.
                                            // Let's calculate the merge cost term.
                                            // If i+1 <= j-1 (len > 2), we need dp[i+1][j-1] + max(0, K-2-(j-i-1))
                                            // If i+1 > j-1 (len <= 2), middle is empty, cost = max(0, K - len).
                                            
                                            if (len_reg > 2) begin
                                                // We need dp[i+1][j-1] to be ready.
                                                // Since we iterate length increasing, dp[i+1][j-1] corresponds to length len-2, which is ready.
                                                cost_merge <= dp[i_reg+1][j-1] + ((K - 2 - (len_reg - 2)) > 0 ? (K - 2 - (len_reg - 2)) : 0);
                                            end else begin
                                                // len is 2. Middle is empty.
                                                cost_merge <= (K > 2) ? (K - 2) : 0;
                                            end
                                            phase <= 2'b01; // Transition to check split points
                                        end
                                    end else begin
                                        // Colors don't match, cannot merge, must split.
                                        // Initialize min with a high value (or first split option)
                                        // We start splitting at k = i_reg
                                        k_reg <= i_reg;
                                        cost_split <= dp[i_reg][i_reg] + dp[i_reg+1][j]; // Initial split k=i
                                        dp[i_reg][j] <= 255; // Reset large
                                        phase <= 2'b10; // Split phase
                                    end
                                end
                                
                                2'b01: begin
                                    // Merge Phase (only entered if colors match and len < K)
                                    // We also need to consider the split option just in case it's better.
                                    // So we set current dp[i][j] to the merge cost, then go to split phase to minimize.
                                    // Or, if len >= K, we set to 0 and we are done with this i,j.
                                    if (len_reg >= K) begin
                                        // Already 0, no need to check splits? 
                                        // Actually, splitting might give better cost? 
                                        // No, 0 is optimal. We are done with this i,j.
                                        i_reg <= i_reg + 1; // Next i
                                        k_reg <= 4'd0;
                                        phase <= 2'b00;
                                    end else begin
                                        // Set initial dp[i][j] to merge cost
                                        dp[i_reg][j] <= cost_merge;
                                        // Now check split points to see if better
                                        k_reg <= i_reg;
                                        phase <= 2'b10;
                                    end
                                end

                                2'b10: begin
                                    // Split Phase (Iterate k)
                                    // We update dp[i][j] = min(dp[i][j], dp[i][k] + dp[k+1][j])
                                    // Since we can't compare and write in same cycle easily without blocking,
                                    // we compute the sum and compare in next cycle.
                                    temp_sum <= dp[i_reg][k_reg] + dp[k_reg+1][j];
                                    phase <= 2'b11;
                                end

                                2'b11: begin
                                    // Compare and Update for Split
                                    if (temp_sum < dp[i_reg][j]) begin
                                        dp[i_reg][j] <= temp_sum;
                                    end
                                    
                                    // Increment k
                                    if (k_reg < j - 1) begin
                                        k_reg <= k_reg + 1;
                                        phase <= 2'b10;
                                    end else begin
                                        // Done with this i,j
                                        i_reg <= i_reg + 1;
                                        phase <= 2'b00;
                                    end
                                end
                            endcase
                        end else begin
                            // Done all i for this length
                            len_reg <= len_reg + 1;
                            i_reg <= 4'd0;
                            phase <= 2'b00;
                        end
                    end else begin
                        // Done all lengths
                        state <= FIND_RESULT;
                    end
                end

                FIND_RESULT: begin
                    // Result is dp[0][N-1]
                    if (N > 0)
                        min_insertions <= dp[0][N-1];
                    else
                        min_insertions <= 8'd0;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
