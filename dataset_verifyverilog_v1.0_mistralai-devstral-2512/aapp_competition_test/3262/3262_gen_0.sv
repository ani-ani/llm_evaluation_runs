module delivery_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] C,
    input wire [3:0] client_idx [0:14],
    input wire [3:0] edge_u [0:63],
    input wire [3:0] edge_v [0:63],
    input wire [15:0] edge_w [0:63],
    input wire [5:0] valid_edges,
    output reg [3:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] COMPUTE_APSP = 3'd2;
    localparam [2:0] VALIDATE_REACH = 3'd3;
    localparam [2:0] BUILD_DAG = 3'd4;
    localparam [2:0] COMPUTE_MATCHING = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Distances: 16-bit, INF = 0xFFFF
    localparam [15:0] INF = 16'hFFFF;
    reg [15:0] dist [0:15][0:15];
    reg [15:0] dist_to [0:14];
    reg [15:0] dag_adj [0:14][0:14];

    // Matching variables
    reg [3:0] match_left [0:14];
    reg [3:0] match_right [0:14];
    reg [3:0] visited [0:14];
    reg [3:0] match_count;

    // Counters
    reg [3:0] i, j, k;
    reg [3:0] u_idx, v_idx;
    reg [5:0] edge_idx;
    reg [3:0] client_i, client_j;
    reg [3:0] dfs_node;
    reg [3:0] dfs_stack [0:14];
    reg [3:0] stack_ptr;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 16'd0;
            result <= 4'd0;
            done <= 1'b0;
            error <= 1'b0;
            match_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            u_idx <= 4'd0;
            v_idx <= 4'd0;
            edge_idx <= 6'd0;
            client_i <= 4'd0;
            client_j <= 4'd0;
            dfs_node <= 4'd0;
            stack_ptr <= 4'd0;

            // Initialize distance matrix
            integer x, y;
            for (x = 0; x < 16; x = x + 1) begin
                for (y = 0; y < 16; y = y + 1) begin
                    if (x == y) begin
                        dist[x][y] <= 16'd0;
                    end else begin
                        dist[x][y] <= INF;
                    end
                end
            end

            // Initialize other arrays
            for (x = 0; x < 15; x = x + 1) begin
                dist_to[x] <= INF;
                match_left[x] <= 4'd0;
                match_right[x] <= 4'd0;
                visited[x] <= 4'd0;
                for (y = 0; y < 15; y = y + 1) begin
                    dag_adj[x][y] <= 16'd0;
                end
            end

            for (x = 0; x < 15; x = x + 1) begin
                dfs_stack[x] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= LOAD_EDGES;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_idx < valid_edges) begin
                        u_idx <= edge_u[edge_idx];
                        v_idx <= edge_v[edge_idx];
                        if (edge_w[edge_idx] > 16'd65535) begin
                            dist[u_idx][v_idx] <= 16'd65535;
                        end else begin
                            dist[u_idx][v_idx] <= edge_w[edge_idx];
                        end
                        edge_idx <= edge_idx + 6'd1;
                    end else begin
                        edge_idx <= 6'd0;
                        next_state <= COMPUTE_APSP;
                    end
                end

                COMPUTE_APSP: begin
                    if (k < N) begin
                        if (i < N) begin
                            if (j < N) begin
                                if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                    dist[i][j] <= dist[i][k] + dist[k][j];
                                end
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            i <= 4'd0;
                            k <= k + 4'd1;
                        end
                    end else begin
                        k <= 4'd0;
                        next_state <= VALIDATE_REACH;
                    end
                end

                VALIDATE_REACH: begin
                    if (client_i < C) begin
                        if (dist[0][client_idx[client_i]] == INF) begin
                            error <= 1'b1;
                        end
                        dist_to[client_i] <= dist[0][client_idx[client_i]];
                        client_i <= client_i + 4'd1;
                    end else begin
                        client_i <= 4'd0;
                        next_state <= BUILD_DAG;
                    end
                end

                BUILD_DAG: begin
                    if (client_i < C) begin
                        if (client_j < C) begin
                            if (dist_to[client_i] + dist[client_idx[client_i]][client_idx[client_j]] == dist_to[client_j]) begin
                                dag_adj[client_i][client_j] <= 16'd1;
                            end else begin
                                dag_adj[client_i][client_j] <= 16'd0;
                            end
                            client_j <= client_j + 4'd1;
                        end else begin
                            client_j <= 4'd0;
                            client_i <= client_i + 4'd1;
                        end
                    end else begin
                        client_i <= 4'd0;
                        next_state <= COMPUTE_MATCHING;
                    end
                end

                COMPUTE_MATCHING: begin
                    if (client_i < C) begin
                        // Reset visited
                        for (j = 0; j < 15; j = j + 1) begin
                            visited[j] <= 4'd0;
                        end
                        stack_ptr <= 4'd0;
                        dfs_node <= client_i;
                        dfs_stack[0] <= client_i;
                        stack_ptr <= 4'd1;

                        // DFS to find augmenting path
                        while (stack_ptr > 0) begin
                            dfs_node <= dfs_stack[stack_ptr - 1];
                            stack_ptr <= stack_ptr - 4'd1;

                            if (dfs_node == 4'd0) begin
                                // Found augmenting path
                                match_count <= match_count + 4'd1;
                                match_left[client_i] <= dfs_node;
                                match_right[dfs_node] <= client_i;
                                break;
                            end

                            for (j = 0; j < C; j = j + 1) begin
                                if (dag_adj[dfs_node][j] && !visited[j]) begin
                                    visited[j] <= 4'd1;
                                    dfs_stack[stack_ptr] <= j;
                                    stack_ptr <= stack_ptr + 4'd1;
                                end
                            end
                        end

                        client_i <= client_i + 4'd1;
                    end else begin
                        client_i <= 4'd0;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= C - match_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end
endmodule