module UniversityTreeDistance(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] univ_mask,
    input [63:0] edge_src,
    input [63:0] edge_dst,
    input [3:0] num_edges,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] BUILD_ADJ  = 3'd1;
    localparam [2:0] DFS_ORDER  = 3'd2;
    localparam [2:0] POST_PROCESS = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Adjacency list (4-bit per entry, max 16 nodes, 3 neighbors per node)
    reg [3:0] adj_list [0:15];
    reg [3:0] adj_ptr [0:15];
    reg [3:0] adj_count [0:15];

    // DFS/BFS structures
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] parent [0:15];
    reg [3:0] process_order [0:15];
    reg [3:0] order_ptr;

    // University counts and processing
    reg [3:0] univ_cnt [0:15];
    reg [15:0] total;
    reg [3:0] current_node;
    reg [3:0] i, j;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 16'd0;
            total <= 16'd0;
            stack_ptr <= 4'd0;
            order_ptr <= 4'd0;
            current_node <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;

            // Initialize adjacency list
            for (i = 0; i < 16; i = i + 1) begin
                adj_list[i] <= 4'd0;
                adj_ptr[i] <= 4'd0;
                adj_count[i] <= 4'd0;
                parent[i] <= 4'd0;
                process_order[i] <= 4'd0;
                univ_cnt[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = BUILD_ADJ;
                    cycle_count = 8'd0;
                end
            end

            BUILD_ADJ: begin
                // Build adjacency list from edge inputs
                if (cycle_count < num_edges) begin
                    // Extract current edge
                    reg [3:0] src = edge_src[(cycle_count * 16) +: 16];
                    reg [3:0] dst = edge_dst[(cycle_count * 16) +: 16];

                    // Add to adjacency lists
                    adj_list[src] = dst;
                    adj_list[dst] = src;
                    adj_count[src] = adj_count[src] + 4'd1;
                    adj_count[dst] = adj_count[dst] + 4'd1;
                end else begin
                    next_state = DFS_ORDER;
                end
            end

            DFS_ORDER: begin
                // Perform DFS to establish parent pointers and processing order
                if (stack_ptr == 4'd0) begin
                    // Initialize stack with root
                    stack[0] = 4'd0;
                    stack_ptr = 4'd1;
                    parent[0] = 4'd0; // Root has no parent
                end else if (stack_ptr > 4'd0) begin
                    // Process current node
                    current_node = stack[stack_ptr - 4'd1];
                    stack_ptr = stack_ptr - 4'd1;

                    // Add to processing order (post-order)
                    process_order[order_ptr] = current_node;
                    order_ptr = order_ptr + 4'd1;

                    // Push children to stack (reverse order for DFS)
                    for (i = 0; i < 3; i = i + 1) begin
                        reg [3:0] neighbor = adj_list[current_node];
                        if (neighbor != 4'd0 && parent[neighbor] == 4'd0 && neighbor != parent[current_node]) begin
                            parent[neighbor] = current_node;
                            stack[stack_ptr] = neighbor;
                            stack_ptr = stack_ptr + 4'd1;
                        end
                    end

                    // If stack is empty, move to next state
                    if (stack_ptr == 4'd0) begin
                        next_state = POST_PROCESS;
                        order_ptr = 4'd0; // Reset for processing
                    end
                end
            end

            POST_PROCESS: begin
                // Process nodes in reverse order (post-order)
                if (order_ptr < n) begin
                    current_node = process_order[order_ptr];
                    order_ptr = order_ptr + 4'd1;

                    // Count universities in this node's subtree
                    univ_cnt[current_node] = (univ_mask[current_node] ? 4'd1 : 4'd0);

                    // Add children's counts
                    for (i = 0; i < 3; i = i + 1) begin
                        reg [3:0] child = adj_list[current_node];
                        if (child != 4'd0 && parent[child] == current_node) begin
                            univ_cnt[current_node] = univ_cnt[current_node] + univ_cnt[child];
                        end
                    end

                    // If not root, add edge contribution
                    if (current_node != 4'd0) begin
                        reg [3:0] u_sub = univ_cnt[current_node];
                        reg [3:0] min_val = (u_sub < (2*k - u_sub)) ? u_sub : (2*k - u_sub);
                        total = total + min_val;
                    end
                end else begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                result = total;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule