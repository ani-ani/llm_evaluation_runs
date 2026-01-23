module army_move_optimizer(
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [31:0] supply [0:7],
    input [31:0] demand [0:7],
    input [31:0] edge_cost [0:63],
    output reg [31:0] total_cost,
    output reg done
);
    // State definitions
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam FIND_ROOT = 4'd2;
    localparam DFS_INIT = 4'd3;
    localparam DFS_LOOP = 4'd4;
    localparam DFS_CHILD = 4'd5;
    localparam DFS_ACCUM = 4'd6;
    localparam CALC_COST = 4'd7;
    localparam UPDATE_COST = 4'd8;
    localparam BACKTRACK = 4'd9;
    localparam DONE = 4'd10;
    
    reg [3:0] state;
    reg [2:0] current_node;
    reg [2:0] child_idx;
    reg [2:0] parent_idx;
    
    // Storage arrays
    reg signed [31:0] net_balance [0:7];
    reg signed [31:0] subtree_sum [0:7];
    reg visited [0:7];
    reg in_stack [0:7];
    reg [31:0] cost_accum;
    
    // Stack for iterative DFS (stores parent of current node)
    reg [2:0] parent_stack [0:7];
    reg [2:0] stack_ptr;
    
    // Temporary variables for edge access
    reg [5:0] edge_addr;
    reg [31:0] edge_val;
    reg signed [31:0] abs_sum;
    reg signed [31:0] edge_cost_val;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_cost <= 32'd0;
            done <= 1'b0;
            cost_accum <= 32'd0;
            stack_ptr <= 3'd0;
            current_node <= 3'd0;
            child_idx <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                net_balance[i] <= 32'sd0;
                subtree_sum[i] <= 32'sd0;
                visited[i] <= 1'b0;
                in_stack[i] <= 1'b0;
                parent_stack[i] <= 3'd0;
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
                            net_balance[i] <= supply[i] - demand[i];
                            subtree_sum[i] <= 32'sd0;
                        end else begin
                            net_balance[i] <= 32'sd0;
                            subtree_sum[i] <= 32'sd0;
                        end
                        visited[i] <= 1'b0;
                        in_stack[i] <= 1'b0;
                    end
                    stack_ptr <= 3'd0;
                    current_node <= 3'd0;
                    state <= FIND_ROOT;
                end
                
                FIND_ROOT: begin
                    // Start DFS from node 0 (assumed root)
                    if (node_count == 3'd0) begin
                        state <= DONE;
                    end else begin
                        current_node <= 3'd0;
                        child_idx <= 3'd0;
                        state <= DFS_INIT;
                    end
                end
                
                DFS_INIT: begin
                    // Mark current node as visited and stack it
                    if (current_node < node_count) begin
                        if (!visited[current_node]) begin
                            visited[current_node] <= 1'b1;
                            in_stack[current_node] <= 1'b1;
                            parent_stack[stack_ptr] <= current_node;
                            stack_ptr <= stack_ptr + 3'd1;
                            subtree_sum[current_node] <= net_balance[current_node];
                            child_idx <= 3'd0;
                            state <= DFS_LOOP;
                        end else begin
                            // Already visited, move to next
                            state <= BACKTRACK;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                DFS_LOOP: begin
                    // Find next unvisited child
                    if (child_idx < node_count) begin
                        edge_addr = current_node * 8 + child_idx;
                        edge_val = edge_cost[edge_addr];
                        if (edge_val != 32'd0 && !visited[child_idx]) begin
                            // Found unvisited child
                            state <= DFS_CHILD;
                        end else begin
                            child_idx <= child_idx + 3'd1;
                            state <= DFS_LOOP;
                        end
                    end else begin
                        // No more children to process, add cost and backtrack
                        state <= CALC_COST;
                    end
                end
                
                DFS_CHILD: begin
                    // Push current node back to stack and go to child
                    parent_stack[stack_ptr] <= current_node;
                    stack_ptr <= stack_ptr + 3'd1;
                    current_node <= child_idx;
                    state <= DFS_INIT;
                end
                
                CALC_COST: begin
                    // Calculate cost for edge from parent to current_node
                    if (stack_ptr > 3'd0) begin
                        parent_idx = parent_stack[stack_ptr - 3'd1];
                        edge_addr = parent_idx * 8 + current_node;
                        edge_cost_val = edge_cost[edge_addr];
                        abs_sum = subtree_sum[current_node];
                        if (abs_sum[31]) abs_sum = -abs_sum;
                        state <= UPDATE_COST;
                    end else begin
                        state <= BACKTRACK;
                    end
                end
                
                UPDATE_COST: begin
                    // Accumulate cost: abs(subtree_sum) * edge_cost
                    cost_accum <= cost_accum + (abs_sum * edge_cost_val);
                    state <= BACKTRACK;
                end
                
                BACKTRACK: begin
                    // Pop from stack to go back up
                    if (stack_ptr > 3'd0) begin
                        stack_ptr <= stack_ptr - 3'd1;
                        parent_idx = parent_stack[stack_ptr - 3'd1];
                        
                        // Update parent's subtree sum
                        if (stack_ptr > 3'd1) begin
                            // Add current node's sum to parent
                            subtree_sum[parent_idx] <= subtree_sum[parent_idx] + subtree_sum[current_node];
                        end
                        
                        current_node <= parent_idx;
                        
                        // If we're back at root and stack is empty, we're done
                        if (stack_ptr == 3'd1) begin
                            state <= DONE;
                        end else begin
                            // Continue processing siblings
                            child_idx <= current_node + 3'd1;
                            state <= DFS_LOOP;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    total_cost <= cost_accum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule