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

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] CAPTURE      = 4'd1;
    localparam [3:0] BUILD_ADJ    = 4'd2;
    localparam [3:0] CALC_DEGREE  = 4'd3;
    localparam [3:0] FIND_LEAVES  = 4'd4;
    localparam [3:0] INIT_BFS     = 4'd5;
    localparam [3:0] BFS_LOOP     = 4'd6;
    localparam [3:0] SORT_LEAVES  = 4'd7;
    localparam [3:0] CALC_M       = 4'd8;
    localparam [3:0] GEN_EDGES    = 4'd9;
    localparam [3:0] OUTPUT_EDGES = 4'd10;
    localparam [3:0] FINISH       = 4'd11;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Registers for computation
    reg [2:0] n_reg;
    reg [2:0] h_reg;
    reg [2:0] edge_u_reg [0:6];
    reg [2:0] edge_v_reg [0:6];
    reg [2:0] degree [0:7];
    reg [2:0] leaves [0:7];
    reg [2:0] sorted_leaves [0:7];
    reg [2:0] leaf_count;
    reg [2:0] bfs_queue [0:7];
    reg [2:0] bfs_head;
    reg [2:0] bfs_tail;
    reg visited [0:7];
    reg [2:0] parent [0:7];
    reg [2:0] edge_index;
    reg [2:0] temp_node;
    reg [2:0] i_idx, j_idx;
    reg [2:0] neighbor;
    reg [2:0] sorted_count;
    reg [2:0] leaf_idx;
    reg [2:0] added_idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            m <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            n_reg <= 3'd0;
            h_reg <= 3'd0;
            leaf_count <= 3'd0;
            sorted_count <= 3'd0;
            added_idx <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                degree[i] <= 3'd0;
                leaves[i] <= 3'd0;
                sorted_leaves[i] <= 3'd0;
                bfs_queue[i] <= 3'd0;
                visited[i] <= 1'b0;
                parent[i] <= 3'd0;
                added_u[i] <= 3'd0;
                added_v[i] <= 3'd0;
            end
            for (i = 0; i < 7; i = i + 1) begin
                edge_u_reg[i] <= 3'd0;
                edge_v_reg[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    n_reg <= (n >= 3'd2 && n <= 4'd8) ? n[2:0] : 3'd0;
                    h_reg <= h;
                    for (i = 0; i < 7; i = i + 1) begin
                        edge_u_reg[i] <= edge_u[i];
                        edge_v_reg[i] <= edge_v[i];
                    end
                    // Initialize arrays
                    leaf_count <= 3'd0;
                    sorted_count <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        degree[i] <= 3'd0;
                        visited[i] <= 1'b0;
                        parent[i] <= 3'd0;
                    end
                    state <= BUILD_ADJ;
                    edge_index <= 3'd0;
                end

                BUILD_ADJ: begin
                    if (edge_index < n_reg - 3'd1 && edge_index < 3'd7) begin
                        degree[edge_u_reg[edge_index[2:0]]] <= degree[edge_u_reg[edge_index[2:0]]] + 3'd1;
                        degree[edge_v_reg[edge_index[2:0]]] <= degree[edge_v_reg[edge_index[2:0]]] + 3'd1;
                        edge_index <= edge_index + 3'd1;
                    end else begin
                        state <= FIND_LEAVES;
                        i_idx <= 3'd0;
                        leaf_count <= 3'd0;
                    end
                end

                FIND_LEAVES: begin
                    if (i_idx < n_reg) begin
                        if (degree[i_idx] == 3'd1 && i_idx != h_reg) begin
                            leaves[leaf_count] <= i_idx;
                            leaf_count <= leaf_count + 3'd1;
                        end
                        i_idx <= i_idx + 3'd1;
                    end else begin
                        state <= INIT_BFS;
                    end
                end

                INIT_BFS: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        visited[i] <= 1'b0;
                        parent[i] <= 3'd0;
                        sorted_leaves[i] <= 3'd0;
                    end
                    bfs_queue[0] <= h_reg;
                    bfs_head <= 3'd1;
                    bfs_tail <= 3'd0;
                    visited[h_reg] <= 1'b1;
                    sorted_count <= 3'd0;
                    state <= BFS_LOOP;
                end

                BFS_LOOP: begin
                    if (bfs_tail < bfs_head) begin
                        temp_node <= bfs_queue[bfs_tail[2:0]];
                        bfs_tail <= bfs_tail + 3'd1;
                        edge_index <= 3'd0;
                    end else begin
                        state <= SORT_LEAVES;
                    end
                end

                SORT_LEAVES: begin
                    if (edge_index < n_reg - 3'd1 && edge_index < 3'd7) begin
                        if (edge_u_reg[edge_index[2:0]] == temp_node) begin
                            neighbor <= edge_v_reg[edge_index[2:0]];
                        end else if (edge_v_reg[edge_index[2:0]] == temp_node) begin
                            neighbor <= edge_u_reg[edge_index[2:0]];
                        end else begin
                            neighbor <= 3'd7;
                        end
                        edge_index <= edge_index + 3'd1;
                        // Process neighbor in next cycle logic if not done
                        if ((edge_u_reg[edge_index[2:0]] == temp_node || edge_v_reg[edge_index[2:0]] == temp_node) && !visited[neighbor]) begin
                            visited[neighbor] <= 1'b1;
                            parent[neighbor] <= temp_node;
                            bfs_queue[bfs_head[2:0]] <= neighbor;
                            bfs_head <= bfs_head + 3'd1;
                            // Check if this is a leaf
                            if (degree[neighbor] == 3'd1 && neighbor != h_reg) begin
                                sorted_leaves[sorted_count] <= neighbor;
                                sorted_count <= sorted_count + 3'd1;
                            end
                        end
                    end else begin
                        state <= BFS_LOOP;
                    end
                end

                CALC_M: begin
                    m <= (leaf_count + 3'd1) >> 1;
                    added_idx <= 3'd0;
                    i_idx <= 3'd0;
                    state <= GEN_EDGES;
                end

                GEN_EDGES: begin
                    if (added_idx < m) begin
                        if (i_idx + 3'd2 < leaf_count) begin
                            added_u[added_idx] <= sorted_leaves[i_idx[2:0]];
                            added_v[added_idx] <= sorted_leaves[i_idx[2:0] + 3'd1];
                            added_idx <= added_idx + 3'd1;
                            i_idx <= i_idx + 3'd2;
                        end else if (i_idx + 3'd1 < leaf_count) begin
                            added_u[added_idx] <= sorted_leaves[i_idx[2:0]];
                            added_v[added_idx] <= sorted_leaves[i_idx[2:0] + 3'd1];
                            added_idx <= added_idx + 3'd1;
                            i_idx <= i_idx + 3'd2;
                        end else begin
                            added_u[added_idx] <= sorted_leaves[leaf_count - 3'd1];
                            added_v[added_idx] <= sorted_leaves[3'd0];
                            added_idx <= added_idx + 3'd1;
                            i_idx <= i_idx + 3'd2;
                        end
                    end else begin
                        state <= OUTPUT_EDGES;
                    end
                end

                OUTPUT_EDGES: begin
                    done <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
            end
        end
    end

endmodule