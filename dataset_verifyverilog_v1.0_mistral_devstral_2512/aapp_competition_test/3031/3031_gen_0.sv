module find_good_nodes(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [55:0] edge_data,
    input [27:0] edge_colors,
    input [2:0] valid_edges,
    output reg [7:0] good_nodes [0:7],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_GRAPH = 3'd1;
    localparam [2:0] CHECK_NODE = 3'd2;
    localparam [2:0] BFS = 3'd3;
    localparam [2:0] NEXT_NODE = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;

    reg [2:0] state;
    reg [7:0] current_node;
    reg [7:0] next_node;
    reg [7:0] node_counter;
    reg [7:0] good_node_counter;
    reg [7:0] bfs_queue [0:7];
    reg [7:0] bfs_head;
    reg [7:0] bfs_tail;
    reg [7:0] parent [0:7];
    reg [3:0] last_color [0:7];
    reg [7:0] visited [0:7];
    reg [7:0] adjacency [0:7][0:7];
    reg [3:0] edge_color [0:7][0:7];
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] k;
    reg [7:0] edge_index;
    reg [7:0] node_a;
    reg [7:0] node_b;
    reg [3:0] color;
    reg [7:0] temp_node;
    reg [7:0] temp_parent;
    reg [3:0] temp_color;
    reg [7:0] temp_visited;
    reg [7:0] temp_adjacency;
    reg [3:0] temp_edge_color;
    reg [7:0] temp_good_nodes;
    reg [3:0] temp_count;
    reg [7:0] temp_bfs_queue;
    reg [7:0] temp_bfs_head;
    reg [7:0] temp_bfs_tail;
    reg [7:0] temp_parent;
    reg [3:0] temp_last_color;
    reg [7:0] temp_visited;
    reg [7:0] temp_edge_index;
    reg [7:0] temp_node_a;
    reg [7:0] temp_node_b;
    reg [3:0] temp_color;
    reg [7:0] temp_i;
    reg [7:0] temp_j;
    reg [7:0] temp_k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_node <= 8'd0;
            next_node <= 8'd0;
            node_counter <= 8'd0;
            good_node_counter <= 8'd0;
            bfs_head <= 8'd0;
            bfs_tail <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                bfs_queue[i] <= 8'd0;
                parent[i] <= 8'd0;
                last_color[i] <= 4'd0;
                visited[i] <= 8'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    adjacency[i][j] <= 8'd0;
                    edge_color[i][j] <= 4'd0;
                end
            end
            for (i = 0; i < 8; i = i + 1) begin
                good_nodes[i] <= 8'd0;
            end
            count <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= BUILD_GRAPH;
                    end
                end

                BUILD_GRAPH: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            adjacency[i][j] <= 8'd0;
                            edge_color[i][j] <= 4'd0;
                        end
                    end
                    for (edge_index = 0; edge_index < valid_edges; edge_index = edge_index + 1) begin
                        node_a = edge_data[edge_index * 8 + 3: edge_index * 8];
                        node_b = edge_data[edge_index * 8 + 7: edge_index * 8 + 4];
                        color = edge_colors[edge_index * 4 + 3: edge_index * 4];
                        adjacency[node_a][node_b] <= 8'd1;
                        adjacency[node_b][node_a] <= 8'd1;
                        edge_color[node_a][node_b] <= color;
                        edge_color[node_b][node_a] <= color;
                    end
                    state <= CHECK_NODE;
                    current_node <= 8'd0;
                end

                CHECK_NODE: begin
                    if (current_node < n) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            visited[i] <= 8'd0;
                            parent[i] <= 8'd0;
                            last_color[i] <= 4'd0;
                        end
                        bfs_head <= 8'd0;
                        bfs_tail <= 8'd0;
                        bfs_queue[bfs_tail] <= current_node;
                        bfs_tail <= bfs_tail + 8'd1;
                        visited[current_node] <= 8'd1;
                        parent[current_node] <= 8'd0;
                        last_color[current_node] <= 4'd0;
                        state <= BFS;
                    end else begin
                        state <= COMPLETE;
                    end
                end

                BFS: begin
                    if (bfs_head < bfs_tail) begin
                        temp_node = bfs_queue[bfs_head];
                        bfs_head <= bfs_head + 8'd1;
                        for (i = 0; i < n; i = i + 1) begin
                            if (adjacency[temp_node][i] && !visited[i]) begin
                                temp_color = edge_color[temp_node][i];
                                if (temp_color != last_color[temp_node]) begin
                                    visited[i] <= 8'd1;
                                    parent[i] <= temp_node;
                                    last_color[i] <= temp_color;
                                    bfs_queue[bfs_tail] <= i;
                                    bfs_tail <= bfs_tail + 8'd1;
                                end
                            end
                        end
                    end else begin
                        for (i = 0; i < n; i = i + 1) begin
                            if (visited[i]) begin
                                for (j = 0; j < n; j = j + 1) begin
                                    if (adjacency[i][j] && visited[j] && parent[i] != j) begin
                                        temp_color = edge_color[i][j];
                                        if (temp_color == last_color[i]) begin
                                            i = n;
                                            j = n;
                                        end
                                    end
                                end
                            end
                        end
                        if (i == n && j == n) begin
                            good_nodes[good_node_counter] <= current_node;
                            good_node_counter <= good_node_counter + 8'd1;
                        end
                        current_node <= current_node + 8'd1;
                        state <= CHECK_NODE;
                    end
                end

                NEXT_NODE: begin
                    current_node <= current_node + 8'd1;
                    state <= CHECK_NODE;
                end

                COMPLETE: begin
                    count <= good_node_counter;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule