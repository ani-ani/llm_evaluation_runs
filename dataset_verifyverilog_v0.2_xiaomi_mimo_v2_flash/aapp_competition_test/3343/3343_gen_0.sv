module wire_bending(
    input clk,
    input rst_n,
    input start,
    input [3:0] bend_point,
    input bend_dir,
    input bend_valid,
    output reg ghost,
    output reg done
);

    // State encoding
    localparam IDLE = 4'b0000;
    localparam READ_BEND = 4'b0001;
    localparam FIND_BEND_POINT = 4'b0010;
    localparam ADD_NEW_SEGMENT = 4'b0011;
    localparam CHECK_INTERSECTION = 4'b0100;
    localparam GHOST_DETECTED = 4'b0101;
    localparam DONE = 4'b0110;
    localparam WAIT_BEND_VALID_LOW = 4'b0111;

    // Direction encoding
    localparam RIGHT = 2'b00;
    localparam UP = 2'b01;
    localparam LEFT = 2'b10;
    localparam DOWN = 2'b11;

    reg [3:0] current_state, next_state;
    
    // Registers for wire state
    reg signed [4:0] head_x, head_y;
    reg signed [4:0] prev_head_x, prev_head_y;
    reg [1:0] current_dir;
    reg [3:0] bend_count;
    reg [2:0] seg_count;
    
    // Segment storage (up to 8 segments)
    reg signed [4:0] seg_start_x [0:7];
    reg signed [4:0] seg_start_y [0:7];
    reg signed [4:0] seg_end_x [0:7];
    reg signed [4:0] seg_end_y [0:7];
    
    // State machine temporary registers
    reg signed [4:0] bend_x, bend_y;
    reg [1:0] bend_idx;
    reg [1:0] search_seg_idx;
    reg signed [4:0] search_x, search_y;
    reg [3:0] remaining_len;
    reg signed [4:0] new_seg_start_x, new_seg_start_y;
    reg signed [4:0] new_seg_end_x, new_seg_end_y;
    reg [3:0] new_seg_len;
    reg [2:0] check_idx;
    reg intersect_detect;
    reg signed [4:0] temp_x1, temp_y1, temp_x2, temp_y2;
    reg signed [4:0] temp_x3, temp_y3, temp_x4, temp_y4;
    reg [1:0] next_dir_reg;
    
    // Combinational logic for intersection math
    wire signed [4:0] dx1 = temp_x2 - temp_x1;
    wire signed [4:0] dy1 = temp_y2 - temp_y1;
    wire signed [4:0] dx2 = temp_x4 - temp_x3;
    wire signed [4:0] dy2 = temp_y4 - temp_y3;
    wire signed [9:0] denom = dx1 * dy2 - dx2 * dy1;
    wire signed [9:0] num1 = (temp_x3 - temp_x1) * dy2 - (temp_y3 - temp_y1) * dx2;
    wire signed [9:0] num2 = (temp_x3 - temp_x1) * dy1 - (temp_y3 - temp_y1) * dx1;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head_x <= 0; head_y <= 0;
            prev_head_x <= 0; prev_head_y <= 0;
            current_dir <= RIGHT;
            bend_count <= 0; seg_count <= 1;
            seg_start_x[0] <= 0; seg_start_y[0] <= 0;
            seg_end_x[0] <= 8; seg_end_y[0] <= 0;
            ghost <= 0; done <= 0;
            intersect_detect <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0; ghost <= 0;
                    if (start) begin
                        bend_count <= 0; seg_count <= 1;
                        head_x <= 8; head_y <= 0;
                        prev_head_x <= 0; prev_head_y <= 0;
                        current_dir <= RIGHT;
                        seg_start_x[0] <= 0; seg_start_y[0] <= 0;
                        seg_end_x[0] <= 8; seg_end_y[0] <= 0;
                        next_state <= READ_BEND;
                    end else next_state <= IDLE;
                end

                READ_BEND: begin
                    if (bend_valid && !ghost) begin
                        remaining_len <= bend_point;
                        search_seg_idx <= 0;
                        search_x <= 0; search_y <= 0;
                        if (bend_point == 0) begin
                            bend_x <= head_x; bend_y <= head_y;
                        end
                        next_state <= FIND_BEND_POINT;
                    end else if (ghost) next_state <= GHOST_DETECTED;
                    else next_state <= READ_BEND;
                end

                FIND_BEND_POINT: begin
                    if (bend_point == 0) begin
                        next_state <= ADD_NEW_SEGMENT;
                    end else begin
                        // Traverse to find bend point
                        reg signed [4:0] curr_sx = seg_start_x[search_seg_idx];
                        reg signed [4:0] curr_sy = seg_start_y[search_seg_idx];
                        reg signed [4:0] curr_ex = seg_end_x[search_seg_idx];
                        reg signed [4:0] curr_ey = seg_end_y[search_seg_idx];
                        reg signed [4:0] seg_len;
                        
                        if (curr_sx == curr_ex) begin
                            seg_len = (curr_ey > curr_sy) ? (curr_ey - curr_sy) : (curr_sy - curr_ey);
                        end else begin
                            seg_len = (curr_ex > curr_sx) ? (curr_ex - curr_sx) : (curr_sx - curr_ex);
                        end
                        
                        if (remaining_len < seg_len) begin
                            if (curr_sx == curr_ex) begin
                                bend_x <= curr_sx;
                                bend_y <= (curr_ey > curr_sy) ? (curr_sy + remaining_len) : (curr_sy - remaining_len);
                            end else begin
                                bend_y <= curr_sy;
                                bend_x <= (curr_ex > curr_sx) ? (curr_sx + remaining_len) : (curr_sx - remaining_len);
                            end
                            next_state <= ADD_NEW_SEGMENT;
                        end else begin
                            remaining_len <= remaining_len - seg_len;
                            search_seg_idx <= search_seg_idx + 1;
                            next_state <= FIND_BEND_POINT;
                        end
                    end
                end

                ADD_NEW_SEGMENT: begin
                    new_seg_start_x <= bend_x;
                    new_seg_start_y <= bend_y;
                    
                    // Determine new direction
                    if (bend_dir == 0) begin // Clockwise
                        case (current_dir)
                            RIGHT: next_dir_reg = DOWN;
                            DOWN: next_dir_reg = LEFT;
                            LEFT: next_dir_reg = UP;
                            UP: next_dir_reg = RIGHT;
                        endcase
                    end else begin // Counter-clockwise
                        case (current_dir)
                            RIGHT: next_dir_reg = UP;
                            UP: next_dir_reg = LEFT;
                            LEFT: next_dir_reg = DOWN;
                            DOWN: next_dir_reg = RIGHT;
                        endcase
                    end
                    
                    new_seg_len <= 8 - bend_point;
                    
                    // Calculate end point
                    case (next_dir_reg)
                        RIGHT: new_seg_end_x <= bend_x + (8 - bend_point);
                        UP: new_seg_end_y <= bend_y + (8 - bend_point);
                        LEFT: new_seg_end_x <= bend_x - (8 - bend_point);
                        DOWN: new_seg_end_y <= bend_y - (8 - bend_point);
                    endcase
                    if (next_dir_reg == RIGHT || next_dir_reg == LEFT) new_seg_end_y <= bend_y;
                    else new_seg_end_y <= bend_y; // Update properly based on direction
                    if (next_dir_reg == UP || next_dir_reg == DOWN) new_seg_end_x <= bend_x;
                    else new_seg_end_x <= bend_x; // Update properly
                    // Explicit assignment for clarity
                    if (next_dir_reg == RIGHT) new_seg_end_x <= bend_x + (8 - bend_point);
                    if (next_dir_reg == LEFT) new_seg_end_x <= bend_x - (8 - bend_point);
                    if (next_dir_reg == UP) new_seg_end_y <= bend_y + (8 - bend_point);
                    if (next_dir_reg == DOWN) new_seg_end_y <= bend_y - (8 - bend_point);
                    
                    // Update current state registers
                    prev_head_x <= bend_x;
                    prev_head_y <= bend_y;
                    head_x <= (next_dir_reg == RIGHT || next_dir_reg == LEFT) ? (bend_x + (next_dir_reg==RIGHT ? (8-bend_point) : -(8-bend_point))) : bend_x;
                    head_y <= (next_dir_reg == UP || next_dir_reg == DOWN) ? (bend_y + (next_dir_reg==UP ? (8-bend_point) : -(8-bend_point))) : bend_y;
                    current_dir <= next_dir_reg;
                    
                    // Setup for intersection check
                    check_idx <= 0;
                    intersect_detect <= 0;
                    next_state <= CHECK_INTERSECTION;
                    
                    // Correct head update logic to avoid multiple drivers
                    if (next_dir_reg == RIGHT) begin head_x <= bend_x + (8 - bend_point); head_y <= bend_y; end
                    else if (next_dir_reg == LEFT) begin head_x <= bend_x - (8 - bend_point); head_y <= bend_y; end
                    else if (next_dir_reg == UP) begin head_x <= bend_x; head_y <= bend_y + (8 - bend_point); end
                    else if (next_dir_reg == DOWN) begin head_x <= bend_x; head_y <= bend_y - (8 - bend_point); end
                end

                CHECK_INTERSECTION: begin
                    // Logic to determine collision
                    // We need to populate temp_x/y for the combinational math
                    // And decide if collision occurred based on previous cycle's math (if any) or current
                    // Since we are in a clocked block, we calculate collision for the segment index from the PREVIOUS cycle
                    // Wait, we need to check the segment setup in the PREVIOUS cycle.
                    
                    // We will calculate collision for check_idx - 1
                    // On entry (cycle 0): we set up for seg 0. No collision yet.
                    // On cycle 1: we check result for seg 0. Set up for seg 1.
                    // ...
                    // On cycle N: check result for seg N-1. Set up for N.
                    // Last cycle: check result for last seg. Transition.
                    
                    // Let's handle the collision check for the segment set up in the PREVIOUS state/iteration
                    // We need to know if we are in the first iteration (check_idx 0).
                    // Actually, let's reset intersect_detect at start of CHECK_INTERSECTION.
                    // Then, if check_idx > 0 (or we have a valid previous check), we evaluate.
                    // But wait, the first time we enter, check_idx is 0. We haven't set up any segment yet.
                    // So we need to do: Set up segment 0 -> Check Segment 0 -> Set up 1 -> Check 1 ...
                    // This requires a pipeline or we calculate and check in the same cycle using latched inputs.
                    
                    // Let's use a flag `check_active` or similar.
                    // Or, better: Check the segment index `check_idx` AFTER setting it up.
                    // But that means we need to set it up in the PREVIOUS cycle.
                    // This is hard in a single always block without extra states.
                    
                    // Revised Strategy for CHECK_INTERSECTION:
                    // We will use a counter `check_cycle` inside this state.
                    // But we already have `check_idx`.
                    // Let's do: In state CHECK_INTERSECTION, we iterate `check_idx`.
                    // If `check_idx` < `seg_count` (or `search_seg_idx` + 1), we check.
                    // We need to evaluate the collision for the current `check_idx`.
                    // To do that, we need the segment data for `check_idx`.
                    // We can load it into temp registers in the same cycle.
                    // But the math is combinational.
                    // If we update temp registers in the clocked block, they become valid in the NEXT cycle.
                    // So we need a state machine that does: LOAD -> CHECK -> NEXT.
                    // To save cycles, we can do CHECK -> LOAD in one cycle if we are careful.
                    // i.e., at cycle T, we check segment `check_idx` (using data loaded at T-1), and load `check_idx+1` for T+1.
                    
                    // Let's modify the logic: In ADD_NEW_SEGMENT, we load `check_idx=0` data into temp registers.
                    // Then in CHECK_INTERSECTION: 
                    // 1. Check collision for `check_idx` (data in temp).
                    // 2. If collision, go to GHOST.
                    // 3. If not, increment `check_idx`.
                    // 4. Load data for new `check_idx` into temp.
                    // 5. If `check_idx` > max, go to NEXT bend.
                    
                    // This fits in ~8 cycles (1 for initial load in ADD_NEW, 7 for checks).
                    // We need 8 segments max. So 8 checks.
                    // Add new segment logic needs to load check_idx 0.
                    // So ADD_NEW_SEGMENT will set temp registers for idx 0, then go to CHECK.
                    // CHECK state will handle idx 0..7.
                    
                    // Step 1: Calculate collision for `check_idx` using `temp` registers.
                    reg collision_detected = 0;
                    reg is_parent = (check_idx == search_seg_idx);
                    
                    // Intersection Logic
                    // We use denom, num1, num2
                    // Conditions:
                    // 1. Standard Intersection (denom != 0): 
                    //    0 <= num1 <= denom AND 0 <= num2 <= denom (handling sign).
                    // 2. Collinear (denom == 0): Check overlap.
                    
                    // Is current segment valid length? (temp_x1 != temp_x2 || temp_y1 != temp_y2)
                    // If length 0 (vertex check), we just check if this point is on the new segment (and not start).
                    
                    // Let's implement the check logic inline.
                    // We need to determine if the segment setup in `temp` registers causes a collision.
                    
                    // If `check_idx` is 0, we just entered state or setup done.
                    // Actually, in ADD_NEW_SEGMENT, we should set up check_idx 0.
                    // So in CHECK_INTERSECTION, we can immediately check idx 0.
                    // Then loop.
                    
                    // Let's refine the flow inside CHECK_INTERSECTION:
                    // If check_idx == 0 AND !intersect_detect (initial entry), start checking.
                    // But wait, `temp` registers are from previous cycle? 
                    // No, `temp` registers are updated at the end of the always block.
                    // If we are in CHECK_INTERSECTION, `temp` contains data for `check_idx` from the PREVIOUS iteration.
                    // THIS IS WRONG. We need to load data for `check_idx` THEN check.
                    // So we need a 2-stage process or load in previous state.
                    
                    // Let's load data for `check_idx` at the END of the previous cycle.
                    // ADD_NEW_SEGMENT loads data for idx 0.
                    // CHECK_INTERSECTION checks data (which was loaded), then loads next.
                    
                    // So, inside CHECK_INTERSECTION:
                    // Check collision for `check_idx`.
                    // If collision, goto GHOST.
                    // Else, increment `check_idx`.
                    // If `check_idx` > `search_seg_idx`, goto NEXT bend.
                    // Else, load data for `check_idx` into temp, stay in state.
                    
                    // Logic to check collision for current `check_idx` (data in `temp` registers):
                    
                    // 1. Check if segment is degenerate (length 0).
                    if (temp_x1 == temp_x2 && temp_y1 == temp_y2) begin
                        // Vertex check. Is this vertex on the new segment?
                        // New segment is temp_x3, temp_y3 to temp_x4, temp_y4.
                        // We are checking if (temp_x1, temp_y1) lies on [temp_x3, temp_x4] x [temp_y3, temp_y4].
                        // And if it is NOT the start point (temp_x3, temp_y3).
                        // If it is the start point, it's the bend point (ignored).
                        // If it is the end point, or interior, it's collision.
                        // Wait, if we check parent segment, we truncated it.
                        // So temp_x2, temp_y2 is bend_x, bend_y.
                        // If check_idx == parent_idx, this vertex check happens.
                        // If temp_x1 == temp_y1 == bend_x, bend_y, then it's the bend point.
                        // This should not happen if we truncated correctly (unless parent segment was length 0).
                        
                        // Check if vertex is on new segment: 
                        // (vx, vy) on line (x3, y3)-(x4, y4) AND (vx-x3)*dx2 == (vy-y3)*dy2 (collinear) AND min/max check.
                        // Since we are integers, we can check.
                        // Let's use the math: is (vx, vy) on new segment?
                        // If dx2 != 0: vy == y3 and vx between x3 and x4.
                        // If dy2 != 0: vx == x3 and vy between y3 and y4.
                        
                        reg on_new_seg = 0;
                        if (dx2 != 0) begin
                            if (temp_y1 == temp_y3 && temp_x1 >= (temp_x3 < temp_x4 ? temp_x3 : temp_x4) && temp_x1 <= (temp_x3 < temp_x4 ? temp_x4 : temp_x3)) on_new_seg = 1;
                        end else if (dy2 != 0) begin
                            if (temp_x1 == temp_x3 && temp_y1 >= (temp_y3 < temp_y4 ? temp_y3 : temp_y4) && temp_y1 <= (temp_y3 < temp_y4 ? temp_y4 : temp_y3)) on_new_seg = 1;
                        end
                        
                        if (on_new_seg && !(temp_x1 == temp_x3 && temp_y1 == temp_y3)) begin
                            collision_detected = 1;
                        end
                    end else begin
                        // Standard segment check
                        // Check if denom != 0
                        if (denom != 0) begin
                            // Check ranges
                            // s = num1/denom, t = num2/denom
                            // 0 <= s <= denom AND 0 <= t <= denom (or reversed if denom < 0)
                            reg s_ok, t_ok;
                            s_ok = (denom > 0) ? (num1 >= 0 && num1 <= denom) : (num1 <= 0 && num1 >= denom);
                            t_ok = (denom > 0) ? (num2 >= 0 && num2 <= denom) : (num2 <= 0 && num2 >= denom);
                            
                            if (s_ok && t_ok) begin
                                // Intersection detected. Now check if we need to ignore it.
                                // Only ignore if this is the parent segment AND the intersection is at the start of new segment (t=0).
                                // t corresponds to num2/denom.
                                // If t=0, then num2=0.
                                // If we allow t=0, we allow the bend point.
                                // So if is_parent and num2 == 0, ignore.
                                // BUT we must ensure it's not overlapping (interior collision).
                                // If t=0, intersection is at start of new seg.
                                // If s=1, it's at end of old seg (bend point).
                                // If s<1, it's interior of old seg (bend point).
                                // So if num2 == 0, it's the start of new seg.
                                // We ignore if is_parent.
                                
                                if (is_parent && (num2 == 0)) begin
                                    // Ignore
                                end else begin
                                    // Collision
                                    // Special case: denom != 0 implies lines cross or touch at endpoints.
                                    // If t=1, intersection is at end of new seg.
                                    // If it touches at end, it's collision.
                                    // So num2 == denom (t=1) is collision.
                                    // So num2 != 0 is collision (since we allow 0).
                                    // Wait, what if t=0.5 (interior)? num2 != 0. Collision.
                                    // So if num2 != 0, it's interior or end. Collision.
                                    // So logic: if (num2 != 0) collision.
                                    // What if num2 == 0 but denom < 0?
                                    // t = num2/denom = 0. Still 0.
                                    // So num2 == 0 check is good.
                                    collision_detected = 1;
                                end
                            end
                        end else begin
                            // denom == 0: Parallel or Collinear.
                            // Check if collinear and overlapping.
                            // New: B to E. Old: A to B (if parent).
                            // Overlap exists if E lies on A-B (excluding B).
                            // Or if they are on same line and intervals overlap.
                            // Since we truncated, Old is A to B. New is B to E.
                            // They share B.
                            // Overlap if E lies between A and B.
                            // Or if A lies between B and E (impossible as A is before B).
                            // So check if E lies on A-B.
                            // If yes, collision.
                            
                            // Check if temp_x4, temp_y4 lies on segment temp_x1, temp_y1 to temp_x2, temp_y2 (excluding temp_x2, temp_y2).
                            // Collinear check: dx1*dy3 == dy1*dx3 where (x3, y3) is E.
                            wire signed [4:0] dx3 = temp_x4 - temp_x1;
                            wire signed [4:0] dy3 = temp_y4 - temp_y1;
                            wire collinear = (dx1 * dy3 == dy1 * dx3);
                            
                            if (collinear) begin
                                // Check if E is between A and B.
                                // min(A,B) <= E < max(A,B) (strictly less than B to exclude bend point).
                                // But wait, E is the end of new segment.
                                // If E is exactly A, it's a point. Collision?
                                // If E is strictly between A and B, yes.
                                
                                reg between = 0;
                                if (dx1 != 0) begin
                                    if (dx1 > 0) between = (temp_x4 > temp_x1 && temp_x4 < temp_x2);
                                    else between = (temp_x4 < temp_x1 && temp_x4 > temp_x2);
                                end else begin
                                    if (dy1 > 0) between = (temp_y4 > temp_y1 && temp_y4 < temp_y2);
                                    else between = (temp_y4 < temp_y1 && temp_y4 > temp_y2);
                                end
                                
                                if (between) collision_detected = 1;
                            end else begin
                                // Parallel but not collinear. No intersection.
                            end
                        end
                    end
                    
                    // Accumulate collision
                    if (collision_detected) intersect_detect <= 1;
                    
                    // Determine next action based on collision
                    if (collision_detected || intersect_detect) begin
                        // If we collided on this segment, or previously, ghost.
                        // But wait, we need to finish checking all segments?
                        // If we hit ghost, we can stop.
                        next_state <= GHOST_DETECTED;
                        ghost <= 1;
                        done <= 1;
                    end else begin
                        // No collision for this segment.
                        // Move to next segment.
                        if (check_idx < search_seg_idx) begin
                            // Load next segment
                            check_idx <= check_idx + 1;
                            
                            // Load data for next index (check_idx + 1) into temp
                            reg [2:0] next_idx = check_idx + 1;
                            if (next_idx == search_seg_idx) begin
                                // Parent segment
                                temp_x1 <= seg_start_x[next_idx];
                                temp_y1 <= seg_start_y[next_idx];
                                temp_x2 <= bend_x;
                                temp_y2 <= bend_y;
                            end else begin
                                temp_x1 <= seg_start_x[next_idx];
                                temp_y1 <= seg_start_y[next_idx];
                                temp_x2 <= seg_end_x[next_idx];
                                temp_y2 <= seg_end_y[next_idx];
                            end
                            // New segment remains same
                            temp_x3 <= new_seg_start_x; temp_y3 <= new_seg_start_y;
                            temp_x4 <= new_seg_end_x; temp_y4 <= new_seg_end_y;
                            
                            next_state <= CHECK_INTERSECTION;
                        end else begin
                            // All segments checked, no collision.
                            // Add segment to storage and update state.
                            if (seg_count < 8) begin
                                seg_start_x[seg_count] <= new_seg_start_x;
                                seg_start_y[seg_count] <= new_seg_start_y;
                                seg_end_x[seg_count] <= new_seg_end_x;
                                seg_end_y[seg_count] <= new_seg_end_y;
                                seg_count <= seg_count + 1;
                            end
                            bend_count <= bend_count + 1;
                            
                            if (bend_count == 7) begin // 8 bends done
                                done <= 1;
                                next_state <= DONE;
                            end else begin
                                next_state <= WAIT_BEND_VALID_LOW;
                            end
                        end
                    end
                end

                WAIT_BEND_VALID_LOW: begin
                    if (!bend_valid) next_state <= READ_BEND;
                    else next_state <= WAIT_BEND_VALID_LOW;
                end

                GHOST_DETECTED: begin
                    ghost <= 1; done <= 1;
                    if (!start) next_state <= IDLE;
                    else next_state <= GHOST_DETECTED;
                end

                DONE: begin
                    done <= 1;
                    if (!start) next_state <= IDLE;
                    else next_state <= DONE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule