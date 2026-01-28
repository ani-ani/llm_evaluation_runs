module WolfRemoval(
    input clk,
    input rst_n,
    input start,
    input [127:0] edges,
    input [63:0] pigs,
    input [4:0] V,
    input [4:0] P,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_EDGES = 3'd1;
    localparam [2:0] BUILD_ADJ = 3'd2;
    localparam [2:0] MARK_PIGS = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Adjacency matrix (16x16)
    reg [15:0] adj_matrix [0:15];
    integer i, j, k;

    // Pig positions and wolf positions
    reg [15:0] pig_mask;
    reg [15:0] wolf_mask;

    // Leaf nodes and reachable nodes
    reg [15:0] leaf_nodes;
    reg [15:0] reachable;

    // Temporary registers
    reg [3:0] edge_index;
    reg [3:0] pig_index;
    reg [3:0] node;
    reg [3:0] neighbor;
    reg [3:0] wolf_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            edge_index <= 4'd0;
            pig_index <= 4'd0;
            node <= 4'd0;
            neighbor <= 4'd0;
            wolf_count <= 4'd0;
            pig_mask <= 16'd0;
            wolf_mask <= 16'd0;
            leaf_nodes <= 16'd0;
            reachable <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                adj_matrix[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PARSE_EDGES;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE_EDGES: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (edge_index < V - 1) begin
                        // Parse edge
                        adj_matrix[edges[edge_index*8 + 7:edge_index*8 + 4]][edges[edge_index*8 + 3:edge_index*8]] <= 1'b1;
                        adj_matrix[edges[edge_index*8 + 3:edge_index*8]][edges[edge_index*8 + 7:edge_index*8 + 4]] <= 1'b1;
                        edge_index <= edge_index + 4'd1;
                        next_state <= PARSE_EDGES;
                    end else begin
                        edge_index <= 4'd0;
                        next_state <= BUILD_ADJ;
                    end
                end

                BUILD_ADJ: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Mark pig positions
                    pig_mask <= 16'd0;
                    for (i = 0; i < P; i = i + 1) begin
                        pig_mask[pigs[i*4 + 3:i*4]] <= 1'b1;
                    end
                    // Mark wolf positions (all nodes not pigs)
                    wolf_mask <= ~pig_mask & ((1 << V) - 1);
                    next_state <= MARK_PIGS;
                end

                MARK_PIGS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize reachable with pigs
                    reachable <= pig_mask;
                    // Find leaf nodes (nodes with only one connection)
                    leaf_nodes <= 16'd0;
                    for (i = 0; i < V; i = i + 1) begin
                        k = 0;
                        for (j = 0; j < V; j = j + 1) begin
                            if (adj_matrix[i][j]) k = k + 1;
                        end
                        if (k == 1) leaf_nodes[i] <= 1'b1;
                    end
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Expand reachable set (BFS-like)
                    reg [15:0] new_reachable;
                    new_reachable <= reachable;
                    for (i = 0; i < V; i = i + 1) begin
                        if (reachable[i]) begin
                            for (j = 0; j < V; j = j + 1) begin
                                if (adj_matrix[i][j] && !reachable[j] && !wolf_mask[j]) begin
                                    new_reachable[j] <= 1'b1;
                                end
                            end
                        end
                    end
                    if (new_reachable == reachable) begin
                        // No more expansion, count wolves blocking paths to leaves
                        wolf_count <= 4'd0;
                        for (i = 0; i < V; i = i + 1) begin
                            if (wolf_mask[i]) begin
                                // Check if this wolf is blocking a path to a leaf
                                reg blocking;
                                blocking <= 1'b0;
                                for (j = 0; j < V; j = j + 1) begin
                                    if (leaf_nodes[j] && !reachable[j]) begin
                                        // Check if wolf is on path from any pig to this leaf
                                        // Simplified: if wolf is adjacent to reachable set
                                        for (k = 0; k < V; k = k + 1) begin
                                            if (reachable[k] && adj_matrix[i][k]) begin
                                                blocking <= 1'b1;
                                            end
                                        end
                                    end
                                end
                                if (blocking) wolf_count <= wolf_count + 4'd1;
                            end
                        end
                        result <= wolf_count;
                        next_state <= FINISH;
                    end else begin
                        reachable <= new_reachable;
                        next_state <= COMPUTE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule