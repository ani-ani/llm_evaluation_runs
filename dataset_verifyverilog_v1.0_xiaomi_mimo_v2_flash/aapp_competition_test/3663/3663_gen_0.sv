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
    reg [2:0] state;
    
    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_TREE = 3'd1;
    localparam [2:0] DFS = 3'd2;
    localparam [2:0] ACCUMULATE = 3'd3;
    localparam [2:0] DONE = 3'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            done <= 1'b0;
            total_cost <= 24'd0;
            state <= IDLE;
            stack_top <= 3'd0;
            q_head <= 3'd0;
            q_tail <= 3'd0;
            for (i = 0; i < MAX_N; i = i + 1) begin
                parent[i] <= 8'hFF;
                child_count[i] <= 8'd0;
                net_flow[i] <= 8'sd0;
                child_index[i] <= 8'd0;
                cost_to_parent[i] <= 8'd0;
                for (j = 0; j < MAX_N; j = j + 1) begin
                    children[i][j] <= 8'hFF;
                end
            end
            u <= 8'd0;
            v <= 8'd0;
            child <= 8'd0;
            current_node <= 8'd0;
            accum_child <= 3'd0;
            temp_flow <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    total_cost <= 24'd0;
                    stack_top <= 3'd0;
                    q_head <= 3'd0;
                    q_tail <= 3'd0;
                    if (start) begin
                        // Initialize BFS
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            parent[i] <= 8'hFF;
                            child_count[i] <= 8'd0;
                            cost_to_parent[i] <= 8'd0;
                            net_flow[i] <= 8'sd0;
                            child_index[i] <= 8'd0;
                            for (j = 0; j < MAX_N; j = j + 1) begin
                                children[i][j] <= 8'hFF;
                            end
                        end
                        parent[0] <= 8'hFF;
                        queue[0] <= 8'd0;
                        q_head <= 3'd0;
                        q_tail <= 3'd1;
                        state <= BUILD_TREE;
                    end
                end

                BUILD_TREE: begin
                    if (q_head != q_tail) begin
                        u <= queue[q_head];
                        q_head <= q_head + 3'd1;
                        i <= 8'd0;
                    end else begin
                        stack_top <= 3'd0;
                        stack[3'd0] <= 8'd0;
                        stack_top <= stack_top + 3'd1;
                        for (i = 0; i < MAX_N; i = i + 1) begin
                            net_flow[i] <= 8'sd0;
                            child_index[i] <= 8'd0;
                        end
                        total_cost <= 24'd0;
                        state <= DFS;
                    end
                end

                DFS: begin
                    if (stack_top != 3'd0) begin
                        if (child_index[stack[stack_top - 3'd1]] < child_count[stack[stack_top - 3'd1]]) begin
                            child <= children[stack[stack_top - 3'd1]][child_index[stack[stack_top - 3'd1]]];
                            child_index[stack[stack_top - 3'd1]] <= child_index[stack[stack_top - 3'd1]] + 8'd1;
                            stack[stack_top] <= children[stack[stack_top - 3'd1]][child_index[stack[stack_top - 3'd1]]];
                            stack_top <= stack_top + 3'd1;
                        end else begin
                            current_node <= stack[stack_top - 3'd1];
                            accum_child <= 3'd0;
                            net_flow[stack[stack_top - 3'd1]] <= $signed(x[stack[stack_top - 3'd1]]) - $signed(y[stack[stack_top - 3'd1]]);
                            state <= ACCUMULATE;
                        end
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                ACCUMULATE: begin
                    if (accum_child < child_count[current_node]) begin
                        child <= children[current_node][accum_child];
                        net_flow[current_node] <= net_flow[current_node] + net_flow[children[current_node][accum_child]];
                        if (net_flow[children[current_node][accum_child]][7]) begin
                            temp_flow <= -net_flow[children[current_node][accum_child]];
                        end else begin
                            temp_flow <= net_flow[children[current_node][accum_child]];
                        end
                        total_cost <= total_cost + temp_flow * cost_to_parent[children[current_node][accum_child]];
                        accum_child <= accum_child + 3'd1;
                    end else begin
                        stack_top <= stack_top - 3'd1;
                        state <= DFS;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase

            if (state == BUILD_TREE && q_head != q_tail && i < n - 8'd1) begin
                if (edge_u[i] == u && parent[edge_v[i]] == 8'hFF && edge_v[i] < n) begin
                    v <= edge_v[i];
                    parent[edge_v[i]] <= u;
                    cost_to_parent[edge_v[i]] <= edge_cost[i];
                    children[u][child_count[u]] <= edge_v[i];
                    child_count[u] <= child_count[u] + 8'd1;
                    queue[q_tail] <= edge_v[i];
                    q_tail <= q_tail + 3'd1;
                    i <= i + 8'd1;
                end else if (edge_v[i] == u && parent[edge_u[i]] == 8'hFF && edge_u[i] < n) begin
                    v <= edge_u[i];
                    parent[edge_u[i]] <= u;
                    cost_to_parent[edge_u[i]] <= edge_cost[i];
                    children[u][child_count[u]] <= edge_u[i];
                    child_count[u] <= child_count[u] + 8'd1;
                    queue[q_tail] <= edge_u[i];
                    q_tail <= q_tail + 3'd1;
                    i <= i + 8'd1;
                end else begin
                    i <= i + 8'd1;
                end
            end
        end
    end

endmodule