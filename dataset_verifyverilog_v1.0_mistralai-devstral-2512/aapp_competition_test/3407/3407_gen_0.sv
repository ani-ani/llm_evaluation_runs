module TreeEmbedding(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] edges_a [0:15],
    input wire [3:0] edges_b [0:15],
    output reg signed [15:0] x_coords [0:15],
    output reg signed [15:0] y_coords [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] TRAVERSE = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1024;

    // Tree data structures
    reg [3:0] adjacency_list [0:15][0:15];
    reg [3:0] subtree_size [0:15];
    reg [3:0] parent [0:15];
    reg [3:0] children [0:15][0:15];
    reg [3:0] num_children [0:15];

    // Traversal control
    reg [3:0] current_node;
    reg [3:0] child_index;
    reg [3:0] stack [0:15];
    reg [3:0] stack_ptr;

    // Angle computation
    reg signed [15:0] angle_ranges [0:15];
    reg signed [15:0] current_angle;
    reg signed [15:0] angle_step;

    // Fixed-point constants (Q8.8 format)
    localparam signed [15:0] PI = 16'd25736;  // 3.1415926535 * 256
    localparam signed [15:0] TWO_PI = 16'd51472;  // 6.283185307 * 256

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 10'd0;
            done <= 1'b0;
            current_node <= 4'd0;
            child_index <= 4'd0;
            stack_ptr <= 4'd0;
            current_angle <= 16'd0;
            angle_step <= 16'd0;
            
            // Initialize coordinates
            for (i = 0; i < 16; i = i + 1) begin
                x_coords[i] <= 16'd0;
                y_coords[i] <= 16'd0;
                parent[i] <= 4'd0;
                num_children[i] <= 4'd0;
                subtree_size[i] <= 4'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    adjacency_list[i][j] <= 4'd0;
                    children[i][j] <= 4'd0;
                end
            end
            
            // Initialize stack
            for (i = 0; i < 16; i = i + 1) begin
                stack[i] <= 4'd0;
            end
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= PARSE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PARSE: begin
                    // Build adjacency list
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = 0; j < n; j = j + 1) begin
                            adjacency_list[i][j] <= 4'd0;
                        end
                    end
                    
                    for (i = 0; i < n-1; i = i + 1) begin
                        adjacency_list[edges_a[i]][edges_b[i]] <= 1'b1;
                        adjacency_list[edges_b[i]][edges_a[i]] <= 1'b1;
                    end
                    
                    next_state <= TRAVERSE;
                end
                
                TRAVERSE: begin
                    // Compute subtree sizes and parent relationships
                    // Using iterative DFS
                    if (stack_ptr == 4'd0) begin
                        stack[0] <= 4'd0;  // Start with root
                        stack_ptr <= 4'd1;
                        parent[0] <= 4'd0;  // Root has no parent
                    end
                    
                    if (stack_ptr > 4'd0) begin
                        current_node <= stack[stack_ptr-1];
                        stack_ptr <= stack_ptr - 4'd1;
                        
                        // Find children
                        num_children[current_node] <= 4'd0;
                        for (i = 0; i < n; i = i + 1) begin
                            if (adjacency_list[current_node][i] && i != parent[current_node]) begin
                                children[current_node][num_children[current_node]] <= i;
                                parent[i] <= current_node;
                                num_children[current_node] <= num_children[current_node] + 4'd1;
                                
                                // Push to stack for DFS
                                stack[stack_ptr] <= i;
                                stack_ptr <= stack_ptr + 4'd1;
                            end
                        end
                        
                        // Compute subtree size
                        subtree_size[current_node] <= 4'd1;  // Count self
                        for (i = 0; i < num_children[current_node]; i = i + 1) begin
                            subtree_size[current_node] <= subtree_size[current_node] + subtree_size[children[current_node][i]];
                        end
                    end
                    
                    // Check if traversal complete
                    if (stack_ptr == 4'd0 && current_node == 4'd0) begin
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= TRAVERSE;
                    end
                end
                
                COMPUTE: begin
                    // Compute coordinates using DFS
                    if (stack_ptr == 4'd0) begin
                        stack[0] <= 4'd0;  // Start with root
                        stack_ptr <= 4'd1;
                        x_coords[0] <= 16'd0;  // Root at (0,0)
                        y_coords[0] <= 16'd0;
                    end
                    
                    if (stack_ptr > 4'd0) begin
                        current_node <= stack[stack_ptr-1];
                        stack_ptr <= stack_ptr - 4'd1;
                        
                        // Compute angle range for this node's children
                        if (num_children[current_node] > 4'd0) begin
                            angle_step <= TWO_PI / num_children[current_node];
                        end else begin
                            angle_step <= TWO_PI;
                        end
                        
                        // Process each child
                        if (child_index < num_children[current_node]) begin
                            reg [3:0] child;
                            child <= children[current_node][child_index];
                            
                            // Compute angle for this child
                            current_angle <= current_angle + angle_step;
                            
                            // Compute coordinates using fixed-point trigonometry
                            // Using Q8.8 format: cos(theta) ≈ theta in radians for small angles
                            // But we need proper approximation
                            reg signed [15:0] cos_val, sin_val;
                            
                            // Simple approximation for demonstration
                            // In real implementation, use LUT or better approximation
                            cos_val <= current_angle;  // Placeholder
                            sin_val <= current_angle;  // Placeholder
                            
                            // Update child coordinates
                            x_coords[child] <= x_coords[current_node] + cos_val;
                            y_coords[child] <= y_coords[current_node] + sin_val;
                            
                            // Push child to stack
                            stack[stack_ptr] <= child;
                            stack_ptr <= stack_ptr + 4'd1;
                            
                            child_index <= child_index + 4'd1;
                        end else begin
                            child_index <= 4'd0;
                        end
                    end
                    
                    // Check if computation complete
                    if (stack_ptr == 4'd0 && current_node == 4'd0) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for safety
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end else begin
                cycle_count <= cycle_count + 10'd1;
            end
        end
    end

endmodule