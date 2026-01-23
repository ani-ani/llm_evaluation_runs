module richard_janet_date (
    input clk,
    input rst_n,
    input start,
    // Graph inputs (8 nodes max, 16 edges max)
    input [4:0] edge_source,       // 1-based index, 0 invalid
    input [4:0] edge_dest,
    input [15:0] edge_weight,
    input edge_valid,
    input edge_done,               // Signal end of edge input
    // Parameters
    input [31:0] param_a,          // Minimum wait time
    input [31:0] param_b,          // Maximum wait time
    output reg [31:0] worst_case_wait,
    output reg done
);
    // State machine for graph setup and computation
    localparam IDLE = 3'b000;
    localparam LOAD_EDGES = 3'b001;
    localparam COMPUTE_DISTANCES = 3'b010;
    localparam FIND_MIN_CYCLE = 3'b011;
    localparam CALCULATE_RESULT = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state;
    
    // Graph storage: Adjacency matrix for 8 nodes (0-7)
    // We use 16 parallel edges conceptually or store min edge weight
    reg [15:0] adj_matrix [0:7][0:7]; // Weight from i to j. 16'hFFFF = infinity
    
    // Computation registers
    reg [2:0] i, j, k; // Loop counters
    reg [15:0] dist [0:7][0:7]; // All-pairs shortest paths
    reg [15:0] min_cycle_mean;
    reg [31:0] temp_calc;
    reg [31:0] direct_path;
    reg [31:0] cycle_val;
    
    integer row, col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            worst_case_wait <= 0;
            // Initialize adjacency matrix to infinity
            for (row = 0; row < 8; row = row + 1) begin
                for (col = 0; col < 8; col = col + 1) begin
                    adj_matrix[row][col] <= 16'hFFFF;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD_EDGES;
                        i <= 0;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_valid) begin
                        // Convert 1-based to 0-based, clamp to 7
                        if (edge_source < 8 && edge_dest < 8) begin
                            adj_matrix[edge_source - 1][edge_dest - 1] <= edge_weight;
                        end
                    end else if (edge_done) begin
                        state <= COMPUTE_DISTANCES;
                        // Initialize Floyd-Warshall
                        for (row = 0; row < 8; row = row + 1) begin
                            for (col = 0; col < 8; col = col + 1) begin
                                if (row == col) dist[row][col] <= 0;
                                else if (adj_matrix[row][col] != 16'hFFFF) dist[row][col] <= adj_matrix[row][col];
                                else dist[row][col] <= 16'hFFFF;
                            end
                        end
                        i <= 0; j <= 0; k <= 0;
                    end
                end

                COMPUTE_DISTANCES: begin
                    // Floyd-Warshall for All-Pairs Shortest Paths
                    // Running for 8 nodes, so 512 cycles max
                    if (k < 8 && j < 8 && i < 8) begin
                        if (dist[i][k] != 16'hFFFF && dist[k][j] != 16'hFFFF) begin
                            if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                dist[i][j] <= dist[i][k] + dist[k][j];
                            end
                        end
                        // Increment counters
                        i <= i + 1;
                        if (i == 7) begin
                            i <= 0;
                            j <= j + 1;
                            if (j == 7) begin
                                j <= 0;
                                k <= k + 1;
                            end
                        end
                    end else begin
                        state <= FIND_MIN_CYCLE;
                        min_cycle_mean <= 16'hFFFF;
                        i <= 0; // Node index
                        j <= 0; // Neighbor index
                    end
                end

                FIND_MIN_CYCLE: begin
                    // Check 2-cycles (u->v->u)
                    if (i < 8 && j < 8) begin
                        // Check if edge i->j exists
                        if (adj_matrix[i][j] != 16'hFFFF) begin
                            // Check return path j->i
                            if (dist[j][i] != 16'hFFFF) begin
                                // Total cycle cost
                                if (adj_matrix[i][j] + dist[j][i] < min_cycle_mean) begin
                                    min_cycle_mean <= adj_matrix[i][j] + dist[j][i];
                                end
                            end
                        end
                        // Increment counters
                        j <= j + 1;
                        if (j == 7) begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        state <= CALCULATE_RESULT;
                        // Setup calculation for node 3 (Intersection 4)
                        // Calculate direct path (0 -> 3)
                        if (dist[0][3] != 16'hFFFF) begin
                            direct_path <= dist[0][3];
                        end else begin
                            direct_path <= 32'hFFFFFFFF;
                        end
                        // Calculate cycle value (half of min 2-cycle cost)
                        if (min_cycle_mean != 16'hFFFF) begin
                            cycle_val <= min_cycle_mean >> 1;
                        end else begin
                            cycle_val <= 32'hFFFFFFFF;
                        end
                    end
                end

                CALCULATE_RESULT: begin
                    // Logic: 
                    // Benefit = min(cycle_val, b - a)
                    // Wait = max(0, direct_path - Benefit)
                    if (direct_path != 32'hFFFFFFFF && cycle_val != 32'hFFFFFFFF) begin
                        reg [31:0] benefit;
                        reg [31:0] diff;
                        diff = param_b - param_a;
                        
                        if (cycle_val < diff) benefit = cycle_val;
                        else benefit = diff;
                        
                        if (direct_path > benefit) 
                            worst_case_wait <= direct_path - benefit;
                        else 
                            worst_case_wait <= 0;
                    end else begin
                        worst_case_wait <= 32'hFFFFFFFF; // Error case
                    end
                    state <= FINISHED;
                    done <= 1;
                end

                FINISHED: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end
endmodule