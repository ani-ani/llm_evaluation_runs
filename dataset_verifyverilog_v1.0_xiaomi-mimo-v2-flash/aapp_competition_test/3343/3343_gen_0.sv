module wire_bending_sim (
    input clk,
    input rst_n,
    input start,
    input [15:0] bend_dist,
    input bend_dir,
    input bend_valid,
    input bend_last,
    output reg done,
    output reg [1:0] result,
    output reg busy
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_BEND = 3'd1;
    localparam [2:0] UPDATE_WIRE = 3'd2;
    localparam [2:0] CHECK_COLLISION = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // Result definitions
    localparam [1:0] RESULT_SAFE = 2'd0;
    localparam [1:0] RESULT_GHOST = 2'd1;
    localparam [1:0] RESULT_ONGOING = 2'd2;
    
    // Registers
    reg [2:0] state, next_state;
    reg [3:0] bend_count;          // Track number of bends (max 16)
    reg [3:0] segment_count;       // Number of segments (bends+1)
    reg [3:0] seg_idx;             // Loop index for segments
    reg [3:0] seg_a, seg_b;        // Pair indices for collision check
    reg collision_detected;
    reg collision_latched;
    reg [15:0] dist_reg;           // Store current bend distance
    reg dir_reg;                   // Store current bend direction
    
    // Wire segments: max 17 segments (16 bends + 1 initial)
    // Each segment: (x1, y1, x2, y2) - 6-bit signed
    reg signed [5:0] seg_x1 [0:16];
    reg signed [5:0] seg_y1 [0:16];
    reg signed [5:0] seg_x2 [0:16];
    reg signed [5:0] seg_y2 [0:16];
    
    // Temporary variables for calculations
    reg signed [5:0] bend_x, bend_y;
    reg signed [5:0] rot_x, rot_y;
    reg signed [5:0] dx, dy;
    reg signed [10:0] temp_sum;    // For intermediate calculations
    
    // Collision detection temporary variables
    reg signed [5:0] a_x1, a_y1, a_x2, a_y2;
    reg signed [5:0] b_x1, b_y1, b_x2, b_y2;
    reg signed [10:0] cross1, cross2, cross3, cross4;
    reg signed [10:0] denom;
    reg signed [10:0] t, u;
    reg collision_found;
    
    // Counter for state timing
    reg [4:0] cycle_counter;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    integer i;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= RESULT_SAFE;
            busy <= 1'b0;
            bend_count <= 4'd0;
            segment_count <= 4'd1;  // Initial wire has 1 segment
            collision_latched <= 1'b0;
            cycle_counter <= 5'd0;
            // Initialize segments: straight line along X
            for (i = 0; i < 17; i = i + 1) begin
                seg_x1[i] <= 6'sd0;
                seg_y1[i] <= 6'sd0;
                seg_x2[i] <= 6'sd0;
                seg_y2[i] <= 6'sd0;
            end
            // Initialize first segment (0,0) to (L,0) - L will be set on start
            seg_x1[0] <= 6'sd0;
            seg_y1[0] <= 6'sd0;
            seg_x2[0] <= 6'sd0;  // Will be set when start is high
            seg_y2[0] <= 6'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    collision_latched <= 1'b0;
                    cycle_counter <= 5'd0;
                    if (start) begin
                        // Initialize wire as straight line from (0,0) to (L,0)
                        // L is in lower 8 bits of bend_dist
                        seg_x2[0] <= {2'b00, bend_dist[7:0]};  // L <= 255
                        seg_y2[0] <= 6'sd0;
                        segment_count <= 4'd1;
                        bend_count <= 4'd0;
                        result <= RESULT_ONGOING;
                    end
                end
                
                LOAD_BEND: begin
                    if (bend_valid) begin
                        dist_reg <= bend_dist;
                        dir_reg <= bend_dir;
                    end
                end
                
                UPDATE_WIRE: begin
                    // Find bend point and rotate sub-wire
                    cycle_counter <= cycle_counter + 5'd1;
                    
                    if (seg_idx < segment_count) begin
                        // Calculate segment length
                        dx <= seg_x2[seg_idx] - seg_x1[seg_idx];
                        dy <= seg_y2[seg_idx] - seg_y1[seg_idx];
                        seg_idx <= seg_idx + 4'd1;
                    end
                end
                
                CHECK_COLLISION: begin
                    cycle_counter <= cycle_counter + 5'd1;
                    // Collision check logic handled in combinational block
                    if (collision_found && !collision_latched) begin
                        collision_latched <= 1'b1;
                        result <= RESULT_GHOST;
                    end
                end
                
                FINISH: begin
                    if (!collision_latched && bend_last) begin
                        result <= RESULT_SAFE;
                    end
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
            
            // Reset cycle counter in IDLE
            if (state == IDLE) begin
                cycle_counter <= 5'd0;
            end
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_BEND;
                end
            end
            
            LOAD_BEND: begin
                if (bend_valid && !collision_latched) begin
                    if (bend_count < 4'd16) begin  // Max 16 bends
                        next_state = UPDATE_WIRE;
                    end else begin
                        next_state = FINISH;
                    end
                end else if (bend_valid && collision_latched) begin
                    next_state = FINISH;
                end
            end
            
            UPDATE_WIRE: begin
                if (seg_idx >= segment_count) begin
                    next_state = CHECK_COLLISION;
                end
            end
            
            CHECK_COLLISION: begin
                // Give enough time for collision detection
                if (cycle_counter >= 5'd3) begin
                    if (bend_last || collision_latched) begin
                        next_state = FINISH;
                    end else begin
                        next_state = LOAD_BEND;
                        bend_count <= bend_count + 4'd1;
                    end
                end
            end
            
            FINISH: begin
                if (done) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Wire update and collision detection combinational logic
    always @(*) begin
        // Initialize outputs
        collision_found = 1'b0;
        
        if (state == UPDATE_WIRE) begin
            // Find segment containing bend point
            bend_x = 6'sd0;
            bend_y = 6'sd0;
            
            // Calculate cumulative distance to find bend segment
            temp_sum = 11'sd0;
            seg_idx = 4'd0;
            
            for (i = 0; i < 17; i = i + 1) begin
                if (i < segment_count && seg_idx == i) begin
                    // Check distance to this segment
                    dx = seg_x2[i] - seg_x1[i];
                    dy = seg_y2[i] - seg_y1[i];
                    temp_sum = temp_sum + {5'b00000, ((dx[5] ? -dx : dx) + (dy[5] ? -dy : dy))};  // Approximate Manhattan dist
                    
                    if (temp_sum >= {1'b0, dist_reg[15:0]}) begin
                        // Bend point is on this segment
                        seg_idx = i;
                        // Calculate exact position
                        // For simplicity, assume bend at segment endpoint
                        // (Full implementation would interpolate)
                        bend_x = seg_x1[i] + {3'b000, dist_reg[7:0]};
                        bend_y = seg_y1[i];
                    end
                end
            end
            
            // Rotate sub-wire (from seg_idx+1 to end)
            for (i = 0; i < 17; i = i + 1) begin
                if (i > seg_idx && i < segment_count) begin
                    // Rotate start point
                    dx = seg_x1[i] - bend_x;
                    dy = seg_y1[i] - bend_y;
                    
                    if (dir_reg == 1'b1) begin  // CCW
                        rot_x = bend_x - dy;
                        rot_y = bend_y + dx;
                    end else begin  // CW
                        rot_x = bend_x + dy;
                        rot_y = bend_y - dx;
                    end
                    seg_x1[i] = rot_x;
                    seg_y1[i] = rot_y;
                    
                    // Rotate end point
                    dx = seg_x2[i] - bend_x;
                    dy = seg_y2[i] - bend_y;
                    
                    if (dir_reg == 1'b1) begin  // CCW
                        rot_x = bend_x - dy;
                        rot_y = bend_y + dx;
                    end else begin  // CW
                        rot_x = bend_x + dy;
                        rot_y = bend_y - dx;
                    end
                    seg_x2[i] = rot_x;
                    seg_y2[i] = rot_y;
                end
            end
            
            // Add new segment at bend point
            if (seg_idx < segment_count && seg_idx < 16) begin
                // Insert new segment
                for (i = 16; i > seg_idx; i = i - 1) begin
                    seg_x1[i] = seg_x1[i-1];
                    seg_y1[i] = seg_y1[i-1];
                    seg_x2[i] = seg_x2[i-1];
                    seg_y2[i] = seg_y2[i-1];
                end
                // Set new segment
                seg_x1[seg_idx + 1] = bend_x;
                seg_y1[seg_idx + 1] = bend_y;
                seg_x2[seg_idx + 1] = seg_x2[seg_idx];  // Previous end
                seg_y2[seg_idx + 1] = seg_y2[seg_idx];
                // Update previous segment end
                seg_x2[seg_idx] = bend_x;
                seg_y2[seg_idx] = bend_y;
                
                segment_count = segment_count + 4'd1;
            end
        end
        
        if (state == CHECK_COLLISION) begin
            // Check all segment pairs for intersection
            for (seg_a = 0; seg_a < 16; seg_a = seg_a + 1) begin
                for (seg_b = seg_a + 1; seg_b < 17; seg_b = seg_b + 1) begin
                    if (seg_a < segment_count && seg_b < segment_count) begin
                        // Skip adjacent segments
                        if (seg_b != seg_a + 1 && seg_a != seg_b + 1) begin
                            a_x1 = seg_x1[seg_a];
                            a_y1 = seg_y1[seg_a];
                            a_x2 = seg_x2[seg_a];
                            a_y2 = seg_y2[seg_a];
                            b_x1 = seg_x1[seg_b];
                            b_y1 = seg_y1[seg_b];
                            b_x2 = seg_x2[seg_b];
                            b_y2 = seg_y2[seg_b];
                            
                            // Check intersection (grid based)
                            // Compute cross products
                            cross1 = (b_x2 - b_x1) * (a_y1 - b_y1) - (b_y2 - b_y1) * (a_x1 - b_x1);
                            cross2 = (b_x2 - b_x1) * (a_y2 - b_y1) - (b_y2 - b_y1) * (a_x2 - b_x1);
                            cross3 = (a_x2 - a_x1) * (b_y1 - a_y1) - (a_y2 - a_y1) * (b_x1 - a_x1);
                            cross4 = (a_x2 - a_x1) * (b_y2 - a_y1) - (a_y2 - a_y1) * (b_x2 - a_x1);
                            
                            // Check if signs differ (segments straddle)
                            if ((cross1[10] != cross2[10]) && (cross3[10] != cross4[10])) begin
                                collision_found = 1'b1;
                            end
                            
                            // Check if endpoint lies on other segment
                            // Point A1 on B
                            if (a_x1 >= (b_x1 < b_x2 ? b_x1 : b_x2) && a_x1 <= (b_x1 > b_x2 ? b_x1 : b_x2) &&
                                a_y1 >= (b_y1 < b_y2 ? b_y1 : b_y2) && a_y1 <= (b_y1 > b_y2 ? b_y1 : b_y2)) begin
                                if ((a_x1 - b_x1) * (b_y2 - b_y1) == (a_y1 - b_y1) * (b_x2 - b_x1)) begin
                                    collision_found = 1'b1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end
endmodule