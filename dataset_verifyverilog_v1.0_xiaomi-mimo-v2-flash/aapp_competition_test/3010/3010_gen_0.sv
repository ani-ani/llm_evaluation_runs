module line_intersection_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] seg_ptr,
    input wire [15:0] seg_x0,
    input wire [15:0] seg_y0,
    input wire [15:0] seg_x1,
    input wire [15:0] seg_y1,
    input wire seg_valid,
    output reg [15:0] result,
    output reg done,
    output reg busy
);

    // FSM States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] COUNT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // Segment storage (16 segments, each 4 coordinates)
    reg [15:0] x0_reg [0:15];
    reg [15:0] y0_reg [0:15];
    reg [15:0] x1_reg [0:15];
    reg [15:0] y1_reg [0:15];
    reg [3:0] seg_loaded;
    
    // Intersection point buffer (128 entries, 32-bit packed: x[15:0], y[15:0])
    reg [31:0] point_buf [0:127];
    reg [6:0] point_count;
    
    // Control registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;  // First segment index
    reg [3:0] j;  // Second segment index
    reg [6:0] k;  // Point buffer index
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd10000;
    
    // Intermediate computation registers
    reg [15:0] x0_i, y0_i, x1_i, y1_i;
    reg [15:0] x0_j, y0_j, x1_j, y1_j;
    
    // Multiplier outputs (32-bit)
    reg signed [31:0] dx1, dy1, dx2, dy2;
    reg signed [31:0] denom, num_t, num_u;
    reg signed [31:0] t, u;
    reg signed [31:0] intersect_x, intersect_y;
    reg signed [31:0] cross1, cross2, cross3, cross4;
    reg signed [31:0] dx1_dy2, dy1_dx2;
    reg signed [31:0] dx1_x0, dy1_y0;
    reg signed [31:0] dx2_x0, dy2_y0;
    
    // Comparison and flag registers
    reg is_collinear;
    reg is_coincident;
    reg is_parallel;
    reg is_valid_intersect;
    reg point_exists;
    reg [31:0] new_point_packed;
    reg [31:0] current_point;
    reg [15:0] new_x, new_y;
    reg [15:0] curr_x, curr_y;
    reg signed [16:0] diff_x, diff_y;
    reg signed [16:0] abs_diff_x, abs_diff_y;
    
    // Point matching tolerance (1 LSB = 1/256 ≈ 0.0039)
    localparam signed [16:0] TOLERANCE = 17'd1;
    
    // Integer for loop
    integer l;
    
    // FSM State transition
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
            // Reset all registers
            busy <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
            seg_loaded <= 4'd0;
            point_count <= 7'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 7'd0;
            cycle_count <= 32'd0;
            is_collinear <= 1'b0;
            is_coincident <= 1'b0;
            is_parallel <= 1'b0;
            is_valid_intersect <= 1'b0;
            point_exists <= 1'b0;
            new_point_packed <= 32'd0;
            current_point <= 32'd0;
            new_x <= 16'd0;
            new_y <= 16'd0;
            curr_x <= 16'd0;
            curr_y <= 16'd0;
            diff_x <= 17'sd0;
            diff_y <= 17'sd0;
            abs_diff_x <= 17'sd0;
            abs_diff_y <= 17'sd0;
            dx1 <= 32'sd0;
            dy1 <= 32'sd0;
            dx2 <= 32'sd0;
            dy2 <= 32'sd0;
            denom <= 32'sd0;
            num_t <= 32'sd0;
            num_u <= 32'sd0;
            t <= 32'sd0;
            u <= 32'sd0;
            intersect_x <= 32'sd0;
            intersect_y <= 32'sd0;
            cross1 <= 32'sd0;
            cross2 <= 32'sd0;
            cross3 <= 32'sd0;
            cross4 <= 32'sd0;
            dx1_dy2 <= 32'sd0;
            dy1_dx2 <= 32'sd0;
            dx1_x0 <= 32'sd0;
            dy1_y0 <= 32'sd0;
            dx2_x0 <= 32'sd0;
            dy2_y0 <= 32'sd0;
            
            // Initialize segment registers
            for (l = 0; l < 16; l = l + 1) begin
                x0_reg[l] <= 16'd0;
                y0_reg[l] <= 16'd0;
                x1_reg[l] <= 16'd0;
                y1_reg[l] <= 16'd0;
            end
            
            // Initialize point buffer
            for (l = 0; l < 128; l = l + 1) begin
                point_buf[l] <= 32'd0;
            end
            
        end else begin
            // Default values
            done <= 1'b0;
            cycle_count <= cycle_count + 32'd1;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 16'd0;
                    cycle_count <= 32'd0;
                    seg_loaded <= 4'd0;
                    point_count <= 7'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 7'd0;
                    
                    // Clear buffer
                    for (l = 0; l < 128; l = l + 1) begin
                        point_buf[l] <= 32'd0;
                    end
                    
                    if (start) begin
                        busy <= 1'b1;
                    end
                end
                
                LOAD: begin
                    // Accept segments with seg_valid=1
                    if (seg_valid && seg_ptr < 16'd16) begin
                        x0_reg[seg_ptr] <= seg_x0;
                        y0_reg[seg_ptr] <= seg_y0;
                        x1_reg[seg_ptr] <= seg_x1;
                        y1_reg[seg_ptr] <= seg_y1;
                        seg_loaded <= seg_loaded + 4'd1;
                    end
                    
                    // Transition when all 16 segments loaded or timeout
                    if (seg_loaded == 4'd15 && seg_valid) begin
                        i <= 4'd0;
                        j <= 4'd1;
                        point_count <= 7'd0;
                    end
                end
                
                COMPUTE: begin
                    // Compute intersections for segment pair (i, j)
                    if (i < 16'd16 && j < 16'd16) begin
                        // Load current segments
                        x0_i <= x0_reg[i];
                        y0_i <= y0_reg[i];
                        x1_i <= x1_reg[i];
                        y1_i <= y1_reg[i];
                        x0_j <= x0_reg[j];
                        y0_j <= y0_reg[j];
                        x1_j <= x1_reg[j];
                        y1_j <= y1_reg[j];
                        
                        // Compute differences (signed 16-bit, extended to 32-bit)
                        dx1 <= { {16{x1_reg[i][15]}}, x1_reg[i] } - { {16{x0_reg[i][15]}}, x0_reg[i] };
                        dy1 <= { {16{y1_reg[i][15]}}, y1_reg[i] } - { {16{y0_reg[i][15]}}, y0_reg[i] };
                        dx2 <= { {16{x1_reg[j][15]}}, x1_reg[j] } - { {16{x0_reg[j][15]}}, x0_reg[j] };
                        dy2 <= { {16{y1_reg[j][15]}}, y1_reg[j] } - { {16{y0_reg[j][15]}}, y0_reg[j] };
                        
                        // Check collinearity using cross products
                        cross1 <= ({ {16{x1_reg[i][15]}}, x1_reg[i] } - { {16{x0_reg[i][15]}}, x0_reg[i] }) * ({ {16{y1_reg[j][15]}}, y1_reg[j] } - { {16{y0_reg[j][15]}}, y0_reg[j] });
                        cross2 <= ({ {16{y1_reg[i][15]}}, y1_reg[i] } - { {16{y0_reg[i][15]}}, y0_reg[i] }) * ({ {16{x1_reg[j][15]}}, x1_reg[j] } - { {16{x0_reg[j][15]}}, x0_reg[j] });
                        
                        // For coincident check (segments on same line)
                        dx1_dy2 <= ({ {16{x1_reg[i][15]}}, x1_reg[i] } - { {16{x0_reg[i][15]}}, x0_reg[i] }) * ({ {16{y1_reg[j][15]}}, y1_reg[j] } - { {16{y0_reg[j][15]}}, y0_reg[j] });
                        dy1_dx2 <= ({ {16{y1_reg[i][15]}}, y1_reg[i] } - { {16{y0_reg[i][15]}}, y0_reg[i] }) * ({ {16{x1_reg[j][15]}}, x1_reg[j] } - { {16{x0_reg[j][15]}}, x0_reg[j] });
                        
                        // Cross products for orientation tests
                        cross3 <= ({ {16{x1_reg[j][15]}}, x1_reg[j] } - { {16{x0_reg[i][15]}}, x0_reg[i] }) * ({ {16{y1_reg[i][15]}}, y1_reg[i] } - { {16{y0_reg[i][15]}}, y0_reg[i] });
                        cross4 <= ({ {16{y1_reg[j][15]}}, y1_reg[j] } - { {16{y0_reg[i][15]}}, y0_reg[i] }) * ({ {16{x1_reg[i][15]}}, x1_reg[i] } - { {16{x0_reg[i][15]}}, x0_reg[i] });
                    end
                end
                
                COUNT: begin
                    // Process computed intersection
                    if (i < 16'd16 && j < 16'd16) begin
                        // Determine intersection type
                        is_collinear <= (cross1 == cross2);
                        is_coincident <= (cross1 == cross2) && 
                                         ( (dx1_dy2 == dy1_dx2) );
                        is_parallel <= (cross1 == cross2) && 
                                       !( (dx1_dy2 == dy1_dx2) );
                        
                        // Compute denominator and numerators
                        denom <= dx1 * dy2 - dy1 * dx2;
                        num_t <= (x0_j - x0_i) * dy2 - (y0_j - y0_i) * dx2;
                        num_u <= (x0_j - x0_i) * dy1 - (y0_j - y0_i) * dx1;
                        
                        // Check if valid intersection (t and u in [0, 1])
                        // Q8.8 format: 0 = 0, 1 = 256 (8'd0, 16'd256)
                        // t = num_t / denom
                        // u = num_u / denom
                        
                        // Valid if denom != 0 and 0 <= t <= 1 and 0 <= u <= 1
                        is_valid_intersect <= (denom != 0) && 
                                             (num_t >= 0 && num_t <= denom) && 
                                             (num_u >= 0 && num_u <= denom);
                        
                        // Compute intersection point if valid
                        if (denom != 0) begin
                            // x = x0_i + t * dx1 = x0_i + (num_t * dx1) / denom
                            // For fixed-point, multiply then divide
                            // Simplified: intersection_x = (x0_i * denom + num_t * dx1) / denom
                            dx1_x0 <= x0_i * denom;
                            dy1_y0 <= y0_i * denom;
                        end
                        
                        // Prepare new point
                        new_point_packed <= 32'd0;
                        point_exists <= 1'b0;
                        
                        // Check for coincident overlap (infinite intersections)
                        if (is_coincident) begin
                            // Check if segments share segment (overlap)
                            // Using bounding box comparison
                            // Return 0xFFFF if infinite
                            result <= 16'hFFFF;
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (is_parallel) begin
                            // Parallel but not coincident - no intersection
                            // Continue to next pair
                        end else if (is_valid_intersect) begin
                            // Compute actual intersection point
                            intersect_x <= (dx1_x0 + num_t * dx1) / denom;
                            intersect_y <= (dy1_y0 + num_t * dy1) / denom;
                            
                            // Pack into 32-bit
                            new_x <= intersect_x[15:0];
                            new_y <= intersect_y[15:0];
                            new_point_packed <= {intersect_x[15:0], intersect_y[15:0]};
                            
                            // Check if point already exists in buffer
                            point_exists <= 1'b0;
                            for (k = 0; k < point_count; k = k + 1) begin
                                if (!point_exists) begin
                                    current_point <= point_buf[k];
                                    curr_x <= point_buf[k][31:16];
                                    curr_y <= point_buf[k][15:0];
                                    
                                    // Compare with tolerance
                                    diff_x <= { {1{intersect_x[15]}}, intersect_x[15:0] } - { {1{point_buf[k][31]}}, point_buf[k][31:16] };
                                    diff_y <= { {1{intersect_y[15]}}, intersect_y[15:0] } - { {1{point_buf[k][15]}}, point_buf[k][15:0] };
                                    
                                    abs_diff_x <= (diff_x[16] ? -diff_x : diff_x);
                                    abs_diff_y <= (diff_y[16] ? -diff_y : diff_y);
                                    
                                    if (abs_diff_x <= TOLERANCE && abs_diff_y <= TOLERANCE) begin
                                        point_exists <= 1'b1;
                                    end
                                end
                            end
                            
                            // Add new point if not exists and buffer not full
                            if (!point_exists && point_count < 7'd128) begin
                                point_buf[point_count] <= new_point_packed;
                                point_count <= point_count + 7'd1;
                            end
                        end
                        
                        // Move to next segment pair
                        j <= j + 4'd1;
                        if (j == 4'd15) begin
                            j <= i + 4'd2;
                            i <= i + 4'd1;
                        end
                    end
                    
                    // Check if done with all pairs
                    if (i >= 4'd15 && j >= 4'd16) begin
                        result <= {9'd0, point_count};
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                result <= 16'd0;
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                // Wait for all segments loaded
                if (seg_loaded == 4'd15 && seg_valid) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // One cycle to compute differences and cross products
                next_state = COUNT;
            end
            
            COUNT: begin
                // Process intersection, check for completion
                if (i >= 4'd15 && j >= 4'd16) begin
                    next_state = IDLE;
                end else if (state == COUNT) begin
                    next_state = COMPUTE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule