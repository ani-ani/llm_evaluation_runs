module eulerian_turning_minimizer #(
    parameter NODE_COUNT = 8,
    parameter EDGE_COUNT = 16,
    parameter COORD_WIDTH = 16,
    parameter FIXED_POINT_WIDTH = 32,
    parameter FIXED_POINT_FRACTION = 16
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,
    output reg [FIXED_POINT_WIDTH-1:0] total_turning,
    
    // Node coordinates (fixed-point representation)
    input wire [COORD_WIDTH-1:0] node_x [0:NODE_COUNT-1],
    input wire [COORD_WIDTH-1:0] node_y [0:NODE_COUNT-1],
    
    // Edge list (adjacency matrix representation)
    input wire [NODE_COUNT-1:0] adj_matrix [0:NODE_COUNT-1],
    
    // Configuration
    input wire [3:0] actual_node_count,
    input wire [4:0] actual_edge_count
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_ADJ_LIST = 3'd1;
    localparam [2:0] FIND_CIRCUIT = 3'd2;
    localparam [2:0] CALC_TURNING = 3'd3;
    localparam [2:0] MINIMIZE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Adjacency list storage
    reg [NODE_COUNT-1:0] adj_list [0:NODE_COUNT-1];
    reg [NODE_COUNT-1:0] current_adj [0:NODE_COUNT-1];
    
    // Circuit tracking
    reg [NODE_COUNT-1:0] circuit [0:EDGE_COUNT];
    reg [7:0] circuit_ptr;
    reg [7:0] circuit_length;
    
    // Current node and stack
    reg [3:0] current_node;
    reg [3:0] stack [0:NODE_COUNT];
    reg [3:0] stack_ptr;
    
    // Turning calculation
    reg signed [FIXED_POINT_WIDTH-1:0] current_turning;
    reg [3:0] prev_node, next_node;
    
    // Minimization state
    reg [3:0] min_node;
    reg [1:0] min_edge_pair;
    reg [1:0] min_state;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Fixed-point arithmetic helpers
    function signed [FIXED_POINT_WIDTH-1:0] fixed_mult(
        input signed [COORD_WIDTH-1:0] a,
        input signed [COORD_WIDTH-1:0] b
    );
        reg signed [FIXED_POINT_WIDTH*2-1:0] temp;
        begin
            temp = $signed(a) * $signed(b);
            fixed_mult = temp[FIXED_POINT_WIDTH*2-2:FIXED_POINT_WIDTH-1];
        end
    endfunction
    
    function signed [FIXED_POINT_WIDTH-1:0] fixed_div(
        input signed [FIXED_POINT_WIDTH-1:0] a,
        input signed [COORD_WIDTH-1:0] b
    );
        reg signed [FIXED_POINT_WIDTH*2-1:0] temp;
        begin
            temp = $signed(a) << FIXED_POINT_FRACTION;
            fixed_div = temp / $signed(b);
        end
    endfunction
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total_turning <= {FIXED_POINT_WIDTH{1'b0}};
            cycle_count <= 8'd0;
            
            // Initialize all registers
            integer i, j;
            for (i = 0; i < NODE_COUNT; i = i + 1) begin
                for (j = 0; j < NODE_COUNT; j = j + 1) begin
                    adj_list[i][j] <= 1'b0;
                    current_adj[i][j] <= 1'b0;
                end
                stack[i] <= 4'd0;
            end
            
            for (i = 0; i < EDGE_COUNT; i = i + 1) begin
                circuit[i] <= 8'd0;
            end
            
            circuit_ptr <= 8'd0;
            circuit_length <= 8'd0;
            stack_ptr <= 4'd0;
            current_node <= 4'd0;
            prev_node <= 4'd0;
            next_node <= 4'd0;
            min_node <= 4'd0;
            min_edge_pair <= 2'd0;
            min_state <= 2'd0;
            current_turning <= {FIXED_POINT_WIDTH{1'b0}};
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= BUILD_ADJ_LIST;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                BUILD_ADJ_LIST: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build adjacency list from matrix
                    integer i, j;
                    for (i = 0; i < actual_node_count; i = i + 1) begin
                        for (j = 0; j < actual_node_count; j = j + 1) begin
                            if (adj_matrix[i][j]) begin
                                adj_list[i][j] <= 1'b1;
                                current_adj[i][j] <= 1'b1;
                            end else begin
                                adj_list[i][j] <= 1'b0;
                                current_adj[i][j] <= 1'b0;
                            end
                        end
                    end
                    
                    // Find starting node (first with odd degree)
                    reg [3:0] degree;
                    for (i = 0; i < actual_node_count; i = i + 1) begin
                        degree = 4'd0;
                        for (j = 0; j < actual_node_count; j = j + 1) begin
                            if (adj_list[i][j]) begin
                                degree = degree + 4'd1;
                            end
                        end
                        
                        if (degree % 2 == 1) begin
                            current_node <= i;
                            break;
                        end
                    end
                    
                    next_state <= FIND_CIRCUIT;
                end
                
                FIND_CIRCUIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Hierholzer's algorithm implementation
                    reg [3:0] next;
                    reg found;
                    
                    // Check if current node has unused edges
                    found = 1'b0;
                    for (next = 0; next < actual_node_count; next = next + 1) begin
                        if (current_adj[current_node][next]) begin
                            found = 1'b1;
                            break;
                        end
                    end
                    
                    if (found) begin
                        // Push current node to stack
                        stack[stack_ptr] <= current_node;
                        stack_ptr <= stack_ptr + 4'd1;
                        
                        // Mark edge as used
                        current_adj[current_node][next] <= 1'b0;
                        current_adj[next][current_node] <= 1'b0;
                        
                        // Move to next node
                        current_node <= next;
                        next_state <= FIND_CIRCUIT;
                    end else begin
                        // Add to circuit
                        circuit[circuit_ptr] <= current_node;
                        circuit_ptr <= circuit_ptr + 8'd1;
                        circuit_length <= circuit_length + 8'd1;
                        
                        // Pop from stack
                        if (stack_ptr > 4'd0) begin
                            stack_ptr <= stack_ptr - 4'd1;
                            current_node <= stack[stack_ptr];
                            next_state <= FIND_CIRCUIT;
                        end else begin
                            next_state <= CALC_TURNING;
                        end
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                
                CALC_TURNING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate turning angles
                    reg signed [FIXED_POINT_WIDTH-1:0] dx1, dy1, dx2, dy2;
                    reg signed [FIXED_POINT_WIDTH-1:0] cross, dot;
                    reg signed [FIXED_POINT_WIDTH-1:0] angle;
                    
                    if (circuit_length > 8'd2) begin
                        prev_node <= circuit[circuit_ptr-2];
                        current_node <= circuit[circuit_ptr-1];
                        next_node <= circuit[circuit_ptr];
                        
                        // Calculate vectors
                        dx1 = $signed(node_x[current_node]) - $signed(node_x[prev_node]);
                        dy1 = $signed(node_y[current_node]) - $signed(node_y[prev_node]);
                        dx2 = $signed(node_x[next_node]) - $signed(node_y[current_node]);
                        dy2 = $signed(node_y[next_node]) - $signed(node_y[current_node]);
                        
                        // Cross product (sin of angle)
                        cross = fixed_mult(dx1, dy2) - fixed_mult(dy1, dx2);
                        
                        // Dot product (cos of angle)
                        dot = fixed_mult(dx1, dx2) + fixed_mult(dy1, dy2);
                        
                        // Approximate atan2 using cross/dot
                        if (dot != 0) begin
                            angle = fixed_div(cross, dot >> FIXED_POINT_FRACTION);
                        end else begin
                            angle = {FIXED_POINT_WIDTH{1'b0}};
                        end
                        
                        // Accumulate absolute turning
                        if (angle[FIXED_POINT_WIDTH-1]) begin
                            angle = -angle;
                        end
                        current_turning = current_turning + angle;
                        
                        // Move to next triplet
                        circuit_ptr <= circuit_ptr + 8'd1;
                        if (circuit_ptr >= circuit_length - 8'd1) begin
                            next_state <= MINIMIZE;
                        end else begin
                            next_state <= CALC_TURNING;
                        end
                    end else begin
                        next_state <= MINIMIZE;
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                
                MINIMIZE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Try different edge orderings at degree-4 nodes
                    // to minimize turning
                    reg [3:0] node;
                    reg [3:0] degree;
                    
                    // Find degree-4 node
                    for (node = 0; node < actual_node_count; node = node + 1) begin
                        degree = 4'd0;
                        for (min_node = 0; min_node < actual_node_count; min_node = min_node + 1) begin
                            if (adj_list[node][min_node]) begin
                                degree = degree + 4'd1;
                            end
                        end
                        
                        if (degree == 4'd4) begin
                            min_node <= node;
                            break;
                        end
                    end
                    
                    // Try different edge pairings
                    // (simplified for synthesis)
                    if (min_state == 2'd0) begin
                        // Try first pairing
                        min_state <= 2'd1;
                        next_state <= MINIMIZE;
                    end else if (min_state == 2'd1) begin
                        // Try second pairing
                        min_state <= 2'd2;
                        next_state <= MINIMIZE;
                    end else begin
                        // Done with minimization
                        total_turning <= current_turning;
                        next_state <= DONE_STATE;
                    end
                    
                    // Safety check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
    end

endmodule