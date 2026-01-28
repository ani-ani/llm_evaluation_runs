module EmbedTree(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] edges_a [0:15],
    input wire [15:0] edges_b [0:15],
    output reg [15:0] x_coords [0:15],
    output reg [15:0] y_coords [0:15],
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT_PARSE   = 4'd1;
    localparam [3:0] PARSE_EDGES  = 4'd2;
    localparam [3:0] INIT_TRAVERSE = 4'd3;
    localparam [3:0] CALC_ANGLE   = 4'd4;
    localparam [3:0] CALC_COORDS  = 4'd5;
    localparam [3:0] UPDATE_STATE = 4'd6;
    localparam [3:0] FINISH       = 4'd7;

    reg [3:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Adjacency list storage (packed for Icarus compatibility)
    reg [63:0] adj_list [0:15];  // Each node: 16 neighbors * 4 bits
    reg [3:0] adj_index [0:15];  // Current neighbor count
    
    // Subtree size storage
    reg [3:0] subtree_size [0:15];
    
    // Computation registers
    reg [3:0] current_node;
    reg [3:0] child_idx;
    reg [15:0] current_angle;
    reg [15:0] angle_range;
    
    // Fixed-point constants
    localparam [15:0] PI = 16'sd51414;  // 3.14159 * 256 in Q8.8
    localparam [15:0] TWO_PI = 16'sd102827;  // 2*PI
    localparam [15:0] ONE = 16'sd256;  // 1.0 in Q8.8
    
    // Math registers for angle calculation
    reg [15:0] atan2_y, atan2_x;
    reg [15:0] atan2_result;
    reg [15:0] angle_scaled;
    reg [15:0] cos_val, sin_val;
    reg [15:0] offset_x, offset_y;
    
    // Traversal stack (FIFO-like)
    reg [3:0] node_stack [0:15];
    reg [3:0] stack_ptr;
    reg [3:0] processed_count;
    
    // Helper signals
    reg [3:0] node_size;
    reg [3:0] i, j;
    
    // Synchronous state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
            done <= 1'b0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                adj_list[i] <= 64'd0;
                adj_index[i] <= 4'd0;
                subtree_size[i] <= 4'd0;
                x_coords[i] <= 16'd0;
                y_coords[i] <= 16'd0;
                node_stack[i] <= 4'd0;
            end
            
            current_node <= 4'd0;
            child_idx <= 4'd0;
            current_angle <= 16'd0;
            angle_range <= 16'd0;
            stack_ptr <= 4'd0;
            processed_count <= 4'd0;
            atan2_y <= 16'd0;
            atan2_x <= 16'd0;
            atan2_result <= 16'd0;
            angle_scaled <= 16'd0;
            cos_val <= 16'd0;
            sin_val <= 16'd0;
            offset_x <= 16'd0;
            offset_y <= 16'd0;
            node_size <= 4'd0;
        end else begin
            state <= next_state;
            
            if (state != IDLE) begin
                cycle_count <= cycle_count + 4'd1;
            end
            
            if (state == IDLE && start) begin
                cycle_count <= 4'd0;
                done <= 1'b0;
                processed_count <= 4'd0;
                stack_ptr <= 4'd0;
            end
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_PARSE;
                end
            end
            
            INIT_PARSE: begin
                next_state = PARSE_EDGES;
            end
            
            PARSE_EDGES: begin
                if (processed_count >= n || cycle_count >= 4'd15) begin
                    next_state = INIT_TRAVERSE;
                end else begin
                    next_state = PARSE_EDGES;
                end
            end
            
            INIT_TRAVERSE: begin
                next_state = CALC_ANGLE;
            end
            
            CALC_ANGLE: begin
                next_state = CALC_COORDS;
            end
            
            CALC_COORDS: begin
                next_state = UPDATE_STATE;
            end
            
            UPDATE_STATE: begin
                if (processed_count >= n || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC_ANGLE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Combinational logic for calculations
    always @(*) begin
        // Initialize defaults
        atan2_y = 16'd0;
        atan2_x = 16'd0;
        atan2_result = 16'd0;
        angle_scaled = 16'd0;
        cos_val = 16'd0;
        sin_val = 16'd0;
        offset_x = 16'd0;
        offset_y = 16'd0;
        node_size = 4'd0;
        
        // Process current node's size from adjacency
        node_size = adj_index[current_node];
        
        // Angle calculation (approximation)
        if (node_size > 4'd0) begin
            // current_angle + (angle_range * i / node_size)
            angle_scaled = (angle_range * child_idx) / node_size;
            atan2_result = current_angle + angle_scaled;
            
            // Normalize to [0, 2*PI)
            if (atan2_result >= TWO_PI) begin
                atan2_result = atan2_result - TWO_PI;
            end
        end else begin
            atan2_result = current_angle;
        end
        
        // Trigonometric approximations (Q8.8)
        case (atan2_result)
            // 0 degrees
            16'd0: begin
                cos_val = 16'sd256;
                sin_val = 16'd0;
            end
            // 30 degrees (PI/6)
            16'sd8577: begin
                cos_val = 16'sd221;
                sin_val = 16'sd128;
            end
            // 45 degrees (PI/4)
            16'sd12866: begin
                cos_val = 16'sd181;
                sin_val = 16'sd181;
            end
            // 60 degrees (PI/3)
            16'sd17155: begin
                cos_val = 16'sd128;
                sin_val = 16'sd221;
            end
            // 90 degrees (PI/2)
            16'sd25707: begin
                cos_val = 16'd0;
                sin_val = 16'sd256;
            end
            // 120 degrees (2*PI/3)
            16'sd34283: begin
                cos_val = -16'sd128;
                sin_val = 16'sd221;
            end
            // 135 degrees (3*PI/4)
            16'sd38572: begin
                cos_val = -16'sd181;
                sin_val = 16'sd181;
            end
            // 150 degrees (5*PI/6)
            16'sd42861: begin
                cos_val = -16'sd221;
                sin_val = 16'sd128;
            end
            // 180 degrees (PI)
            16'sd51414: begin
                cos_val = -16'sd256;
                sin_val = 16'd0;
            end
            // 210 degrees (7*PI/6)
            16'sd59990: begin
                cos_val = -16'sd221;
                sin_val = -16'sd128;
            end
            // 225 degrees (5*PI/4)
            16'sd64279: begin
                cos_val = -16'sd181;
                sin_val = -16'sd181;
            end
            // 240 degrees (4*PI/3)
            16'sd68568: begin
                cos_val = -16'sd128;
                sin_val = -16'sd221;
            end
            // 270 degrees (3*PI/2)
            16'sd77120: begin
                cos_val = 16'd0;
                sin_val = -16'sd256;
            end
            // 300 degrees (5*PI/3)
            16'sd85696: begin
                cos_val = 16'sd128;
                sin_val = -16'sd221;
            end
            // 315 degrees (7*PI/4)
            16'sd89985: begin
                cos_val = 16'sd181;
                sin_val = -16'sd181;
            end
            // 330 degrees (11*PI/6)
            16'sd94274: begin
                cos_val = 16'sd221;
                sin_val = -16'sd128;
            end
            default: begin
                // Approximate for other angles
                if (atan2_result < 16'sd8577) begin
                    cos_val = 16'sd240;
                    sin_val = atan2_result / 67;
                end else if (atan2_result < 16'sd17155) begin
                    cos_val = 16'sd221;
                    sin_val = 16'sd128;
                end else if (atan2_result < 16'sd25707) begin
                    cos_val = 16'sd128;
                    sin_val = 16'sd221;
                end else if (atan2_result < 16'sd34283) begin
                    cos_val = 16'sd0;
                    sin_val = 16'sd256;
                end else if (atan2_result < 16'sd42861) begin
                    cos_val = -16'sd128;
                    sin_val = 16'sd221;
                end else if (atan2_result < 16'sd51414) begin
                    cos_val = -16'sd221;
                    sin_val = 16'sd128;
                end else if (atan2_result < 16'sd59990) begin
                    cos_val = -16'sd256;
                    sin_val = 16'd0;
                end else if (atan2_result < 16'sd68568) begin
                    cos_val = -16'sd221;
                    sin_val = -16'sd128;
                end else if (atan2_result < 16'sd77120) begin
                    cos_val = -16'sd128;
                    sin_val = -16'sd221;
                end else if (atan2_result < 16'sd85696) begin
                    cos_val = 16'd0;
                    sin_val = -16'sd256;
                end else if (atan2_result < 16'sd94274) begin
                    cos_val = 16'sd128;
                    sin_val = -16'sd221;
                end else begin
                    cos_val = 16'sd221;
                    sin_val = -16'sd128;
                end
            end
        endcase
        
        offset_x = cos_val;
        offset_y = sin_val;
    end

    // Sequential operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in always block above
        end else begin
            case (state)
                INIT_PARSE: begin
                    processed_count <= 4'd0;
                end
                
                PARSE_EDGES: begin
                    if (processed_count < n && processed_count < 4'd16) begin
                        // Add edge to adjacency lists
                        for (j = 0; j < 16; j = j + 1) begin
                            if (j == processed_count) begin
                                if (edges_a[j] < 4'd16) begin
                                    if (adj_index[edges_a[j]] < 4'd16) begin
                                        adj_list[edges_a[j]] <= adj_list[edges_a[j]] | (edges_b[j] << (adj_index[edges_a[j]] * 4));
                                        adj_index[edges_a[j]] <= adj_index[edges_a[j]] + 4'd1;
                                    end
                                end
                                if (edges_b[j] < 4'd16) begin
                                    if (adj_index[edges_b[j]] < 4'd16) begin
                                        adj_list[edges_b[j]] <= adj_list[edges_b[j]] | (edges_a[j] << (adj_index[edges_b[j]] * 4));
                                        adj_index[edges_b[j]] <= adj_index[edges_b[j]] + 4'd1;
                                    end
                                end
                            end
                        end
                        processed_count <= processed_count + 4'd1;
                    end
                end
                
                INIT_TRAVERSE: begin
                    // Set root coordinates
                    x_coords[0] <= 16'd0;
                    y_coords[0] <= 16'd0;
                    processed_count <= 4'd1;
                    current_node <= 4'd0;
                    child_idx <= 4'd0;
                    current_angle <= 16'd0;
                    angle_range <= PI;
                    stack_ptr <= 4'd0;
                    
                    // Initialize subtree sizes
                    for (i = 0; i < 16; i = i + 1) begin
                        subtree_size[i] <= 4'd0;
                    end
                end
                
                CALC_ANGLE: begin
                    if (processed_count < n && processed_count < 4'd16) begin
                        // Get child node
                        node_size <= adj_index[current_node];
                    end
                end
                
                CALC_COORDS: begin
                    if (child_idx < node_size && node_size > 4'd0) begin
                        // Calculate coordinates for child
                        x_coords[ ((adj_list[current_node] >> (child_idx * 4)) & 4'hF) ] <= x_coords[current_node] + offset_x;
                        y_coords[ ((adj_list[current_node] >> (child_idx * 4)) & 4'hF) ] <= y_coords[current_node] + offset_y;
                    end
                end
                
                UPDATE_STATE: begin
                    if (child_idx < node_size && node_size > 4'd0) begin
                        // Update angle range for next child
                        current_angle <= current_angle + angle_range;
                        
                        // Update child index
                        child_idx <= child_idx + 4'd1;
                        
                        // Check if all children processed
                        if (child_idx + 4'd1 >= node_size) begin
                            // Move to next node in stack or root
                            processed_count <= processed_count + 4'd1;
                            if (stack_ptr > 4'd0) begin
                                current_node <= node_stack[stack_ptr - 4'd1];
                                stack_ptr <= stack_ptr - 4'd1;
                            end else begin
                                // Find next unprocessed node
                                current_node <= current_node + 4'd1;
                            end
                            child_idx <= 4'd0;
                            current_angle <= 16'd0;
                            angle_range <= PI;
                        end
                    end else begin
                        // No children or all children processed
                        if (node_size > 4'd0) begin
                            // Push to stack for later processing
                            if (stack_ptr < 4'd16) begin
                                node_stack[stack_ptr] <= current_node;
                                stack_ptr <= stack_ptr + 4'd1;
                            end
                        end
                        processed_count <= processed_count + 4'd1;
                        if (stack_ptr > 4'd0) begin
                            current_node <= node_stack[stack_ptr - 4'd1];
                            stack_ptr <= stack_ptr - 4'd1;
                        end else begin
                            current_node <= current_node + 4'd1;
                        end
                        child_idx <= 4'd0;
                        current_angle <= 16'd0;
                        angle_range <= PI;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule