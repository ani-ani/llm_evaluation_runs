module cube_reconstructor (
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg valid,
    output reg [239:0] result,  // 8 vertices * 3 coordinates * 32 bits
    output reg done
);

// Permutations for coordinate indices: 6 possible orders for (x, y, z)
localparam [2:0] PERMUTATIONS [0:5][0:2] = '{
    '{3'd0, 3'd1, 3'd2},  // (x, y, z)
    '{3'd0, 3'd2, 3'd1},  // (x, z, y)
    '{3'd1, 3'd0, 3'd2},  // (y, x, z)
    '{3'd1, 3'd2, 3'd0},  // (y, z, x)
    '{3'd2, 3'd0, 3'd1},  // (z, x, y)
    '{3'd2, 3'd1, 3'd0}   // (z, y, x)
};

// State definitions
localparam [3:0] IDLE       = 4'd0;
localparam [3:0] LOAD_INPUT = 4'd1;
localparam [3:0] SEARCH     = 4'd2;
localparam [3:0] VALIDATE   = 4'd3;
localparam [3:0] OUTPUT     = 4'd4;
localparam [3:0] NO_RESULT  = 4'd5;

// Input storage (8 vertices, 3 coordinates each)
reg signed [31:0] input_verts [0:7][0:2];
reg signed [31:0] permuted_verts [0:7][0:2];

// Current permutation indices for each vertex
reg [2:0] current_perm_idx [0:7];

// State machine
reg [3:0] state, next_state;

// Permutation index counters
reg [2:0] perm_counters [0:7];

// Cycle counter for timeout
reg [13:0] cycle_count;  // 14 bits = max 16383 cycles
localparam [13:0] MAX_CYCLES = 14'd10000;

// Distance calculation signals
reg signed [31:0] dist_x, dist_y, dist_z;
reg signed [63:0] dist_x_sq, dist_y_sq, dist_z_sq;
reg signed [63:0] squared_distance;

// Cube validation
reg [5:0] edge_count;      // Should be 12
reg [5:0] face_diag_count; // Should be 12  
reg [5:0] space_diag_count; // Should be 4
reg signed [63:0] side_sq;   // Side squared (S)
reg signed [63:0] face_sq;   // Face diagonal squared (2S)
reg signed [63:0] space_sq;  // Space diagonal squared (3S)
reg signed [63:0] min_dist;  // Track smallest distance for S

// Pair counter for validation
reg [4:0] pair_counter;  // 0 to 27 (28 pairs total)
reg [2:0] vert_i, vert_j;  // Vertex indices

// Comparison helper
reg signed [63:0] current_dist;
reg [1:0] distance_type;  // 0=invalid, 1=edge, 2=face, 3=space

// Permutation iteration
reg [3:0] vertex_counter;  // 0 to 7 for vertex selection
reg [2:0] perm_counter;    // 0 to 5 for permutation selection

// Output buffer
reg [239:0] result_buffer;
reg valid_buffer;

// Integer indices for loops
integer i, j, k;

// Sequential logic: State machine and registers
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        result <= 240'd0;
        cycle_count <= 14'd0;
        
        // Reset input storage
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) begin
                input_verts[i][j] <= 32'sd0;
                permuted_verts[i][j] <= 32'sd0;
            end
            perm_counters[i] <= 3'd0;
        end
        
        // Reset permutation iteration
        vertex_counter <= 4'd0;
        perm_counter <= 3'd0;
        
        // Reset validation
        pair_counter <= 5'd0;
        vert_i <= 3'd0;
        vert_j <= 3'd0;
        edge_count <= 6'd0;
        face_diag_count <= 6'd0;
        space_diag_count <= 6'd0;
        side_sq <= 64'sd0;
        face_sq <= 64'sd0;
        space_sq <= 64'sd0;
        min_dist <= 64'sd0;
        
        result_buffer <= 240'd0;
        valid_buffer <= 1'b0;
        
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                cycle_count <= 14'd0;
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    // Prepare for search
                    for (i = 0; i < 8; i = i + 1) begin
                        perm_counters[i] <= 3'd0;
                    end
                    vertex_counter <= 4'd0;
                    perm_counter <= 3'd0;
                end
            end
            
            LOAD_INPUT: begin
                // Store input vertices (passed as 240-bit result in previous cycle)
                // In a real scenario, we'd have separate input ports
                // Here we assume inputs are in result register during start
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 3; j = j + 1) begin
                        input_verts[i][j] <= result[(i*96) + (j*32) +: 32];
                    end
                end
                // Initialize first permutation
                for (i = 0; i < 8; i = i + 1) begin
                    permuted_verts[i][0] <= result[(i*96) + 0 +: 32];
                    permuted_verts[i][1] <= result[(i*96) + 32 +: 32];
                    permuted_verts[i][2] <= result[(i*96) + 64 +: 32];
                end
            end
            
            SEARCH: begin
                cycle_count <= cycle_count + 14'd1;
                
                // Generate next permutation combination
                // This is a simplified approach: iterate through all 6^8 combinations
                // We track which vertex we're modifying
                if (perm_counter < 6'd6) begin
                    // Apply current permutation to vertex_counter
                    for (k = 0; k < 3; k = k + 1) begin
                        permuted_verts[vertex_counter][k] <= 
                            input_verts[vertex_counter][PERMUTATIONS[perm_counter][k]];
                    end
                    perm_counter <= perm_counter + 3'd1;
                    if (perm_counter == 3'd5) begin
                        perm_counter <= 3'd0;
                        vertex_counter <= vertex_counter + 4'd1;
                    end
                end
            end
            
            VALIDATE: begin
                // Compute distances for current pair
                if (pair_counter < 5'd28) begin
                    // Get vertices
                    dist_x <= permuted_verts[vert_i][0] - permuted_verts[vert_j][0];
                    dist_y <= permuted_verts[vert_i][1] - permuted_verts[vert_j][1];
                    dist_z <= permuted_verts[vert_i][2] - permuted_verts[vert_j][2];
                    
                    // After compute cycle, calculate squares
                    dist_x_sq <= (dist_x * dist_x);
                    dist_y_sq <= (dist_y * dist_y);
                    dist_z_sq <= (dist_z * dist_z);
                    
                    squared_distance <= dist_x_sq + dist_y_sq + dist_z_sq;
                    
                    // Classify distance
                    if (squared_distance == 64'sd0) begin
                        distance_type <= 2'd0;  // Same vertex
                    end else begin
                        // Check cube pattern
                        if (edge_count < 6'd12 && squared_distance == min_dist && min_dist != 64'sd0) begin
                            edge_count <= edge_count + 6'd1;
                            distance_type <= 2'd1;
                        end else if (face_diag_count < 6'd12 && squared_distance == (min_dist << 1)) begin
                            face_diag_count <= face_diag_count + 6'd1;
                            distance_type <= 2'd2;
                        end else if (space_diag_count < 6'd4 && squared_distance == (min_dist + (min_dist << 1))) begin
                            space_diag_count <= space_diag_count + 6'd1;
                            distance_type <= 2'd3;
                        end else if (min_dist == 64'sd0 && squared_distance != 64'sd0) begin
                            // First non-zero distance = side squared
                            min_dist <= squared_distance;
                            edge_count <= 6'd1;
                            distance_type <= 2'd1;
                        end else begin
                            distance_type <= 2'd0;  // Invalid
                        end
                    end
                    
                    // Increment pair counter
                    pair_counter <= pair_counter + 5'd1;
                    
                    // Update vertex indices
                    if (vert_j < 3'd7) begin
                        vert_j <= vert_j + 3'd1;
                    end else begin
                        vert_i <= vert_i + 3'd1;
                        vert_j <= vert_i + 3'd1;
                    end
                end
            end
            
            OUTPUT: begin
                // Build result output
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 3; j = j + 1) begin
                        result[(i*96) + (j*32) +: 32] <= permuted_verts[i][j];
                    end
                end
                valid <= 1'b1;
                done <= 1'b1;
            end
            
            NO_RESULT: begin
                // No valid cube found
                result <= 240'd0;  // All zeros as per reset
                valid <= 1'b0;
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            end
        endcase
    end
end

// Combinational next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) begin
                next_state = LOAD_INPUT;
            end else begin
                next_state = IDLE;
            end
        end
        
        LOAD_INPUT: begin
            next_state = SEARCH;
        end
        
        SEARCH: begin
            // Check if we've processed all 8 vertices
            // Simplified: after some cycles, go to validation
            if (vertex_counter >= 4'd8 || cycle_count >= MAX_CYCLES) begin
                next_state = VALIDATE;
            end else begin
                next_state = SEARCH;
            end
        end
        
        VALIDATE: begin
            if (pair_counter >= 5'd28) begin
                // Check if cube pattern is satisfied
                if (edge_count == 6'd12 && face_diag_count == 6'd12 && space_diag_count == 6'd4) begin
                    next_state = OUTPUT;
                end else begin
                    // Try next permutation or give up
                    if (cycle_count < MAX_CYCLES) begin
                        // Reset for next search
                        next_state = SEARCH;
                        // Need to increment permutation counters
                    end else begin
                        next_state = NO_RESULT;
                    end
                end
            end else begin
                next_state = VALIDATE;
            end
        end
        
        OUTPUT: begin
            next_state = IDLE;
        end
        
        NO_RESULT: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule