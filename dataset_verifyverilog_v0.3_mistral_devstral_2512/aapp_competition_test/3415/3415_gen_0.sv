module binary_tree_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    output reg [15:0] preorder_data,
    output reg [14:0] preorder_index,
    output reg done,
    output reg valid
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATE_NODES = 3'd1;
    localparam [2:0] CONSTRUCT_TREE = 3'd2;
    localparam [2:0] PREORDER_INIT = 3'd3;
    localparam [2:0] PREORDER_OUTPUT = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    // State registers
    reg [2:0] state, next_state;

    // Tree storage (1-based indexing)
    reg [15:0] tree [0:32766];

    // Stack for preorder traversal
    reg [14:0] stack [0:32766];
    reg [14:0] sp; // stack pointer

    // Tree construction variables
    reg [14:0] total_nodes;
    reg [14:0] current_node;
    reg [14:0] level_start;
    reg [14:0] level_size;
    reg [3:0] current_level;

    // Preorder output variables
    reg [14:0] output_index;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            sp <= 15'd0;
            current_node <= 15'd0;
            current_level <= 4'd0;
            preorder_index <= 15'd0;
            output_index <= 15'd0;
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
            end
            CALCULATE_NODES: begin
                next_state = CONSTRUCT_TREE;
            end
            CONSTRUCT_TREE: begin
                if (current_level == 0) next_state = PREORDER_INIT;
                else next_state = CONSTRUCT_TREE;
            end
            PREORDER_INIT: begin
                next_state = PREORDER_OUTPUT;
            end
            PREORDER_OUTPUT: begin
                if (sp == 0) next_state = FINISHED;
                else next_state = PREORDER_OUTPUT;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main logic
    always @(posedge clk) begin
        if (state == CALCULATE_NODES) begin
            // Calculate total nodes
            total_nodes = (1 << N) - 1;
            current_level = N - 1;
            current_node = 0;
            level_start = (1 << (N - 1)) - 1;
            level_size = 1 << (N - 1);
            
            // Initialize leaves
            for (integer i = 0; i < level_size; i = i + 1) begin
                tree[level_start + i] = i + 1;
            end
        end else if (state == CONSTRUCT_TREE) begin
            // Construct internal nodes
            level_start = (1 << current_level) - 1;
            level_size = 1 << current_level;
            
            for (integer i = 0; i < level_size; i = i + 1) begin
                reg [15:0] left_val = tree[2*(level_start + i) + 1];
                reg [15:0] right_val = tree[2*(level_start + i) + 2];
                
                // Calculate parent value to satisfy constraint
                if (current_level == N - 2) begin
                    // Parent of leaves: assign to satisfy leaf difference constraint
                    tree[level_start + i] = (left_val + right_val) / 2;
                end else begin
                    // Higher levels: assign to maintain constraint
                    tree[level_start + i] = (left_val + right_val) / 2;
                end
            end
            
            current_level = current_level - 1;
        end else if (state == PREORDER_INIT) begin
            // Initialize stack for preorder traversal
            sp = 0;
            if (total_nodes > 0) begin
                stack[sp] = 1; // Root at index 1
                sp = sp + 1;
            end
            output_index = 0;
            preorder_index = 0;
        end else if (state == PREORDER_OUTPUT) begin
            // Output preorder traversal using stack
            if (sp > 0) begin
                sp = sp - 1;
                reg [14:0] node_idx = stack[sp];
                preorder_data = tree[node_idx];
                valid = 1'b1;
                preorder_index = preorder_index + 1;
                
                // Push right child then left child (stack is LIFO)
                if (2*node_idx + 1 <= total_nodes) begin
                    stack[sp] = 2*node_idx + 1; // Right child
                    sp = sp + 1;
                end
                if (2*node_idx <= total_nodes) begin
                    stack[sp] = 2*node_idx; // Left child
                    sp = sp + 1;
                end
            end else begin
                valid = 1'b0;
                done = 1'b1;
            end
        end else if (state == FINISHED) begin
            done <= 1'b1;
            valid <= 1'b0;
        end
    end

endmodule