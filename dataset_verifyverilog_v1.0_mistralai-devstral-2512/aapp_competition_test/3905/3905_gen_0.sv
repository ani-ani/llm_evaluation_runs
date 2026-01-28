module DataCenterSCC(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [5:0] m,
    input [4:0] h,
    input [0:15][4:0] u,
    input [0:31][4:0] client1,
    input [0:31][4:0] client2,
    output reg [4:0] result_size,
    output reg [0:15] result_indices,
    output reg done
);

    // State declarations
    localparam [7:0] IDLE = 8'd0;
    localparam [7:0] BUILD_GRAPH = 8'd1;
    localparam [7:0] FIRST_DFS = 8'd2;
    localparam [7:0] TRANSPOSE = 8'd3;
    localparam [7:0] SECOND_DFS = 8'd4;
    localparam [7:0] COMPUTE_OUTDEG = 8'd5;
    localparam [7:0] FIND_SINK = 8'd6;
    localparam [7:0] OUTPUT = 8'd7;
    localparam [7:0] DONE_STATE = 8'd8;

    reg [7:0] state;
    reg [7:0] next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Graph representation
    reg [0:15][0:15] adj_matrix;
    reg [0:15][0:15] transpose_matrix;

    // DFS stack and state
    reg [3:0] stack_ptr;
    reg [3:0] stack [0:15];
    reg [3:0] visited [0:15];
    reg [3:0] finish_order [0:15];
    reg [7:0] finish_ptr;

    // SCC tracking
    reg [3:0] scc_id [0:15];
    reg [3:0] current_scc;
    reg [3:0] scc_size [0:15];
    reg [3:0] out_degree [0:15];

    // Temporary counters
    reg [3:0] i, j, k;
    reg [3:0] temp_node;
    reg [3:0] min_size;
    reg [3:0] sink_scc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            result_size <= 5'd0;
            result_indices <= 16'd0;
            done <= 1'b0;

            // Initialize all registers
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    adj_matrix[i][j] <= 1'b0;
                    transpose_matrix[i][j] <= 1'b0;
                end
                visited[i] <= 1'b0;
                finish_order[i] <= 4'd0;
                scc_id[i] <= 4'd0;
                scc_size[i] <= 4'd0;
                out_degree[i] <= 4'd0;
            end
            stack_ptr <= 4'd0;
            finish_ptr <= 8'd0;
            current_scc <= 4'd0;
            min_size <= 4'd16;
            sink_scc <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= BUILD_GRAPH;
                        cycle_count <= 8'd0;
                    end
                end

                BUILD_GRAPH: begin
                    // Build adjacency matrix based on maintenance hours
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            if ((u[i] + 1'b1) % h == u[j]) begin
                                adj_matrix[i][j] <= 1'b1;
                            end else begin
                                adj_matrix[i][j] <= 1'b0;
                            end
                        end
                    end
                    next_state <= FIRST_DFS;
                end

                FIRST_DFS: begin
                    // Iterative DFS to compute finish order
                    stack_ptr <= 4'd0;
                    finish_ptr <= 8'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end

                    // Perform DFS for each unvisited node
                    for (i = 0; i < n; i = i + 1) begin
                        if (!visited[i]) begin
                            // Push node to stack
                            stack[stack_ptr] <= i;
                            stack_ptr <= stack_ptr + 1'b1;
                            visited[i] <= 1'b1;

                            // DFS loop
                            while (stack_ptr > 0) begin
                                temp_node <= stack[stack_ptr - 1'b1];
                                j <= 4'd0;
                                // Find next unvisited neighbor
                                while (j < n && (!adj_matrix[temp_node][j] || visited[j])) begin
                                    j <= j + 1'b1;
                                end

                                if (j < n) begin
                                    // Visit neighbor
                                    stack[stack_ptr] <= j;
                                    stack_ptr <= stack_ptr + 1'b1;
                                    visited[j] <= 1'b1;
                                end else begin
                                    // Pop and record finish order
                                    stack_ptr <= stack_ptr - 1'b1;
                                    finish_order[finish_ptr] <= temp_node;
                                    finish_ptr <= finish_ptr + 1'b1;
                                end
                            end
                        end
                    end
                    next_state <= TRANSPOSE;
                end

                TRANSPOSE: begin
                    // Build transpose graph
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            transpose_matrix[i][j] <= adj_matrix[j][i];
                        end
                    end
                    next_state <= SECOND_DFS;
                end

                SECOND_DFS: begin
                    // Reset visited for second DFS
                    for (i = 0; i < 16; i = i + 1) begin
                        visited[i] <= 1'b0;
                    end
                    current_scc <= 4'd0;

                    // Process nodes in reverse finish order
                    for (i = 0; i < finish_ptr; i = i + 1) begin
                        temp_node <= finish_order[finish_ptr - 1'b1 - i];
                        if (!visited[temp_node]) begin
                            current_scc <= current_scc + 1'b1;
                            scc_size[current_scc] <= 4'd0;

                            // DFS on transpose graph
                            stack_ptr <= 4'd0;
                            stack[stack_ptr] <= temp_node;
                            stack_ptr <= stack_ptr + 1'b1;
                            visited[temp_node] <= 1'b1;
                            scc_id[temp_node] <= current_scc;
                            scc_size[current_scc] <= scc_size[current_scc] + 1'b1;

                            while (stack_ptr > 0) begin
                                temp_node <= stack[stack_ptr - 1'b1];
                                j <= 4'd0;
                                // Find next unvisited neighbor in transpose
                                while (j < n && (!transpose_matrix[temp_node][j] || visited[j])) begin
                                    j <= j + 1'b1;
                                end

                                if (j < n) begin
                                    // Visit neighbor
                                    stack[stack_ptr] <= j;
                                    stack_ptr <= stack_ptr + 1'b1;
                                    visited[j] <= 1'b1;
                                    scc_id[j] <= current_scc;
                                    scc_size[current_scc] <= scc_size[current_scc] + 1'b1;
                                end else begin
                                    stack_ptr <= stack_ptr - 1'b1;
                                end
                            end
                        end
                    end
                    next_state <= COMPUTE_OUTDEG;
                end

                COMPUTE_OUTDEG: begin
                    // Compute out-degree for each SCC
                    for (i = 0; i < 16; i = i + 1) begin
                        out_degree[i] <= 4'd0;
                    end

                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            if (adj_matrix[i][j] && (scc_id[i] != scc_id[j])) begin
                                out_degree[scc_id[i]] <= out_degree[scc_id[i]] + 1'b1;
                            end
                        end
                    end
                    next_state <= FIND_SINK;
                end

                FIND_SINK: begin
                    // Find SCC with out-degree 0 and minimum size
                    min_size <= 4'd16;
                    sink_scc <= 4'd0;

                    for (i = 1; i <= current_scc; i = i + 1) begin
                        if (out_degree[i] == 4'd0 && scc_size[i] < min_size) begin
                            min_size <= scc_size[i];
                            sink_scc <= i;
                        end
                    end

                    // Set result outputs
                    result_size <= min_size;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (scc_id[i] == sink_scc) begin
                            result_indices[i] <= 1'b1;
                        end else begin
                            result_indices[i] <= 1'b0;
                        end
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule