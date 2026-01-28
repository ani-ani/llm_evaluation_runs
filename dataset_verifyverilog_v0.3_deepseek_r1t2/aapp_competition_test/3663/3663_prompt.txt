module army_movement (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] edge_u [0:6],
    input wire [7:0] edge_v [0:6],
    input wire [7:0] edge_cost [0:6],
    input wire [7:0] x [0:7],
    input wire [7:0] y [0:7],
    output reg [23:0] total_cost,
    output reg done
);

    // Maximum parameters
    parameter MAX_N = 8;
    parameter MAX_EDGES = 7;

    // Internal registers
    reg [7:0] parent [0:MAX_N-1];
    reg [7:0] cost_to_parent [0:MAX_N-1];
    reg [7:0] children [0:MAX_N-1][0:MAX_N-1];
    reg [7:0] child_count [0:MAX_N-1];
    reg signed [7:0] net_flow [0:MAX_N-1];
    reg [7:0] child_index [0:MAX_N-1];
    reg [2:0] stack [0:MAX_N-1];
    reg [2:0] stack_top;
    reg [2:0] queue [0:MAX_N-1];
    reg [2:0] q_head, q_tail;
    reg [7:0] i, j, u, v, child;
    reg [15:0] temp_cost;
    reg signed [7:0] temp_flow;
    reg [2:0] accum_child;
    reg [7:0] current_node;
    
    // State machine states
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam BUILD_TREE = 3'b001;
    localparam DFS = 3'b010;
    localparam ACCUMULATE = 3'b011;
    localparam DONE = 3'b100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            done <= 0;
            total_cost <= 0;
            state <= IDLE;
            stack_top <= 0;
            q_head <= 0;
            q_tail <= 0;
            for (i = 0; i < MAX_N; i = i + 1) begin
                parent[i] <= 8'hFF;
                child_count[i] <= 0;
                net_flow[i] <= 0;
                child_index[i] <= 0;
                cost_to_parent[i] <= 0;
                for (j = 0; j < MAX_N; j = j + 1) begin
                    children[i][j] <= 8'hFF;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    total_cost <= 0;
                    if (start) begin
                        // Initialize BFS
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            parent[i] <= 8'hFF;
                            child_count[i] <= 0;
                            cost_to_parent[i] <= 0;
                            net_flow[i] <= 0;
                            child_index[i] <= 0;
                            for (j = 0; j < MAX_N; j = j + 1) begin
                                children[i][j] <= 8'hFF;
                            end
                        end
                        parent[0] <= 8'hFF;  // Mark root as unvisited initially
                        queue[0] <= 0;
                        q_head <= 0;
                        q_tail <= 1;
                        state <= BUILD_TREE;
                    end
                end

                BUILD_TREE: begin
                    if (q_head != q_tail) begin
                        // Dequeue node
                        u <= queue[q_head];
                        q_head <= q_head + 1;
                        i <= 0;
                    end else begin
                        // Tree built, initialize DFS
                        stack_top <= 0;
                        stack[stack_top] <= 0;
                        stack_top <= stack_top + 1;
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            net_flow[i] <= 0;
                            child_index[i] <= 0;
                        end
                        total_cost <= 0;
                        state <= DFS;
                    end
                end

                DFS: begin
                    if (stack_top != 0) begin
                        // Get current node from stack
                        u <= stack[stack_top - 1];
                        if (child_index[stack[stack_top - 1]] < child_count[stack[stack_top - 1]]) begin
                            // Push next child to stack
                            child <= children[stack[stack_top - 1]][child_index[stack[stack_top - 1]]];
                            child_index[stack[stack_top - 1]] <= child_index[stack[stack_top - 1]] + 1;
                            stack[stack_top] <= children[stack[stack_top - 1]][child_index[stack[stack_top - 1]]];
                            stack_top <= stack_top + 1;
                        end else begin
                            // All children processed, now accumulate
                            current_node <= stack[stack_top - 1];
                            accum_child <= 0;
                            net_flow[stack[stack_top - 1]] <= $signed(x[stack[stack_top - 1]]) - $signed(y[stack[stack_top - 1]]);
                            state <= ACCUMULATE;
                        end
                    end else begin
                        state <= DONE;
                        done <= 1;
                    end
                end

                ACCUMULATE: begin
                    if (accum_child < child_count[current_node]) begin
                        // Add child's net flow and cost
                        child <= children[current_node][accum_child];
                        net_flow[current_node] <= net_flow[current_node] + net_flow[children[current_node][accum_child]];
                        // Calculate absolute value of child's net flow
                        if (net_flow[children[current_node][accum_child]][7]) begin
                            temp_flow <= -net_flow[children[current_node][accum_child]];
                        end else begin
                            temp_flow <= net_flow[children[current_node][accum_child]];
                        end
                        // Add cost: |net_flow| * edge_cost
                        total_cost <= total_cost + temp_flow * cost_to_parent[children[current_node][accum_child]];
                        accum_child <= accum_child + 1;
                    end else begin
                        // Done with this node, pop from stack
                        stack_top <= stack_top - 1;
                        state <= DFS;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase

            // Edge processing during BUILD_TREE
            if (state == BUILD_TREE && q_head != q_tail && i < n - 1) begin
                if (edge_u[i] == u && parent[edge_v[i]] == 8'hFF && edge_v[i] < n) begin
                    v <= edge_v[i];
                    parent[edge_v[i]] <= u;
                    cost_to_parent[edge_v[i]] <= edge_cost[i];
                    children[u][child_count[u]] <= edge_v[i];
                    child_count[u] <= child_count[u] + 1;
                    queue[q_tail] <= edge_v[i];
                    q_tail <= q_tail + 1;
                    i <= i + 1;
                end else if (edge_v[i] == u && parent[edge_u[i]] == 8'hFF && edge_u[i] < n) begin
                    v <= edge_u[i];
                    parent[edge_u[i]] <= u;
                    cost_to_parent[edge_u[i]] <= edge_cost[i];
                    children[u][child_count[u]] <= edge_u[i];
                    child_count[u] <= child_count[u] + 1;
                    queue[q_tail] <= edge_u[i];
                    q_tail <= q_tail + 1;
                    i <= i + 1;
                end else begin
                    i <= i + 1;
                end
            end
        end
    end

endmodule