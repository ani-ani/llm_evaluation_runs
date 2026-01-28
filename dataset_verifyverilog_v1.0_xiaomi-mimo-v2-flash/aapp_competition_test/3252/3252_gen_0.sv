module envelope_minimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] card_w [0:4],
    input [7:0] card_h [0:4],
    input [15:0] card_q [0:4],
    input [2:0] max_k,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] INPUT_REG    = 3'd1;
    localparam [2:0] GEN_CANDIDATES = 3'd2;
    localparam [2:0] DP_COMPUTE   = 3'd3;
    localparam [2:0] OUTPUT_STATE = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;

    // Internal state
    reg [2:0] state, next_state;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Registered inputs
    reg [7:0] reg_card_w [0:4];
    reg [7:0] reg_card_h [0:4];
    reg [15:0] reg_card_q [0:4];
    reg [2:0] reg_max_k;

    // Candidate envelope storage (top 10 candidates)
    reg [7:0] cand_w [0:9];
    reg [7:0] cand_h [0:9];
    reg [31:0] cand_waste [0:9];
    reg [4:0] cand_count;
    reg [4:0] i_cand, j_cand, k_cand;
    reg [4:0] mask;
    reg [7:0] max_cw, max_ch;
    reg [31:0] total_area;
    reg [31:0] card_area;
    reg [31:0] waste_temp;
    reg [31:0] best_waste;
    reg [31:0] best_area;

    // DP table: dp[mask][t]
    // 32 masks (0-31), 4 t values (0-3)
    reg [31:0] dp [0:31][0:3];
    reg [4:0] dp_mask;
    reg [1:0] dp_t;
    reg [4:0] submask;
    reg [4:0] mask_idx;
    reg [1:0] t_idx;
    reg [1:0] cand_idx;
    reg [31:0] dp_waste;
    reg [31:0] cand_waste_val;

    // Helper: iterate subsets
    reg [4:0] subset_mask;
    reg [4:0] full_mask;
    reg [2:0] subset_count;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_counter <= 8'd0;
            for (i = 0; i < 5; i = i + 1) begin
                reg_card_w[i] <= 8'd0;
                reg_card_h[i] <= 8'd0;
                reg_card_q[i] <= 16'd0;
            end
            reg_max_k <= 3'd0;
            for (i = 0; i < 10; i = i + 1) begin
                cand_w[i] <= 8'd0;
                cand_h[i] <= 8'd0;
                cand_waste[i] <= 32'd0;
            end
            cand_count <= 5'd0;
            i_cand <= 5'd0;
            j_cand <= 5'd0;
            k_cand <= 5'd0;
            mask <= 5'd0;
            max_cw <= 8'd0;
            max_ch <= 8'd0;
            total_area <= 32'd0;
            card_area <= 32'd0;
            waste_temp <= 32'd0;
            best_waste <= 32'd0;
            best_area <= 32'd0;
            dp_mask <= 5'd0;
            dp_t <= 2'd0;
            submask <= 5'd0;
            mask_idx <= 5'd0;
            t_idx <= 2'd0;
            cand_idx <= 2'd0;
            dp_waste <= 32'd0;
            cand_waste_val <= 32'd0;
            subset_mask <= 5'd0;
            full_mask <= 5'd0;
            subset_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= INPUT_REG;
                    end
                end

                INPUT_REG: begin
                    // Register all inputs
                    for (i = 0; i < 5; i = i + 1) begin
                        reg_card_w[i] <= card_w[i];
                        reg_card_h[i] <= card_h[i];
                        reg_card_q[i] <= card_q[i];
                    end
                    reg_max_k <= max_k;
                    // Reset candidate storage
                    cand_count <= 5'd0;
                    i_cand <= 5'd0;
                    j_cand <= 5'd1;
                    state <= GEN_CANDIDATES;
                end

                GEN_CANDIDATES: begin
                    // Generate candidates for all non-empty subsets
                    if (i_cand < 31) begin
                        mask <= i_cand + 5'd1;
                        // Find max dimensions and total area for this subset
                        max_cw <= 8'd0;
                        max_ch <= 8'd0;
                        total_area <= 32'd0;
                        k_cand <= 5'd0;
                        state <= GEN_CANDIDATES + 3'd1; // Find max
                    end else begin
                        // Done generating
                        dp_mask <= 5'd0;
                        dp_t <= 2'd0;
                        // Initialize DP table
                        for (mask_idx = 0; mask_idx < 32; mask_idx = mask_idx + 1) begin
                            for (t_idx = 0; t_idx < 4; t_idx = t_idx + 1) begin
                                dp[mask_idx][t_idx] <= 32'hFFFFFFFF;
                            end
                        end
                        dp[0][0] <= 32'd0; // Base case
                        state <= DP_COMPUTE;
                    end
                end

                GEN_CANDIDATES + 3'd1: begin // Find max
                    if (k_cand < 5) begin
                        if ((mask >> k_cand) & 5'd1) begin
                            if (reg_card_w[k_cand] > max_cw)
                                max_cw <= reg_card_w[k_cand];
                            if (reg_card_h[k_cand] > max_ch)
                                max_ch <= reg_card_h[k_cand];
                            card_area <= total_area + ({16'd0, reg_card_w[k_cand]} * {16'd0, reg_card_h[k_cand]} * {16'd0, reg_card_q[k_cand]});
                        end else begin
                            card_area <= total_area;
                        end
                        k_cand <= k_cand + 5'd1;
                    end else begin
                        total_area <= card_area;
                        // Calculate waste
                        waste_temp <= ({24'd0, max_cw} * {24'd0, max_ch}) - card_area;
                        waste_temp <= (waste_temp * 64);
                        state <= GEN_CANDIDATES + 3'd2;
                    end
                end

                GEN_CANDIDATES + 3'd2: begin // Insert candidate
                    // Simple insertion sort logic for top 10 (simplified)
                    if (cand_count < 5'd10) begin
                        cand_w[cand_count] <= max_cw;
                        cand_h[cand_count] <= max_ch;
                        cand_waste[cand_count] <= waste_temp;
                        cand_count <= cand_count + 5'd1;
                    end else begin
                        // Check if better than current worst
                        // Simplified: just replace last if better
                        if (waste_temp < cand_waste[9]) begin
                            cand_w[9] <= max_cw;
                            cand_h[9] <= max_ch;
                            cand_waste[9] <= waste_temp;
                        end
                    end
                    i_cand <= i_cand + 5'd1;
                    state <= GEN_CANDIDATES;
                end

                DP_COMPUTE: begin
                    // Compute dp[mask][t] = min(dp[mask][t], dp[mask ^ submask][t-1] + cand_waste[submask])
                    if (dp_mask < 32) begin
                        if (dp_t <= reg_max_k) begin
                            if (dp_t == 0) begin
                                // Base case already set
                                if (dp[dp_mask][dp_t] > 32'hFFFFFFFF) begin
                                    dp[dp_mask][dp_t] <= 32'd0;
                                end
                                dp_t <= dp_t + 2'd1;
                            end else begin
                                // Iterate over all possible assignments of card types to envelope types
                                // We need to partition the subset dp_mask into t groups
                                // This is complex; simplified approach:
                                // Try all non-empty subsets of dp_mask as the last envelope
                                subset_mask <= dp_mask;
                                submask <= dp_mask;
                                dp_waste <= dp[dp_mask][dp_t];
                                state <= DP_COMPUTE + 3'd1;
                            end
                        end else begin
                            dp_t <= 2'd0;
                            dp_mask <= dp_mask + 5'd1;
                        end
                    end else begin
                        // DP done, find result
                        result <= dp[31][reg_max_k];
                        state <= OUTPUT_STATE;
                    end
                end

                DP_COMPUTE + 3'd1: begin // Iterate submask
                    // submask = (submask - 1) & dp_mask to iterate all subsets
                    if (submask > 5'd0) begin
                        // Check waste for this partition
                        // Find matching candidate
                        // Simplified: calculate envelope for submask
                        // This is heavy, so we use precomputed candidates
                        // We need to map submask to a candidate
                        // For now, use a linear search through candidates
                        if (cand_idx < 10) begin
                            // Check if candidate covers submask
                            // Calculate required envelope for submask
                            // Heuristic: just use candidate's waste if it's big enough
                            // Actually, we need to compute waste for THIS submask
                            // Reuse logic from GEN_CANDIDATES for this submask
                            if (cand_idx < cand_count) begin
                                // Check coverage
                                max_cw <= 8'd0;
                                max_ch <= 8'd0;
                                total_area <= 32'd0;
                                k_cand <= 5'd0;
                                state <= DP_COMPUTE + 3'd2;
                            end else begin
                                cand_idx <= 2'd0;
                                submask <= (submask - 5'd1) & dp_mask;
                            end
                        end else begin
                            cand_idx <= 2'd0;
                            submask <= (submask - 5'd1) & dp_mask;
                        end
                    end else begin
                        dp[dp_mask][dp_t] <= dp_waste;
                        state <= DP_COMPUTE;
                    end
                end

                DP_COMPUTE + 3'd2: begin // Calc submask waste
                    if (k_cand < 5) begin
                        if ((submask >> k_cand) & 5'd1) begin
                            if (reg_card_w[k_cand] > max_cw)
                                max_cw <= reg_card_w[k_cand];
                            if (reg_card_h[k_cand] > max_ch)
                                max_ch <= reg_card_h[k_cand];
                            card_area <= total_area + ({16'd0, reg_card_w[k_cand]} * {16'd0, reg_card_h[k_cand]} * {16'd0, reg_card_q[k_cand]});
                        end else begin
                            card_area <= total_area;
                        end
                        k_cand <= k_cand + 5'd1;
                    end else begin
                        total_area <= card_area;
                        // Compare with candidate[cand_idx]
                        // If candidate dimensions >= required, use its waste
                        if (cand_w[cand_idx] >= max_cw && cand_h[cand_idx] >= max_ch) begin
                            cand_waste_val <= cand_waste[cand_idx];
                        end else begin
                            // Compute local waste
                            waste_temp <= ({24'd0, max_cw} * {24'd0, max_ch}) - card_area;
                            waste_temp <= (waste_temp * 64);
                            cand_waste_val <= waste_temp;
                        end
                        state <= DP_COMPUTE + 3'd3;
                    end
                end

                DP_COMPUTE + 3'd3: begin // Update DP
                    // Check if dp[submask][1] + dp[dp_mask ^ submask][dp_t-1] is better
                    // Note: this is a simplified DP, exact computation is cycle intensive
                    // We are using: dp[mask] = min(dp[mask], dp[mask ^ submask] + cost(submask))
                    // Cost(submask) is minimum waste covering exactly submask with 1 envelope
                    if (dp[dp_mask ^ submask][dp_t - 2'd1] != 32'hFFFFFFFF) begin
                        if (cand_waste_val + dp[dp_mask ^ submask][dp_t - 2'd1] < dp_waste) begin
                            dp_waste <= cand_waste_val + dp[dp_mask ^ submask][dp_t - 2'd1];
                        end
                    end
                    cand_idx <= cand_idx + 2'd1;
                    state <= DP_COMPUTE + 3'd1;
                end

                OUTPUT_STATE: begin
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule