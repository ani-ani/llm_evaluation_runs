module ShortestPath(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] node_count,
    input wire [23:0] x [0:15],
    input wire [23:0] d [0:15],
    input wire [23:0] r [0:15],
    output reg [255:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] BUILD_EDGES = 2'd1;
    localparam [1:0] DIJKSTRA  = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Edge matrix: 16x16 bits
    reg edge_exists [0:15][0:15];
    reg [23:0] edge_weight [0:15][0:15];

    // Dijkstra variables
    reg [15:0] dist [0:15];
    reg visited [0:15];
    reg [3:0] current_node;
    reg [3:0] i, j, k;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 256'd0;

            // Initialize edge matrix
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    edge_exists[i][j] <= 1'b0;
                    edge_weight[i][j] <= 24'd0;
                end
            end

            // Initialize Dijkstra variables
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 16'd65535;
                visited[i] <= 1'b0;
            end
            current_node <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = BUILD_EDGES;
                    done = 1'b0;
                    cycle_count = 8'd0;
                    // Initialize Dijkstra
                    dist[0] = 16'd0; // Start from node 0
                    for (i = 1; i < 16; i = i + 1) begin
                        dist[i] = 16'd65535;
                    end
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] = 1'b0;
                    end
                    current_node = 4'd0;
                    i = 4'd0;
                    j = 4'd0;
                    k = 4'd0;
                end
            end

            BUILD_EDGES: begin
                // Build edge matrix
                if (j < node_count) begin
                    if (i < node_count) begin
                        // Calculate |x_i - x_j|
                        reg [23:0] diff;
                        if (x[i] > x[j]) begin
                            diff = x[i] - x[j];
                        end else begin
                            diff = x[j] - x[i];
                        end
                        
                        // Check if edge exists
                        if (diff >= d[i]) begin
                            edge_exists[i][j] = 1'b1;
                            edge_weight[i][j] = r[i] + diff;
                        end else begin
                            edge_exists[i][j] = 1'b0;
                            edge_weight[i][j] = 24'd0;
                        end
                        
                        i = i + 1;
                    end else begin
                        i = 4'd0;
                        j = j + 1;
                    end
                end else begin
                    next_state = DIJKSTRA;
                    i = 4'd0;
                    j = 4'd0;
                end
            end

            DIJKSTRA: begin
                // Dijkstra's algorithm
                if (current_node < node_count) begin
                    // Mark current node as visited
                    visited[current_node] = 1'b1;
                    
                    // Update distances to neighbors
                    if (j < node_count) begin
                        if (edge_exists[current_node][j] && !visited[j]) begin
                            reg [23:0] new_dist;
                            new_dist = dist[current_node] + edge_weight[current_node][j];
                            
                            // Convert to 16-bit (Q8.16 to integer)
                            reg [15:0] new_dist_16;
                            new_dist_16 = new_dist[23:8]; // Take upper 16 bits
                            
                            if (new_dist_16 < dist[j]) begin
                                dist[j] = new_dist_16;
                            end
                        end
                        j = j + 1;
                    end else begin
                        j = 4'd0;
                        
                        // Find next unvisited node with minimum distance
                        if (i < node_count) begin
                            if (!visited[i] && dist[i] < dist[k]) begin
                                k = i;
                            end
                            i = i + 1;
                        end else begin
                            i = 4'd0;
                            current_node = k;
                            k = 4'd0;
                        end
                    end
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                // Prepare output
                for (i = 0; i < 16; i = i + 1) begin
                    result[(i*16)+15:i*16] = dist[i];
                end
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter and done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
            
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end
            end
        end
    end

endmodule