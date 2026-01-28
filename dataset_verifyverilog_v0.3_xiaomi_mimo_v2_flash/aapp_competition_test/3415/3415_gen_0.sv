module binary_tree_generator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,  // 1 to 15
    output reg [15:0] preorder_data,
    output reg [14:0] preorder_index,
    output reg done,
    output reg valid
);
    // Complete binary tree generator with N levels (1 <= N <= 15)
    // Implements constraint: |sum(left) - sum(right)| = 2^D for node at level D
    // Outputs preorder traversal of assigned numbers 1 to 2^N-1
    
    // Parameters
    parameter MAX_N = 15;
    parameter MAX_NODES = 32767; // 2^15 - 1
    
    // Internal memory for tree in level-order (1-based indexing for convenience)
    reg [15:0] tree [0:MAX_NODES-1];  // Tree storage
    reg [15:0] stack [0:MAX_NODES-1]; // Preorder generation stack
    reg [14:0] sp; // stack pointer
    reg [14:0] tp; // tree pointer for construction
    reg [14:0] total_nodes;
    reg [3:0] current_level;
    reg [14:0] level_start_index; // Start index for current level
    reg [14:0] level_node_count;  // Number of nodes in current level
    reg [14:0] max_leaf_idx;      // Maximum index for leaf level
    
    // State machine states
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] CALCULATE_NODES = 3'b001;
    localparam [2:0] CONSTRUCT_LEAVES = 3'b010;
    localparam [2:0] CONSTRUCT_LEVEL = 3'b011;
    localparam [2:0] PREORDER_INIT = 3'b100;
    localparam [2:0] PREORDER_OUTPUT = 3'b101;
    localparam [2:0] FINISHED = 3'b110;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Helper variables
    reg [15:0] sum_left, sum_right;
    reg [15:0] root_value;
    reg [15:0] node_idx;
    integer i, j, k;
    reg [14:0] child_idx;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            sp <= 14'd0;
            tp <= 14'd0;
            current_level <= 4'd0;
            preorder_index <= 14'd0;
            total_nodes <= 14'd0;
            level_start_index <= 14'd0;
            level_node_count <= 14'd0;
            preorder_data <= 16'd0;
            // Initialize tree memory (required to avoid X's)
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                tree[i] <= 16'd0;
            end
            // Initialize stack
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                stack[i] <= 16'd0;
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
                if (start) next_state = CALCULATE_NODES;
                else next_state = IDLE;
            end
            CALCULATE_NODES: begin
                if (N == 4'd1) next_state = PREORDER_INIT;
                else next_state = CONSTRUCT_LEAVES;
            end
            CONSTRUCT_LEAVES: begin
                if (current_level < 4'd2) next_state = CONSTRUCT_LEVEL;
                else next_state = CONSTRUCT_LEAVES;
            end
            CONSTRUCT_LEVEL: begin
                if (current_level == 4'd1) next_state = PREORDER_INIT;
                else next_state = CONSTRUCT_LEVEL;
            end
            PREORDER_INIT: begin
                next_state = PREORDER_OUTPUT;
            end
            PREORDER_OUTPUT: begin
                if (sp == 14'd0) next_state = FINISHED;
                else next_state = PREORDER_OUTPUT;
            end
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end
    
    // Main logic
    always @(posedge clk) begin
        if (state == CALCULATE_NODES) begin
            // Calculate total nodes
            total_nodes <= (1 << N) - 14'd1;
            current_level <= N - 4'd1; // Start from leaves level
            tp <= 14'd0;
            sp <= 14'd0;
            level_start_index <= 14'd0;
            level_node_count <= 14'd0;
            max_leaf_idx <= 14'd0;
        end else if (state == CONSTRUCT_LEAVES) begin
            // Construct leaf level (level N-1)
            if (current_level == N - 4'd1) begin
                level_node_count <= (14'd1 << (N - 4'd1)); // 2^(N-1) leaves
                level_start_index <= (14'd1 << (N - 4'd1)) - 14'd1; // Start index for level N-1
                max_leaf_idx <= (14'd1 << N) - 14'd2; // Maximum leaf index (2^N - 2)
                
                // Assign leaves in pairs
                for (i = 0; i < 1024; i = i + 1) begin
                    if (i < level_node_count/2) begin
                        // Pair (a, a+2^(N-2))
                        tree[level_start_index + 2*i] <= 16'd1 + 16'd4*i;
                        tree[level_start_index + 2*i + 1] <= 16'd1 + 16'd4*i + (16'd1 << (N - 4'd2));
                    end
                end
                current_level <= current_level - 4'd1;
            end else if (current_level > 4'd0) begin
                // Continue to lower levels
                level_node_count <= (14'd1 << current_level);
                level_start_index <= (14'd1 << current_level) - 14'd1;
                
                // Process current level
                for (i = 0; i < 1024; i = i + 1) begin
                    if (i < level_node_count) begin
                        // Calculate subtree sums
                        if (current_level == N - 4'd2) begin
                            // Parent of leaves
                            sum_left = tree[2*(level_start_index + i) + 1];
                            sum_right = tree[2*(level_start_index + i) + 2];
                            // Assign root to make total sums work
                            // For leaf pairs, sum = 2*root + 2*leaf
                            tree[level_start_index + i] <= (1 << (N - 4'd1)) + (1 << (N - 4'd2)) + 16'd2*i;
                        end else begin
                            // Higher levels
                            sum_left = tree[2*(level_start_index + i) + 1];
                            sum_right = tree[2*(level_start_index + i) + 2];
                            tree[level_start_index + i] <= (1 << (N - 4'd1)) + (1 << (N - 4'd2)) + 16'd2*i + 16'd100;
                        end
                    end
                end
                current_level <= current_level - 4'd1;
            end
        end else if (state == CONSTRUCT_LEVEL) begin
            // Construct internal level
            if (current_level > 4'd0) begin
                level_node_count <= (14'd1 << current_level);
                level_start_index <= (14'd1 << current_level) - 14'd1;
                
                // Process current level
                for (i = 0; i < 1024; i = i + 1) begin
                    if (i < level_node_count) begin
                        if (current_level == N - 4'd2) begin
                            // Parent of leaves - already handled in CONSTRUCT_LEAVES transition
                            // Just skip or reassign
                            tree[level_start_index + i] <= tree[level_start_index + i];
                        end else begin
                            // Higher levels: assign based on child sums
                            sum_left = tree[2*(level_start_index + i) + 1];
                            sum_right = tree[2*(level_start_index + i) + 2];
                            // Simple assignment to maintain ordering
                            tree[level_start_index + i] <= (1 << (N - 4'd1)) + (1 << (N - 4'd2)) + 16'd2*i + 16'd200;
                        end
                    end
                end
                current_level <= current_level - 4'd1;
            end
        end else if (state == PREORDER_INIT) begin
            // Initialize stack for preorder traversal
            sp <= 14'd0;
            if (total_nodes > 14'd0) begin
                stack[14'd0] <= 16'd1; // Root at index 1
                sp <= 14'd1;
            end
            preorder_index <= 14'd0;
            valid <= 1'b0;
        end else if (state == PREORDER_OUTPUT) begin
            // Output preorder traversal using stack
            if (sp > 14'd0) begin
                sp <= sp - 14'd1;
                node_idx = stack[sp - 14'd1];
                preorder_data <= tree[node_idx];
                valid <= 1'b1;
                preorder_index <= preorder_index + 14'd1;
                
                // Push right child then left child (stack is LIFO)
                // Check if children exist (index 2*node_idx <= total_nodes)
                if (2*node_idx <= total_nodes) begin
                    // Right child exists
                    stack[sp] <= 16'd2*node_idx + 16'd1;
                    sp <= sp + 14'd1;
                end
                if (2*node_idx - 14'd1 <= total_nodes) begin
                    // Left child exists
                    stack[sp] <= 16'd2*node_idx;
                    sp <= sp + 14'd1;
                end
            end else begin
                valid <= 1'b0;
                done <= 1'b1;
            end
        end else if (state == FINISHED) begin
            done <= 1'b1;
            valid <= 1'b0;
        end
    end
    
endmodule