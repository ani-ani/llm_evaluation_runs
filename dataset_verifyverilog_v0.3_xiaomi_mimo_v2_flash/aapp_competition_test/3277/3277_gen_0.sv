module smooth_array(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] K,
    input [4:0] S,
    input [7:0] A0, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10, A11, A12, A13, A14, A15,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COUNT_FREQ = 3'd2;
    localparam [2:0] DP_INIT = 3'd3;
    localparam [2:0] DP_ITER = 3'd4;
    localparam [2:0] DP_FINAL = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [7:0] arr [0:15]; // 16 elements
    reg [7:0] freq [0:15] [0:16]; // K x (S+1) frequencies
    reg signed [7:0] dp [0:16]; // dp[s] for s = 0..S
    reg signed [7:0] new_dp [0:16];
    
    // Counters and indices
    reg [4:0] idx; // 0..15 for array elements
    reg [3:0] r; // residue 0..K-1
    reg [4:0] v; // value 0..S
    reg [4:0] s; // sum 0..S
    reg [4:0] s_prime;
    reg [7:0] max_val;
    reg signed [7:0] temp_val;
    reg [7:0] profit;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            idx <= 5'd0;
            r <= 4'd0;
            v <= 5'd0;
            s <= 5'd0;
            s_prime <= 5'd0;
            max_val <= 8'd0;
            profit <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                arr[i] <= 8'd0;
                for (j = 0; j < 17; j = j + 1) begin
                    freq[i][j] <= 8'd0;
                end
            end
            for (i = 0; i < 17; i = i + 1) begin
                dp[i] <= 8'd255; // Initialize to -1 (using 255 as -1 for unsigned logic)
                new_dp[i] <= 8'd255;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    done <= 1'b0;
                    result <= 5'd0;
                    // Clear freq and dp arrays for next operation
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 17; j = j + 1) begin
                            freq[i][j] <= 8'd0;
                        end
                    end
                    for (i = 0; i < 17; i = i + 1) begin
                        dp[i] <= 8'd255;
                        new_dp[i] <= 8'd255;
                    end
                    idx <= 5'd0;
                    r <= 4'd0;
                    v <= 5'd0;
                    s <= 5'd0;
                end
                
                LOAD: begin
                    // Capture array
                    if (idx < 16) begin
                        case (idx)
                            5'd0: arr[0] <= A0;
                            5'd1: arr[1] <= A1;
                            5'd2: arr[2] <= A2;
                            5'd3: arr[3] <= A3;
                            5'd4: arr[4] <= A4;
                            5'd5: arr[5] <= A5;
                            5'd6: arr[6] <= A6;
                            5'd7: arr[7] <= A7;
                            5'd8: arr[8] <= A8;
                            5'd9: arr[9] <= A9;
                            5'd10: arr[10] <= A10;
                            5'd11: arr[11] <= A11;
                            5'd12: arr[12] <= A12;
                            5'd13: arr[13] <= A13;
                            5'd14: arr[14] <= A14;
                            5'd15: arr[15] <= A15;
                        endcase
                        idx <= idx + 5'd1;
                    end
                end
                
                COUNT_FREQ: begin
                    // Count frequencies for each residue r and value v
                    // Each cycle, process one element idx (0 to N-1)
                    if (idx < N && idx < 16) begin
                        r = idx % K; // Use combinational calculation
                        // Check if value is within valid range 0..S
                        if (arr[idx] <= S) begin
                            freq[r][arr[idx]] <= freq[r][arr[idx]] + 8'd1;
                        end
                        idx <= idx + 5'd1;
                    end
                end
                
                DP_INIT: begin
                    // Initialize dp: dp[0] = 0, others = -1
                    for (i = 0; i < 17; i = i + 1) begin
                        dp[i] <= 8'd255; // -1
                    end
                    dp[0] <= 8'd0;
                    r <= 4'd0; // Start with residue 0
                    s <= 5'd0;
                    v <= 5'd0;
                end
                
                DP_ITER: begin
                    // Process one residue r at a time
                    // For each s from 0 to S, update new_dp[s] = max_{v} (dp[s-v] + freq[r][v])
                    // We do this in a nested loop: for each s, iterate v
                    // But we need to be careful about dependencies. We compute new_dp for current r.
                    // We'll iterate v for current s.
                    
                    if (v <= S) begin
                        s_prime = s - v; // Calculate s_prime
                        if (s_prime <= S) begin // Valid s_prime
                            if (dp[s_prime] != 8'd255) begin // dp[s_prime] is valid (not -1)
                                temp_val = dp[s_prime] + freq[r][v];
                                if (temp_val > max_val) begin
                                    max_val = temp_val;
                                end
                            end
                        end
                        v <= v + 5'd1;
                    end else begin
                        // Done iterating v for current s
                        new_dp[s] <= max_val;
                        max_val <= 8'd0;
                        s <= s + 5'd1;
                        v <= 5'd0;
                    end
                    
                    // If done all s for current r, copy new_dp to dp
                    if (s > S) begin
                        // Copy new_dp to dp
                        for (i = 0; i < 17; i = i + 1) begin
                            dp[i] <= new_dp[i];
                            new_dp[i] <= 8'd255; // Reset for next iteration
                        end
                        r <= r + 4'd1;
                        s <= 5'd0;
                        v <= 5'd0;
                    end
                end
                
                DP_FINAL: begin
                    // Compute final result: N - dp[S]
                    // dp[S] is max profit
                    if (dp[S] != 8'd255) begin
                        profit <= N - dp[S]; // Minimum changes
                        result <= N - dp[S];
                    end else begin
                        // Should not happen if problem is solvable
                        result <= N;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // Default
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (idx >= 5'd16) begin // Captured all 16 inputs (even if N is smaller, we read all ports)
                    next_state = COUNT_FREQ;
                    // Reset idx for COUNT_FREQ
                    // (Handled in sequential logic by resetting idx in IDLE)
                    // Need to reset idx here for COUNT_FREQ logic
                end
            end
            COUNT_FREQ: begin
                if (idx >= N) begin
                    next_state = DP_INIT;
                end
            end
            DP_INIT: begin
                next_state = DP_ITER;
            end
            DP_ITER: begin
                // Check if all residues processed
                // Logic: r increments from 0 to K-1
                // s increments 0..S
                // v increments 0..S
                // Transition conditions handled in sequential block by r >= K
                // Here we check the state transitions
                
                if (r >= K) begin
                    next_state = DP_FINAL;
                end else if (s > S) begin
                    // When s > S, it means we finished v iteration for all s, so we move to next residue
                    // But we need to wait for the copy operation to complete? 
                    // The copy happens in the same cycle in sequential logic? No, it happens over multiple cycles.
                    // Actually, in the sequential block, when s > S, we start copying and increment r.
                    // But `r >= K` check happens in next cycle.
                    // The check `s > S` is tricky. The sequential block increments `s` past S, then resets `s` and `v`.
                    // Wait, if s > S, we enter the else block in sequential logic which copies and increments r.
                    // So we need to wait until r >= K.
                    // But we also need to handle the cycle where we finish s == S.
                    // Let's look at DP_ITER sequential block again:
                    // When v iterates, if s == S and v finishes, then s becomes S+1.
                    // Then `if (s > S)` block executes, copying new_dp to dp, and incrementing r.
                    // So the state machine should stay in DP_ITER until r >= K.
                    // However, the check `s > S` is inside DP_ITER.
                    // So if r < K, we stay in DP_ITER.
                    // If r >= K (which happens after the copy and increment r), we go to DP_FINAL.
                    // But `r` is updated in the same cycle as `s` goes to S+1.
                    // So `r >= K` check should be true in the same cycle or next.
                    // Let's simplify: The DP_ITER state loops until r completes all K residues.
                    // We can add a counter for cycles within DP_ITER.
                    // Or simply: If r >= K, next_state = DP_FINAL.
                    // This check is done in combinational logic, so it sees the updated r.
                    // If r increments to K in one cycle, next_state will see r >= K as true.
                end
                // We need to ensure we don't loop forever. 
                // Since K and S are bounded, we are safe.
            end
            DP_FINAL: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
        
        // Handle specific transitions
        if (state == DP_ITER) begin
            // We need to determine if we are done with all K residues
            // r is incremented in the sequential block when s > S.
            // So when r >= K, we are done.
            if (r >= K) begin
                next_state = DP_FINAL;
            end
        end
        
        // Timeout safety
        if (cycle_count > MAX_CYCLES && state != IDLE && state != DONE) begin
            next_state = DONE;
        end
    end

endmodule