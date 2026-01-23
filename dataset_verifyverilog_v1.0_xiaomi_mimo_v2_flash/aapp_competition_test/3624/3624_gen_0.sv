module trekking #(
    parameter N = 5,                    // Number of cabins (1..8)
    parameter M = 6,                    // Number of trails (1..16)
    parameter logic [3:0] U [0:M-1] = '{5,0,1,2,2,4}, // Trail start nodes (0..N-1)
    parameter logic [3:0] V [0:M-1] = '{1,3,2,3,4,3}, // Trail end nodes
    parameter logic [3:0] D [0:M-1] = '{2,8,11,5,2,9}  // Trail durations (0..12)
) (
    input  wire       clk,      // Clock
    input  wire       rst_n,    // Active-low reset
    input  wire       start,    // Start computation (pulse after parameters set)
    output reg  [7:0] result,   // Waiting time (hours)
    output reg        done      // Computation finished, result valid
);

// ============================================================================
// CONSTANTS & LOCALPARAMETERS
// ============================================================================
localparam INF       = 8'hFF;    // Infinity for distances (255)
localparam NO_EDGE   = 4'hF;     // No edge in adjacency matrix (15)
localparam MAX_N     = 8;        // Maximum supported nodes
localparam MAX_STATE = 13;       // States per node (0..12 hours)

// State machine states
localparam [4:0] S_IDLE        = 5'd0;
localparam [4:0] S_INIT        = 5'd1;  // Initialize matrices
localparam [4:0] S_FLOYD_INIT  = 5'd2;  // Prepare Floyd-Warshall
localparam [4:0] S_FLOYD_K     = 5'd3;  // Floyd-Warshall k loop
localparam [4:0] S_FLOYD_I     = 5'd4;  // Floyd-Warshall i loop
localparam [4:0] S_FLOYD_J     = 5'd5;  // Floyd-Warshall j loop
localparam [4:0] S_FLOYD_UPD   = 5'd6;  // Floyd-Warshall update
localparam [4:0] S_KNIGHT_CALC = 5'd7;  // Compute Dr. Knight elapsed
localparam [4:0] S_DK_INIT     = 5'd8;  // Dijkstra init
localparam [4:0] S_DK_LOOP     = 5'd9;  // Dijkstra main loop
localparam [4:0] S_DK_RELAX    = 5'd10; // Relax neighbors
localparam [4:0] S_DK_SLEEP    = 5'd11; // Relax sleep transition
localparam [4:0] S_DK_RESULT   = 5'd12; // Extract Mr. Day elapsed
localparam [4:0] S_WAIT        = 5'd13; // Wait one cycle
localparam [4:0] S_DONE        = 5'd14; // Finish

// ============================================================================
// REGISTERS & WIRES
// ============================================================================
reg  [4:0]  state, next_state;
reg  [3:0]  i_reg, j_reg, k_reg;  // Loop counters (0..MAX_N-1)
reg  [3:0]  e_reg;                // Edge counter (0..M-1)
reg  [7:0]  knight_elapsed_reg;   // Dr. Knight elapsed time
reg  [7:0]  day_elapsed_reg;      // Mr. Day elapsed time
reg  [7:0]  T_knight;             // Shortest path distance
reg  [7:0]  min_dist;             // Minimum distance in Dijkstra
reg  [3:0]  best_state;           // State with minimum distance
reg         found_min;            // Flag for min found
reg  [7:0]  dist [0:MAX_N-1][0:MAX_N-1]; // Floyd-Warshall distance matrix
reg  [3:0]  adj  [0:MAX_N-1][0:MAX_N-1]; // Adjacency matrix (min edge weight)
reg  [7:0]  dist_state [0:(MAX_STATE*MAX_N)-1];  // Dijkstra distances per state
reg         visited  [0:(MAX_STATE*MAX_N)-1];    // Dijkstra visited flags
reg  [3:0]  node_u;               // For Dijkstra relaxation
reg  [3:0]  hours_cur;            // Hours at current node
reg  [7:0]  new_dist;
reg  [3:0]  state_idx;            // Index = node * 13 + hours
reg  [3:0]  loop_counter;         // General loop counter
reg  [7:0]  temp_dist;
reg  [3:0]  temp_node;
reg  [3:0]  temp_hours;

// ============================================================================
// STATE TRANSITION & OUTPUT LOGIC
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        result <= 0;
    end else begin
        state <= next_state;
        // Default: clear done when not in DONE
        if (state != S_DONE) done <= 0;
        if (state == S_DONE) begin
            result <= day_elapsed_reg - knight_elapsed_reg; // Waiting time
            done <= 1;
        end
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE:        if (start) next_state = S_INIT;
        S_INIT:        if (e_reg >= M) next_state = S_FLOYD_INIT;
                        else next_state = S_INIT;
        S_FLOYD_INIT:  next_state = S_FLOYD_K;
        S_FLOYD_K:     if (k_reg >= N) next_state = S_KNIGHT_CALC;
                        else next_state = S_FLOYD_I;
        S_FLOYD_I:     if (i_reg >= N) next_state = S_FLOYD_K;
                        else next_state = S_FLOYD_J;
        S_FLOYD_J:     if (j_reg >= N) next_state = S_FLOYD_UPD;
                        else next_state = S_FLOYD_J;
        S_FLOYD_UPD:   next_state = S_FLOYD_I;
        S_KNIGHT_CALC: next_state = S_DK_INIT;
        S_DK_INIT:     next_state = S_DK_LOOP;
        S_DK_LOOP:     if (found_min) next_state = S_DK_RELAX;
                        else if (day_elapsed_reg != INF) next_state = S_DK_RESULT; // All processed
                        else next_state = S_DK_RESULT;
        S_DK_RELAX:    next_state = S_DK_SLEEP;
        S_DK_SLEEP:    if (hours_cur == 0) next_state = S_DK_LOOP;
                        else next_state = S_DK_LOOP;
        S_DK_RESULT:   next_state = S_WAIT;
        S_WAIT:        next_state = S_DONE;
        S_DONE:        next_state = S_IDLE;
        default:       next_state = S_IDLE;
    endcase
end

// ============================================================================
// DATA PATH - COMPUTATION LOGIC
// ============================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all arrays and counters
        integer r, c, s;
        for (r = 0; r < MAX_N; r = r + 1) begin
            for (c = 0; c < MAX_N; c = c + 1) begin
                dist[r][c] <= INF;
                adj[r][c] <= NO_EDGE;
            end
        end
        for (s = 0; s < (MAX_STATE * MAX_N); s = s + 1) begin
            dist_state[s] <= INF;
            visited[s] <= 0;
        end
        i_reg <= 0; j_reg <= 0; k_reg <= 0; e_reg <= 0;
        knight_elapsed_reg <= 0; day_elapsed_reg <= 0;
        T_knight <= 0;
        min_dist <= 0; best_state <= 0; found_min <= 0;
        node_u <= 0; hours_cur <= 0;
        new_dist <= 0; state_idx <= 0;
        loop_counter <= 0;
        temp_dist <= 0;
        temp_node <= 0;
        temp_hours <= 0;
    end else begin
        case (state)
            // ----------------------------------------------------------------
            // INIT: Load edges into adjacency matrix (take minimum)
            // ----------------------------------------------------------------
            S_INIT: begin
                if (e_reg < M) begin
                    // Update both directions (undirected graph)
                    if (adj[U[e_reg]][V[e_reg]] > D[e_reg])
                        adj[U[e_reg]][V[e_reg]] <= D[e_reg];
                    if (adj[V[e_reg]][U[e_reg]] > D[e_reg])
                        adj[V[e_reg]][U[e_reg]] <= D[e_reg];
                    e_reg <= e_reg + 1;
                end else begin
                    // Initialize distance matrix with adjacency
                    for (integer r = 0; r < N; r = r + 1) begin
                        for (integer c = 0; c < N; c = c + 1) begin
                            if (r == c)
                                dist[r][c] <= 8'd0;
                            else if (adj[r][c] != NO_EDGE)
                                dist[r][c] <= {4'd0, adj[r][c]}; // Convert 4-bit to 8-bit
                            else
                                dist[r][c] <= INF;
                        end
                    end
                end
            end

            // ----------------------------------------------------------------
            // FLOYD-WARSHALL INIT: Reset loop counters
            // ----------------------------------------------------------------
            S_FLOYD_INIT: begin
                k_reg <= 0; i_reg <= 0; j_reg <= 0;
            end

            // ----------------------------------------------------------------
            // FLOYD-WARSHALL LOOPS: k, i, j
            // ----------------------------------------------------------------
            S_FLOYD_K: begin
                i_reg <= 0;
                if (k_reg < N) k_reg <= k_reg + 1;
            end
            S_FLOYD_I: begin
                j_reg <= 0;
                if (i_reg < N) i_reg <= i_reg + 1;
            end
            S_FLOYD_J: begin
                if (j_reg < N) j_reg <= j_reg + 1;
            end

            // ----------------------------------------------------------------
            // FLOYD-WARSHALL UPDATE: dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
            // ----------------------------------------------------------------
            S_FLOYD_UPD: begin
                if (k_reg < N && i_reg < N && j_reg < N) begin
                    if (dist[i_reg][k_reg] != INF && dist[k_reg][j_reg] != INF) begin
                        new_dist <= dist[i_reg][k_reg] + dist[k_reg][j_reg];
                        // Update if better (comb logic for min)
                        if (dist[i_reg][k_reg] + dist[k_reg][j_reg] < dist[i_reg][j_reg]) begin
                            dist[i_reg][j_reg] <= dist[i_reg][k_reg] + dist[k_reg][j_reg];
                        end
                    end
                end
            end

            // ----------------------------------------------------------------
            // KNIGHT CALC: Compute T_knight and knight_elapsed
            // ----------------------------------------------------------------
            S_KNIGHT_CALC: begin
                T_knight <= dist[0][N-1];
                if (dist[0][N-1] != INF) begin
                    // days = ceil(T/12) = (T + 11) / 12
                    // knight_elapsed = T + 12*(days-1)
                    if (dist[0][N-1] <= 8'd12)
                        knight_elapsed_reg <= dist[0][N-1];
                    else begin
                        // Compute (dist[0][N-1] + 11) / 12 using a loop (synthesis unrolls)
                        // Since max dist is 84, loop runs at most 7 times
                        loop_counter <= 0;
                        temp_dist <= dist[0][N-1];
                    end
                end else begin
                    knight_elapsed_reg <= INF; // No path
                end
                // Handle the division logic immediately if needed
                if (dist[0][N-1] > 8'd12) begin
                    // Manual integer division for small numbers
                    if (dist[0][N-1] > 8'd23) begin
                        if (dist[0][N-1] > 8'd35) begin
                            if (dist[0][N-1] > 8'd47) begin
                                if (dist[0][N-1] > 8'd59) begin
                                    if (dist[0][N-1] > 8'd71) begin
                                        knight_elapsed_reg <= dist[0][N-1] + 8'd72; // days = 7
                                    end else begin
                                        knight_elapsed_reg <= dist[0][N-1] + 8'd60; // days = 6
                                    end
                                end else begin
                                    knight_elapsed_reg <= dist[0][N-1] + 8'd48; // days = 5
                                end
                            end else begin
                                knight_elapsed_reg <= dist[0][N-1] + 8'd36; // days = 4
                            end
                        end else begin
                            knight_elapsed_reg <= dist[0][N-1] + 8'd24; // days = 3
                        end
                    end else begin
                        knight_elapsed_reg <= dist[0][N-1] + 8'd12; // days = 2
                    end
                end
            end

            // ----------------------------------------------------------------
            // DIJKSTRA INIT: Initialize state distances and visited
            // ----------------------------------------------------------------
            S_DK_INIT: begin
                for (integer s = 0; s < (MAX_STATE * MAX_N); s = s + 1) begin
                    dist_state[s] <= INF;
                    visited[s] <= 0;
                end
                // State (0,0) index = 0*13 + 0 = 0
                dist_state[0] <= 0;
                min_dist <= INF;
                found_min <= 0;
            end

            // ----------------------------------------------------------------
            // DIJKSTRA LOOP: Find unvisited state with minimum distance
            // ----------------------------------------------------------------
            S_DK_LOOP: begin
                min_dist <= INF;
                found_min <= 0;
                // Scan all states to find minimum
                for (integer s = 0; s < (N * MAX_STATE); s = s + 1) begin
                    if (!visited[s] && dist_state[s] < min_dist) begin
                        min_dist <= dist_state[s];
                        best_state <= s;
                        found_min <= 1;
                    end
                end
                // If we found a min, we will mark visited and relax in next states
                if (found_min) begin
                    visited[best_state] <= 1;
                    // Extract node and hours from best_state
                    node_u <= best_state / 13;        // node = index / 13
                    hours_cur <= best_state % 13;     // hours = index % 13
                end
            end

            // ----------------------------------------------------------------
            // DIJKSTRA RELAX: Walk transitions (edges from node_u)
            // ----------------------------------------------------------------
            S_DK_RELAX: begin
                // Iterate over all possible neighbors
                for (integer v = 0; v < N; v = v + 1) begin
                    if (adj[node_u][v] != NO_EDGE) begin
                        // Check if edge fits within remaining hours today
                        if (hours_cur + adj[node_u][v] <= 12) begin
                            // Compute new state index
                            state_idx <= v * 13 + (hours_cur + adj[node_u][v]);
                            new_dist <= dist_state[best_state] + adj[node_u][v];
                            // Update if better (comb logic)
                            if (dist_state[best_state] + adj[node_u][v] < dist_state[v * 13 + (hours_cur + adj[node_u][v])]) begin
                                dist_state[v * 13 + (hours_cur + adj[node_u][v])] <= dist_state[best_state] + adj[node_u][v];
                            end
                        end
                    end
                end
            end

            // ----------------------------------------------------------------
            // DIJKSTRA SLEEP: Sleep transition (reset hours, add 24 - hours_cur)
            // ----------------------------------------------------------------
            S_DK_SLEEP: begin
                if (hours_cur > 0) begin
                    // Sleep transition: (node_u, 0) with cost 24 - hours_cur
                    state_idx <= node_u * 13 + 0;
                    new_dist <= dist_state[best_state] + (24 - hours_cur);
                    // Update if better
                    if (dist_state[best_state] + (24 - hours_cur) < dist_state[node_u * 13 + 0]) begin
                        dist_state[node_u * 13 + 0] <= dist_state[best_state] + (24 - hours_cur);
                    end
                end
            end

            // ----------------------------------------------------------------
            // DIJKSTRA RESULT: Find minimum elapsed time to destination
            // ----------------------------------------------------------------
            S_DK_RESULT: begin
                day_elapsed_reg <= INF;
                for (integer h = 0; h <= 12; h = h + 1) begin
                    integer idx = (N-1) * 13 + h;
                    if (dist_state[idx] < day_elapsed_reg) begin
                        day_elapsed_reg <= dist_state[idx];
                    end
                end
            end

            // ----------------------------------------------------------------
            // WAIT: One cycle to latch result
            // ----------------------------------------------------------------
            S_WAIT: begin
                // Nothing, just transition to DONE
            end

            // ----------------------------------------------------------------
            // DONE: Result already latched in state transition
            // ----------------------------------------------------------------
            S_DONE: begin
                // Nothing
            end

            default: begin
                // Reset counters
                e_reg <= 0; i_reg <= 0; j_reg <= 0; k_reg <= 0;
            end
        endcase
    end
end

endmodule