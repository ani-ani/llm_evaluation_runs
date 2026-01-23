module constrained_mst (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [3:0] k,
    input [3:0] w,
    input [15:0] special_nodes_mask,
    input [15:0] edge_node_a [0:15],
    input [15:0] edge_node_b [0:15],
    input [15:0] edge_cost [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] GENERATE = 3'b001;
    localparam [2:0] CHECK = 3'b010;
    localparam [2:0] DONE = 3'b100;

    reg [2:0] state = IDLE;

    // Internal registers
    reg [15:0] current_combination = 0;
    reg [31:0] min_cost = 32'hFFFFFFFF;
    reg [3:0] edge_count = 0;
    reg [3:0] special_edge_count = 0;
    reg [31:0] current_cost = 0;
    reg [15:0] parent [0:15];
    reg [15:0] rank [0:15];
    reg [3:0] i, j;

    // Union-Find functions
    function [15:0] find;
        input [15:0] x;
        begin
            if (parent[x] != x) begin
                parent[x] = find(parent[x]);
            end
            find = parent[x];
        end
    endfunction

    function void union_nodes;
        input [15:0] x, y;
        begin
            x = find(x);
            y = find(y);
            if (x != y) begin
                if (rank[x] < rank[y]) begin
                    parent[x] = y;
                end else if (rank[x] > rank[y]) begin
                    parent[y] = x;
                end else begin
                    parent[y] = x;
                    rank[x] = rank[x] + 1;
                end
            end
        end
    endfunction

    // Check if edge is special-nonspecial
    function reg is_special_edge;
        input [15:0] a, b;
        begin
            is_special_edge = (special_nodes_mask[a] ^ special_nodes_mask[b]);
        end
    endfunction

    // Check if current combination forms a spanning tree
    reg is_spanning_tree;
    reg [15:0] root;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_combination <= 0;
            min_cost <= 32'hFFFFFFFF;
            edge_count <= 0;
            special_edge_count <= 0;
            current_cost <= 0;
            done <= 0;
            result <= 32'hFFFFFFFF;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= GENERATE;
                        current_combination <= 0;
                        min_cost <= 32'hFFFFFFFF;
                        done <= 0;
                        result <= 32'hFFFFFFFF;
                    end
                end

                GENERATE: begin
                    // Iterate through all combinations of n-1 edges
                    if (current_combination == (1 << m) - 1) begin
                        state <= DONE;
                        if (min_cost == 32'hFFFFFFFF) begin
                            result <= 32'hFFFFFFFF;
                        end else begin
                            result <= min_cost;
                        end
                        done <= 1;
                    end else begin
                        edge_count <= 0;
                        special_edge_count <= 0;
                        current_cost <= 0;
                        // Reset Union-Find
                        for (i = 0; i < 16; i = i + 1) begin
                            parent[i] <= i;
                            rank[i] <= 0;
                        end
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check if current combination has exactly n-1 edges
                    for (i = 0; i < m; i = i + 1) begin
                        if (current_combination[i]) begin
                            edge_count <= edge_count + 1;
                            if (is_special_edge(edge_node_a[i], edge_node_b[i])) begin
                                special_edge_count <= special_edge_count + 1;
                            end
                            current_cost <= current_cost + edge_cost[i];
                        end
                    end

                    if (edge_count == n - 1 && special_edge_count == w) begin
                        // Check if it forms a spanning tree
                        is_spanning_tree = 1;
                        for (i = 0; i < m; i = i + 1) begin
                            if (current_combination[i]) begin
                                union_nodes(edge_node_a[i], edge_node_b[i]);
                            end
                        end
                        root = find(0);
                        for (i = 1; i < n; i = i + 1) begin
                            if (find(i) != root) begin
                                is_spanning_tree = 0;
                            end
                        end

                        if (is_spanning_tree && current_cost < min_cost) begin
                            min_cost <= current_cost;
                        end
                    end

                    current_combination <= current_combination + 1;
                    state <= GENERATE;
                end

                DONE: begin
                    // Stay in DONE state until reset
                end
            endcase
        end
    end

endmodule