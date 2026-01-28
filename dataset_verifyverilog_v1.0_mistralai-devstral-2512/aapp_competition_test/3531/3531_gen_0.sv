module MSTWithSpecialEdges(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] edge_in,
    input wire [4:0] edge_count,
    input wire [15:0] special_mask,
    input wire [3:0] target_w,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] SORT_EDGES = 3'd2;
    localparam [2:0] BUILD_MST = 3'd3;
    localparam [2:0] CHECK_RESULT = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] edge_index;
    reg [4:0] sort_pass;
    reg [4:0] build_index;
    reg [15:0] total_cost;
    reg [3:0] current_w;
    reg [3:0] edges_added;
    reg [15:0] parent [0:15];
    reg [3:0] rank [0:15];

    // Edge storage (max 32 edges)
    reg [15:0] edge_cost [0:31];
    reg [7:0] edge_a [0:31];
    reg [7:0] edge_b [0:31];

    // Temporary variables for sorting
    reg [15:0] temp_cost;
    reg [7:0] temp_a, temp_b;

    // Union-Find functions
    function [7:0] find;
        input [7:0] x;
        reg [7:0] root;
        begin
            root = x;
            while (parent[root] != root) begin
                root = parent[root];
            end
            find = root;
        end
    endfunction

    function void union_sets;
        input [7:0] x, y;
        reg [7:0] x_root, y_root;
        begin
            x_root = find(x);
            y_root = find(y);
            if (x_root != y_root) begin
                if (rank[x_root] < rank[y_root]) begin
                    parent[x_root] = y_root;
                end else if (rank[x_root] > rank[y_root]) begin
                    parent[y_root] = x_root;
                end else begin
                    parent[y_root] = x_root;
                    rank[x_root] = rank[x_root] + 1'b1;
                end
            end
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_index <= 5'd0;
            sort_pass <= 5'd0;
            build_index <= 5'd0;
            total_cost <= 16'd0;
            current_w <= 4'd0;
            edges_added <= 4'd0;
            done <= 1'b0;
            result <= 16'd0;

            // Initialize Union-Find
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                rank[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_EDGES;
                end
            end

            LOAD_EDGES: begin
                if (edge_index == edge_count) begin
                    next_state = SORT_EDGES;
                end
            end

            SORT_EDGES: begin
                if (sort_pass == 5'd31) begin
                    next_state = BUILD_MST;
                end
            end

            BUILD_MST: begin
                if (build_index == edge_count) begin
                    next_state = CHECK_RESULT;
                end
            end

            CHECK_RESULT: begin
                next_state = OUTPUT;
            end

            OUTPUT: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Edge loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_index <= 5'd0;
        end else if (state == LOAD_EDGES && edge_index < edge_count) begin
            edge_cost[edge_index] <= edge_in[15:0];
            edge_a[edge_index] <= edge_in[23:16];
            edge_b[edge_index] <= edge_in[31:24];
            edge_index <= edge_index + 5'd1;
        end
    end

    // Bubble sort implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_pass <= 5'd0;
        end else if (state == SORT_EDGES) begin
            if (sort_pass < 5'd31) begin
                integer i;
                for (i = 0; i < 31 - sort_pass; i = i + 1) begin
                    if (edge_cost[i] > edge_cost[i + 1]) begin
                        // Swap edges
                        temp_cost = edge_cost[i];
                        temp_a = edge_a[i];
                        temp_b = edge_b[i];

                        edge_cost[i] = edge_cost[i + 1];
                        edge_a[i] = edge_a[i + 1];
                        edge_b[i] = edge_b[i + 1];

                        edge_cost[i + 1] = temp_cost;
                        edge_a[i + 1] = temp_a;
                        edge_b[i + 1] = temp_b;
                    end
                end
                sort_pass <= sort_pass + 5'd1;
            end
        end
    end

    // MST building
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            build_index <= 5'd0;
            total_cost <= 16'd0;
            current_w <= 4'd0;
            edges_added <= 4'd0;
        end else if (state == BUILD_MST && build_index < edge_count) begin
            reg [7:0] a = edge_a[build_index];
            reg [7:0] b = edge_b[build_index];
            reg [7:0] a_root, b_root;

            a_root = find(a);
            b_root = find(b);

            if (a_root != b_root) begin
                // Check if this is a special-nonspecial edge
                reg is_special_a = (special_mask[a] == 1'b1);
                reg is_special_b = (special_mask[b] == 1'b1);

                if (is_special_a != is_special_b) begin
                    if (current_w < target_w) begin
                        current_w <= current_w + 4'd1;
                        total_cost <= total_cost + edge_cost[build_index];
                        edges_added <= edges_added + 4'd1;
                        union_sets(a, b);
                    end
                end else begin
                    total_cost <= total_cost + edge_cost[build_index];
                    edges_added <= edges_added + 4'd1;
                    union_sets(a, b);
                end
            end
            build_index <= build_index + 5'd1;
        end
    end

    // Result checking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else if (state == CHECK_RESULT) begin
            if (edges_added == edge_count - 5'd1 && current_w == target_w) begin
                result <= total_cost;
            end else begin
                result <= 16'd65535; // -1 in 16-bit unsigned
            end
        end else if (state == OUTPUT) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule