module ping_pong (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,          // number of players (<=8)
    input wire [2:0] k,          // number of originally disqualified players (<=8)
    input wire [63:0] adj,       // adjacency matrix packed row-major: adj[i*8 + j] = 1 if i beats j
    input wire [7:0] s_mask,     // mask of originally disqualified players: bit i = 1 if player i in S
    output reg [7:0] result,     // size of S' (0-7) or 255 if impossible
    output reg done
);

    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_S        = 3'd1;
    localparam [2:0] ENUMERATE      = 3'd2;
    localparam [2:0] CHECK_SUBSET   = 3'd3;
    localparam [3:0] CHECK_ACYCLIC  = 4'd4;
    localparam [2:0] FOUND          = 3'd5;
    localparam [2:0] IMPOSSIBLE     = 3'd6;

    reg [2:0] state, next_state;
    reg [2:0] current_t;           // current t being tested
    reg [7:0] current_subset;      // current subset of T
    reg [7:0] t_mask;              // mask of T (players not in S)
    reg [7:0] check_mask;          // mask for current V' = S | subset
    reg [7:0] vertices;            // vertices in V' (bitmask)
    reg [2:0] vertex_count;        // number of vertices in V'
    reg [2:0] v_idx;               // index for Floyd-Warshall
    reg [2:0] i_idx, j_idx;        // indices for Floyd-Warshall
    reg [7:0] reach [0:7][0:7];    // reachability matrix (packed as wire)
    reg [7:0] reach_next [0:7][0:7];
    reg has_cycle;                 // flag for cycle detection
    reg [3:0] cycle_count;         // prevent infinite loops
    reg [2:0] s_pop;               // population count of S
    reg [2:0] r_pop;               // population count of current subset R
    reg [2:0] subset_idx;          // index for iterating subsets
    reg [7:0] temp_mask;           // temporary mask
    integer i, j, l;               // loop variables

    // Helper: population count for 8-bit value
    function automatic [2:0] popcount(input [7:0] val);
        reg [2:0] count;
        integer m;
        begin
            count = 3'd0;
            for (m = 0; m < 8; m = m + 1) begin
                if (val[m]) count = count + 3'd1;
            end
            popcount = count;
        end
    endfunction

    // Always block for next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            current_t <= 3'd0;
            current_subset <= 8'd0;
            t_mask <= 8'd0;
            check_mask <= 8'd0;
            vertices <= 8'd0;
            vertex_count <= 3'd0;
            v_idx <= 3'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            has_cycle <= 1'b0;
            cycle_count <= 4'd0;
            s_pop <= 3'd0;
            r_pop <= 3'd0;
            subset_idx <= 3'd0;
            temp_mask <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    reach[i][j] <= 8'd0;
                    reach_next[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
                    current_t <= 3'd0;
                    current_subset <= 8'd0;
                    if (start) begin
                        state <= CHECK_S;
                    end
                end

                CHECK_S: begin
                    // Extract S and T
                    // S = s_mask (bits 0..n-1)
                    // T = ~s_mask & ((1 << n) - 1)
                    t_mask <= ~s_mask & ((8'd1 << n) - 8'd1);
                    s_pop <= popcount(s_mask & ((8'd1 << n) - 8'd1));
                    
                    // Check if S is acyclic (initial check)
                    vertices <= s_mask;
                    vertex_count <= popcount(s_mask & ((8'd1 << n) - 8'd1));
                    // Initialize reachability for S
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            reach[i][j] <= 8'd0;
                        end
                    end
                    v_idx <= 3'd0;
                    i_idx <= 3'd0;
                    j_idx <= 3'd0;
                    cycle_count <= 4'd0;
                    state <= CHECK_ACYCLIC;
                    has_cycle <= 1'b0;
                end

                ENUMERATE: begin
                    // Iterate t from 0 to k-1
                    if (current_t < k) begin
                        // Check if s_pop + t <= n (valid combination)
                        if (s_pop + current_t <= n) begin
                            // Start enumerating subsets of T of size current_t
                            current_subset <= 8'd0;
                            subset_idx <= 3'd0;
                            state <= CHECK_SUBSET;
                        end else begin
                            // Skip to next t
                            current_t <= current_t + 3'd1;
                            state <= ENUMERATE;
                        end
                    end else begin
                        // No valid subset found
                        state <= IMPOSSIBLE;
                    end
                end

                CHECK_SUBSET: begin
                    // Iterate through all subsets of T (0..255) and test size
                    // Since T is limited, we can iterate over all values and mask with T
                    // Use subset_idx as index to generate next subset
                    // Simple approach: generate next subset by incrementing and masking
                    if (subset_idx < 8'd256) begin
                        temp_mask <= t_mask & subset_idx;
                        if (popcount(temp_mask) == current_t) begin
                            // Valid subset R found
                            r_pop <= popcount(temp_mask);
                            // V' = S | (T \ R) = S | (T & ~R)
                            check_mask <= s_mask | (t_mask & ~temp_mask);
                            vertices <= s_mask | (t_mask & ~temp_mask);
                            vertex_count <= popcount(s_mask | (t_mask & ~temp_mask));
                            
                            // Initialize reachability
                            for (i = 0; i < 8; i = i + 1) begin
                                for (j = 0; j < 8; j = j + 1) begin
                                    reach[i][j] <= 8'd0;
                                end
                            end
                            v_idx <= 3'd0;
                            i_idx <= 3'd0;
                            j_idx <= 3'd0;
                            cycle_count <= 4'd0;
                            has_cycle <= 1'b0;
                            state <= CHECK_ACYCLIC;
                        end else begin
                            subset_idx <= subset_idx + 8'd1;
                        end
                    end else begin
                        // No more subsets of this size
                        current_t <= current_t + 3'd1;
                        state <= ENUMERATE;
                    end
                end

                CHECK_ACYCLIC: begin
                    // Floyd-Warshall for vertices in V'
                    // If vertex_count <= 1, no cycle possible
                    if (vertex_count <= 3'd1) begin
                        has_cycle <= 1'b0;
                        state <= FOUND;
                    end else begin
                        // Initialize reachability: reach[i][j] = 1 if edge i->j exists in V'
                        if (i_idx < n && j_idx < n) begin
                            // Check if both i and j are in V'
                            if (vertices[i_idx] && vertices[j_idx]) begin
                                // Check if edge i->j exists: adj[i*n + j]
                                if (adj[i_idx * n + j_idx]) begin
                                    reach[i_idx][j_idx] <= 8'd1;
                                end
                            end
                            j_idx <= j_idx + 3'd1;
                            if (j_idx == n - 3'd1) begin
                                j_idx <= 3'd0;
                                i_idx <= i_idx + 3'd1;
                            end
                        end else if (i_idx < n && j_idx == 3'd0) begin
                            // Continue initialization
                            if (vertices[i_idx]) begin
                                reach[i_idx][i_idx] <= 8'd1; // path to self
                            end
                            i_idx <= i_idx + 3'd1;
                        end else begin
                            // Floyd-Warshall algorithm
                            if (v_idx < n) begin
                                if (vertices[v_idx]) begin
                                    // Update reachability using vertex v_idx as intermediate
                                    for (l = 0; l < 8; l = l + 1) begin
                                        // This loop is unrolled manually in hardware
                                        if (vertices[l]) begin
                                            for (i = 0; i < 8; i = i + 1) begin
                                                if (vertices[i] && reach[i][v_idx]) begin
                                                    for (j = 0; j < 8; j = j + 1) begin
                                                        if (vertices[j] && reach[v_idx][j]) begin
                                                            reach_next[i][j] <= 8'd1;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    // Update reach matrix for next cycle
                                    for (i = 0; i < 8; i = i + 1) begin
                                        for (j = 0; j < 8; j = j + 1) begin
                                            reach[i][j] <= reach[i][j] | reach_next[i][j];
                                            reach_next[i][j] <= 8'd0;
                                        end
                                    end
                                end
                                v_idx <= v_idx + 3'd1;
                                cycle_count <= cycle_count + 4'd1;
                            end else begin
                                // Check for cycles: if any reach[i][i] == 1 for path length >= 2
                                // But we initialized reach[i][i] = 1 always. 
                                // Cycle exists if there is a path i -> j -> ... -> i with intermediate nodes.
                                // After Floyd-Warshall, if reach[i][i] == 1, it could be direct or via others.
                                // Since we initialized reach[i][i] = 1, we need to check if there is a non-trivial cycle.
                                // Actually, if reach[i][i] == 1 and we used intermediate nodes, cycle exists.
                                // Simplified: if reach[i][i] == 1 for any i, and vertex_count > 1, assume cycle (since we set diagonal to 1)
                                // Wait, we need to check for paths that use at least one intermediate node.
                                // Let's check if reach[i][i] is true via path length >= 2.
                                // Since reach is updated, if reach[i][i] becomes true again, it's a cycle.
                                // Actually, standard check: after FW, if reach[i][i] is true, cycle exists.
                                // Since we initialized diagonal to 1, this is always true. 
                                // We must check if there is a path from i to i with length > 0.
                                // Let's use a simpler check: if any i can reach j and j can reach i.
                                has_cycle <= 1'b0;
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (vertices[i]) begin
                                        for (j = 0; j < 8; j = j + 1) begin
                                            if (vertices[j] && i != j) begin
                                                if (reach[i][j] && reach[j][i]) begin
                                                    has_cycle <= 1'b1;
                                                end
                                            end
                                        end
                                    end
                                end
                                // Prevent infinite loop
                                if (cycle_count > 4'd15) begin
                                    has_cycle <= 1'b1; // Timeout -> assume impossible
                                end
                                state <= FOUND;
                            end
                        end
                    end
                end

                FOUND: begin
                    if (!has_cycle) begin
                        result <= {5'd0, current_t};
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // This subset failed, try next
                        subset_idx <= subset_idx + 8'd1;
                        state <= CHECK_SUBSET;
                    end
                end

                IMPOSSIBLE: begin
                    result <= 8'd255;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule