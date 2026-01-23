module min_scc_finder (
    input clk,
    input rst_n,
    input start,
    input edge_valid,
    input [3:0] src_node,
    input [3:0] dst_node,
    output [3:0] result_size,
    output [10][3:0] result_nodes,
    output done
);

    // Parameters
    localparam N = 10; // Number of nodes (0-9)
    localparam M = 20; // Maximum edges

    // States
    typedef enum logic [2:0] {
        IDLE,
        LOAD_EDGES,
        COMPUTE_ORDER,
        COMPUTE_SCC,
        SELECT_SCC,
        OUTPUT_RESULT
    } state_t;

    // Graph storage
    logic [N-1:0][N-1:0] adj_matrix = '0; // Original graph
    logic [N-1:0][N-1:0] adj_matrix_t = '0; // Transpose graph

    // Edge loading
    logic [3:0] edge_count = 0;

    // DFS state machines
    logic [3:0] dfs_stack [N:0]; // Stack for DFS
    logic [3:0] dfs_stack_ptr = 0;
    logic [N-1:0] visited = '0;
    logic [3:0] current_node = 0;
    logic [3:0] finish_stack [N:0]; // Finish time stack
    logic [3:0] finish_stack_ptr = 0;

    // SCC tracking
    logic [N-1:0] scc_id = '0; // SCC ID for each node
    logic [3:0] scc_count = 0;
    logic [3:0] scc_sizes [N:0] = '0; // Size of each SCC
    logic [N-1:0][N-1:0] scc_out_edges = '0; // Outgoing edges from SCCs

    // Result tracking
    logic [3:0] min_scc_size = N;
    logic [3:0] min_scc_id = 0;

    // State machine
    state_t state = IDLE;

    // Output registers
    logic [3:0] result_size_reg = 0;
    logic [10][3:0] result_nodes_reg = '0;
    logic done_reg = 0;

    assign result_size = result_size_reg;
    assign result_nodes = result_nodes_reg;
    assign done = done_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_count <= 0;
            dfs_stack_ptr <= 0;
            finish_stack_ptr <= 0;
            current_node <= 0;
            visited <= '0;
            adj_matrix <= '0;
            adj_matrix_t <= '0;
            scc_id <= '0;
            scc_count <= 0;
            scc_sizes <= '0;
            scc_out_edges <= '0;
            min_scc_size <= N;
            min_scc_id <= 0;
            result_size_reg <= 0;
            result_nodes_reg <= '0;
            done_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_EDGES;
                        edge_count <= 0;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_valid && edge_count < M) begin
                        adj_matrix[src_node][dst_node] <= 1;
                        adj_matrix_t[dst_node][src_node] <= 1;
                        edge_count <= edge_count + 1;
                    end else if (!edge_valid && edge_count > 0) begin
                        state <= COMPUTE_ORDER;
                        visited <= '0;
                        dfs_stack_ptr <= 0;
                        finish_stack_ptr <= 0;
                    end
                end

                COMPUTE_ORDER: begin
                    // First pass: DFS on original graph to get finish times
                    if (dfs_stack_ptr == 0) begin
                        // Initialize DFS for all unvisited nodes
                        for (int i = 0; i < N; i++) begin
                            if (!visited[i]) begin
                                dfs_stack[0] <= i;
                                dfs_stack_ptr <= 1;
                                visited[i] <= 1;
                            end
                        end
                    end else begin
                        current_node <= dfs_stack[dfs_stack_ptr - 1];
                        logic found_unvisited = 0;
                        for (int j = 0; j < N; j++) begin
                            if (adj_matrix[current_node][j] && !visited[j]) begin
                                dfs_stack[dfs_stack_ptr] <= j;
                                dfs_stack_ptr <= dfs_stack_ptr + 1;
                                visited[j] <= 1;
                                found_unvisited <= 1;
                                break;
                            end
                        end
                        if (!found_unvisited) begin
                            // Pop from stack and add to finish stack
                            dfs_stack_ptr <= dfs_stack_ptr - 1;
                            finish_stack[finish_stack_ptr] <= current_node;
                            finish_stack_ptr <= finish_stack_ptr + 1;
                        end
                    end
                    if (dfs_stack_ptr == 0 && finish_stack_ptr == N) begin
                        state <= COMPUTE_SCC;
                        visited <= '0;
                        dfs_stack_ptr <= 0;
                        scc_count <= 0;
                    end
                end

                COMPUTE_SCC: begin
                    // Second pass: DFS on transpose graph using finish stack
                    if (dfs_stack_ptr == 0) begin
                        if (finish_stack_ptr > 0) begin
                            finish_stack_ptr <= finish_stack_ptr - 1;
                            current_node <= finish_stack[finish_stack_ptr];
                            if (!visited[current_node]) begin
                                dfs_stack[0] <= current_node;
                                dfs_stack_ptr <= 1;
                                visited[current_node] <= 1;
                                scc_id[current_node] <= scc_count;
                            end
                        end else begin
                            state <= SELECT_SCC;
                        end
                    end else begin
                        current_node <= dfs_stack[dfs_stack_ptr - 1];
                        logic found_unvisited = 0;
                        for (int j = 0; j < N; j++) begin
                            if (adj_matrix_t[current_node][j] && !visited[j]) begin
                                dfs_stack[dfs_stack_ptr] <= j;
                                dfs_stack_ptr <= dfs_stack_ptr + 1;
                                visited[j] <= 1;
                                scc_id[j] <= scc_count;
                                found_unvisited <= 1;
                                break;
                            end
                        end
                        if (!found_unvisited) begin
                            dfs_stack_ptr <= dfs_stack_ptr - 1;
                            scc_sizes[scc_count] <= scc_sizes[scc_count] + 1;
                        end
                    end
                    if (dfs_stack_ptr == 0 && finish_stack_ptr == 0) begin
                        scc_count <= scc_count + 1;
                    end
                end

                SELECT_SCC: begin
                    // Check outgoing edges for each SCC
                    logic [3:0] scc_out_degree [N:0] = '0;
                    for (int i = 0; i < N; i++) begin
                        for (int j = 0; j < N; j++) begin
                            if (adj_matrix[i][j] && scc_id[i] != scc_id[j]) begin
                                scc_out_degree[scc_id[i]] <= 1;
                            end
                        end
                    end
                    // Find smallest SCC with zero out-degree
                    min_scc_size <= N;
                    min_scc_id <= 0;
                    for (int i = 0; i < scc_count; i++) begin
                        if (!scc_out_degree[i] && scc_sizes[i] < min_scc_size) begin
                            min_scc_size <= scc_sizes[i];
                            min_scc_id <= i;
                        end
                    end
                    state <= OUTPUT_RESULT;
                end

                OUTPUT_RESULT: begin
                    result_size_reg <= min_scc_size;
                    for (int i = 0; i < N; i++) begin
                        if (scc_id[i] == min_scc_id) begin
                            result_nodes_reg[i] <= i;
                        end else begin
                            result_nodes_reg[i] <= 0;
                        end
                    end
                    done_reg <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule