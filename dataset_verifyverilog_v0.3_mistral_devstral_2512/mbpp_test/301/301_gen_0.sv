module dict_depth (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input: Fixed-size representation of a dictionary tree
    // We represent the dictionary as an adjacency matrix
    // node_children[i][j] = 1 if node i has child node j
    // node_is_dict[i] = 1 if node i is a dictionary node
    // Input tree has maximum 8 nodes and 4 levels
    input wire [7:0] node_children_0,
    input wire [7:0] node_children_1,
    input wire [7:0] node_children_2,
    input wire [7:0] node_children_3,
    input wire [7:0] node_children_4,
    input wire [7:0] node_children_5,
    input wire [7:0] node_children_6,
    input wire [7:0] node_children_7,
    input wire [7:0] node_is_dict,
    
    // Starting node (root of the dictionary)
    input wire [3:0] root_node,
    
    // Output: Maximum depth of the dictionary tree
    output reg [3:0] depth,
    
    // Done signal
    output reg done
);

parameter MAX_NODES = 8;
parameter MAX_DEPTH = 15; // 4-bit output

// State machine states
localparam [1:0] IDLE = 2'd0;
localparam [1:0] CALCULATE = 2'd1;
localparam [1:0] RETURN = 2'd2;
localparam [1:0] DONE_STATE = 2'd3;

reg [1:0] state;
reg [1:0] next_state;

// Stack for iterative DFS
reg [3:0] stack_node [0:15]; // Node index
reg [3:0] stack_depth [0:15]; // Current depth at that node
reg [4:0] stack_ptr; // Stack pointer
reg [4:0] stack_size; // Number of elements in stack

// Current traversal variables
reg [3:0] current_node;
reg [3:0] current_depth;
reg [3:0] max_depth;

// Child tracking
reg [3:0] child_idx;
reg [3:0] child_count;

// Helper to check if node has children
wire has_children;
wire is_dict_node;

assign is_dict_node = node_is_dict[current_node];

// Check children based on adjacency matrix
wire child_0, child_1, child_2, child_3, child_4, child_5, child_6, child_7;
assign child_0 = node_children_0[current_node];
assign child_1 = node_children_1[current_node];
assign child_2 = node_children_2[current_node];
assign child_3 = node_children_3[current_node];
assign child_4 = node_children_4[current_node];
assign child_5 = node_children_5[current_node];
assign child_6 = node_children_6[current_node];
assign child_7 = node_children_7[current_node];

wire [7:0] children_bits;
assign children_bits = {child_7, child_6, child_5, child_4, child_3, child_2, child_1, child_0};
assign has_children = (children_bits != 8'h00);

// Next child finder (priority encoder)
reg [3:0] next_child;
reg found_child;

always @(*) begin
    found_child = 0;
    next_child = 4'h0;
    
    // Find first child from current position
    if (child_idx < 8) begin
        case (child_idx)
            0: if (child_0) begin next_child = 0; found_child = 1; end
            1: if (child_1) begin next_child = 1; found_child = 1; end
            2: if (child_2) begin next_child = 2; found_child = 1; end
            3: if (child_3) begin next_child = 3; found_child = 1; end
            4: if (child_4) begin next_child = 4; found_child = 1; end
            5: if (child_5) begin next_child = 5; found_child = 1; end
            6: if (child_6) begin next_child = 6; found_child = 1; end
            7: if (child_7) begin next_child = 7; found_child = 1; end
            default: begin next_child = 0; found_child = 0; end
        endcase
    end
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Main FSM logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 0;
        depth <= 0;
        stack_ptr <= 0;
        stack_size <= 0;
        max_depth <= 0;
        current_node <= 0;
        current_depth <= 0;
        child_idx <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                depth <= 0;
                max_depth <= 0;
                stack_ptr <= 0;
                stack_size <= 0;
                if (start) begin
                    // Push root node to stack
                    current_node <= root_node;
                    current_depth <= 0;
                    child_idx <= 0;
                    next_state <= CALCULATE;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            CALCULATE: begin
                // Process current node
                if (is_dict_node && has_children) begin
                    // If we have more children to process
                    if (found_child) begin
                        // Push current node back to stack for remaining children
                        if (stack_ptr < 16) begin
                            stack_node[stack_ptr] <= current_node;
                            stack_depth[stack_ptr] <= current_depth;
                            stack_ptr <= stack_ptr + 1;
                            stack_size <= stack_size + 1;
                        end
                        
                        // Push child to process
                        current_node <= next_child;
                        current_depth <= current_depth + 1;
                        child_idx <= 0;
                        
                        // Update max depth
                        if (current_depth + 1 > max_depth) begin
                            max_depth <= current_depth + 1;
                        end
                        
                        next_state <= CALCULATE;
                    end else begin
                        // No more children for this node, pop from stack
                        if (stack_size > 0) begin
                            stack_ptr <= stack_ptr - 1;
                            stack_size <= stack_size - 1;
                            current_node <= stack_node[stack_ptr - 1];
                            current_depth <= stack_depth[stack_ptr - 1];
                            // Resume from next child index
                            child_idx <= stack_node[stack_ptr - 1] + 1;
                            next_state <= CALCULATE;
                        end else begin
                            // Done with this branch
                            next_state <= RETURN;
                        end
                    end
                end else begin
                    // Leaf node or non-dict node, pop from stack
                    if (stack_size > 0) begin
                        stack_ptr <= stack_ptr - 1;
                        stack_size <= stack_size - 1;
                        current_node <= stack_node[stack_ptr - 1];
                        current_depth <= stack_depth[stack_ptr - 1];
                        // Resume from next child
                        child_idx <= stack_node[stack_ptr - 1] + 1;
                        next_state <= CALCULATE;
                    end else begin
                        // No more nodes to process
                        next_state <= RETURN;
                    end
                end
            end
            
            RETURN: begin
                // Set final output
                depth <= max_depth;
                done <= 1;
                next_state <= DONE_STATE;
            end
            
            DONE_STATE: begin
                done <= 0;
                if (!start) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= DONE_STATE;
                end
            end
            
            default: begin
                next_state <= IDLE;
            end
        endcase
    end
end

endmodule