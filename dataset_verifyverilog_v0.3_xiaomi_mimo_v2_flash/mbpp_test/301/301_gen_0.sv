module dict_depth (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] node_children_0,
    input wire [7:0] node_children_1,
    input wire [7:0] node_children_2,
    input wire [7:0] node_children_3,
    input wire [7:0] node_children_4,
    input wire [7:0] node_children_5,
    input wire [7:0] node_children_6,
    input wire [7:0] node_children_7,
    input wire [7:0] node_is_dict,
    input wire [3:0] root_node,
    output reg [3:0] depth,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] PUSH_CHILD = 3'd1;
    localparam [2:0] POP_STACK  = 3'd2;
    localparam [2:0] RETURN     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Stack for iterative DFS (depth-first search)
    reg [3:0] stack_node [0:15];
    reg [3:0] stack_depth [0:15];
    reg [4:0] stack_ptr;
    reg [4:0] stack_size;

    // Current traversal state
    reg [3:0] current_node;
    reg [3:0] current_depth;
    reg [3:0] max_depth;

    // Child tracking
    reg [3:0] child_idx;
    reg [3:0] next_child;
    reg found_child;

    // Helper wires for children bits
    wire child_0, child_1, child_2, child_3, child_4, child_5, child_6, child_7;
    wire is_dict_node;

    assign child_0 = node_children_0[current_node];
    assign child_1 = node_children_1[current_node];
    assign child_2 = node_children_2[current_node];
    assign child_3 = node_children_3[current_node];
    assign child_4 = node_children_4[current_node];
    assign child_5 = node_children_5[current_node];
    assign child_6 = node_children_6[current_node];
    assign child_7 = node_children_7[current_node];

    assign is_dict_node = node_is_dict[current_node];

    // Combinational logic to find next child
    always @(*) begin
        found_child = 1'b0;
        next_child = 4'd0;

        if (child_idx < 8) begin
            case (child_idx)
                4'd0: if (child_0) begin found_child = 1'b1; next_child = 4'd0; end
                4'd1: if (child_1) begin found_child = 1'b1; next_child = 4'd1; end
                4'd2: if (child_2) begin found_child = 1'b1; next_child = 4'd2; end
                4'd3: if (child_3) begin found_child = 1'b1; next_child = 4'd3; end
                4'd4: if (child_4) begin found_child = 1'b1; next_child = 4'd4; end
                4'd5: if (child_5) begin found_child = 1'b1; next_child = 4'd5; end
                4'd6: if (child_6) begin found_child = 1'b1; next_child = 4'd6; end
                4'd7: if (child_7) begin found_child = 1'b1; next_child = 4'd7; end
                default: begin found_child = 1'b0; next_child = 4'd0; end
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
            done <= 1'b0;
            depth <= 4'd0;
            stack_ptr <= 5'd0;
            stack_size <= 5'd0;
            max_depth <= 4'd0;
            current_node <= 4'd0;
            current_depth <= 4'd0;
            child_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    depth <= 4'd0;
                    max_depth <= 4'd0;
                    stack_ptr <= 5'd0;
                    stack_size <= 5'd0;
                    child_idx <= 4'd0;
                    
                    if (start) begin
                        current_node <= root_node;
                        current_depth <= 4'd0;
                        next_state <= PUSH_CHILD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PUSH_CHILD: begin
                    if (is_dict_node && found_child) begin
                        // Push current node to stack if stack has space
                        if (stack_ptr < 16) begin
                            stack_node[stack_ptr] <= current_node;
                            stack_depth[stack_ptr] <= current_depth;
                            stack_ptr <= stack_ptr + 5'd1;
                            stack_size <= stack_size + 5'd1;
                        end

                        // Update max depth
                        if (current_depth + 4'd1 > max_depth) begin
                            max_depth <= current_depth + 4'd1;
                        end

                        // Move to child
                        current_node <= next_child;
                        current_depth <= current_depth + 4'd1;
                        child_idx <= 4'd0;
                        next_state <= PUSH_CHILD;
                    end else begin
                        // No valid child found for current node
                        // Move to POP_STACK to backtrack
                        next_state <= POP_STACK;
                    end
                end

                POP_STACK: begin
                    if (stack_size > 5'd0) begin
                        // Pop from stack
                        stack_ptr <= stack_ptr - 5'd1;
                        stack_size <= stack_size - 5'd1;
                        
                        // Get parent node from stack
                        current_node <= stack_node[stack_ptr - 5'd1];
                        current_depth <= stack_depth[stack_ptr - 5'd1];
                        
                        // Resume searching from next child index
                        child_idx <= stack_node[stack_ptr - 5'd1] + 4'd1;
                        
                        next_state <= PUSH_CHILD;
                    end else begin
                        // Stack empty, traversal complete
                        next_state <= RETURN;
                    end
                end

                RETURN: begin
                    depth <= max_depth;
                    done <= 1'b1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
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