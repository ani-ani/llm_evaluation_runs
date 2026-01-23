module EscapeRoutes(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [2:0] h,
    input [2:0] edge_u [0:6],
    input [2:0] edge_v [0:6],
    output reg [2:0] m,
    output reg [2:0] added_u [0:3],
    output reg [2:0] added_v [0:3],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] BUILD_MAT = 3'd1;
    localparam [2:0] COMP_DEG  = 3'd2;
    localparam [2:0] FIND_LEAF = 3'd3;
    localparam [2:0] BFS       = 3'd4;
    localparam [2:0] COUNT_LEAF= 3'd5;
    localparam [2:0] GEN_EDGES = 3'd6;
    localparam [2:0] OUTPUT    = 3'd7;
    localparam [2:0] DONE_STATE= 3'd8;

    reg [2:0] state, next_state;

    // Adjacency matrix (8x8)
    reg [7:0] adj_matrix [0:7];

    // Degree of each node
    reg [2:0] degree [0:7];

    // Leaves and BFS queue
    reg [2:0] leaves [0:7];
    reg [2:0] bfs_queue [0:7];
    reg [2:0] leaf_count;
    reg [2:0] leaf_index;
    reg [2:0] bfs_front, bfs_rear;
    reg [2:0] current_node;

    // Visited array
    reg [7:0] visited;

    // Cycle counter
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            m <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize adjacency matrix
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                adj_matrix[i] <= 8'd0;
            end

            // Initialize degree array
            for (i = 0; i < 8; i = i + 1) begin
                degree[i] <= 3'd0;
            end

            // Initialize leaves and BFS queue
            for (i = 0; i < 8; i = i + 1) begin
                leaves[i] <= 3'd0;
                bfs_queue[i] <= 3'd0;
            end

            leaf_count <= 3'd0;
            leaf_index <= 3'd0;
            bfs_front <= 3'd0;
            bfs_rear <= 3'd0;
            current_node <= 3'd0;
            visited <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // State machine logic
    always @(*) begin
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = BUILD_MAT;
                end else begin
                    next_state = IDLE;
                end
            end

            BUILD_MAT: begin
                // Build adjacency matrix from edges
                integer i;
                for (i = 0; i < 7; i = i + 1) begin
                    if (i < n - 1) begin
                        adj_matrix[edge_u[i]][edge_v[i]] = 1'b1;
                        adj_matrix[edge_v[i]][edge_u[i]] = 1'b1;
                    end
                end
                next_state = COMP_DEG;
            end

            COMP_DEG: begin
                // Compute degree of each node
                integer i, j;
                for (i = 0; i < 8; i = i + 1) begin
                    degree[i] = 3'd0;
                    for (j = 0; j < 8; j = j + 1) begin
                        if (adj_matrix[i][j]) begin
                            degree[i] = degree[i] + 3'd1;
                        end
                    end
                end
                next_state = FIND_LEAF;
            end

            FIND_LEAF: begin
                // Identify leaves (degree 1)
                integer i;
                leaf_count = 3'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < n && degree[i] == 3'd1) begin
                        leaves[leaf_count] = i;
                        leaf_count = leaf_count + 3'd1;
                    end
                end
                next_state = BFS;
            end

            BFS: begin
                // BFS to order leaves
                integer i;
                visited = 8'd0;
                bfs_front = 3'd0;
                bfs_rear = 3'd0;
                bfs_queue[bfs_rear] = h;
                bfs_rear = bfs_rear + 3'd1;
                visited[h] = 1'b1;

                while (bfs_front < bfs_rear) begin
                    current_node = bfs_queue[bfs_front];
                    bfs_front = bfs_front + 3'd1;

                    for (i = 0; i < 8; i = i + 1) begin
                        if (adj_matrix[current_node][i] && !visited[i]) begin
                            visited[i] = 1'b1;
                            bfs_queue[bfs_rear] = i;
                            bfs_rear = bfs_rear + 3'd1;
                        end
                    end
                end
                next_state = COUNT_LEAF;
            end

            COUNT_LEAF: begin
                // Count leaves in BFS order
                integer i, j;
                leaf_index = 3'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        if (bfs_queue[i] == leaves[j]) begin
                            leaves[leaf_index] = bfs_queue[i];
                            leaf_index = leaf_index + 3'd1;
                        end
                    end
                end
                next_state = GEN_EDGES;
            end

            GEN_EDGES: begin
                // Generate added edges
                integer i;
                m = (leaf_count + 3'd1) >> 1;

                for (i = 0; i < 4; i = i + 1) begin
                    added_u[i] = 3'd0;
                    added_v[i] = 3'd0;
                end

                for (i = 0; i < leaf_count - 3'd1; i = i + 3'd2) begin
                    if (i < 4) begin
                        added_u[i] = leaves[i];
                        added_v[i] = leaves[i + 3'd1];
                    end
                end

                if (leaf_count % 3'd2 == 3'd1) begin
                    if (leaf_count - 3'd1 < 4) begin
                        added_u[leaf_count - 3'd1] = leaves[leaf_count - 3'd1];
                        added_v[leaf_count - 3'd1] = leaves[3'd0];
                    end
                end
                next_state = OUTPUT;
            end

            OUTPUT: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Ensure done is only asserted for one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule