module shortest_path_edge_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Graph configuration interface
    input wire [3:0] config_edge_index,  // Edge ID: 0 to 15
    input wire [3:0] config_src,         // Source city: 0 to 7
    input wire [3:0] config_dst,         // Destination city: 0 to 7  
    input wire [15:0] config_weight,     // Edge weight: 0 to 65535
    input wire config_valid,             // Write edge to memory
    input wire [3:0] num_edges,          // Total edges (1 to 8)
    
    // Computation control
    input wire compute_start,            // Pulse high to start computation
    
    // Result output
    output reg [3:0] result_edge_index,  // Which edge this result is for
    output reg [31:0] result_count,      // Number of shortest paths containing this edge
    output reg result_valid,             // Result is valid
    output reg done                      // All results computed
);

// Parameters
parameter MAX_CITIES = 8;
parameter MAX_EDGES = 16;
parameter MODULUS = 1000000007;

// Memory for graph data (packed edge format)
reg [23:0] edge_memory [0:15];  // {src[3:0], dst[3:0], weight[15:0]}

// State machine states
localparam [3:0] IDLE = 4'd0;
localparam [3:0] LOAD_EDGES = 4'd1;
localparam [3:0] COMPUTE_FLOYD = 4'd2;
localparam [3:0] COUNT_PATHS = 4'd3;
localparam [3:0] OUTPUT_RESULTS = 4'd4;
localparam [3:0] FINISHED = 4'd5;

reg [3:0] current_state, next_state;

// Floyd-Warshall matrices (using 8x8 arrays)
reg [31:0] dist [0:7][0:7];      // Shortest distances
reg [31:0] paths [0:7][0:7];     // Number of shortest paths

// Iteration counters
reg [2:0] i, j, k;  // For Floyd-Warshall loops
reg [3:0] edge_idx; // For counting and output

// Helper: extract fields from packed edge
wire [3:0] edge_src = edge_memory[edge_idx][23:20];
wire [3:0] edge_dst = edge_memory[edge_idx][19:16];
wire [15:0] edge_w = edge_memory[edge_idx][15:0];

// Modulo addition helper
function automatic [31:0] mod_add;
    input [31:0] a, b;
    begin
        mod_add = (a + b) % MODULUS;
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (compute_start && num_edges > 0)
                next_state = COMPUTE_FLOYD;
            else if (config_valid)
                next_state = LOAD_EDGES;
        end
        
        LOAD_EDGES: begin
            if (!config_valid && compute_start)
                next_state = COMPUTE_FLOYD;
            else
                next_state = LOAD_EDGES;
        end
        
        COMPUTE_FLOYD: begin
            if (i == 0 && j == 0 && k == 0)
                next_state = COUNT_PATHS;  // Floyd-Warshall complete
            else
                next_state = COMPUTE_FLOYD;
        end
        
        COUNT_PATHS: begin
            if (edge_idx >= num_edges)
                next_state = OUTPUT_RESULTS;
            else
                next_state = COUNT_PATHS;
        end
        
        OUTPUT_RESULTS: begin
            if (edge_idx >= num_edges)
                next_state = FINISHED;
            else
                next_state = OUTPUT_RESULTS;
        end
        
        FINISHED: begin
            next_state = IDLE;
        end
    endcase
end

// Output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_edge_index <= 0;
        result_count <= 0;
        result_valid <= 0;
        done <= 0;
        i <= 0; j <= 0; k <= 0;
        edge_idx <= 0;
        // Reset distance and path matrices
        integer x, y;
        for (x = 0; x < 8; x = x + 1) begin
            for (y = 0; y < 8; y = y + 1) begin
                dist[x][y] <= (x == y) ? 0 : 32'hFFFF_FFFF;
                paths[x][y] <= (x == y) ? 1 : 0;
            end
        end
    end else begin
        case (current_state)
            IDLE: begin
                result_valid <= 0;
                done <= 0;
                edge_idx <= 0;
                i <= 0; j <= 0; k <= 0;
                if (config_valid) begin
                    edge_memory[config_edge_index] <= {config_src, config_dst, config_weight};
                end
            end
            
            LOAD_EDGES: begin
                if (config_valid) begin
                    edge_memory[config_edge_index] <= {config_src, config_dst, config_weight};
                end
            end
            
            COMPUTE_FLOYD: begin
                // Initialize edges on first iteration
                if (i == 0 && j == 0 && k == 0) begin
                    // Load edges from memory into dist matrix
                    integer e;
                    for (e = 0; e < 16; e = e + 1) begin
                        if (e < num_edges) begin
                            reg [3:0] s = edge_memory[e][23:20];
                            reg [3:0] d = edge_memory[e][19:16];
                            reg [15:0] w = edge_memory[e][15:0];
                            if (w < dist[s][d]) begin
                                dist[s][d] <= w;
                                paths[s][d] <= 1;
                            end else if (w == dist[s][d]) begin
                                paths[s][d] <= paths[s][d] + 1;
                            end
                        end
                    end
                    i <= 1; j <= 0; k <= 0;
                end else begin
                    // Floyd-Warshall: dist[k][i] + dist[i][j] < dist[k][j]
                    if (k < 8 && i < 8 && j < 8) begin
                        reg [31:0] new_dist = dist[k][i] + dist[i][j];
                        reg [31:0] cur_dist = dist[k][j];
                        
                        if (dist[k][i] != 32'hFFFF_FFFF && dist[i][j] != 32'hFFFF_FFFF) begin
                            if (new_dist < cur_dist) begin
                                dist[k][j] <= new_dist;
                                paths[k][j] <= paths[k][i];
                            end else if (new_dist == cur_dist) begin
                                paths[k][j] <= mod_add(paths[k][j], paths[k][i]);
                            end
                        end
                        
                        // Increment counters
                        if (j == 7) begin
                            j <= 0;
                            if (i == 7) begin
                                i <= 0;
                                if (k == 7) begin
                                    k <= 0;  // Will trigger transition
                                end else begin
                                    k <= k + 1;
                                end
                            end else begin
                                i <= i + 1;
                            end
                        end else begin
                            j <= j + 1;
                        end
                    end
                end
            end
            
            COUNT_PATHS: begin
                if (edge_idx < num_edges) begin
                    // For each edge, count shortest paths that use it
                    // Count = sum_{u,v} (paths[u][src] * paths[dst][v]) for shortest paths using this edge
                    reg [3:0] s = edge_memory[edge_idx][23:20];
                    reg [3:0] d = edge_memory[edge_idx][19:16];
                    reg [15:0] w = edge_memory[edge_idx][15:0];
                    
                    // Check if this edge can be part of any shortest path
                    // For all pairs (u,v), if dist[u][s] + w + dist[d][v] == dist[u][v], then add paths[u][s] * paths[d][v]
                    reg [31:0] count = 0;
                    
                    integer u, v;
                    for (u = 0; u < 8; u = u + 1) begin
                        for (v = 0; v < 8; v = v + 1) begin
                            if (u != v && dist[u][s] != 32'hFFFF_FFFF && dist[d][v] != 32'hFFFF_FFFF) begin
                                reg [31:0] total_dist = dist[u][s] + w + dist[d][v];
                                if (total_dist == dist[u][v]) begin
                                    count = mod_add(count, (paths[u][s] * paths[d][v]) % MODULUS);
                                end
                            end
                        end
                    end
                    
                    result_edge_index <= edge_idx;
                    result_count <= count;
                    result_valid <= 1;
                    edge_idx <= edge_idx + 1;
                end else begin
                    result_valid <= 0;
                end
            end
            
            OUTPUT_RESULTS: begin
                result_valid <= 0;
                // Wait for downstream to read
                if (edge_idx < num_edges) begin
                    // Handled by COUNT_PATHS state
                end
            end
            
            FINISHED: begin
                done <= 1;
                edge_idx <= 0;
            end
        endcase
    end
end

endmodule