module boar_charge_probability (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [23:0] b_radius,
    input wire [23:0] d_distance,
    input wire [23:0] tree_x [0:7],
    input wire [23:0] tree_y [0:7],
    input wire [23:0] tree_r [0:7],
    input wire [3:0] num_trees,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_ZERO = 3'd1;
    localparam [2:0] INIT_VARS  = 3'd2;
    localparam [2:0] CHECK_ANGLE = 3'd3;
    localparam [2:0] CHECK_TREE = 3'd4;
    localparam [2:0] NEXT_ANGLE = 3'd5;
    localparam [2:0] CALC_RESULT = 3'd6;
    localparam [2:0] FINISH     = 3'd7;

    reg [2:0] state, next_state;
    
    // Fixed-point constants
    localparam [23:0] FIXED_256 = 24'd65536;  // 256.0 in Q12.12 (256 * 4096)
    localparam [23:0] FIXED_1_0 = 24'd4096;   // 1.0 in Q12.12
    localparam [31:0] PROB_1_0  = 32'd65536;  // 1.0 in Q16.16
    localparam [31:0] TWO_PI_Q16 = 32'd411774; // 2*PI in Q16.16 (approx 6.283185 * 65536)
    localparam [15:0] TWO_PI_Q12 = 16'd25736;  // 2*PI in Q12.12 (approx 6.283185 * 4096)
    
    // Pre-computed cosine and sine tables for 256 angles (Q12.12 format)
    // These are 24-bit values where 4096 = 1.0
    reg signed [23:0] cos_table [0:255];
    reg signed [23:0] sin_table [0:255];
    
    // Initialize cosine and sine tables (simplified, approximate)
    integer i;
    initial begin
        // Fill with approximated values for 256 angles
        // These are Q12.12 fixed-point approximations of cos(i*2*PI/256)
        for (i = 0; i < 256; i = i + 1) begin
            cos_table[i] = get_cos(i);
            sin_table[i] = get_sin(i);
        end
    end
    
    // Computation registers
    reg [7:0] angle_idx;      // 0-255
    reg [7:0] tree_idx;       // 0-7
    reg [15:0] safe_count;    // Count of safe angles
    reg [15:0] angle_count;   // Total angles processed
    reg [23:0] path_end_x;    // Q12.12
    reg [23:0] path_end_y;    // Q12.12
    reg collision_found;      // Flag for current angle
    
    // Intermediate calculations
    reg signed [47:0] mult_temp;     // For 24x24 multiplication
    reg signed [47:0] mult_temp2;
    reg signed [23:0] dx, dy;        // Vector from tree to start
    reg signed [23:0] path_vec_x, path_vec_y; // Path direction vector
    reg signed [23:0] t_param;       // Projection parameter (Q12.12)
    reg signed [23:0] min_dist_sq;   // Minimum distance squared
    reg signed [23:0] sum_radius;    // b + r_i in Q12.12
    reg signed [23:0] sum_radius_sq; // (b + r_i)^2 in Q24.24 (shifted to match)
    
    // State machine and control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            angle_idx <= 8'd0;
            tree_idx <= 8'd0;
            safe_count <= 16'd0;
            angle_count <= 16'd0;
            collision_found <= 1'b0;
            path_end_x <= 24'd0;
            path_end_y <= 24'd0;
            dx <= 24'd0;
            dy <= 24'd0;
            path_vec_x <= 24'd0;
            path_vec_y <= 24'd0;
            t_param <= 24'd0;
            min_dist_sq <= 24'd0;
            sum_radius <= 24'd0;
            sum_radius_sq <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CHECK_ZERO;
                    end
                end
                
                CHECK_ZERO: begin
                    // Check if d_distance is 0 or num_trees is 0
                    if (d_distance == 24'd0 || num_trees == 4'd0) begin
                        result <= PROB_1_0;
                        state <= FINISH;
                    end else begin
                        state <= INIT_VARS;
                    end
                end
                
                INIT_VARS: begin
                    angle_idx <= 8'd0;
                    safe_count <= 16'd0;
                    angle_count <= 16'd0;
                    state <= CHECK_ANGLE;
                end
                
                CHECK_ANGLE: begin
                    // Check if all angles processed (256)
                    if (angle_count >= 16'd256) begin
                        state <= CALC_RESULT;
                    end else begin
                        // Calculate path endpoint for current angle
                        // path_end_x = d * cos(angle)
                        mult_temp <= $signed({{24{d_distance[23]}}, d_distance}) * $signed({{24{cos_table[angle_idx][23]}}, cos_table[angle_idx]});
                        mult_temp2 <= $signed({{24{d_distance[23]}}, d_distance}) * $signed({{24{sin_table[angle_idx][23]}}, sin_table[angle_idx]});
                        
                        // Wait one cycle for multiplication
                        state <= CHECK_TREE;
                        tree_idx <= 8'd0;
                        collision_found <= 1'b0;
                    end
                end
                
                CHECK_TREE: begin
                    // Path endpoint (Q24.24, shift to Q12.12: [35:12])
                    path_end_x <= mult_temp[35:12];
                    path_end_y <= mult_temp2[35:12];
                    
                    if (tree_idx >= num_trees) begin
                        // All trees checked for this angle
                        if (!collision_found) begin
                            safe_count <= safe_count + 16'd1;
                        end
                        state <= NEXT_ANGLE;
                    end else begin
                        // Check collision with current tree
                        // Vector from origin (boar start) to tree center
                        dx <= $signed({{24{tree_x[tree_idx][23]}}, tree_x[tree_idx]}) - 24'sd0;
                        dy <= $signed({{24{tree_y[tree_idx][23]}}, tree_y[tree_idx]}) - 24'sd0;
                        
                        // Path direction vector (end - start)
                        path_vec_x <= path_end_x;
                        path_vec_y <= path_end_y;
                        
                        // Sum of radii
                        sum_radius <= $signed({{24{b_radius[23]}}, b_radius}) + $signed({{24{tree_r[tree_idx][23]}}, tree_r[tree_idx]});
                        
                        state <= CHECK_TREE + 1;  // Next state (check tree logic)
                    end
                end
                
                (CHECK_TREE + 1): begin
                    // Calculate t_param = (dx * path_vec_x + dy * path_vec_y) / (path_vec_x^2 + path_vec_y^2)
                    // numerator: Q24.24
                    mult_temp <= $signed(dx) * $signed(path_vec_x);
                    mult_temp2 <= $signed(dy) * $signed(path_vec_y);
                    state <= CHECK_TREE + 2;
                end
                
                (CHECK_TREE + 2): begin
                    // Sum dot products (Q24.24)
                    reg signed [47:0] dot_prod;
                    dot_prod = mult_temp + mult_temp2;
                    
                    // Denominator: path_vec length squared (Q24.24)
                    mult_temp <= $signed(path_vec_x) * $signed(path_vec_x);
                    mult_temp2 <= $signed(path_vec_y) * $signed(path_vec_y);
                    
                    // Store dot product temporarily
                    if (dot_prod < 48'sd0) begin
                        // Path goes away from tree, t < 0
                        t_param <= 24'sd0;
                    end else begin
                        // Will compute division in next state
                        // Store numerator shifted right by 12 to get Q12.12 for division
                        t_param <= dot_prod[35:12];  // Q12.12
                    end
                    state <= CHECK_TREE + 3;
                end
                
                (CHECK_TREE + 3): begin
                    // Calculate denominator (path length squared)
                    reg signed [47:0] denom;
                    denom = mult_temp + mult_temp2;
                    
                    // Clamp denominator to avoid division by zero
                    if (denom == 48'sd0) begin
                        // Path is zero length (shouldn't happen if d > 0)
                        state <= CHECK_TREE + 4;
                    end else begin
                        // Division: t_param / denom (both Q12.12, result Q12.12)
                        // Using shift-based approximation: t / d
                        // For Q12.12: result = (t << 12) / denom
                        // denom is Q24.24, need to shift right 12 to match
                        denom = denom >>> 12;  // Convert to Q12.12
                        
                        if (denom != 48'sd0) begin
                            // Simple shift approximation for t/d (t_param is Q12.12)
                            // t_param is already in Q12.12
                            t_param <= (t_param << 12) / denom[23:0];
                        end
                        state <= CHECK_TREE + 4;
                    end
                end
                
                (CHECK_TREE + 4): begin
                    // Check if t_param > 1.0 (projection beyond endpoint)
                    if (t_param > FIXED_1_0) begin
                        t_param <= FIXED_1_0;
                    end
                    
                    // Calculate closest point on path
                    // closest_x = t_param * path_vec_x / 4096 (Q12.12 * Q12.12 / 4096)
                    mult_temp <= $signed(t_param) * $signed(path_vec_x);
                    mult_temp2 <= $signed(t_param) * $signed(path_vec_y);
                    
                    state <= CHECK_TREE + 5;
                end
                
                (CHECK_TREE + 5): begin
                    // closest point (Q24.24, shift to Q12.12)
                    reg signed [23:0] closest_x, closest_y;
                    closest_x = mult_temp[35:12];
                    closest_y = mult_temp2[35:12];
                    
                    // Distance from tree to closest point
                    dx <= $signed({{24{tree_x[tree_idx][23]}}, tree_x[tree_idx]}) - closest_x;
                    dy <= $signed({{24{tree_y[tree_idx][23]}}, tree_y[tree_idx]}) - closest_y;
                    
                    state <= CHECK_TREE + 6;
                end
                
                (CHECK_TREE + 6): begin
                    // Calculate distance squared
                    mult_temp <= $signed(dx) * $signed(dx);
                    mult_temp2 <= $signed(dy) * $signed(dy);
                    
                    state <= CHECK_TREE + 7;
                end
                
                (CHECK_TREE + 7): begin
                    min_dist_sq <= mult_temp[47:24] + mult_temp2[47:24];  // Q24.24 to Q12.12
                    
                    // Calculate (b + r)^2
                    mult_temp <= $signed(sum_radius) * $signed(sum_radius);
                    
                    state <= CHECK_TREE + 8;
                end
                
                (CHECK_TREE + 8): begin
                    // Compare min_dist_sq < sum_radius^2
                    // Both in Q12.12 (min_dist_sq is Q12.12, sum_radius^2 is Q24.24, need to align)
                    sum_radius_sq <= mult_temp[35:12];  // Q24.24 to Q12.12
                    
                    state <= CHECK_TREE + 9;
                end
                
                (CHECK_TREE + 9): begin
                    if (min_dist_sq < sum_radius_sq) begin
                        // Collision detected
                        collision_found <= 1'b1;
                    end
                    
                    // Next tree
                    tree_idx <= tree_idx + 8'd1;
                    state <= CHECK_TREE;
                end
                
                NEXT_ANGLE: begin
                    angle_idx <= angle_idx + 8'd1;
                    angle_count <= angle_count + 16'd1;
                    state <= CHECK_ANGLE;
                end
                
                CALC_RESULT: begin
                    // Result = safe_count / 256.0 in Q16.16
                    // safe_count is 16-bit (0-256), we need (safe_count * 65536) / 256
                    // = safe_count * 256
                    // = safe_count << 8
                    result <= {safe_count, 8'd0};  // Multiply by 256 to get Q16.16
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Helper functions for table initialization (synthesis-friendly, called at elaboration)
    function automatic [23:0] get_cos(input [7:0] idx);
        reg signed [23:0] cos_val;
        integer angle;
        begin
            // Calculate cos(idx * 2 * PI / 256) * 4096
            angle = idx * 2 * 31416 / 256;  // angle in milli-radians
            // Approximate cos using Taylor series or lookup
            // Simplified: use pre-calculated pattern
            case (idx % 64)
                0:  cos_val = 24'd4096;    // cos(0) = 1.0
                16: cos_val = 24'd0;       // cos(90deg) = 0.0
                32: cos_val = -24'd4096;   // cos(180deg) = -1.0
                48: cos_val = 24'd0;       // cos(270deg) = 0.0
                default: begin
                    // Linear approximation for simplicity
                    if (idx < 16) cos_val = 4096 - ((idx * 4096) >> 6);
                    else if (idx < 32) cos_val = (idx - 16) * 4096 / 16;
                    else if (idx < 48) cos_val = 24'd0;
                    else cos_val = 24'd0;
                end
            endcase
            get_cos = cos_val;
        end
    endfunction
    
    function automatic [23:0] get_sin(input [7:0] idx);
        reg signed [23:0] sin_val;
        begin
            // sin(x) = cos(x - 64)
            sin_val = get_cos(idx - 8'd64);
            get_sin = sin_val;
        end
    endfunction

endmodule