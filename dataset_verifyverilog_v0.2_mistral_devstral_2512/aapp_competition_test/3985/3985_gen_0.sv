module max_operations (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] m,
    input [7:0] a_i,
    input [2:0] idx1_i,
    input [2:0] idx2_i,
    output reg [5:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        LOAD_ARRAY,
        LOAD_PAIRS,
        FACTOR,
        BUILD,
        MATCH_BFS,
        MATCH_DFS,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [2:0] n_reg, m_reg;
    reg [7:0] a [0:7];
    reg [2:0] idx1 [0:7], idx2 [0:7];
    reg [2:0] load_idx;
    reg [2:0] factor_idx;
    reg [2:0] build_idx;
    reg [2:0] bfs_idx, dfs_idx;

    // Prime factorization storage
    reg [7:0] factors [0:7][0:7]; // [number_idx][factor_idx]
    reg [2:0] factor_count [0:7];

    // Bipartite graph storage
    reg [4:0] left_nodes [0:31]; // [node_idx] = array_idx
    reg [4:0] right_nodes [0:31]; // [node_idx] = array_idx
    reg [4:0] left_count, right_count;
    reg [31:0] adj_matrix [0:31]; // [left_node][right_node]

    // Hopcroft-Karp variables
    reg [4:0] left_match [0:31]; // left_match[i] = matched right node
    reg [4:0] right_match [0:31]; // right_match[j] = matched left node
    reg [4:0] dist [0:31];
    reg [4:0] queue [0:31];
    reg [4:0] q_head, q_tail;
    reg [4:0] matching_count;

    // Precomputed primes up to 255
    localparam [7:0] primes [0:54] = '{2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,211,223,227,229,233,239,241,251};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            load_idx <= 0;
            factor_idx <= 0;
            build_idx <= 0;
            bfs_idx <= 0;
            dfs_idx <= 0;
            left_count <= 0;
            right_count <= 0;
            q_head <= 0;
            q_tail <= 0;
            matching_count <= 0;
            for (int i = 0; i < 8; i++) begin
                factor_count[i] <= 0;
                for (int j = 0; j < 8; j++) begin
                    factors[i][j] <= 0;
                end
            end
            for (int i = 0; i < 32; i++) begin
                left_match[i] <= 0;
                right_match[i] <= 0;
                dist[i] <= 0;
                adj_matrix[i] <= 0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_ARRAY;
            end
            LOAD_ARRAY: begin
                if (load_idx == n_reg - 1) next_state = LOAD_PAIRS;
            end
            LOAD_PAIRS: begin
                if (load_idx == m_reg - 1) next_state = FACTOR;
            end
            FACTOR: begin
                if (factor_idx == n_reg - 1) next_state = BUILD;
            end
            BUILD: begin
                if (build_idx == m_reg - 1) next_state = MATCH_BFS;
            end
            MATCH_BFS: begin
                if (bfs_idx == left_count) next_state = MATCH_DFS;
            end
            MATCH_DFS: begin
                if (dfs_idx == left_count) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load array phase
    always @(posedge clk) begin
        if (state == LOAD_ARRAY && load_idx < n_reg) begin
            a[load_idx] <= a_i;
            load_idx <= load_idx + 1;
        end
    end

    // Load pairs phase
    always @(posedge clk) begin
        if (state == LOAD_PAIRS && load_idx < m_reg) begin
            idx1[load_idx] <= idx1_i - 1;
            idx2[load_idx] <= idx2_i - 1;
            load_idx <= load_idx + 1;
        end
    end

    // Factorization phase
    always @(posedge clk) begin
        if (state == FACTOR && factor_idx < n_reg) begin
            reg [7:0] num = a[factor_idx];
            reg [7:0] temp = num;
            reg [2:0] cnt = 0;
            for (int i = 0; i < 54; i++) begin
                if (primes[i] > temp) break;
                while (temp % primes[i] == 0) begin
                    factors[factor_idx][cnt] = primes[i];
                    cnt = cnt + 1;
                    temp = temp / primes[i];
                end
            end
            if (temp > 1) begin
                factors[factor_idx][cnt] = temp;
                cnt = cnt + 1;
            end
            factor_count[factor_idx] = cnt;
            factor_idx <= factor_idx + 1;
        end
    end

    // Build graph phase
    always @(posedge clk) begin
        if (state == BUILD && build_idx < m_reg) begin
            reg [2:0] i = idx1[build_idx];
            reg [2:0] j = idx2[build_idx];
            reg is_odd_i = (i % 2 == 1);
            reg is_odd_j = (j % 2 == 1);

            if (is_odd_i && !is_odd_j) begin
                // Connect left factors of i to right factors of j
                for (int fi = 0; fi < factor_count[i]; fi++) begin
                    for (int fj = 0; fj < factor_count[j]; fj++) begin
                        if (factors[i][fi] == factors[j][fj]) begin
                            reg [4:0] left_node = left_count + fi;
                            reg [4:0] right_node = right_count + fj;
                            adj_matrix[left_node][right_node] = 1;
                        end
                    end
                end
                left_count = left_count + factor_count[i];
                right_count = right_count + factor_count[j];
            end else if (!is_odd_i && is_odd_j) begin
                // Connect left factors of j to right factors of i
                for (int fj = 0; fj < factor_count[j]; fj++) begin
                    for (int fi = 0; fi < factor_count[i]; fi++) begin
                        if (factors[j][fj] == factors[i][fi]) begin
                            reg [4:0] left_node = left_count + fj;
                            reg [4:0] right_node = right_count + fi;
                            adj_matrix[left_node][right_node] = 1;
                        end
                    end
                end
                left_count = left_count + factor_count[j];
                right_count = right_count + factor_count[i];
            end
            build_idx <= build_idx + 1;
        end
    end

    // BFS phase
    always @(posedge clk) begin
        if (state == MATCH_BFS) begin
            if (bfs_idx == 0) begin
                // Initialize BFS
                for (int i = 0; i < left_count; i++) begin
                    if (left_match[i] == 0) begin
                        dist[i] = 0;
                        queue[q_tail] = i;
                        q_tail = q_tail + 1;
                    end else begin
                        dist[i] = 32;
                    end
                end
            end else begin
                // Process queue
                if (q_head < q_tail) begin
                    reg [4:0] u = queue[q_head];
                    q_head = q_head + 1;
                    if (dist[u] < 32) begin
                        for (int v = 0; v < right_count; v++) begin
                            if (adj_matrix[u][v] && right_match[v] != 32 && dist[right_match[v]] == 32) begin
                                dist[right_match[v]] = dist[u] + 1;
                                queue[q_tail] = right_match[v];
                                q_tail = q_tail + 1;
                            end
                        end
                    end
                end
            end
            bfs_idx <= bfs_idx + 1;
        end
    end

    // DFS phase
    always @(posedge clk) begin
        if (state == MATCH_DFS) begin
            if (dfs_idx == 0) begin
                // Initialize DFS
                for (int i = 0; i < left_count; i++) begin
                    if (left_match[i] == 0) begin
                        if (dfs(i)) begin
                            matching_count = matching_count + 1;
                        end
                    end
                end
            end
            dfs_idx <= dfs_idx + 1;
        end
    end

    // DFS function
    function reg dfs(input [4:0] u);
        for (int v = 0; v < right_count; v++) begin
            if (adj_matrix[u][v]) begin
                if (right_match[v] == 32 || (dist[right_match[v]] == dist[u] + 1 && dfs(right_match[v]))) begin
                    right_match[v] = u;
                    left_match[u] = v;
                    return 1;
                end
            end
        end
        dist[u] = 32;
        return 0;
    endfunction

    // Done state
    always @(posedge clk) begin
        if (state == DONE) begin
            done <= 1;
            result <= matching_count;
        end else begin
            done <= 0;
        end
    end

    // Initialize registers on start
    always @(posedge clk) begin
        if (start && state == IDLE) begin
            n_reg <= n;
            m_reg <= m;
            load_idx <= 0;
            factor_idx <= 0;
            build_idx <= 0;
            bfs_idx <= 0;
            dfs_idx <= 0;
            left_count <= 0;
            right_count <= 0;
            q_head <= 0;
            q_tail <= 0;
            matching_count <= 0;
            for (int i = 0; i < 8; i++) begin
                factor_count[i] <= 0;
                for (int j = 0; j < 8; j++) begin
                    factors[i][j] <= 0;
                end
            end
            for (int i = 0; i < 32; i++) begin
                left_match[i] <= 32;
                right_match[i] <= 32;
                dist[i] <= 0;
                adj_matrix[i] <= 0;
            end
        end
    end

endmodule