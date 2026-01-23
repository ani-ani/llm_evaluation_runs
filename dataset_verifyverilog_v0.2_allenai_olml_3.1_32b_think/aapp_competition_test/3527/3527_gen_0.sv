module network_optimizer (input clk, input rst_n, input start, input [4:0] node_count, input [15:0] edge_count, input [4:0] edges_u [15:0], input [4:0] edges_v [15:0], output reg [3:0] result, output reg done);

reg [2:0] state;
reg [7:0] edge_idx;
reg [3:0] node_idx;
reg [3:0] start_node_1, start_node_2;
reg [4:0] diameter_1, diameter_2;
reg adj [15:0][15:0];
reg [15:0] visited;
reg [3:0] queue [15:0];
reg [3:0] head, tail;
reg full, empty;
reg [4:0] dist [15:0];

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        edge_idx <= 0;
        node_idx <= 0;
        start_node_1 <= 0;
        start_node_2 <= 0;
        diameter_1 <= 0;
        diameter_2 <= 0;
        visited <= 0;
        head <= 0;
        tail <= 0;
        full <= 0;
        empty <= 0;
        result <= 0;
        done <= 0;
        // Initialize adjacency matrix to 0 (default)
    end else begin
        case (state)
            0: // IDLE
                if (start) state <= 1;
                else state <= 0;
            endcase
            1: // BUILD_GRAPH
                if (edge_idx < edge_count) begin
                    reg [4:0] u_val = edges_u[edge_idx];
                    reg [4:0] v_val = edges_v[edge_idx];
                    u_val = u_val[3:0];
                    v_val = v_val[3:0];
                    adj[u_val][v_val] <= 1;
                    adj[v_val][u_val] <= 1;
                    edge_idx <= edge_idx + 1;
                end else begin
                    state <= 2;
                    node_idx <= 0;
                end
            endcase
            2: // FIND_FIRST_NODE_1
                if (node_idx < node_count) begin
                    if (!visited[node_idx]) begin
                        start_node_1 <= node_idx;
                        state <= 3;
                        node_idx <= 0;
                        head <= 0;
                        tail <= 0;
                        full <= 0;
                        empty <= 0;
                        dist <= 16'd16;
                        dist[start_node_1] <= 0;
                    end else begin
                        node_idx <= node_idx + 1;
                    end
                end else begin
                    state <= 5;
                end
            endcase
            3: // BFS_FIRST_PASS_1
                if (empty) begin
                    queue[tail] <= start_node_1;
                    tail <= tail + 1;
                    empty <= 0;
                    full <= (tail == head);
                end
                state <= 3;
            endcase
            default: state <=0;
        endcase
    end
end

endmodule