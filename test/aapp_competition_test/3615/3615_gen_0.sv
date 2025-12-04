module max_connected_towers(
    input              clk,
    input              rst_n,
    input              start,
    input      [15:0]  tower_x [0:7],
    input      [15:0]  tower_y [0:7],
    input      [3:0]   num_towers,
    output reg [3:0]   max_count,
    output reg         done
);

    // ------------------------------------------------------------------
    // Local parameters
    // ------------------------------------------------------------------
    localparam DIST2_THRESH = 32'd16384; // 4.0 in Q10.6: (2.0)^2 << 12 = 0x4000

    // FSM states
    localparam S_IDLE        = 4'd0;
    localparam S_LATCH       = 4'd1;
    localparam S_BUILD_ADJ   = 4'd2;
    localparam S_DSU_INIT    = 4'd3;
    localparam S_DSU_UNION   = 4'd4;
    localparam S_DSU_SIZE    = 4'd5;
    localparam S_CAND_PREP   = 4'd6;
    localparam S_CAND_SCAN   = 4'd7;
    localparam S_DONE        = 4'd8;

    // ------------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------------

    reg [3:0] cur_n;

    // Latched coordinates
    reg [15:0] x_reg [0:7];
    reg [15:0] y_reg [0:7];

    // Adjacency matrix: adj[i][j] == 1 if connected (i<j used for build, read symmetric)
    reg adj [0:7][0:7];

    // DSU: parent and size per node
    reg [2:0] parent [0:7];
    reg [3:0] comp_size [0:7];

    // Per-root component size (for quick access)
    reg [3:0] root_size [0:7];

    // Candidate evaluation
    reg [3:0] best_combined; // best connected size (existing) for any candidate
    reg [3:0] cand_index;    // which tower is candidate center

    // Loop indices
    reg [3:0] i_idx;
    reg [3:0] j_idx;

    // For find-root operation
    reg [2:0] find_node;
    reg [2:0] find_cur;
    reg [2:0] find_next;
    reg       find_busy;
    reg [2:0] find_root_res;

    // For candidate union mask and visited roots
    reg [7:0] cand_union_mask;   // which towers within 2km of candidate
    reg [7:0] visited_roots;     // avoid double counting a root
    reg [3:0] cand_sum;          // sum of component sizes for candidate

    reg [3:0] state, next_state;

    // ------------------------------------------------------------------
    // Helper: squared distance (combinational)
    // ------------------------------------------------------------------
    function automatic [31:0] dist2_sq;
        input [15:0] x1, x2, y1, y2;
        reg signed [16:0] dx;
        reg signed [16:0] dy;
        reg [31:0] dx2;
        reg [31:0] dy2;
    begin
        dx = $signed(x1) - $signed(x2);
        dy = $signed(y1) - $signed(y2);
        dx2 = dx * dx;
        dy2 = dy * dy;
        dist2_sq = dx2 + dy2;
    end
    endfunction

    // ------------------------------------------------------------------
    // Sequential state register
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            done       <= 1'b0;
            max_count  <= 4'd0;
            cur_n      <= 4'd0;
            best_combined <= 4'd0;
        end else begin
            state <= next_state;

            // Default done low, will be pulsed in S_DONE
            done <= 1'b0;

            case (state)
                // ------------------------------------------------------
                // IDLE: wait for start
                // ------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        // Latch number of towers
                        cur_n <= (num_towers == 0) ? 4'd0 : num_towers;
                    end
                end

                // ------------------------------------------------------
                // LATCH: capture coordinates
                // ------------------------------------------------------
                S_LATCH: begin
                    // Latch coordinates for all 8 entries
                    x_reg[0] <= tower_x[0];
                    x_reg[1] <= tower_x[1];
                    x_reg[2] <= tower_x[2];
                    x_reg[3] <= tower_x[3];
                    x_reg[4] <= tower_x[4];
                    x_reg[5] <= tower_x[5];
                    x_reg[6] <= tower_x[6];
                    x_reg[7] <= tower_x[7];

                    y_reg[0] <= tower_y[0];
                    y_reg[1] <= tower_y[1];
                    y_reg[2] <= tower_y[2];
                    y_reg[3] <= tower_y[3];
                    y_reg[4] <= tower_y[4];
                    y_reg[5] <= tower_y[5];
                    y_reg[6] <= tower_y[6];
                    y_reg[7] <= tower_y[7];

                    // Clear adjacency
                    adj[0][0] <= 1'b0; adj[0][1] <= 1'b0; adj[0][2] <= 1'b0; adj[0][3] <= 1'b0;
                    adj[0][4] <= 1'b0; adj[0][5] <= 1'b0; adj[0][6] <= 1'b0; adj[0][7] <= 1'b0;
                    adj[1][0] <= 1'b0; adj[1][1] <= 1'b0; adj[1][2] <= 1'b0; adj[1][3] <= 1'b0;
                    adj[1][4] <= 1'b0; adj[1][5] <= 1'b0; adj[1][6] <= 1'b0; adj[1][7] <= 1'b0;
                    adj[2][0] <= 1'b0; adj[2][1] <= 1'b0; adj[2][2] <= 1'b0; adj[2][3] <= 1'b0;
                    adj[2][4] <= 1'b0; adj[2][5] <= 1'b0; adj[2][6] <= 1'b0; adj[2][7] <= 1'b0;
                    adj[3][0] <= 1'b0; adj[3][1] <= 1'b0; adj[3][2] <= 1'b0; adj[3][3] <= 1'b0;
                    adj[3][4] <= 1'b0; adj[3][5] <= 1'b0; adj[3][6] <= 1'b0; adj[3][7] <= 1'b0;
                    adj[4][0] <= 1'b0; adj[4][1] <= 1'b0; adj[4][2] <= 1'b0; adj[4][3] <= 1'b0;
                    adj[4][4] <= 1'b0; adj[4][5] <= 1'b0; adj[4][6] <= 1'b0; adj[4][7] <= 1'b0;
                    adj[5][0] <= 1'b0; adj[5][1] <= 1'b0; adj[5][2] <= 1'b0; adj[5][3] <= 1'b0;
                    adj[5][4] <= 1'b0; adj[5][5] <= 1'b0; adj[5][6] <= 1'b0; adj[5][7] <= 1'b0;
                    adj[6][0] <= 1'b0; adj[6][1] <= 1'b0; adj[6][2] <= 1'b0; adj[6][3] <= 1'b0;
                    adj[6][4] <= 1'b0; adj[6][5] <= 1'b0; adj[6][6] <= 1'b0; adj[6][7] <= 1'b0;
                    adj[7][0] <= 1'b0; adj[7][1] <= 1'b0; adj[7][2] <= 1'b0; adj[7][3] <= 1'b0;
                    adj[7][4] <= 1'b0; adj[7][5] <= 1'b0; adj[7][6] <= 1'b0; adj[7][7] <= 1'b0;

                    // Reset indices
                    i_idx <= 4'd0;
                    j_idx <= 4'd1;

                    // Reset best result
                    best_combined <= 4'd0;
                end

                // ------------------------------------------------------
                // BUILD_ADJ: compute pairwise adjacency
                // ------------------------------------------------------
                S_BUILD_ADJ: begin
                    if (i_idx < cur_n) begin
                        if (j_idx < cur_n) begin
                            if (dist2_sq(x_reg[i_idx], x_reg[j_idx], y_reg[i_idx], y_reg[j_idx]) <= DIST2_THRESH) begin
                                adj[i_idx][j_idx] <= 1'b1;
                                adj[j_idx][i_idx] <= 1'b1;
                            end
                            j_idx <= j_idx + 4'd1;
                        end else begin
                            i_idx <= i_idx + 4'd1;
                            j_idx <= i_idx + 4'd2; // next j = i+1
                        end
                    end
                end

                // ------------------------------------------------------
                // DSU_INIT: initialize DSU parents and sizes
                // ------------------------------------------------------
                S_DSU_INIT: begin
                    for (integer k = 0; k < 8; k = k + 1) begin
                        if (k < cur_n) begin
                            parent[k]    <= k[2:0];
                            comp_size[k] <= 4'd1;
                        end else begin
                            parent[k]    <= k[2:0];
                            comp_size[k] <= 4'd0;
                        end
                    end
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                end

                // ------------------------------------------------------
                // DSU_UNION: process adjacency to merge sets
                // ------------------------------------------------------
                S_DSU_UNION: begin
                    if (i_idx < cur_n) begin
                        if (j_idx < cur_n) begin
                            if (adj[i_idx][j_idx]) begin
                                // Simple union without full path compression
                                if (parent[i_idx] != parent[j_idx]) begin
                                    if (parent[i_idx] < parent[j_idx]) begin
                                        comp_size[parent[i_idx]] <= comp_size[parent[i_idx]] + comp_size[parent[j_idx]];
                                        parent[j_idx] <= parent[i_idx];
                                    end else begin
                                        comp_size[parent[j_idx]] <= comp_size[parent[j_idx]] + comp_size[parent[i_idx]];
                                        parent[i_idx] <= parent[j_idx];
                                    end
                                end
                            end
                            j_idx <= j_idx + 4'd1;
                        end else begin
                            i_idx <= i_idx + 4'd1;
                            j_idx <= 4'd0;
                        end
                    end
                end

                // ------------------------------------------------------
                // DSU_SIZE: finalize root sizes and root_size array
                // ------------------------------------------------------
                S_DSU_SIZE: begin
                    // For small N, treat comp_size as valid for indices where parent[i]==i
                    for (integer r = 0; r < 8; r = r + 1) begin
                        if (r < cur_n) begin
                            if (parent[r] == r[2:0]) begin
                                root_size[r] <= comp_size[r];
                            end else begin
                                root_size[r] <= 4'd0;
                            end
                        end else begin
                            root_size[r] <= 4'd0;
                        end
                    end

                    cand_index <= 4'd0;
                    best_combined <= 4'd0;
                end

                // ------------------------------------------------------
                // CAND_PREP: initialize per-candidate tracking
                // ------------------------------------------------------
                S_CAND_PREP: begin
                    // union mask: towers within 2km of candidate tower position
                    cand_union_mask <= 8'd0;
                    visited_roots   <= 8'd0;
                    cand_sum        <= 4'd0;
                    i_idx           <= 4'd0;
                end

                // ------------------------------------------------------
                // CAND_SCAN: build mask and sum unique component sizes
                // ------------------------------------------------------
                S_CAND_SCAN: begin
                    if (i_idx < cur_n) begin
                        // For each tower i, check if within 2km of candidate position
                        if (dist2_sq(x_reg[cand_index], x_reg[i_idx], y_reg[cand_index], y_reg[i_idx]) <= DIST2_THRESH) begin
                            // mark in mask
                            cand_union_mask[i_idx] <= 1'b1;

                            // find root (simple 1-level indirection)
                            find_node = parent[i_idx];
                            // mark visited per root index
                            if (!visited_roots[find_node]) begin
                                visited_roots[find_node] <= 1'b1;
                                cand_sum <= cand_sum + root_size[find_node];
                            end
                        end
                        i_idx <= i_idx + 4'd1;
                    end else begin
                        // finished scanning: update best if needed
                        if (cand_sum > best_combined)
                            best_combined <= cand_sum;

                        // move to next candidate index handled in next_state logic
                    end
                end

                // ------------------------------------------------------
                // DONE: output result and pulse done
                // ------------------------------------------------------
                S_DONE: begin
                    // add 1 for the new tower itself
                    if (best_combined + 4'd1 > 4'd15)
                        max_count <= 4'd15;
                    else
                        max_count <= best_combined + 4'd1;
                    done <= 1'b1;
                end

                default: begin
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Next-state logic
    // ------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_LATCH;
            end

            S_LATCH: begin
                next_state = S_BUILD_ADJ;
            end

            S_BUILD_ADJ: begin
                if (!(i_idx < cur_n))
                    next_state = S_DSU_INIT;
            end

            S_DSU_INIT: begin
                next_state = S_DSU_UNION;
            end

            S_DSU_UNION: begin
                if (!(i_idx < cur_n))
                    next_state = S_DSU_SIZE;
            end

            S_DSU_SIZE: begin
                // If no towers, best_combined remains 0; still evaluate candidates (none) and finish
                if (cur_n == 0)
                    next_state = S_DONE;
                else
                    next_state = S_CAND_PREP;
            end

            S_CAND_PREP: begin
                next_state = S_CAND_SCAN;
            end

            S_CAND_SCAN: begin
                if (i_idx >= cur_n) begin
                    if (cand_index + 4'd1 < cur_n) begin
                        next_state = S_CAND_PREP;
                    end else begin
                        next_state = S_DONE;
                    end
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Candidate index update (sequential)
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cand_index <= 4'd0;
        end else begin
            if (state == S_CAND_SCAN && i_idx >= cur_n) begin
                if (cand_index + 4'd1 < cur_n)
                    cand_index <= cand_index + 4'd1;
            end
        end
    end

endmodule