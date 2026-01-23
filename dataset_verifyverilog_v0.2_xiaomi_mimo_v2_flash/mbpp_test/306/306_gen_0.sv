module max_sum_increasing_subseq(
    input clk,
    input rst_n,
    input start,
    input [2:0] i_index,
    input [2:0] k_index,
    input [15:0] a [0:7],
    output reg [15:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam INIT = 3'b010;
    localparam ROW_PROCESS = 3'b100;
    localparam DONE = 3'b000; // Done combined with IDLE logic or separate state
    // Actually, let's use distinct states for clarity and safe transition
    localparam S_IDLE = 3'b000;
    localparam S_INIT = 3'b001;
    localparam S_FETCH_DP_PREV = 3'b010;
    localparam S_COMPARE = 3'b011;
    localparam S_UPDATE_DP = 3'b100;
    localparam S_RESULT = 3'b101;

    reg [2:0] current_state, next_state;
    
    // DP Table Storage (8x8 array of 16-bit values)
    // We use a dual-port RAM style inference or registers.
    // Since size is small (8x8 = 64 entries), we can use registers or a memory block.
    // To ensure predictable latency and logic, we will use 64 16-bit registers.
    reg [15:0] dp_reg [0:63];
    
    // Control Registers
    reg [2:0] row_idx; // Iterates 0 to 7 (i)
    reg [2:0] col_idx; // Iterates 0 to 7 (j)
    reg [15:0] val_a_i; // Cached a[i]
    reg [15:0] val_a_j; // Cached a[j]
    reg [15:0] val_dp_prev_i; // Cached dp[i-1][i]
    reg [15:0] val_dp_prev_j; // Cached dp[i-1][j]
    reg [15:0] temp_sum;
    
    // State Transition and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            done <= 1'b0;
            result <= 16'b0;
            row_idx <= 3'b0;
            col_idx <= 3'b0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= S_INIT;
                        row_idx <= 3'b0;
                        col_idx <= 3'b0;
                    end
                end

                S_INIT: begin
                    // Initialize Row 0 (i=0)
                    // Logic: if a[j] > a[0] then dp[0][j] = a[j] + a[0], else a[j]
                    val_a_i <= a[0];
                    val_a_j <= a[col_idx];
                    
                    // We wait one cycle for read/mux, or do it combinational if registers are nearby.
                    // Let's compute in next state to be clean.
                    current_state <= S_UPDATE_DP;
                    // We need a flag to know we are in init mode vs normal update
                    // Or just handle logic explicitly in UPDATE_DP state.
                end

                S_FETCH_DP_PREV: begin
                    // Fetch values for comparison and calculation
                    val_a_i <= a[row_idx];
                    val_a_j <= a[col_idx];
                    
                    // Fetch dp[i-1][i] and dp[i-1][j]
                    // Index for dp[i-1][i]: (row_idx - 1) * 8 + i
                    // Index for dp[i-1][j]: (row_idx - 1) * 8 + col_idx
                    // Note: row_idx is the CURRENT target row index in this state
                    
                    if (row_idx > 0) begin
                        val_dp_prev_i <= dp_reg[(row_idx - 1) * 8 + row_idx]; // Wait, dp[i][j] means row i, col j. dp[i-1][i] is row (i-1), col (i)
                        val_dp_prev_j <= dp_reg[(row_idx - 1) * 8 + col_idx];
                    end
                    
                    current_state <= S_COMPARE;
                end

                S_COMPARE: begin
                    // Determine dp[row_idx][col_idx]
                    if (row_idx == 0) begin
                        // Init logic: dp[0][j] = (a[j] > a[0]) ? (a[j] + a[0]) : a[j]
                        if (val_a_j > val_a_i) begin
                            temp_sum <= val_a_j + val_a_i;
                        end else begin
                            temp_sum <= val_a_j;
                        end
                    end else begin
                        // Normal logic: 
                        // If (a[j] > a[i] && j > i): dp[i][j] = max(dp[i-1][i] + a[j], dp[i-1][j])
                        // Else: dp[i][j] = dp[i-1][j]
                        
                        if (val_a_j > val_a_i && col_idx > row_idx) begin
                            // Calculate dp[i-1][i] + a[j]
                            temp_sum <= val_dp_prev_i + val_a_j;
                            // Compare with dp[i-1][j] (stored in val_dp_prev_j)
                            // We will do the max logic in UPDATE_DP or here.
                            // Let's do Max logic here.
                            if ((val_dp_prev_i + val_a_j) > val_dp_prev_j) begin
                                dp_reg[row_idx * 8 + col_idx] <= val_dp_prev_i + val_a_j;
                            end else begin
                                dp_reg[row_idx * 8 + col_idx] <= val_dp_prev_j;
                            end
                        end else begin
                            dp_reg[row_idx * 8 + col_idx] <= val_dp_prev_j;
                        end
                    end
                    
                    current_state <= S_UPDATE_DP;
                end

                S_UPDATE_DP: begin
                    // Write result to RAM (handle Init case which bypasses COMPARE slightly or modifies logic)
                    // Actually, the flow S_INIT -> S_UPDATE_DP for Init requires different logic.
                    // Let's restructure to be cleaner.
                    // Reset to S_IDLE if done? No, iterate.
                    
                    // If we were in Init mode (row_idx=0), logic was set in S_INIT. 
                    // We need to commit it here if we came from S_INIT.
                    if (current_state == S_INIT || (current_state == S_FETCH_DP_PREV)) begin
                        // We need to handle the commit properly.
                        // If we are here from S_INIT (row_idx=0), we need to write.
                        // Let's merge S_INIT and S_FETCH logic to avoid state explosion.
                    end
                    
                    // Increment Indices
                    if (col_idx < 7) begin
                        col_idx <= col_idx + 1;
                    end else begin
                        col_idx <= 0;
                        if (row_idx < 7) begin
                            row_idx <= row_idx + 1;
                            // Logic: We need to stop if we reached i_index (for the row part) 
                            // But the spec says "compute dp[i][j] for all j". 
                            // Wait, the task is specific: "After computing up to i_index".
                            // So we stop processing rows when row_idx > i_index? 
                            // Actually, the loop is "For i from 1 to 7". But we only need result at i_index.
                            // If we stop at i_index, we might miss dependencies for future rows? 
                            // No, dp[i][j] depends on dp[i-1][*].
                            // So we MUST compute ALL rows 0..i_index.
                            // We should stop row processing when we have computed row i_index.
                            if (row_idx == i_index) begin
                                // We are done with computation phase (if we just finished row i_index)
                                // But wait, row_idx is incremented after writing col 7.
                                // So if we finished row i_index, we are done.
                                current_state <= S_RESULT;
                            end else begin
                                current_state <= S_FETCH_DP_PREV; // Go fetch next row's prev values
                            end
                        end else begin
                            // Row 7 done (or max allowed, but we limited by i_index usually)
                            current_state <= S_RESULT;
                        end
                    end
                    
                    // Logic handling for the WRITE operation
                    // We need to compute and write inside S_FETCH_DP_PREV or a dedicated state to avoid race.
                    // Let's put the WRITE and Logic inside S_FETCH_DP_PREV, and S_INIT does the first row write.
                end

                S_RESULT: begin
                    result <= dp_reg[i_index * 8 + k_index];
                    done <= 1'b1;
                    current_state <= S_IDLE;
                end
            endcase
        end
    end

    // Re-implementing the state machine with clearer logic flow:
    // The previous draft was getting messy with states jumping. 
    // Let's use a linear flow: 
    // IDLE -> INIT_ROW_0 (Loop j) -> LOOP_ROWS (i=1 to i_index) (Loop j) -> RESULT
    
    // Final Implementation override
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            done <= 1'b0;
            result <= 16'b0;
            row_idx <= 3'b0;
            col_idx <= 3'b0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= S_INIT;
                        row_idx <= 3'b0;
                        col_idx <= 3'b0;
                    end
                end

                S_INIT: begin
                    // Compute dp[0][col_idx]
                    if (a[col_idx] > a[0]) begin
                        dp_reg[0*8 + col_idx] <= a[0] + a[col_idx];
                    end else begin
                        dp_reg[0*8 + col_idx] <= a[col_idx];
                    end

                    // Next column
                    if (col_idx < 7) begin
                        col_idx <= col_idx + 1;
                    end else begin
                        // Check if we are done (i_index = 0)
                        if (i_index == 0) begin
                            current_state <= S_RESULT;
                        end else begin
                            row_idx <= 3'd1; // Start row 1
                            col_idx <= 3'd0;
                            current_state <= S_FETCH_DP_PREV;
                        end
                    end
                end

                S_FETCH_DP_PREV: begin
                    // We need values for formula:
                    // If (a[j] > a[i] && j > i) dp[i][j] = max(dp[i-1][i] + a[j], dp[i-1][j])
                    // Else dp[i][j] = dp[i-1][j]
                    
                    // Load needed values
                    val_a_i <= a[row_idx];
                    val_a_j <= a[col_idx];
                    val_dp_prev_i <= dp_reg[(row_idx - 1) * 8 + row_idx]; // dp[i-1][i]
                    val_dp_prev_j <= dp_reg[(row_idx - 1) * 8 + col_idx]; // dp[i-1][j]
                    
                    current_state <= S_COMPARE;
                end

                S_COMPARE: begin
                    // Compute and Write dp[i][j]
                    if (val_a_j > val_a_i && col_idx > row_idx) begin
                        // max(dp[i-1][i] + a[j], dp[i-1][j])
                        if ((val_dp_prev_i + val_a_j) > val_dp_prev_j) begin
                            dp_reg[row_idx * 8 + col_idx] <= val_dp_prev_i + val_a_j;
                        end else begin
                            dp_reg[row_idx * 8 + col_idx] <= val_dp_prev_j;
                        end
                    end else begin
                        dp_reg[row_idx * 8 + col_idx] <= val_dp_prev_j;
                    end

                    // Increment Column
                    if (col_idx < 7) begin
                        col_idx <= col_idx + 1;
                        current_state <= S_FETCH_DP_PREV;
                    end else begin
                        // Row Finished
                        if (row_idx == i_index) begin
                            current_state <= S_RESULT;
                        end else begin
                            row_idx <= row_idx + 1;
                            col_idx <= 0;
                            current_state <= S_FETCH_DP_PREV;
                        end
                    end
                end

                S_RESULT: begin
                    result <= dp_reg[i_index * 8 + k_index];
                    done <= 1'b1;
                    current_state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
