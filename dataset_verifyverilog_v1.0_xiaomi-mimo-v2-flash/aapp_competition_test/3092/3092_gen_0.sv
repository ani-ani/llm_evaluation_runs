module EdgeShortestPathCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [4:0] num_edges,
    input wire [31:0] edge_in [0:31],
    output reg [31:0] result,
    output reg result_valid,
    output reg edge_done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [5:0] MAX_NODES = 6'd16;
    localparam [5:0] MAX_EDGES = 6'd32;
    localparam [5:0] MAX_K = 6'd16;
    localparam [5:0] MAX_I = 6'd16;
    localparam [5:0] MAX_J = 6'd16;
    localparam [31:0] INF = 32'hFFFFFFFF;

    // State Machine States
    localparam [3:0] IDLE              = 4'd0;
    localparam [3:1] RESET_STATES      = 4'd1; // Reset dist RAM
    localparam [3:0] INIT_DIST         = 4'd2; // Initialize dist from edges
    localparam [3:0] FLOYD_K_LOOP      = 4'd3; // Outer loop for Floyd-Warshall
    localparam [3:0] FLOYD_I_LOOP      = 4'd4; // Middle loop
    localparam [3:0] FLOYD_J_LOOP      = 4'd5; // Inner loop
    localparam [3:0] PREP_COUNT_S      = 4'd6; // Setup for counting phase
    localparam [3:0] COUNT_INIT        = 4'd7; // Initialize cnt/rev for source S
    localparam [3:0] COUNT_DP_SOLVE    = 4'd8; // DP to compute cnt for S
    localparam [3:0] REVERSE_DP_SOLVE  = 4'd9; // DP to compute rev for S
    localparam [3:0] EDGE_EVAL_START   = 4'd10; // Prepare edge loop
    localparam [3:0] EDGE_EVAL_LOOP    = 4'd11; // Iterate edges
    localparam [3:0] SUM_MERGE         = 4'd12; // Accumulate edge contributions
    localparam [3:0] OUTPUT_RESULTS    = 4'd13; // Output results for edges
    localparam [3:0] DONE              = 4'd14;

    reg [3:0] state, next_state;

    // Control Registers
    reg [3:0] N; // Actual node count (1-16)
    reg [4:0] M; // Actual edge count (1-32)
    reg [5:0] k_cnt, i_cnt, j_cnt; // Loop counters
    reg [4:0] s_idx; // Source node index (0 to N-1)
    reg [4:0] t_idx; // Target node index (0 to N-1)
    reg [4:0] e_idx; // Edge index (0 to M-1)
    reg [31:0] cycle_counter;
    
    // RAM Read/Write Interfaces
    reg dist_ram_we;
    reg [7:0] dist_ram_waddr; // 16*16 = 256 entries
    reg [7:0] dist_ram_raddr1, dist_ram_raddr2;
    reg [23:0] dist_ram_wdata;
    wire [23:0] dist_ram_rdata1, dist_ram_rdata2;

    reg cnt_ram_we;
    reg [7:0] cnt_ram_waddr;
    reg [7:0] cnt_ram_raddr1, cnt_ram_raddr2;
    reg [31:0] cnt_ram_wdata;
    wire [31:0] cnt_ram_rdata1, cnt_ram_rdata2;

    reg rev_ram_we;
    reg [7:0] rev_ram_waddr;
    reg [7:0] rev_ram_raddr1, rev_ram_raddr2;
    reg [31:0] rev_ram_wdata;
    wire [31:0] rev_ram_rdata1, rev_ram_rdata2;

    // Edge Storage (Using distributed RAM logic via registers)
    reg [31:0] edges_src [0:31];
    reg [31:0] edges_dst [0:31];
    reg [31:0] edges_len [0:31];
    
    // Intermediate Registers for Computation
    reg [23:0] dist_ik;
    reg [23:0] dist_kj;
    reg [23:0] dist_ij;
    reg [47:0] sum_dist;
    reg [31:0] dist_new;
    
    reg [31:0] cnt_u; // cnt[S][u]
    reg [31:0] cnt_v; // cnt[S][v]
    reg [31:0] rev_v; // rev[S][v]
    reg [31:0] rev_t; // rev[S][t]
    reg [31:0] dist_Su, dist_vT;
    reg [31:0] dist_ST;
    
    // Edge Contribution Accumulator
    reg [31:0] edge_acc [0:31]; // Stores sum for each edge
    reg [31:0] product;
    reg [63:0] extended_product;

    // Output State Machine
    reg [4:0] out_idx;
    reg outputting;

    // -----------------------------------------
    // Distributed RAM Instances (Synthesizable)
    // -----------------------------------------

    // dist_ram: 256 x 24 bits
    // Use 3 instances of 256x8 for 24 bits
    reg [7:0] dist_ram0 [0:255];
    reg [7:0] dist_ram1 [0:255];
    reg [7:0] dist_ram2 [0:255];

    always @(posedge clk) begin
        if (dist_ram_we) begin
            dist_ram0[dist_ram_waddr] <= dist_ram_wdata[7:0];
            dist_ram1[dist_ram_waddr] <= dist_ram_wdata[15:8];
            dist_ram2[dist_ram_waddr] <= dist_ram_wdata[23:16];
        end
    end
    assign dist_ram_rdata1 = {dist_ram2[dist_ram_raddr1], dist_ram1[dist_ram_raddr1], dist_ram0[dist_ram_raddr1]};
    assign dist_ram_rdata2 = {dist_ram2[dist_ram_raddr2], dist_ram1[dist_ram_raddr2], dist_ram0[dist_ram_raddr2]};

    // cnt_ram: 256 x 32 bits (Only used for N*N, but mapped 16x16=256)
    reg [31:0] cnt_ram0 [0:255];
    always @(posedge clk) begin
        if (cnt_ram_we) cnt_ram0[cnt_ram_waddr] <= cnt_ram_wdata;
    end
    assign cnt_ram_rdata1 = cnt_ram0[cnt_ram_raddr1];
    assign cnt_ram_rdata2 = cnt_ram0[cnt_ram_raddr2];

    // rev_ram: 256 x 32 bits
    reg [31:0] rev_ram0 [0:255];
    always @(posedge clk) begin
        if (rev_ram_we) rev_ram0[rev_ram_waddr] <= rev_ram_wdata;
    end
    assign rev_ram_rdata1 = rev_ram0[rev_ram_raddr1];
    assign rev_ram_rdata2 = rev_ram0[rev_ram_raddr2];

    // -----------------------------------------
    // Main Logic
    // -----------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            N <= 4'd0;
            M <= 5'd0;
            dist_ram_we <= 1'b0;
            cnt_ram_we <= 1'b0;
            rev_ram_we <= 1'b0;
            result <= 32'd0;
            result_valid <= 1'b0;
            edge_done <= 1'b0;
            cycle_counter <= 32'd0;
            outputting <= 1'b0;
        end else begin
            dist_ram_we <= 1'b0;
            cnt_ram_we <= 1'b0;
            rev_ram_we <= 1'b0;
            result_valid <= 1'b0;
            edge_done <= 1'b0;
            cycle_counter <= cycle_counter + 32'd1;

            case (state)
                IDLE: begin
                    cycle_counter <= 32'd0;
                    edge_done <= 1'b0;
                    if (start) begin
                        N <= num_nodes[3:0];
                        M <= num_edges;
                        // Parse edges into registers
                        if (num_edges > 0) edges_src[0] <= edge_in[0][10:6];
                        if (num_edges > 1) edges_src[1] <= edge_in[1][10:6];
                        if (num_edges > 2) edges_src[2] <= edge_in[2][10:6];
                        if (num_edges > 3) edges_src[3] <= edge_in[3][10:6];
                        if (num_edges > 4) edges_src[4] <= edge_in[4][10:6];
                        if (num_edges > 5) edges_src[5] <= edge_in[5][10:6];
                        if (num_edges > 6) edges_src[6] <= edge_in[6][10:6];
                        if (num_edges > 7) edges_src[7] <= edge_in[7][10:6];
                        if (num_edges > 8) edges_src[8] <= edge_in[8][10:6];
                        if (num_edges > 9) edges_src[9] <= edge_in[9][10:6];
                        if (num_edges > 10) edges_src[10] <= edge_in[10][10:6];
                        if (num_edges > 11) edges_src[11] <= edge_in[11][10:6];
                        if (num_edges > 12) edges_src[12] <= edge_in[12][10:6];
                        if (num_edges > 13) edges_src[13] <= edge_in[13][10:6];
                        if (num_edges > 14) edges_src[14] <= edge_in[14][10:6];
                        if (num_edges > 15) edges_src[15] <= edge_in[15][10:6];
                        if (num_edges > 16) edges_src[16] <= edge_in[16][10:6];
                        if (num_edges > 17) edges_src[17] <= edge_in[17][10:6];
                        if (num_edges > 18) edges_src[18] <= edge_in[18][10:6];
                        if (num_edges > 19) edges_src[19] <= edge_in[19][10:6];
                        if (num_edges > 20) edges_src[20] <= edge_in[20][10:6];
                        if (num_edges > 21) edges_src[21] <= edge_in[21][10:6];
                        if (num_edges > 22) edges_src[22] <= edge_in[22][10:6];
                        if (num_edges > 23) edges_src[23] <= edge_in[23][10:6];
                        if (num_edges > 24) edges_src[24] <= edge_in[24][10:6];
                        if (num_edges > 25) edges_src[25] <= edge_in[25][10:6];
                        if (num_edges > 26) edges_src[26] <= edge_in[26][10:6];
                        if (num_edges > 27) edges_src[27] <= edge_in[27][10:6];
                        if (num_edges > 28) edges_src[28] <= edge_in[28][10:6];
                        if (num_edges > 29) edges_src[29] <= edge_in[29][10:6];
                        if (num_edges > 30) edges_src[30] <= edge_in[30][10:6];
                        if (num_edges > 31) edges_src[31] <= edge_in[31][10:6];

                        if (num_edges > 0) edges_dst[0] <= edge_in[0][15:11];
                        if (num_edges > 1) edges_dst[1] <= edge_in[1][15:11];
                        if (num_edges > 2) edges_dst[2] <= edge_in[2][15:11];
                        if (num_edges > 3) edges_dst[3] <= edge_in[3][15:11];
                        if (num_edges > 4) edges_dst[4] <= edge_in[4][15:11];
                        if (num_edges > 5) edges_dst[5] <= edge_in[5][15:11];
                        if (num_edges > 6) edges_dst[6] <= edge_in[6][15:11];
                        if (num_edges > 7) edges_dst[7] <= edge_in[7][15:11];
                        if (num_edges > 8) edges_dst[8] <= edge_in[8][15:11];
                        if (num_edges > 9) edges_dst[9] <= edge_in[9][15:11];
                        if (num_edges > 10) edges_dst[10] <= edge_in[10][15:11];
                        if (num_edges > 11) edges_dst[11] <= edge_in[11][15:11];
                        if (num_edges > 12) edges_dst[12] <= edge_in[12][15:11];
                        if (num_edges > 13) edges_dst[13] <= edge_in[13][15:11];
                        if (num_edges > 14) edges_dst[14] <= edge_in[14][15:11];
                        if (num_edges > 15) edges_dst[15] <= edge_in[15][15:11];
                        if (num_edges > 16) edges_dst[16] <= edge_in[16][15:11];
                        if (num_edges > 17) edges_dst[17] <= edge_in[17][15:11];
                        if (num_edges > 18) edges_dst[18] <= edge_in[18][15:11];
                        if (num_edges > 19) edges_dst[19] <= edge_in[19][15:11];
                        if (num_edges > 20) edges_dst[20] <= edge_in[20][15:11];
                        if (num_edges > 21) edges_dst[21] <= edge_in[21][15:11];
                        if (num_edges > 22) edges_dst[22] <= edge_in[22][15:11];
                        if (num_edges > 23) edges_dst[23] <= edge_in[23][15:11];
                        if (num_edges > 24) edges_dst[24] <= edge_in[24][15:11];
                        if (num_edges > 25) edges_dst[25] <= edge_in[25][15:11];
                        if (num_edges > 26) edges_dst[26] <= edge_in[26][15:11];
                        if (num_edges > 27) edges_dst[27] <= edge_in[27][15:11];
                        if (num_edges > 28) edges_dst[28] <= edge_in[28][15:11];
                        if (num_edges > 29) edges_dst[29] <= edge_in[29][15:11];
                        if (num_edges > 30) edges_dst[30] <= edge_in[30][15:11];
                        if (num_edges > 31) edges_dst[31] <= edge_in[31][15:11];

                        if (num_edges > 0) edges_len[0] <= {26'd0, edge_in[0][5:0]};
                        if (num_edges > 1) edges_len[1] <= {26'd0, edge_in[1][5:0]};
                        if (num_edges > 2) edges_len[2] <= {26'd0, edge_in[2][5:0]};
                        if (num_edges > 3) edges_len[3] <= {26'd0, edge_in[3][5:0]};
                        if (num_edges > 4) edges_len[4] <= {26'd0, edge_in[4][5:0]};
                        if (num_edges > 5) edges_len[5] <= {26'd0, edge_in[5][5:0]};
                        if (num_edges > 6) edges_len[6] <= {26'd0, edge_in[6][5:0]};
                        if (num_edges > 7) edges_len[7] <= {26'd0, edge_in[7][5:0]};
                        if (num_edges > 8) edges_len[8] <= {26'd0, edge_in[8][5:0]};
                        if (num_edges > 9) edges_len[9] <= {26'd0, edge_in[9][5:0]};
                        if (num_edges > 10) edges_len[10] <= {26'd0, edge_in[10][5:0]};
                        if (num_edges > 11) edges_len[11] <= {26'd0, edge_in[11][5:0]};
                        if (num_edges > 12) edges_len[12] <= {26'd0, edge_in[12][5:0]};
                        if (num_edges > 13) edges_len[13] <= {26'd0, edge_in[13][5:0]};
                        if (num_edges > 14) edges_len[14] <= {26'd0, edge_in[14][5:0]};
                        if (num_edges > 15) edges_len[15] <= {26'd0, edge_in[15][5:0]};
                        if (num_edges > 16) edges_len[16] <= {26'd0, edge_in[16][5:0]};
                        if (num_edges > 17) edges_len[17] <= {26'd0, edge_in[17][5:0]};
                        if (num_edges > 18) edges_len[18] <= {26'd0, edge_in[18][5:0]};
                        if (num_edges > 19) edges_len[19] <= {26'd0, edge_in[19][5:0]};
                        if (num_edges > 20) edges_len[20] <= {26'd0, edge_in[20][5:0]};
                        if (num_edges > 21) edges_len[21] <= {26'd0, edge_in[21][5:0]};
                        if (num_edges > 22) edges_len[22] <= {26'd0, edge_in[22][5:0]};
                        if (num_edges > 23) edges_len[23] <= {26'd0, edge_in[23][5:0]};
                        if (num_edges > 24) edges_len[24] <= {26'd0, edge_in[24][5:0]};
                        if (num_edges > 25) edges_len[25] <= {26'd0, edge_in[25][5:0]};
                        if (num_edges > 26) edges_len[26] <= {26'd0, edge_in[26][5:0]};
                        if (num_edges > 27) edges_len[27] <= {26'd0, edge_in[27][5:0]};
                        if (num_edges > 28) edges_len[28] <= {26'd0, edge_in[28][5:0]};
                        if (num_edges > 29) edges_len[29] <= {26'd0, edge_in[29][5:0]};
                        if (num_edges > 30) edges_len[30] <= {26'd0, edge_in[30][5:0]};
                        if (num_edges > 31) edges_len[31] <= {26'd0, edge_in[31][5:0]};

                        state <= RESET_STATES;
                        k_cnt <= 6'd0;
                    end
                end

                RESET_STATES: begin
                    // Clear Dist RAM (Initialize to INF except diagonal)
                    if (k_cnt < MAX_K * MAX_K) begin
                        dist_ram_waddr <= k_cnt[7:0];
                        if ((k_cnt % 16) == (k_cnt / 16)) begin
                            dist_ram_wdata <= 24'd0; // Diagonal is 0
                        end else begin
                            dist_ram_wdata <= INF[23:0];
                        end
                        dist_ram_we <= 1'b1;
                        k_cnt <= k_cnt + 6'd1;
                    end else begin
                        k_cnt <= 6'd0;
                        state <= INIT_DIST;
                    end
                end

                INIT_DIST: begin
                    // Load edges into Dist RAM
                    if (k_cnt < M) begin
                        // src = edges_src[k_cnt], dst = edges_dst[k_cnt]
                        // Check if new dist is shorter (currently INF)
                        dist_ram_raddr1 <= {edges_src[k_cnt][3:0], edges_dst[k_cnt][3:0]};
                        state <= state + 1; // Transition to load/compare state
                    end else begin
                        k_cnt <= 6'd0;
                        i_cnt <= 6'd0;
                        j_cnt <= 6'd0;
                        state <= FLOYD_K_LOOP;
                    end
                end

                4'd13: begin // Auxiliary state for INIT_DIST logic
                    // Wait cycle for RAM read
                    state <= INIT_DIST;
                    k_cnt <= k_cnt + 6'd1;
                    // Compare logic: dist[u][v] should be min(current, len)
                    // Since we only load once here, we assume current is INF or 0
                    // However, multiple edges between same nodes? Spec doesn't forbid.
                    // Use <= to keep shortest edge if duplicates exist.
                    if (dist_ram_rdata1 > edges_len[k_cnt - 6'd1]) begin
                        dist_ram_waddr <= {edges_src[k_cnt - 6'd1][3:0], edges_dst[k_cnt - 6'd1][3:0]};
                        dist_ram_wdata <= edges_len[k_cnt - 6'd1][23:0];
                        dist_ram_we <= 1'b1;
                    end
                end

                FLOYD_K_LOOP: begin
                    if (i_cnt < N && j_cnt < N) begin
                        // Load dist[i][k] and dist[k][j]
                        dist_ram_raddr1 <= {i_cnt[3:0], k_cnt[3:0]};
                        dist_ram_raddr2 <= {k_cnt[3:0], j_cnt[3:0]};
                        state <= FLOYD_I_LOOP;
                    end else begin
                        // Increment Loop Logic
                        if (j_cnt < N) begin
                            j_cnt <= j_cnt + 6'd1;
                        end else begin
                            j_cnt <= 6'd0;
                            if (i_cnt < N) i_cnt <= i_cnt + 6'd1;
                            else begin
                                i_cnt <= 6'd0;
                                if (k_cnt < N) k_cnt <= k_cnt + 6'd1;
                                else begin
                                    // Floyd Complete
                                    state <= PREP_COUNT_S;
                                    s_idx <= 4'd0;
                                    // Init edge accumulators to 0
                                    for (integer idx = 0; idx < 32; idx = idx + 1) edge_acc[idx] <= 32'd0;
                                end
                            end
                        end
                        state <= FLOYD_K_LOOP;
                    end
                end

                FLOYD_I_LOOP: begin
                    // Wait for RAM
                    state <= FLOYD_J_LOOP;
                end

                FLOYD_J_LOOP: begin
                    dist_ik <= dist_ram_rdata1;
                    dist_kj <= dist_ram_rdata2;
                    dist_ram_raddr1 <= {i_cnt[3:0], j_cnt[3:0]};
                    state <= state + 1; // Transition to calc
                end

                4'd14: begin // FLOYD_CALC
                    dist_ij <= dist_ram_rdata1;
                    if (dist_ik != INF[23:0] && dist_kj != INF[23:0]) begin
                        sum_dist = dist_ik + dist_kj;
                        if (sum_dist < dist_ij) begin
                            dist_ram_waddr <= {i_cnt[3:0], j_cnt[3:0]};
                            dist_ram_wdata <= sum_dist[23:0];
                            dist_ram_we <= 1'b1;
                        end
                    end
                    state <= FLOYD_K_LOOP;
                end

                PREP_COUNT_S: begin
                    if (s_idx < N) begin
                        state <= COUNT_INIT;
                        i_cnt <= 6'd0; // Used for resetting loop
                    end else begin
                        outputting <= 1'b1;
                        out_idx <= 5'd0;
                        state <= OUTPUT_RESULTS;
                    end
                end

                COUNT_INIT: begin
                    // Initialize cnt[s_idx][*] = 0, cnt[s_idx][s_idx] = 1
                    // Initialize rev[s_idx][*] = 0
                    // We use a single loop over all nodes (0 to 15) to do this
                    if (i_cnt < MAX_NODES) begin
                        cnt_ram_waddr <= {s_idx[3:0], i_cnt[3:0]};
                        if (i_cnt == s_idx) cnt_ram_wdata <= 32'd1;
                        else cnt_ram_wdata <= 32'd0;
                        cnt_ram_we <= 1'b1;

                        rev_ram_waddr <= {s_idx[3:0], i_cnt[3:0]};
                        rev_ram_wdata <= 32'd0;
                        rev_ram_we <= 1'b1;

                        i_cnt <= i_cnt + 6'd1;
                    end else begin
                        i_cnt <= 6'd0;
                        j_cnt <= 6'd0;
                        state <= COUNT_DP_SOLVE;
                    end
                end

                COUNT_DP_SOLVE: begin
                    // Topological DP for shortest paths from s_idx
                    // Iterate over all nodes u in topological order
                    // Since N is small, we can relax edges M times or use iteration.
                    // Standard DP: update cnt[v] if dist[s][u] + len == dist[s][v]
                    // We iterate over all edges. If edges are not in order, we might need multiple passes.
                    // 4 passes (N times) is enough for N=16.
                    
                    // Optimization: Iterate edges M times, repeated N times.
                    // However, to save cycles, we do 1 pass over edges. If graph is DAG-like in terms of shortest path tree, it works.
                    // If not, we need multiple iterations. Let's do N iterations of M edges.
                    // State machine: Iterate edge index e_idx (0 to M-1). Repeat N times.
                    
                    if (i_cnt < N) begin // Outer iteration counter
                        if (j_cnt < M) begin // Edge iterator
                            // Read dist[s][src], dist[s][dst], edge_len
                            // Read cnt[s][src]
                            dist_ram_raddr1 <= {s_idx[3:0], edges_src[j_cnt][3:0]};
                            dist_ram_raddr2 <= {s_idx[3:0], edges_dst[j_cnt][3:0]};
                            cnt_ram_raddr1 <= {s_idx[3:0], edges_src[j_cnt][3:0]};
                            state <= state + 1; // Wait/read
                        end else begin
                            j_cnt <= 6'd0;
                            if (i_cnt < N) i_cnt <= i_cnt + 6'd1;
                            else begin
                                // Done forward DP, start reverse
                                i_cnt <= 6'd0;
                                j_cnt <= 6'd0;
                                state <= REVERSE_DP_SOLVE;
                            end
                        end
                    end else begin
                        // Should have been caught in else above
                    end
                end

                4'd15: begin // COUNT_DP_PROCESS
                    dist_Su <= dist_ram_rdata1;
                    dist_vT <= dist_ram_rdata2; // Here dist_vT is actually dist[s][v]
                    cnt_u <= cnt_ram_rdata1;
                    
                    // Check condition: dist[S][u] + w == dist[S][v]
                    if (dist_Su != INF[23:0]) begin
                        sum_dist = dist_Su + edges_len[j_cnt - 6'd1][23:0]; // Wait, index j_cnt is current, need previous
                        // Fix logic: j_cnt was incremented before state transition? No.
                        // j_cnt is current index.
                        if (sum_dist == dist_vT && dist_vT != INF[23:0]) begin
                            // Update cnt[S][v] += cnt[S][u]
                            cnt_ram_raddr2 <= {s_idx[3:0], edges_dst[j_cnt][3:0]}; // Read current cnt[v]
                            state <= state + 1; // Calc update
                        end else begin
                            state <= COUNT_DP_SOLVE;
                            j_cnt <= j_cnt + 6'd1;
                        end
                    end else begin
                        state <= COUNT_DP_SOLVE;
                        j_cnt <= j_cnt + 6'd1;
                    end
                end

                4'd0: begin // aux state for cnt update
                    // cnt_v read
                    extended_product = cnt_u + cnt_ram_rdata2;
                    if (extended_product >= MOD) extended_product = extended_product - MOD;
                    cnt_ram_waddr <= {s_idx[3:0], edges_dst[j_cnt - 6'd1][3:0]};
                    cnt_ram_wdata <= extended_product[31:0];
                    cnt_ram_we <= 1'b1;
                    state <= COUNT_DP_SOLVE;
                    j_cnt <= j_cnt + 6'd1;
                end

                REVERSE_DP_SOLVE: begin
                    // Compute rev[S][v] (paths from v to T where dist[S][T] = shortest)
                    // We iterate over edges reversed: u->v becomes v->u in reverse graph logic.
                    // Condition: dist[S][u] + w == dist[S][v] implies v contributes to u for paths to T via v? No.
                    // Rev logic: If dist[S][u] + w == dist[S][v], then paths from S to v passing through u
                    // contribute to edge usage. 
                    // Actually, standard approach: rev[S][v] = sum of shortest paths from v to T (for all T) 
                    // where the path S->...->v->...->T is a shortest S->T path.
                    // This is equivalent to counting paths in the shortest path DAG from S.
                    // We already have fwd counts. 
                    // Reverse graph approach:
                    // Iterate edges u->v. If dist[S][u] + w == dist[S][v], then we can extend paths from u to v.
                    // For reverse counts: 
                    // Initialize rev[S][v] = 1 for all v (path from v to itself of length 0 is shortest? No, only if v is reachable and v=v).
                    // Actually, standard algorithm: 
                    // 1. Construct Shortest Path DAG from S.
                    // 2. Run DP forward on DAG to get cnt[S][*]. (Done)
                    // 3. Run DP backward on DAG to get rev[S][*].
                    //    rev[S][v] = 1 (base: path from v to itself)
                    //    rev[S][u] += rev[S][v] if edge u->v is in DAG.
                    // Wait, S is source. We want paths from S to T using u->v.
                    // Count = cnt[S][u] * paths(v->T in DAG).
                    // Let rev[S][v] = paths from v to any T in DAG.
                    // Base: rev[S][v] = 1 (the path from v to itself is a valid suffix if v is reachable from S? 
                    // Yes, if we consider T=v. But usually we sum over T where S->T is valid).
                    // Let's refine: Sum over S,T: cnt(S,u) * rev(v,T) where S->u->v->T is shortest path.
                    // This is sum over S: cnt(S,u) * (sum over T: paths v->T in DAG of S).
                    // Let V_rev[S][v] = number of shortest paths from v to any T in the S-shortest-path DAG.
                    // Base: V_rev[S][v] = 1 (counting path of length 0 v->v).
                    // Transition: If u->v is in DAG (dist[S][u]+w==dist[S][v]), then V_rev[S][u] += V_rev[S][v].
                    // Note: We must process nodes in reverse topological order of the DAG (decreasing dist[S]).
                    
                    // Initialize V_rev[S][v] = 1 for all v reachable from S.
                    if (i_cnt < N) begin
                        dist_ram_raddr1 <= {s_idx[3:0], i_cnt[3:0]};
                        state <= state + 1; // Check reachability
                    end else begin
                        i_cnt <= 6'd0;
                        j_cnt <= 6'd0;
                        // Reset i_cnt for iteration
                        state <= 4'd1; // Transition to DP loop
                    end
                end

                4'd2: begin // REV_INIT_WRITE
                    // i_cnt is current node. dist_Su holds dist[S][i_cnt]
                    rev_ram_waddr <= {s_idx[3:0], i_cnt[3:0]};
                    if (dist_Su != INF[23:0]) begin
                        rev_ram_wdata <= 32'd1;
                    end else begin
                        rev_ram_wdata <= 32'd0;
                    end
                    rev_ram_we <= 1'b1;
                    i_cnt <= i_cnt + 6'd1;
                    state <= REVERSE_DP_SOLVE;
                end

                4'd1: begin // REV_DP_LOOP
                    // Iterate edges N times for DP propagation
                    // We need topological sort or simple iteration.
                    // Since dist[S][v] is unique for shortest paths, we can process edges in order of dist[S][dst] (increasing).
                    // But that's complex. We'll just iterate M edges, N times (relaxation).
                    if (i_cnt < N) begin
                        if (j_cnt < M) begin
                            // Check if u->v is in DAG (dist[S][u] + w == dist[S][v])
                            dist_ram_raddr1 <= {s_idx[3:0], edges_src[j_cnt][3:0]};
                            dist_ram_raddr2 <= {s_idx[3:0], edges_dst[j_cnt][3:0]};
                            state <= state + 1; // Read dists
                        end else begin
                            j_cnt <= 6'd0;
                            i_cnt <= i_cnt + 6'd1;
                        end
                    end else begin
                        // Done with this S
                        state <= EDGE_EVAL_START;
                        e_idx <= 5'd0;
                    end
                end

                4'd3: begin // REV_DP_CHECK
                    dist_Su <= dist_ram_rdata1;
                    dist_vT <= dist_ram_rdata2;
                    // Read rev[S][v]
                    rev_ram_raddr1 <= {s_idx[3:0], edges_dst[j_cnt][3:0]};
                    state <= state + 1;
                end

                4'd4: begin // REV_DP_UPDATE
                    rev_v <= rev_ram_rdata1;
                    if (dist_vT != INF[23:0] && dist_Su != INF[23:0]) begin
                        sum_dist = dist_Su + edges_len[j_cnt][23:0];
                        if (sum_dist == dist_vT) begin
                            // Update rev[S][u] += rev[S][v]
                            rev_ram_raddr2 <= {s_idx[3:0], edges_src[j_cnt][3:0]};
                            state <= state + 1;
                        end else begin
                            state <= REV_DP_LOOP;
                            j_cnt <= j_cnt + 6'd1;
                        end
                    end else begin
                        state <= REV_DP_LOOP;
                        j_cnt <= j_cnt + 6'd1;
                    end
                end

                4'd5: begin // REV_DP_COMMIT
                    rev_t <= rev_ram_rdata2;
                    extended_product = rev_v + rev_t;
                    if (extended_product >= MOD) extended_product = extended_product - MOD;
                    rev_ram_waddr <= {s_idx[3:0], edges_src[j_cnt][3:0]};
                    rev_ram_wdata <= extended_product[31:0];
                    rev_ram_we <= 1'b1;
                    state <= REV_DP_LOOP;
                    j_cnt <= j_cnt + 6'd1;
                end

                EDGE_EVAL_START: begin
                    // For edge e_idx, sum over T (or rather, sum over S handled by loop)
                    // Current edge: u = edges_src[e_idx], v = edges_dst[e_idx]
                    // We already have cnt[S][u] and rev[S][v] for current S.
                    // Check if edge (u->v) is in shortest path DAG from S.
                    // Condition: dist[S][u] + w + dist[v][T] == dist[S][T] for some T.
                    // This is equivalent to: dist[S][u] + w == dist[S][v] AND v can reach T.
                    // Actually, the contribution for a fixed S is: 
                    // If dist[S][u] + w == dist[S][v], then contribution = cnt[S][u] * rev[S][v].
                    // Note: rev[S][v] sums over all T reachable from v in DAG.
                    
                    dist_ram_raddr1 <= {s_idx[3:0], edges_src[e_idx][3:0]};
                    dist_ram_raddr2 <= {s_idx[3:0], edges_dst[e_idx][3:0]};
                    cnt_ram_raddr1 <= {s_idx[3:0], edges_src[e_idx][3:0]};
                    rev_ram_raddr1 <= {s_idx[3:0], edges_dst[e_idx][3:0]};
                    state <= SUM_MERGE;
                end

                SUM_MERGE: begin
                    dist_Su <= dist_ram_rdata1;
                    dist_vT <= dist_ram_rdata2; // dist[S][v]
                    cnt_u <= cnt_ram_rdata1;
                    rev_v <= rev_ram_rdata1;
                    state <= state + 1;
                end

                4'd11: begin // SUM_CALC
                    if (dist_Su != INF[23:0] && dist_vT != INF[23:0]) begin
                        sum_dist = dist_Su + edges_len[e_idx][23:0];
                        if (sum_dist == dist_vT) begin
                            // Add to accumulator
                            extended_product = cnt_u * rev_v;
                            // Modulo
                            extended_product = extended_product % MOD;
                            product <= extended_product[31:0];
                            state <= state + 1; // Add to RAM
                        end else begin
                            state <= EDGE_EVAL_LOOP;
                        end
                    end else begin
                        state <= EDGE_EVAL_LOOP;
                    end
                end

                4'd12: begin // SUM_ACCUM
                    // Read current edge_acc[e_idx], add product, write back
                    // Since we are in distributed RAM logic (registers), we can access directly if we use array.
                    // But we need to model RAM read latency or just update register.
                    // edge_acc is a register array.
                    // Wait, we can just read-modify-write in one cycle if we declare it as reg array.
                    // However, strict sequencing might be needed if we want to avoid multi-driver.
                    // Since this is inside always block, we can update the array directly.
                    extended_product = edge_acc[e_idx] + product;
                    if (extended_product >= MOD) extended_product = extended_product - MOD;
                    edge_acc[e_idx] <= extended_product[31:0];
                    state <= EDGE_EVAL_LOOP;
                end

                EDGE_EVAL_LOOP: begin
                    if (e_idx < M) begin
                        e_idx <= e_idx + 6'd1;
                        state <= EDGE_EVAL_START;
                    end else begin
                        // Next S
                        s_idx <= s_idx + 4'd1;
                        state <= PREP_COUNT_S;
                    end
                end

                OUTPUT_RESULTS: begin
                    // Output edge_acc in order 0 to M-1
                    if (out_idx < M) begin
                        result <= edge_acc[out_idx];
                        result_valid <= 1'b1;
                        out_idx <= out_idx + 5'd1;
                    end else begin
                        edge_done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule