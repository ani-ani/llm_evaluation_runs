module wire_bending_sim(
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
    localparam [2:0] PROCESS_BEND = 3'd1;
    localparam [2:0] CHECK_COLLISION = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    // Constants
    localparam [7:0] MAX_BENDS = 8'd16;
    localparam [7:0] MAX_LENGTH = 8'd16;
    localparam [7:0] MAX_CYCLES = 8'd256;
    localparam [5:0] MAX_COORD = 6'd31;
    localparam [5:0] MIN_COORD = 6'd32; // -32 in 6-bit signed

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] bend_count;
    reg [7:0] cycle_count;
    reg [7:0] current_length;
    reg [7:0] segment_count;
    reg [5:0] segments_x1 [0:16];
    reg [5:0] segments_y1 [0:16];
    reg [5:0] segments_x2 [0:16];
    reg [5:0] segments_y2 [0:16];
    reg [15:0] current_dist;
    reg current_dir;
    reg collision_detected;
    reg [7:0] i, j, k;
    reg [5:0] temp_x, temp_y;
    reg [5:0] bend_x, bend_y;
    reg [5:0] new_x, new_y;
    reg [5:0] dx, dy;
    reg [5:0] s1_x1, s1_y1, s1_x2, s1_y2;
    reg [5:0] s2_x1, s2_y1, s2_x2, s2_y2;
    reg [5:0] denom, num1, num2;
    reg [5:0] ua_num, ub_num;
    reg [5:0] ua, ub;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            busy <= 1'b0;
            done <= 1'b0;
            bend_count <= 8'd0;
            cycle_count <= 8'd0;
            current_length <= 8'd0;
            segment_count <= 8'd0;
            collision_detected <= 1'b0;
            
            // Initialize segments
            for (i = 0; i < 17; i = i + 1) begin
                segments_x1[i] <= 6'd0;
                segments_y1[i] <= 6'd0;
                segments_x2[i] <= 6'd0;
                segments_y2[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 2'd0;
                    if (start) begin
                        // Initialize wire as straight line along X-axis
                        current_length <= MAX_LENGTH;
                        segment_count <= 8'd1;
                        segments_x1[0] <= 6'd0;
                        segments_y1[0] <= 6'd0;
                        segments_x2[0] <= 6'd16;
                        segments_y2[0] <= 6'd0;
                        bend_count <= 8'd0;
                        cycle_count <= 8'd0;
                        collision_detected <= 1'b0;
                        next_state <= PROCESS_BEND;
                    end
                end
                
                PROCESS_BEND: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    
                    if (cycle_count < 8'd16) begin
                        cycle_count <= cycle_count + 8'd1;
                        
                        // Process bend on first cycle of this state
                        if (cycle_count == 8'd1) begin
                            current_dist <= bend_dist;
                            current_dir <= bend_dir;
                            
                            // Find segment containing bend point
                            for (i = 0; i < segment_count; i = i + 1) begin
                                if (current_dist <= current_length) begin
                                    // Found the segment
                                    s1_x1 <= segments_x1[i];
                                    s1_y1 <= segments_y1[i];
                                    s1_x2 <= segments_x2[i];
                                    s1_y2 <= segments_y2[i];
                                    
                                    // Calculate bend point coordinates
                                    if (s1_x1 == s1_x2) begin
                                        // Vertical segment
                                        bend_y <= s1_y1 + (current_dist - (i == 0 ? 0 : current_length - (segment_count - i) * MAX_LENGTH));
                                        bend_x <= s1_x1;
                                    end else begin
                                        // Horizontal segment
                                        bend_x <= s1_x1 + (current_dist - (i == 0 ? 0 : current_length - (segment_count - i) * MAX_LENGTH));
                                        bend_y <= s1_y1;
                                    end
                                    
                                    // Rotate the remaining wire
                                    for (j = i; j < segment_count; j = j + 1) begin
                                        // Translate to local coordinates
                                        temp_x <= segments_x1[j] - bend_x;
                                        temp_y <= segments_y1[j] - bend_y;
                                        
                                        // Rotate
                                        if (current_dir == 1'b0) begin
                                            // CW: (x, y) -> (x+y, y-x)
                                            new_x <= temp_x + temp_y;
                                            new_y <= temp_y - temp_x;
                                        end else begin
                                            // CCW: (x, y) -> (x-y, y+x)
                                            new_x <= temp_x - temp_y;
                                            new_y <= temp_y + temp_x;
                                        end
                                        
                                        // Translate back
                                        segments_x1[j] <= new_x + bend_x;
                                        segments_y1[j] <= new_y + bend_y;
                                        
                                        temp_x <= segments_x2[j] - bend_x;
                                        temp_y <= segments_y2[j] - bend_y;
                                        
                                        if (current_dir == 1'b0) begin
                                            new_x <= temp_x + temp_y;
                                            new_y <= temp_y - temp_x;
                                        end else begin
                                            new_x <= temp_x - temp_y;
                                            new_y <= temp_y + temp_x;
                                        end
                                        
                                        segments_x2[j] <= new_x + bend_x;
                                        segments_y2[j] <= new_y + bend_y;
                                    end
                                    
                                    // Update segment count if this is the first bend
                                    if (bend_count == 8'd0) begin
                                        segment_count <= segment_count + 8'd1;
                                    end
                                    
                                    break;
                                end
                            end
                        end
                        
                        // After processing, move to collision check
                        if (cycle_count == 8'd16) begin
                            next_state <= CHECK_COLLISION;
                            cycle_count <= 8'd0;
                        end
                    end else begin
                        next_state <= CHECK_COLLISION;
                        cycle_count <= 8'd0;
                    end
                end
                
                CHECK_COLLISION: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    
                    if (cycle_count < 8'd16) begin
                        cycle_count <= cycle_count + 8'd1;
                        
                        // Check for collisions on first cycle
                        if (cycle_count == 8'd1) begin
                            collision_detected <= 1'b0;
                            
                            // Check all segment pairs
                            for (i = 0; i < segment_count; i = i + 1) begin
                                s1_x1 <= segments_x1[i];
                                s1_y1 <= segments_y1[i];
                                s1_x2 <= segments_x2[i];
                                s1_y2 <= segments_y2[i];
                                
                                for (j = i + 1; j < segment_count; j = j + 1) begin
                                    s2_x1 <= segments_x1[j];
                                    s2_y1 <= segments_y1[j];
                                    s2_x2 <= segments_x2[j];
                                    s2_y2 <= segments_y2[j];
                                    
                                    // Skip adjacent segments
                                    if (j == i + 1) begin
                                        continue;
                                    end
                                    
                                    // Calculate denominator
                                    dx <= s2_x2 - s2_x1;
                                    dy <= s2_y2 - s2_y1;
                                    denom <= (s1_x2 - s1_x1) * dy - (s1_y2 - s1_y1) * dx;
                                    
                                    // If denominator is zero, lines are parallel
                                    if (denom == 6'd0) begin
                                        // Check if lines are collinear and overlapping
                                        // This is a simplified check
                                        if ((s1_x1 == s2_x1 && s1_y1 == s2_y1) ||
                                            (s1_x1 == s2_x2 && s1_y1 == s2_y2) ||
                                            (s1_x2 == s2_x1 && s1_y2 == s2_y1) ||
                                            (s1_x2 == s2_x2 && s1_y2 == s2_y2)) begin
                                            collision_detected <= 1'b1;
                                        end
                                    end else begin
                                        // Calculate numerators
                                        num1 <= (s1_x1 - s2_x1) * dy - (s1_y1 - s2_y1) * dx;
                                        num2 <= (s1_x1 - s2_x1) * (s1_y2 - s1_y1) - (s1_y1 - s2_y1) * (s1_x2 - s1_x1);
                                        
                                        // Calculate parameters
                                        ua_num <= num1 * denom;
                                        ub_num <= num2 * denom;
                                        
                                        // Check if parameters are in [0, 1]
                                        if ((ua_num >= 6'd0 && ua_num <= denom) &&
                                            (ub_num >= 6'd0 && ub_num <= denom)) begin
                                            collision_detected <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                        
                        // After checking, move to next state
                        if (cycle_count == 8'd16) begin
                            if (collision_detected) begin
                                result <= 2'd1; // GHOST
                                next_state <= FINISH;
                            end else if (bend_last) begin
                                result <= 2'd0; // SAFE
                                next_state <= FINISH;
                            end else begin
                                bend_count <= bend_count + 8'd1;
                                next_state <= PROCESS_BEND;
                            end
                            cycle_count <= 8'd0;
                        end
                    end else begin
                        if (collision_detected) begin
                            result <= 2'd1; // GHOST
                            next_state <= FINISH;
                        end else if (bend_last) begin
                            result <= 2'd0; // SAFE
                            next_state <= FINISH;
                        end else begin
                            bend_count <= bend_count + 8'd1;
                            next_state <= PROCESS_BEND;
                        end
                        cycle_count <= 8'd0;
                    end
                end
                
                FINISH: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 2'd0;
                end
            endcase
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 2'd0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 2'd0;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
                PROCESS_BEND: begin
                    result <= 2'd2; // ONGOING
                    busy <= 1'b1;
                    done <= 1'b0;
                end
                CHECK_COLLISION: begin
                    result <= 2'd2; // ONGOING
                    busy <= 1'b1;
                    done <= 1'b0;
                end
                FINISH: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
                default: begin
                    result <= 2'd0;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule