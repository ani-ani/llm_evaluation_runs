module critical_elements(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] seq [0:7],
    output reg [7:0] critical_mask,
    output reg done,
    output reg error
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam CHECK_L0 = 4'd1;
    localparam CHECK_L1 = 4'd2;
    localparam CHECK_L2 = 4'd3;
    localparam CHECK_L3 = 4'd4;
    localparam CHECK_L4 = 4'd5;
    localparam CHECK_L5 = 4'd6;
    localparam CHECK_L6 = 4'd7;
    localparam CHECK_L7 = 4'd8;
    localparam DONE = 4'd9;

    reg [3:0] state;
    reg [3:0] next_state;

    // Internal registers
    reg [7:0] L0;          // Original LIS length
    reg [7:0] Li;          // Current LIS length (for removed element)
    reg [7:0] dp [0:7];    // DP array
    reg [2:0] dp_idx;      // Outer loop index for DP
    reg [2:0] inner_j;     // Inner loop index for DP
    reg [7:0] max_len;     // Max length found in current computation

    // Combinational helper signals
    wire [3:0] skip_idx;   // Index to skip (8 if none)
    wire [3:0] limit;      // Loop limit (n or n-1)
    wire [2:0] real_idx;   // Mapped index in seq array

    // Helper assignments
    assign skip_idx = (state == IDLE) ? 4'd8 : {1'b0, state} - 4'd1;
    assign limit = (state == IDLE) ? {1'b0, n} : {1'b0, n} - 4'd1;
    assign real_idx = (dp_idx >= skip_idx[2:0]) ? dp_idx + 3'h1 : dp_idx;

    // Next State Logic (Combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n < 2 || n > 8) begin
                        next_state = DONE;
                    end else if (dp_idx >= n) begin
                        // L0 computation finished inside IDLE
                        next_state = CHECK_L0;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            CHECK_L0, CHECK_L1, CHECK_L2, CHECK_L3, CHECK_L4, CHECK_L5, CHECK_L6, CHECK_L7: begin
                if (dp_idx >= limit) begin
                    // Computation for this state finished
                    if (skip_idx == n - 1) begin
                        // We just finished checking the last element
                        next_state = DONE;
                    end else begin
                        next_state = state + 1;
                    end
                end
            end
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            critical_mask <= 8'h00;
            done <= 1'b0;
            error <= 1'b0;
            L0 <= 8'h00;
            dp_idx <= 3'h0;
            inner_j <= 3'h0;
            max_len <= 8'h00;
            // Reset dp array explicitly to avoid latch inference
            dp[0] <= 8'h00; dp[1] <= 8'h00; dp[2] <= 8'h00; dp[3] <= 8'h00;
            dp[4] <= 8'h00; dp[5] <= 8'h00; dp[6] <= 8'h00; dp[7] <= 8'h00;
        end else begin
            state <= next_state;

            // Default updates (reset counters when transitioning to a new computation state)
            if (state != next_state) begin
                if (next_state == IDLE || next_state == CHECK_L0) begin
                    // Start of new computation (either L0 or first removal)
                    dp_idx <= 3'h0;
                    inner_j <= 3'h0;
                    max_len <= 8'h00;
                    // Clear DP array for next use
                    dp[0] <= 8'h00; dp[1] <= 8'h00; dp[2] <= 8'h00; dp[3] <= 8'h00;
                    dp[4] <= 8'h00; dp[5] <= 8'h00; dp[6] <= 8'h00; dp[7] <= 8'h00;
                end
            end

            // Computation Logic (Active in IDLE and CHECK_Lx states)
            if (state == IDLE && start && n >= 2 && n <= 8) begin
                // Perform L0 DP step
                if (dp_idx < n) begin
                    if (inner_j < dp_idx) begin
                        if (seq[inner_j] < seq[dp_idx]) begin
                            if (dp[inner_j] + 1 > dp[dp_idx]) begin
                                dp[dp_idx] <= dp[inner_j] + 1;
                            end
                        end
                        inner_j <= inner_j + 1;
                    end else begin
                        // End inner loop
                        if (dp[dp_idx] == 8'h00) dp[dp_idx] <= 8'h01;
                        if (dp[dp_idx] > max_len) max_len <= dp[dp_idx];
                        // Prepare for next iteration (reset next dp slot)
                        if (dp_idx + 1 < 8) dp[dp_idx + 1] <= 8'h00;
                        dp_idx <= dp_idx + 1;
                        inner_j <= 3'h0;
                    end
                end else if (dp_idx == n) begin
                    // L0 Calculation Complete (waiting for transition to CHECK_L0)
                    L0 <= max_len;
                end
            end else if (state >= CHECK_L0 && state <= CHECK_L7) begin
                // Perform Li DP step
                if (dp_idx < limit[2:0]) begin // limit is n-1, fits in 3 bits if n<=8
                    if (inner_j < dp_idx) begin
                        // Use real_idx to access seq, but check bounds on real_idx implied by limit logic
                        // real_idx logic handles the skipping
                        if (seq[real_idx] < seq[real_idx]) begin // Wait, we need to compare current value with previous values
                            // In standard LIS DP, we need value of current element (val[i]) vs previous (val[j]).
                            // Here we need seq[real_idx(dp_idx)] vs seq[real_idx(inner_j)].

                            // Helper for value comparison
                            if (seq[real_idx] < seq[real_idx]) begin 
                                // This is wrong, real_idx depends on dp_idx.
                                // We need to evaluate real_idx for dp_idx and inner_j separately.
                                // Since we can't have combinational logic inside always_ff easily, we pre-calculate or inline.

                                // Let's inline the mapping logic for comparison:
                                // val_curr = (dp_idx >= skip_idx) ? seq[dp_idx+1] : seq[dp_idx];
                                // val_prev = (inner_j >= skip_idx) ? seq[inner_j+1] : seq[inner_j];

                                reg [2:0] idx_curr = (dp_idx >= skip_idx[2:0]) ? dp_idx + 3'h1 : dp_idx;
                                reg [2:0] idx_prev = (inner_j >= skip_idx[2:0]) ? inner_j + 3'h1 : inner_j;

                                if (seq[idx_prev] < seq[idx_curr]) begin
                                    if (dp[inner_j] + 1 > dp[dp_idx]) begin
                                        dp[dp_idx] <= dp[inner_j] + 1;
                                    end
                                end
                            end
                        end else begin
                           // Same logic without if nesting for the comparison block:
                           // Just do the comparison directly:
                           reg [2:0] idx_curr = (dp_idx >= skip_idx[2:0]) ? dp_idx + 3'h1 : dp_idx;
                           reg [2:0] idx_prev = (inner_j >= skip_idx[2:0]) ? inner_j + 3'h1 : inner_j;
                           if (seq[idx_prev] < seq[idx_curr]) begin
                                if (dp[inner_j] + 1 > dp[dp_idx]) begin
                                    dp[dp_idx] <= dp[inner_j] + 1;
                                end
                           end
                        end
                        inner_j <= inner_j + 1;
                    end else begin
                        // End inner loop for Li
                        // Determine value of current element to set initial dp if 0
                        reg [2:0] idx_curr = (dp_idx >= skip_idx[2:0]) ? dp_idx + 3'h1 : dp_idx;
                        if (dp[dp_idx] == 8'h00) dp[dp_idx] <= 8'h01;
                        if (dp[dp_idx] > max_len) max_len <= dp[dp_idx];

                        if (dp_idx + 1 < 8) dp[dp_idx + 1] <= 8'h00;
                        dp_idx <= dp_idx + 1;
                        inner_j <= 3'h0;
                    end
                end else if (dp_idx == limit[2:0]) begin
                    // Li Calculation Complete
                    Li <= max_len;
                    // Update mask immediately if Li < L0
                    // Note: L0 is stable from previous state.
                    if (max_len < L0) begin
                        // Determine which bit to set. Bit = skip_idx (which is state - 1)
                        critical_mask[skip_idx[2:0]] <= 1'b1;
                    end
                    // We wait for transition to next state, handled by next_state logic
                end
            end

            // Done and Error signals
            if (state == DONE && next_state == DONE) begin
                done <= 1'b1;
            end else if (state == IDLE && start && (n < 2 || n > 8)) begin
                error <= 1'b1;
                done <= 1'b1;
            end else if (next_state != DONE) begin
                done <= 1'b0;
                error <= 1'b0;
            end
        end
    end

endmodule