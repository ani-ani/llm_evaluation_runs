module treeland_max_distance (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] universities,
    input [15:0] adj [0:15],
    output reg [7:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_TREE = 3'd1;
    localparam [2:0] CALC_SUBTREE = 3'd2;
    localparam [2:0] CALC_DISTANCE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] node_counter;
    reg [3:0] parent [0:15];
    reg [3:0] subtree_count [0:15];
    reg [7:0] total_distance;
    reg [3:0] i_idx, j_idx;
    reg [15:0] visited;
    reg [3:0] queue [0:15];
    reg [3:0] head, tail;
    reg [3:0] bfs_order [0:15];
    reg [3:0] bfs_index;
    reg [3:0] cycle_count;
    reg processing_neighbors;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            total_distance <= 8'd0;
            visited <= 16'd0;
            head <= 4'd0;
            tail <= 4'd0;
            bfs_index <= 4'd0;
            node_counter <= 4'd0;
            cycle_count <= 8'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            processing_neighbors <= 1'b0;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                parent[idx] <= 4'b1111;
                subtree_count[idx] <= 4'd0;
                bfs_order[idx] <= 4'd0;
                queue[idx] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize subtree counts with university markers
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            subtree_count[idx] <= universities[idx] ? 4'd1 : 4'd0;
                        end
                        state <= BUILD_TREE;
                        node_counter <= 4'd0;
                        visited <= 16'd1;
                        parent[0] <= 4'd0;
                        head <= 4'd0;
                        tail <= 4'd1;
                        queue[0] <= 4'd0;
                        bfs_index <= 4'd0;
                        processing_neighbors <= 1'b1;
                        i_idx <= 4'd0;
                        j_idx <= 4'd0;
                    end
                end

                BUILD_TREE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= 8'd255) begin
                        state <= DONE_STATE;
                    end else if (processing_neighbors) begin
                        if (j_idx < n) begin
                            if (adj[i_idx][j_idx] && !visited[j_idx]) begin
                                parent[j_idx] <= i_idx;
                                visited[j_idx] <= 1'b1;
                                queue[tail] <= j_idx;
                                tail <= tail + 4'd1;
                                bfs_order[bfs_index] <= j_idx;
                                bfs_index <= bfs_index + 4'd1;
                            end
                            j_idx <= j_idx + 4'd1;
                        end else begin
                            processing_neighbors <= 1'b0;
                        end
                    end else if (head < tail) begin
                        i_idx <= queue[head];
                        head <= head + 4'd1;
                        j_idx <= 4'd0;
                        processing_neighbors <= 1'b1;
                    end else if (bfs_index < n) begin
                        state <= CALC_SUBTREE;
                        node_counter <= n - 4'd1;
                    end else begin
                        state <= DONE_STATE;
                        result <= 8'd0;
                        done <= 1'b1;
                    end
                end

                CALC_SUBTREE: begin
                    if (node_counter > 4'd0) begin
                        if (parent[node_counter] != 4'b1111 && parent[node_counter] != node_counter) begin
                            subtree_count[parent[node_counter]] <= subtree_count[parent[node_counter]] + subtree_count[node_counter];
                        end
                        node_counter <= node_counter - 4'd1;
                    end else begin
                        state <= CALC_DISTANCE;
                        node_counter <= 4'd1;
                        total_distance <= 8'd0;
                    end
                end

                CALC_DISTANCE: begin
                    if (node_counter < n) begin
                        if (subtree_count[node_counter] > 4'd0 && subtree_count[node_counter] < ((k << 1))) begin
                            if (subtree_count[node_counter] <= k) begin
                                total_distance <= total_distance + {4'd0, subtree_count[node_counter]};
                            end else begin
                                total_distance <= total_distance + {4'd0, ((k << 1) - subtree_count[node_counter])};
                            end
                        end
                        node_counter <= node_counter + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                        result <= total_distance;
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule