module find_good_nodes(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [55:0] edge_data,
    input wire [27:0] edge_colors,
    input wire [2:0] valid_edges,
    output reg [7:0] good_nodes [0:7],
    output reg [3:0] count,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] BUILD_GRAPH  = 4'd1;
    localparam [3:0] CHECK_NODE   = 4'd2;
    localparam [3:0] BFS          = 4'd3;
    localparam [3:0] NEXT_NODE    = 4'd4;
    localparam [3:0] COMPLETE     = 4'd5;

    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] good_nodes_reg [0:7];
    reg [3:0] count_reg;
    reg done_reg;
    reg [2:0] edge_idx;
    reg [3:0] current_node;
    reg [7:0] visited;  // 8-bit visited mask
    reg [7:0] queue [0:7];  // BFS queue
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [7:0] parent [0:7];  // Parent for each node
    reg [3:0] last_color [0:7];  // Last edge color to parent
    reg is_good;
    reg [7:0] adj_matrix [0:7][0:7];  // Adjacency matrix: bit=connected, lower 4 bits=color
    reg [3:0] node_idx;
    reg [7:0] child_node;
    reg [3:0] child_color;
    reg [7:0] parent_node;
    reg [3:0] parent_color;
    reg [3:0] check_child;
    reg [7:0] found_good;
    reg [2:0] cycle_count;
    reg processing_child;
    reg edge_check_done;
    reg [3:0] edge_node_a;
    reg [3:0] edge_node_b;
    reg [3:0] edge_color;

    integer i, j, k;

    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done_reg <= 1'b0;
            count_reg <= 4'd0;
            cycle_count <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                good_nodes_reg[i] <= 8'd255;
                for (j = 0; j < 8; j = j + 1) begin
                    adj_matrix[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            done_reg <= done_reg;
            if (state == IDLE && start) begin
                done_reg <= 1'b0;
                count_reg <= 4'd0;
                cycle_count <= 3'd0;
                for (i = 0; i < 8; i = i + 1) begin
                    good_nodes_reg[i] <= 8'd255;
                end
            end
            if (state == COMPLETE) begin
                done_reg <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = BUILD_GRAPH;
                else next_state = IDLE;
            end
            BUILD_GRAPH: begin
                if (edge_idx >= valid_edges) next_state = CHECK_NODE;
                else next_state = BUILD_GRAPH;
            end
            CHECK_NODE: begin
                if (current_node >= n) next_state = COMPLETE;
                else next_state = BFS;
            end
            BFS: begin
                if (queue_head >= queue_tail) next_state = NEXT_NODE;
                else if (processing_child) next_state = BFS;
                else next_state = CHECK_NODE;
            end
            NEXT_NODE: begin
                if (is_good) next_state = CHECK_NODE;
                else next_state = CHECK_NODE;
            end
            COMPLETE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_idx <= 3'd0;
            current_node <= 4'd0;
            node_idx <= 4'd0;
            check_child <= 4'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            is_good <= 1'b0;
            found_good <= 8'd0;
            processing_child <= 1'b0;
            edge_check_done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                visited <= 8'd0;
                parent[i] <= 8'd255;
                last_color[i] <= 4'd15;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        edge_idx <= 3'd0;
                        current_node <= 4'd0;
                        node_idx <= 4'd0;
                        check_child <= 4'd0;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        is_good <= 1'b0;
                        processing_child <= 1'b0;
                        edge_check_done <= 1'b0;
                        for (k = 0; k < 8; k = k + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                adj_matrix[k][j] <= 8'd0;
                            end
                        end
                    end
                end

                BUILD_GRAPH: begin
                    if (edge_idx < 3'd7 && edge_idx < valid_edges) begin
                        edge_node_a = edge_data[edge_idx * 8 + 3 : edge_idx * 8];
                        edge_node_b = edge_data[edge_idx * 8 + 7 : edge_idx * 8 + 4];
                        edge_color = edge_colors[edge_idx * 4 + 3 : edge_idx * 4];
                        if (edge_node_a < 4'd8 && edge_node_b < 4'd8 && edge_color < 4'd15) begin
                            adj_matrix[edge_node_a][edge_node_b] <= {4'd0, edge_color};
                            adj_matrix[edge_node_b][edge_node_a] <= {4'd0, edge_color};
                        end
                        edge_idx <= edge_idx + 3'd1;
                    end
                end

                CHECK_NODE: begin
                    if (current_node < n) begin
                        visited <= 8'd0;
                        for (k = 0; k < 8; k = k + 1) begin
                            parent[k] <= 8'd255;
                            last_color[k] <= 4'd15;
                        end
                        visited[current_node] <= 1'b1;
                        queue[0] <= current_node;
                        parent[current_node] <= 8'd255;
                        last_color[current_node] <= 4'd15;
                        queue_head <= 4'd0;
                        queue_tail <= 4'd1;
                        is_good <= 1'b1;
                        processing_child <= 1'b0;
                        edge_check_done <= 1'b0;
                    end
                end

                BFS: begin
                    if (!edge_check_done && queue_head < queue_tail) begin
                        parent_node = queue[queue_head];
                        if (parent_node < 4'd8 && parent_node < n) begin
                            check_child <= 4'd0;
                            processing_child <= 1'b1;
                            edge_check_done <= 1'b1;
                        end else begin
                            queue_head <= queue_head + 4'd1;
                            edge_check_done <= 1'b0;
                        end
                    end else if (edge_check_done && check_child < n) begin
                        if (!visited[check_child] && adj_matrix[parent_node][check_child] != 8'd0) begin
                            child_color = adj_matrix[parent_node][check_child][3:0];
                            parent_color = last_color[parent_node];
                            if (parent_color != 4'd15 && child_color == parent_color) begin
                                is_good <= 1'b0;
                            end
                            visited[check_child] <= 1'b1;
                            parent[check_child] <= parent_node;
                            last_color[check_child] <= child_color;
                            queue[queue_tail] <= check_child;
                            queue_tail <= queue_tail + 4'd1;
                        end
                        check_child <= check_child + 4'd1;
                    end else begin
                        if (processing_child) begin
                            queue_head <= queue_head + 4'd1;
                            processing_child <= 1'b0;
                            edge_check_done <= 1'b0;
                        end
                    end
                end

                NEXT_NODE: begin
                    if (is_good && current_node < 4'd8 && count_reg < 4'd8) begin
                        good_nodes_reg[count_reg] <= current_node;
                        count_reg <= count_reg + 4'd1;
                    end
                    current_node <= current_node + 4'd1;
                end

                COMPLETE: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        good_nodes[i] <= good_nodes_reg[i];
                    end
                    count <= count_reg;
                end
            endcase
        end
    end

    // Combinational outputs
    always @(*) begin
        done = done_reg;
        for (i = 0; i < 8; i = i + 1) begin
            good_nodes[i] = good_nodes_reg[i];
        end
        count = count_reg;
    end

endmodule