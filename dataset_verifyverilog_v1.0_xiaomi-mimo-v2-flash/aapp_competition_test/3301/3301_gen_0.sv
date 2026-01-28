module PathfindingTax (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] edges_src [0:31],
    input wire [31:0] edges_dst [0:31],
    input wire [31:0] edges_wt [0:31],
    input wire [15:0] swerc_nodes,
    input wire [3:0] num_nodes,
    input wire [5:0] num_edges,
    input wire [3:0] src_node,
    input wire [3:0] dst_node,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [4:0] IDLE           = 5'd0;
    localparam [4:0] CHECK_INPUTS   = 5'd1;
    localparam [4:0] DIJKSTRA_NON   = 5'd2;
    localparam [4:0] PREPARE_BS     = 5'd3;
    localparam [4:0] DIJKSTRA_SWERC = 5'd4;
    localparam [4:0] COMPARE        = 5'd5;
    localparam [4:0] UPDATE_BS      = 5'd6;
    localparam [4:0] BS_DONE        = 5'd7;
    localparam [4:0] OUTPUT_RESULT  = 5'd8;
    localparam [4:0] OUTPUT_INF     = 5'd9;
    localparam [4:0] OUTPUT_IMP     = 5'd10;

    // Special result values
    localparam [31:0] VAL_INFINITE = 32'hFFFFFFFF;
    localparam [31:0] VAL_IMPOSSIBLE = 32'hFFFFFFFE;
    localparam [31:0] MAX_T_LIMIT = 32'd1000000000; // 10^9 limit for safety

    reg [4:0] state, next_state;
    
    // Dijkstra control signals
    reg dijkstra_start;
    wire dijkstra_done;
    wire [63:0] dijkstra_cost;
    wire dijkstra_found;
    reg [3:0] dijkstra_src;
    reg [3:0] dijkstra_dst;
    reg [31:0] dijkstra_T;
    reg use_swerc_nodes;

    // Intermediate storage
    reg [63:0] min_non_swerc_cost;
    reg [31:0] current_T;
    reg [31:0] best_T;
    reg [31:0] low, high;
    reg [31:0] swerc_cost_T;
    reg path_valid_T;
    
    // Counters for wait states
    reg [7:0] wait_cnt;

    // Dijkstra Submodule Instantiation
    DijkstraEngine dijkstra_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(dijkstra_start),
        .src(dijkstra_src),
        .dst(dijkstra_dst),
        .T(dijkstra_T),
        .use_swerc(use_swerc_nodes),
        .edges_src(edges_src),
        .edges_dst(edges_dst),
        .edges_wt(edges_wt),
        .swerc_nodes(swerc_nodes),
        .num_nodes(num_nodes),
        .num_edges(num_edges),
        .done(dijkstra_done),
        .min_cost(dijkstra_cost),
        .found(dijkstra_found)
    );

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            dijkstra_start <= 1'b0;
            low <= 32'd0;
            high <= 32'd0;
            best_T <= 32'd0;
            min_non_swerc_cost <= 64'd0;
            swerc_cost_T <= 64'd0;
            path_valid_T <= 1'b0;
            wait_cnt <= 8'd0;
        end else begin
            done <= 1'b0;
            dijkstra_start <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Check if source and dest are SWERC (problem requirement)
                        if (swerc_nodes[src_node] && swerc_nodes[dst_node]) begin
                            state <= DIJKSTRA_NON;
                        end else begin
                            // Source or Dest not SWERC, SWERC path impossible as per problem statement
                            state <= OUTPUT_IMP;
                        end
                    end
                end

                DIJKSTRA_NON: begin
                    // Run Dijkstra on full graph (T=0, ignore swerc restriction)
                    if (!dijkstra_start && !dijkstra_done) begin
                        dijkstra_start <= 1'b1;
                        dijkstra_src <= src_node;
                        dijkstra_dst <= dst_node;
                        dijkstra_T <= 32'd0;
                        use_swerc_nodes <= 1'b0;
                    end else if (dijkstra_done) begin
                        if (dijkstra_found) begin
                            min_non_swerc_cost <= dijkstra_cost;
                            state <= PREPARE_BS;
                        end else begin
                            // Non-SWERC path unreachable. SWERC path is valid if it exists.
                            // We need to verify SWERC path exists.
                            state <= PREPARE_BS;
                        end
                    end
                end

                PREPARE_BS: begin
                    // Check if SWERC path exists at all (T=0)
                    if (!dijkstra_start && !dijkstra_done) begin
                        dijkstra_start <= 1'b1;
                        dijkstra_src <= src_node;
                        dijkstra_dst <= dst_node;
                        dijkstra_T <= 32'd0;
                        use_swerc_nodes <= 1'b1; // Only SWERC nodes
                    end else if (dijkstra_done) begin
                        if (dijkstra_found) begin
                            // If Non-SWERC is unreachable (cost is huge or found is false logic handled above)
                            // Actually, if Non-SWERC is unreachable, we set min_non_swerc to INF in previous state logic
                            // Let's refine: if Non-SWERC is unreachable, we output INFINITY immediately if SWERC path exists.
                            if (min_non_swerc_cost >= 64'hFFFFFFFFFFFFFF00) begin // Treat as infinity
                                state <= OUTPUT_INF;
                            end else begin
                                // Non-SWERC path exists, SWERC path exists.
                                // Start Binary Search for Max T.
                                // Note: T is integer. Range 0 to 10^9 (or 2^30).
                                low <= 32'd0;
                                high <= 32'd1000000000;
                                best_T <= 32'd0;
                                state <= DIJKSTRA_SWERC;
                            end
                        end else begin
                            // SWERC path doesn't exist (even with T=0)
                            state <= OUTPUT_IMP;
                        end
                    end
                end

                DIJKSTRA_SWERC: begin
                    // Binary Search Step
                    // Run Dijkstra with T = (low + high) / 2
                    if (!dijkstra_start && !dijkstra_done) begin
                        current_T <= (low + high) >> 1;
                        dijkstra_start <= 1'b1;
                        dijkstra_src <= src_node;
                        dijkstra_dst <= dst_node;
                        dijkstra_T <= (low + high) >> 1;
                        use_swerc_nodes <= 1'b1;
                    end else if (dijkstra_done) begin
                        if (dijkstra_found) begin
                            swerc_cost_T <= dijkstra_cost;
                            path_valid_T <= 1'b1;
                            state <= COMPARE;
                        end else begin
                            // For this T, SWERC path invalid (shouldn't happen if T=0 valid, unless weights cause overflow?)
                            // Treat as too expensive.
                            swerc_cost_T <= 64'hFFFFFFFFFFFFFF00;
                            path_valid_T <= 1'b0;
                            state <= COMPARE;
                        end
                    end
                end

                COMPARE: begin
                    // Compare swerc_cost_T + (current_T * edges_count) vs min_non_swerc_cost
                    // Dijkstra engine already includes T*edges in cost.
                    // Condition: SWERC path is strictly cheaper.
                    if (path_valid_T && (swerc_cost_T < min_non_swerc_cost)) begin
                        // This T works, try higher
                        best_T <= current_T;
                        if (current_T == MAX_T_LIMIT) begin
                            state <= OUTPUT_INF;
                        end else begin
                            state <= UPDATE_BS;
                        end
                    end else begin
                        // This T fails (too expensive or invalid), try lower
                        if (current_T == 0) begin
                            // No valid T found (T=0 failed)
                            state <= OUTPUT_IMP;
                        end else begin
                            state <= UPDATE_BS;
                        end
                    end
                end

                UPDATE_BS: begin
                    if (path_valid_T && (swerc_cost_T < min_non_swerc_cost)) begin
                        // Current T works, move lower bound up
                        if (current_T == MAX_T_LIMIT) begin
                            state <= OUTPUT_INF;
                        end else begin
                            if (current_T == high) state <= BS_DONE;
                            else begin
                                low <= current_T + 32'd1;
                                if (low + 32'd1 > high) state <= BS_DONE;
                                else state <= DIJKSTRA_SWERC;
                            end
                        end
                    end else begin
                        // Current T fails, move upper bound down
                        if (current_T == 0) state <= BS_DONE; 
                        else begin
                            if (current_T == low) state <= BS_DONE;
                            else begin
                                high <= current_T - 32'd1;
                                if (low > current_T - 32'd1) state <= BS_DONE;
                                else state <= DIJKSTRA_SWERC;
                            end
                        end
                    end
                end

                BS_DONE: begin
                    // Best T found in range
                    if (best_T == 0 && !path_valid_T) begin
                        // Failed even at T=0 (re-check logic, but handled in COMPARE)
                        state <= OUTPUT_IMP;
                    end else begin
                        result <= best_T;
                        state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                OUTPUT_INF: begin
                    result <= VAL_INFINITE;
                    done <= 1'b1;
                    state <= IDLE;
                end

                OUTPUT_IMP: begin
                    result <= VAL_IMPOSSIBLE;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

module DijkstraEngine (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] src,
    input wire [3:0] dst,
    input wire [31:0] T,
    input wire use_swerc,
    input wire [31:0] edges_src [0:31],
    input wire [31:0] edges_dst [0:31],
    input wire [31:0] edges_wt [0:31],
    input wire [15:0] swerc_nodes,
    input wire [3:0] num_nodes,
    input wire [5:0] num_edges,
    output reg done,
    output reg [63:0] min_cost,
    output reg found
);

    localparam [3:0] INIT = 4'd0;
    localparam [3:0] SELECT_U = 4'd1;
    localparam [3:0] CHECK_VISITED = 4'd2;
    localparam [3:0] UPDATE_NEIGHBORS = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;
    localparam [3:0] WAIT_START = 4'd5;

    reg [3:0] state;
    reg [63:0] dist [0:15];
    reg visited [0:15];
    reg [3:0] u;
    reg [3:0] i; // loop for neighbors
    reg [5:0] edge_idx;
    reg [63:0] alt;
    reg [3:0] v;
    
    integer idx;
    
    // Localparam for infinity
    localparam [63:0] INF = 64'h00FFFFFFFFFFFFFF; // 64-bit max safe

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT_START;
            done <= 1'b0;
            min_cost <= 64'd0;
            found <= 1'b0;
            // Initialize dist/visited arrays
            for (idx = 0; idx < 16; idx = idx + 1) begin
                dist[idx] <= INF;
                visited[idx] <= 1'b0;
            end
        end else begin
            case (state)
                WAIT_START: begin
                    if (start) begin
                        // Initialize
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            dist[idx] <= INF;
                            visited[idx] <= 1'b0;
                        end
                        dist[src] <= 64'd0;
                        u <= 4'd0;
                        i <= 4'd0;
                        edge_idx <= 6'd0;
                        state <= SELECT_U;
                    end
                end

                SELECT_U: begin
                    // Find unvisited node with min dist
                    reg [63:0] min_dist;
                    reg [3:0] min_node;
                    reg found_min;
                    
                    min_dist = INF;
                    min_node = 4'd15;
                    found_min = 1'b0;
                    
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        if (!visited[idx] && dist[idx] < min_dist) begin
                            min_dist = dist[idx];
                            min_node = idx;
                            found_min = 1'b1;
                        end
                    end
                    
                    if (found_min && min_node <= num_nodes) begin
                        u <= min_node;
                        state <= CHECK_VISITED;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                CHECK_VISITED: begin
                    if (visited[u] || dist[u] == INF) begin
                        state <= DONE_STATE;
                    end else begin
                        visited[u] <= 1'b1;
                        edge_idx <= 6'd0;
                        state <= UPDATE_NEIGHBORS;
                    end
                end

                UPDATE_NEIGHBORS: begin
                    if (edge_idx < num_edges) begin
                        // Check if this edge starts from u
                        if (edges_src[edge_idx] == u) begin
                            v <= edges_dst[edge_idx];
                            
                            // Check SWERC constraint if active
                            if (!use_swerc || (swerc_nodes[edges_dst[edge_idx]] && swerc_nodes[u])) begin
                                // Calculate cost: weight + T (if edge connects SWERC nodes)
                                // If use_swerc is true, u is SWERC (checked above) and v is SWERC.
                                // If use_swerc is false, no tax.
                                // Note: In the SWERC search, we only traverse SWERC nodes, so edges are always SWERC-SWERC.
                                // In full graph search, tax is applied if EITHER end is SWERC? 
                                // Problem: "edge connected to a SWERC node (source or dest) incurs an additional tax T."
                                // However, standard Dijkstra runs on given weights. 
                                // The 'tax' is part of the 'cheapest path' calculation for the SWERC path.
                                // The problem implies we want to find if exists path using ONLY SWERC nodes.
                                // In the NON-SWERC search (step 1 logic in prompt), we find min cost without tax constraint.
                                // So Dijkstra engine is used in two modes:
                                // 1. Full Graph (use_swerc=0): Weight = edges_wt[edge_idx].
                                // 2. SWERC Graph (use_swerc=1): Weight = edges_wt[edge_idx] + T.
                                
                                if (use_swerc) begin
                                    // Add T to edge weight. Check overflow 32 -> 64
                                    alt <= dist[u] + edges_wt[edge_idx] + T;
                                end else begin
                                    alt <= dist[u] + edges_wt[edge_idx];
                                end
                                
                                // Need 1 cycle delay for dist update check? 
                                // We can check immediately.
                                if (alt < dist[v]) begin
                                    dist[v] <= alt;
                                end
                            end
                        end
                        edge_idx <= edge_idx + 6'd1;
                        state <= UPDATE_NEIGHBORS;
                    end else begin
                        state <= SELECT_U;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (dist[dst] < INF) begin
                        found <= 1'b1;
                        min_cost <= dist[dst];
                    end else begin
                        found <= 1'b0;
                        min_cost <= 64'd0;
                    end
                    state <= WAIT_START;
                end
                
                default: state <= WAIT_START;
            endcase
        end
    end
endmodule