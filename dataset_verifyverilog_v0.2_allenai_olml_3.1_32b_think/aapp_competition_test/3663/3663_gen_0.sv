module army_move_optimizer(input clk, input rst_n, input start, input [2:0] node_count, input [31:0] supply [0:7], input [31:0] demand [0:7], input [31:0] edge_cost [0:63], output reg [31:0] total_cost, output reg done);
    // State definitions
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam DFS_PROCESS = 3'd2;
    localparam ACCUMULATE = 3'd3;
    localparam DONE = 3'd4;

    reg [2:0] state;
    reg [2:0] current_node;
    reg [2:0] next_node;
    reg [31:0] net_balance [0:7];
    reg [31:0] subtree_sum [0:7];
    reg visited [0:7];
    reg [31:0] cost_accum;
    reg [2:0] edge_idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_cost <= 32'd0;
            done <= 1'b0;
            cost_accum <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                net_balance[i] <= 32'd0;
                subtree_sum[i] <= 32'd0;
                visited[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cost_accum <= 32'd0;
                    end
                end

                INIT: begin
                    // Compute net balance for each node
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < node_count) begin
                            net_balance[i] <= supply[i] - demand[i];  // Fixed: removed ternary
                        end else begin
                            net_balance[i] <= 32'd0;
                        end
                        visited[i] <= 1'b0;
                        subtree_sum[i] <= 32'd0;
                    end
                    current_node <= 3'd0;
                    state <= DFS_PROCESS;
                end

                DFS_PROCESS: begin
                    // Iterative DFS: compute subtree sums
                    // Simplified: process nodes in order, accumulate from children
                    if (current_node < node_count) begin
                        if (!visited[current_node]) begin
                            visited[current_node] <= 1'b1;
                            subtree_sum[current_node] <= net_balance[current_node];
                            // Find children via adjacency matrix
                            edge_idx <= 3'd0;
                            state <= ACCUMULATE;
                        end else begin
                            current_node <= current_node + 3'd1;
                            if (current_node >= node_count - 1) begin
                                state <= DONE;
                            end
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                ACCUMULATE: begin
                    // Check edge from current_node to edge_idx
                    if (edge_idx < node_count) begin
                        if (edge_cost[current_node * 8 + edge_idx] != 32'd0 && !visited[edge_idx]) begin
                            // Add child's subtree sum
                            subtree_sum[current_node] <= subtree_sum[current_node] + subtree_sum[edge_idx];
                            // Add edge cost: abs(subtree_sum[edge_idx]) * cost
                            cost_accum <= cost_accum + (subtree_sum[edge_idx][31] ? (~subtree_sum[edge_idx] + 1) * edge_cost[current_node * 8 + edge_idx] : subtree_sum[edge_idx] * edge_cost[current_node * 8 + edge_idx]);
                        end
                        edge_idx <= edge_idx + 3'd1;
                    end else begin
                        current_node <= current_node + 3'd1;
                        state <= DFS_PROCESS;
                    end
                end

                DONE: begin
                    total_cost <= cost_accum;
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule