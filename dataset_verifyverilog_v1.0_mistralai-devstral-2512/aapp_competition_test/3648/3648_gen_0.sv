module secure_telephone_network(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] p_mask,
    input wire edge_valid,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire [11:0] edge_w,
    input wire edge_end,
    output reg [15:0] result,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] READ_EDGES = 4'd1;
    localparam [3:0] SORT_EDGES = 4'd2;
    localparam [3:0] INIT_MST = 4'd3;
    localparam [3:0] PROCESS_EDGES = 4'd4;
    localparam [3:0] CHECK_CONNECTIVITY = 4'd5;
    localparam [3:0] DONE_STATE = 4'd6;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd5000;

    // Edge buffer (max 32 edges)
    reg [3:0] edge_buffer_u [0:31];
    reg [3:0] edge_buffer_v [0:31];
    reg [11:0] edge_buffer_w [0:31];
    reg [4:0] edge_count;

    // Sorting variables
    reg [4:0] sort_i;
    reg [4:0] sort_j;
    reg [4:0] sort_n;

    // DSU variables
    reg [3:0] parent [0:15];
    reg [3:0] rank [0:15];

    // Degree counters
    reg [3:0] degree [0:15];

    // MST variables
    reg [15:0] total_cost;
    reg [4:0] edge_index;
    reg [3:0] current_u;
    reg [3:0] current_v;
    reg [11:0] current_w;

    // Connectivity check
    reg [3:0] root;
    reg [3:0] check_node;
    reg all_connected;

    // DSU find function
    function [3:0] find(input [3:0] x);
        if (parent[x] != x) begin
            parent[x] = find(parent[x]);
        end
        find = parent[x];
    endfunction

    // DSU union function
    function [3:0] union_nodes(input [3:0] x, input [3:0] y);
        x = find(x);
        y = find(y);
        if (x == y) begin
            union_nodes = x;
        end else if (rank[x] < rank[y]) begin
            parent[x] = y;
            union_nodes = y;
        end else if (rank[x] > rank[y]) begin
            parent[y] = x;
            union_nodes = x;
        end else begin
            parent[y] = x;
            rank[x] = rank[x] + 1'b1;
            union_nodes = x;
        end
    endfunction

    // Check if node is insecure
    function is_insecure(input [3:0] node);
        is_insecure = (p_mask & (1 << node)) ? 1'b1 : 1'b0;
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            edge_count <= 5'd0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sort_n <= 5'd0;
            edge_index <= 5'd0;
            total_cost <= 16'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            all_connected <= 1'b0;
            check_node <= 4'd0;

            // Initialize edge buffer
            integer k;
            for (k = 0; k < 32; k = k + 1) begin
                edge_buffer_u[k] <= 4'd0;
                edge_buffer_v[k] <= 4'd0;
                edge_buffer_w[k] <= 12'd0;
            end

            // Initialize DSU
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 2'd0;
                degree[i] <= 4'd0;
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= DONE_STATE;
            end

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        state <= READ_EDGES;
                        edge_count <= 5'd0;
                    end
                end

                READ_EDGES: begin
                    if (edge_valid && edge_count < 32) begin
                        edge_buffer_u[edge_count] <= edge_u;
                        edge_buffer_v[edge_count] <= edge_v;
                        edge_buffer_w[edge_count] <= edge_w;
                        edge_count <= edge_count + 5'd1;
                    end
                    if (edge_end) begin
                        state <= SORT_EDGES;
                        sort_n <= edge_count;
                        sort_i <= 5'd0;
                    end
                end

                SORT_EDGES: begin
                    if (sort_i < sort_n - 1) begin
                        if (sort_j < sort_n - sort_i - 1) begin
                            if (edge_buffer_w[sort_j] > edge_buffer_w[sort_j + 1]) begin
                                // Swap edges
                                reg [3:0] temp_u;
                                reg [3:0] temp_v;
                                reg [11:0] temp_w;
                                temp_u = edge_buffer_u[sort_j];
                                temp_v = edge_buffer_v[sort_j];
                                temp_w = edge_buffer_w[sort_j];
                                edge_buffer_u[sort_j] <= edge_buffer_u[sort_j + 1];
                                edge_buffer_v[sort_j] <= edge_buffer_v[sort_j + 1];
                                edge_buffer_w[sort_j] <= edge_buffer_w[sort_j + 1];
                                edge_buffer_u[sort_j + 1] <= temp_u;
                                edge_buffer_v[sort_j + 1] <= temp_v;
                                edge_buffer_w[sort_j + 1] <= temp_w;
                            end
                            sort_j <= sort_j + 5'd1;
                        end else begin
                            sort_j <= 5'd0;
                            sort_i <= sort_i + 5'd1;
                        end
                    end else begin
                        state <= INIT_MST;
                        edge_index <= 5'd0;
                        total_cost <= 16'd0;
                        // Reinitialize DSU and degrees
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= i;
                            rank[i] <= 2'd0;
                            degree[i] <= 4'd0;
                        end
                    end
                end

                INIT_MST: begin
                    state <= PROCESS_EDGES;
                end

                PROCESS_EDGES: begin
                    if (edge_index < sort_n) begin
                        current_u <= edge_buffer_u[edge_index];
                        current_v <= edge_buffer_v[edge_index];
                        current_w <= edge_buffer_w[edge_index];

                        reg [3:0] root_u = find(current_u);
                        reg [3:0] root_v = find(current_v);

                        if (root_u != root_v) begin
                            // Check degree constraints for insecure nodes
                            reg insecure_u = is_insecure(current_u);
                            reg insecure_v = is_insecure(current_v);
                            reg valid_edge = 1'b1;

                            if (insecure_u && degree[current_u] >= 1) begin
                                valid_edge = 1'b0;
                            end
                            if (insecure_v && degree[current_v] >= 1) begin
                                valid_edge = 1'b0;
                            end

                            if (valid_edge) begin
                                // Add edge to MST
                                total_cost <= total_cost + current_w;
                                union_nodes(current_u, current_v);
                                degree[current_u] <= degree[current_u] + 4'd1;
                                degree[current_v] <= degree[current_v] + 4'd1;
                            end
                        end
                        edge_index <= edge_index + 5'd1;
                    end else begin
                        state <= CHECK_CONNECTIVITY;
                        check_node <= 4'd0;
                        root <= find(0);
                        all_connected <= 1'b1;
                    end
                end

                CHECK_CONNECTIVITY: begin
                    if (check_node < n) begin
                        if (find(check_node) != root) begin
                            all_connected <= 1'b0;
                        end
                        check_node <= check_node + 4'd1;
                    end else begin
                        if (all_connected) begin
                            result <= total_cost;
                            impossible <= 1'b0;
                        end else begin
                            result <= 16'd0;
                            impossible <= 1'b1;
                        end
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule