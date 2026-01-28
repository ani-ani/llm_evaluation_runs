module LongestPathCactus(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [5:0] M,
    input [3:0] edge_A [0:15],
    input [3:0] edge_B [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] BUILD_MATRIX = 3'd2;
    localparam [2:0] BFS = 3'd3;
    localparam [2:0] CYCLE_CHECK = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    reg [2:0] state, next_state;

    // Adjacency matrix (16x16)
    reg [15:0] adj [0:15];
    integer i, j, k;

    // Distance array
    reg [7:0] dist [0:15];

    // BFS queue
    reg [3:0] queue [0:15];
    reg [3:0] queue_head, queue_tail;
    reg [3:0] current_node;

    // Cycle check variables
    reg [7:0] max_path;
    reg [3:0] u, v;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize adjacency matrix
            for (i = 0; i < 16; i = i + 1) begin
                adj[i] <= 16'd0;
            end

            // Initialize distance array
            for (i = 0; i < 16; i = i + 1) begin
                dist[i] <= 8'd255; // Initialize to infinity
            end

            // Initialize BFS queue
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            current_node <= 4'd0;

            // Initialize cycle check variables
            max_path <= 8'd0;
            u <= 4'd0;
            v <= 4'd0;

        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Already handled in reset block
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD_EDGES;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_EDGES: begin
                    // Load edges into adjacency matrix
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < M) begin
                            u <= edge_A[i];
                            v <= edge_B[i];
                            adj[u][v] <= 1'b1;
                            adj[v][u] <= 1'b1;
                        end
                    end
                    next_state <= BUILD_MATRIX;
                end

                BUILD_MATRIX: begin
                    // Matrix is already built in LOAD_EDGES
                    next_state <= BFS;
                end

                BFS: begin
                    // Initialize BFS from node 1 (index 0)
                    if (cycle_count == 8'd0) begin
                        dist[0] <= 8'd0; // Node 1 (index 0) has distance 0
                        queue[0] <= 4'd0; // Node 1
                        queue_head <= 4'd0;
                        queue_tail <= 4'd1;
                    end

                    // Process queue
                    if (queue_head < queue_tail) begin
                        current_node <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;

                        // Visit neighbors
                        for (i = 0; i < 16; i = i + 1) begin
                            if (adj[current_node][i] && dist[i] == 8'd255) begin
                                dist[i] <= dist[current_node] + 8'd1;
                                queue[queue_tail] <= i;
                                queue_tail <= queue_tail + 4'd1;
                            end
                        end
                    end else begin
                        next_state <= CYCLE_CHECK;
                    end

                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                    end
                end

                CYCLE_CHECK: begin
                    // Check all edges for cycles
                    max_path <= 8'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < M) begin
                            u <= edge_A[i];
                            v <= edge_B[i];
                            // Check if this edge is not in BFS tree
                            if (dist[u] + 8'd1 != dist[v] && dist[v] + 8'd1 != dist[u]) begin
                                // This edge forms a cycle
                                if (dist[u] + dist[v] + 8'd1 > max_path) begin
                                    max_path <= dist[u] + dist[v] + 8'd1;
                                end
                            end
                        end
                    end

                    // Also consider direct paths
                    for (i = 0; i < 16; i = i + 1) begin
                        if (dist[i] > max_path) begin
                            max_path <= dist[i];
                        end
                    end

                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    result <= max_path;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule