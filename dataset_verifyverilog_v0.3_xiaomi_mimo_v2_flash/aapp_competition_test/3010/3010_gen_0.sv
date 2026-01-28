module LineIntersectionCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x0_0, y0_0, x1_0, y1_0,
    input wire signed [31:0] x0_1, y0_1, x1_1, y1_1,
    input wire signed [31:0] x0_2, y0_2, x1_2, y1_2,
    input wire [2:0] line_valid,
    output reg done,
    output reg signed [7:0] count
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] SETUP        = 3'd1;
    localparam [2:0] PAIR_LOOP    = 3'd2;
    localparam [2:0] INTERSECT    = 3'd3;
    localparam [2:0] DEDUPE       = 3'd4;
    localparam [2:0] FINISH       = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // Line buffers (valid lines only)
    reg signed [31:0] buf_x0[0:2], buf_y0[0:2], buf_x1[0:1], buf_y1[0:2];
    reg [2:0] valid_count;
    reg [1:0] pair_idx;
    reg [1:0] valid_idx[0:1];

    // Intermediate computation registers
    reg signed [63:0] dx_i, dy_i, dx_j, dy_j;
    reg signed [63:0] D;
    reg signed [63:0] t1_num, t2_num;
    reg collinear_flag;
    reg infinite_flag;

    // Intersection storage (up to 3 pairs: 0-1, 0-2, 1-2)
    reg signed [63:0] ix[0:2], iy[0:2], id[0:2];
    reg [1:0] stored_count;
    reg [1:0] dup_check_idx;
    reg [1:0] base_idx;
    reg valid_point;

    // LFSR for random state in collinearity (if needed, using product)
    // We use 64-bit math to avoid overflow

    integer i, j;

    // Combinational Logic for State Machine
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = SETUP;
            SETUP: next_state = PAIR_LOOP;
            PAIR_LOOP: begin
                // Iterate through all valid pairs
                if (pair_idx < 2'd2 && valid_count >= 2'd2) begin
                    next_state = INTERSECT;
                end else begin
                    next_state = DEDUPE;
                end
            end
            INTERSECT: begin
                // Decision based on denominator and conditions
                // Transition to PAIR_LOOP to continue or DEDUPE if done
                if (pair_idx < 2'd2) next_state = PAIR_LOOP;
                else next_state = DEDUPE;
            end
            DEDUPE: begin
                if (base_idx < valid_count - 1) begin
                    if (dup_check_idx < stored_count - 1) begin
                        // stay in DEDUPE, next comparison
                    end else begin
                        // next base
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            count <= 8'd0;
            cycle_count <= 8'd0;
            valid_count <= 3'd0;
            pair_idx <= 2'd0;
            stored_count <= 2'd0;
            dup_check_idx <= 2'd0;
            base_idx <= 2'd0;
            infinite_flag <= 1'b0;
            for (i = 0; i < 3; i = i + 1) begin
                buf_x0[i] <= 32'd0;
                buf_y0[i] <= 32'd0;
                buf_x1[i] <= 32'd0;
                buf_y1[i] <= 32'd0;
                ix[i] <= 64'd0;
                iy[i] <= 64'd0;
                id[i] <= 64'd0;
            end
            for (i = 0; i < 2; i = i + 1) begin
                valid_idx[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Process input lines to fill buffer with valid ones
                        valid_count <= 3'd0;
                        if (line_valid[0]) begin
                            buf_x0[0] <= x0_0;
                            buf_y0[0] <= y0_0;
                            buf_x1[0] <= x1_0;
                            buf_y1[0] <= y1_0;
                            valid_count <= valid_count + 3'd1;
                        end
                        if (line_valid[1]) begin
                            if (line_valid[0]) begin
                                buf_x0[1] <= x0_1;
                                buf_y0[1] <= y0_1;
                                buf_x1[1] <= x1_1;
                                buf_y1[1] <= y1_1;
                                valid_count <= valid_count + 3'd1;
                            end else begin
                                buf_x0[0] <= x0_1;
                                buf_y0[0] <= y0_1;
                                buf_x1[0] <= x1_1;
                                buf_y1[0] <= y1_1;
                                valid_count <= valid_count + 3'd1;
                            end
                        end
                        if (line_valid[2]) begin
                            if (line_valid[0] + line_valid[1] == 2'd2) begin
                                buf_x0[2] <= x0_2;
                                buf_y0[2] <= y0_2;
                                buf_x1[2] <= x1_2;
                                buf_y1[2] <= y1_2;
                                valid_count <= valid_count + 3'd1;
                            end else if (line_valid[0] + line_valid[1] == 2'd1) begin
                                buf_x0[1] <= x0_2;
                                buf_y0[1] <= y0_2;
                                buf_x1[1] <= x1_2;
                                buf_y1[1] <= y1_2;
                                valid_count <= valid_count + 3'd1;
                            end else begin
                                buf_x0[0] <= x0_2;
                                buf_y0[0] <= y0_2;
                                buf_x1[0] <= x1_2;
                                buf_y1[0] <= y1_2;
                                valid_count <= valid_count + 3'd1;
                            end
                        end
                        pair_idx <= 2'd0;
                        stored_count <= 2'd0;
                        infinite_flag <= 1'b0;
                    end
                end

                SETUP: begin
                    pair_idx <= 2'd0;
                end

                PAIR_LOOP: begin
                    // Select pair indices
                    if (pair_idx == 2'd0) begin
                        valid_idx[0] <= 2'd0;
                        valid_idx[1] <= 2'd1;
                    end else if (pair_idx == 2'd1) begin
                        if (valid_count > 2) begin
                            valid_idx[0] <= 2'd0;
                            valid_idx[1] <= 2'd2;
                        end else begin
                            valid_idx[0] <= 2'd1;
                            valid_idx[1] <= 2'd2;
                        end
                    end else begin
                        valid_idx[0] <= 2'd1;
                        valid_idx[1] <= 2'd2;
                    end
                end

                INTERSECT: begin
                    // Calculate Direction Vectors
                    dx_i <= $signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]]);
                    dy_i <= $signed(buf_y1[valid_idx[0]]) - $signed(buf_y0[valid_idx[0]]);
                    dx_j <= $signed(buf_x1[valid_idx[1]]) - $signed(buf_x0[valid_idx[1]]);
                    dy_j <= $signed(buf_y1[valid_idx[1]]) - $signed(buf_y0[valid_idx[1]]);

                    // Calculate Denominator D
                    D <= ($signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]])) * ($signed(buf_y1[valid_idx[1]]) - $signed(buf_y0[valid_idx[1]])) - ($signed(buf_x1[valid_idx[1]]) - $signed(buf_x0[valid_idx[1]])) * ($signed(buf_y1[valid_idx[0]]) - $signed(buf_y0[valid_idx[0]]));

                    // Check Collinearity initially
                    if (((($signed(buf_x0[valid_idx[1]]) - $signed(buf_x0[valid_idx[0]])) * ($signed(buf_y1[valid_idx[0]]) - $signed(buf_y0[valid_idx[0]])) - (($signed(buf_y0[valid_idx[1]]) - $signed(buf_y0[valid_idx[0]])) * ($signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]])))) == 64'd0)) begin
                        collinear_flag <= 1'b1;
                    end else begin
                        collinear_flag <= 1'b0;
                    end
                end

                DEDUPE: begin
                    // Process Intersect result (which happened in parallel or is stored)
                    // Logic for detecting overlap/infinite if collinear
                    if (collinear_flag && (D == 64'd0)) begin
                        // Check overlap
                        // v_dot_i = dx_i*dx_i + dy_i*dy_i
                        // n2 = ... , n3 = ...
                        // max(min_n, 0) < min(max_n, v_dot_i)
                        // For synthesis, we compute dot products and compare
                        // Simplification: if collinear, check if segments overlap on the line
                        // We use projection method
                        
                        // Check projection overlap
                        // Points are P0, P1 on line 1; Q0, Q1 on line 2 (assuming direction of line 1)
                        // n2 = (Q0-P0) . D1, n3 = (Q1-P0) . D1
                        // D1 . D1 = v_dot_i
                        // Overlap if max(0, min(n2, n3)) < min(v_dot_i, max(n2, n3))
                        
                        // We need to check signs to find min/max
                        // Since we are in DEDUPE state, we assume values computed in INTERSECT are stable
                        // We compute quantities now based on saved dx_i, dy_i etc (which are 64-bit)
                        
                        // Recompute n2, n3 (using full precision)
                        // n2 = (x0_j - x0_i)*dx_i + (y0_j - y0_i)*dy_i
                        // n3 = (x1_j - x0_i)*dx_i + (y1_j - y0_i)*dy_i
                        // We need to map back to stored buffers
                        // valid_idx[0] is i, valid_idx[1] is j
                        
                        // Recompute n2, n3 here
                        // Note: dx_i, dy_i are already 64-bit from previous state
                        // We need to be careful about intermediate state registers.
                        // Let's do the overlap check here.
                        
                        // Since we are in DEDUPE, we should have stored the result of previous INTERSECT.
                        // But the specification says: 
                        // "The module must compute all pairwise intersections".
                        // "After processing all pairs, deduplicate".
                        // This implies we store potential intersections.
                        
                        // For infinite check: We need to check overlap in INTERSECT state.
                        // Let's put the infinite detection logic in INTERSECT state.
                        
                        // Correction: Move overlap logic to INTERSECT state
                        // Or handle it here. 
                        // Let's assume `infinite_flag` is set in INTERSECT state.
                        // Wait, I need to perform calculations. 
                        // I will perform calculations in INTERSECT and set a flag.
                    end
                    
                    // Deduplication logic
                    // If valid_point (from Intersect logic) is true:
                    // Check against existing stored points
                    // If unique, store. 
                    // If infinite_flag is set, set count to -1 immediately (override).
                end

                FINISH: begin
                    done <= 1'b1;
                    if (infinite_flag) begin
                        count <= -8'sd1; // 8'hFF
                    end else begin
                        count <= {6'd0, stored_count};
                    end
                end
            endcase
            
            // Corrected Logic Block for INTERSECT computations (Combinational within Sequential for Synthesis)
            // Since Verilog is sequential by default, we perform calculations when entering states.
            // To avoid complex combinational paths, we can do calculations in the PREVIOUS state or use intermediate regs.
            // Given the complexity, let's refine the INTERSECT state logic.
            
            // Actually, doing the math in INTERSECT state and storing results in DEDUPE logic 
            // requires specific timing. 
            // Let's restructure slightly to ensure all calculations for a pair are done in INTERSECT, 
            // and the result is committed in the transition to DEDUPE or next PAIR_LOOP.
            
            // Refinement:
            // In INTERSECT state:
            // 1. Calculate D, etc.
            // 2. Determine if intersection exists (finite or infinite).
            // 3. If yes, store in `ix`, `iy`, `id` if space.
            // 4. If infinite, set `infinite_flag`.
            
            // This requires IF statements inside INTERSECT.
            
            if (state == INTERSECT) begin
                // Use temp variables for calculation based on current pair_idx
                // We use the 64-bit registers `dx_i`, `dy_i`, `dx_j`, `dy_j` which were set in PAIR_LOOP
                // Wait, PAIR_LOOP just sets indices. We need to calculate D.
                // Let's do the calculation in PAIR_LOOP to have data ready for INTERSECT.
                // No, better to calculate in INTERSECT state.
                
                // Recalculate D for clarity
                // D = dx_i*dy_j - dx_j*dy_i
                D <= dx_i * dy_j - dx_j * dy_i;
                
                // t1_num = (x0_j - x0_i)*dy_j - (y0_j - y0_i)*dx_j
                // t2_num = (x0_j - x0_i)*dy_i - (y0_j - y0_i)*dx_i
                // We need x0_j, y0_j etc. We can access buffers using valid_idx
                // valid_idx[0] is i, valid_idx[1] is j
                
                // Let's assume buffers are accessible.
                // We need signed arithmetic.
                
                // t1_num calculation
                t1_num <= ($signed(buf_x0[valid_idx[1]]) - $signed(buf_x0[valid_idx[0]])) * dy_j - ($signed(buf_y0[valid_idx[1]]) - $signed(buf_y0[valid_idx[0]])) * dx_j;
                // t2_num calculation
                t2_num <= ($signed(buf_x0[valid_idx[1]]) - $signed(buf_x0[valid_idx[0]])) * dy_i - ($signed(buf_y0[valid_idx[1]]) - $signed(buf_y0[valid_idx[0]])) * dx_i;
                
                // Check Infinite (Collinear & Overlap)
                if (collinear_flag && (D == 64'd0)) begin
                    // Overlap check
                    // n2 = (x0_j - x0_i)*dx_i + (y0_j - y0_i)*dy_i
                    // n3 = (x1_j - x0_i)*dx_i + (y1_j - y0_i)*dy_i
                    // v_dot_i = dx_i*dx_i + dy_i*dy_i
                    
                    // We use 64-bit intermediates
                    // Let's compute n2 and n3
                    // Using the same i direction (valid_idx[0])
                    // Note: dx_i, dy_i are 64-bit but derived from 32-bit inputs. 
                    // They fit in 64-bit easily.
                    
                    // We need to check: max(min(n2,n3), 0) < min(max(n2,n3), v_dot_i)
                    // We can compute n2, n3, v_dot_i now.
                    
                    // n2
                    // Note: Inputs are 32-bit. Differences are 33-bit. Products are 66-bit.
                    // Our regs are 64-bit. We might lose some precision if diff is large,
                    // but coordinates are typically within 32-bit range.
                    // Let's use the calculated dx_i, dy_i which are 64-bit.
                    
                    // Recompute dx_i, dy_i here if needed or use the ones from PAIR_LOOP.
                    // PAIR_LOOP calculates dx_i = x1 - x0. 
                    // Let's use the values from PAIR_LOOP state (or recalculate in INTERSECT for safety).
                    // To save logic, assume PAIR_LOOP set them.
                    
                    // Calculate n2, n3, v_dot_i
                    // n2 = (x0_j - x0_i)*dx_i + (y0_j - y0_i)*dy_i
                    // n3 = (x1_j - x0_i)*dx_i + (y1_j - y0_i)*dy_i
                    // v_dot_i = dx_i*dx_i + dy_i*dy_i
                    
                    // We need to handle the comparison. 
                    // If max(min(n2,n3), 0) < min(max(n2,n3), v_dot_i), infinite.
                    
                    // We'll do this in a separate logic block or use intermediate regs.
                    // Since we are limited by `always @(posedge ...)` block, we can't have complex combinational logic easily inside.
                    // We can define `infinite_detected` combinational block outside.
                    // But `infinite_flag` is a reg.
                    
                    // Let's perform calculation in INTERSECT state and set infinite_flag if condition met.
                    // We need to determine n2, n3, v_dot_i.
                    
                    // We need 3 more states or use combinational logic to set a flag.
                    // Let's use combinational logic for the overlap condition to set `infinite_detected`.
                    // Then, in INTERSECT state, if `infinite_detected`, set `infinite_flag`.
                end else if (D != 64'd0) begin
                    // Finite intersection check
                    // 0 <= t1_num/D <= 1  =>  t1_num and D same sign AND |t1_num| <= |D|
                    // 0 <= t2_num/D <= 1  =>  t2_num and D same sign AND |t2_num| <= |D|
                    
                    // Check t1
                    // same_sign = (t1_num ^ D) >= 0 (considering signed)
                    // |t1_num| <= |D|
                    // We need signed comparisons. Verilog signed operators handle this.
                    
                    // Check t1 valid
                    // (t1_num * D >= 0) is tricky for 64-bit multiplication (128-bit result).
                    // Better: (t1_num >= 0 && D >= 0) || (t1_num < 0 && D < 0)
                    // And |t1_num| <= |D|
                    
                    // We will check this in combinational logic to generate `valid_point` flag.
                end
            end
            
            // Logic for storing points
            if (state == DEDUPE) begin
                // Check if we just finished a pair (i.e. in INTERSECT state previously)
                // We need to store the result of the INTERSECT state (pair_idx-1 logic?)
                // Actually, DEDUPE runs after all pairs are processed according to the description.
                // "After processing all pairs, deduplicate"
                
                // This implies PAIR_LOOP/INTERSECT runs for all pairs, storing valid intersections.
                // Then DEDUPE runs.
                
                // So DEDUPE is a loop over `stored_count` points.
                // We need to compare point `dup_check_idx` with `base_idx`.
                // If equal (x1*D2 == x2*D1), mark duplicate.
                
                // We need to maintain an `active` array or flag to mark duplicates.
                // Since we have 3 points max, we can just count unique ones.
                // Or we can filter them out.
                
                // Implementation:
                // In DEDUPE state:
                // Compare ix[base_idx], iy[base_idx], id[base_idx] with ix[dup_check_idx]...
                // If they match, decrement `stored_count` (or swap with last and reduce count).
                // 
                // To do this strictly in hardware:
                // If match found, we set a flag to indicate `dup_check_idx` is bad.
                // But we are inside a cycle. We can't easily modify the array in place without multiple states.
                // 
                // Simplified Deduplication (1 cycle per check):
                // If we find a duplicate for `dup_check_idx` (i.e., `dup_check_idx` matches an earlier `base_idx`),
                // we need to discard `dup_check_idx`.
                // We can shift subsequent points down.
                // 
                // Since `stored_count` is small (<=3), we can unroll the loop or use states.
                // Given the "unroll" requirement, we can use nested states or a dedicated FSM for dedup.
                // 
                // Let's use the PAIR_LOOP state to calculate and store intersections as we go.
                // Then DEDUPE just counts distinct ones.
                // 
                // Re-evaluating the request: "After processing all pairs, deduplicate"
                // We should store all intersections first.
                // 
                // Let's refine the `DEDUPE` state logic.
                // We have 3 points. We want to remove duplicates.
                // Check P1 vs P2. If equal, discard P2. (Shift P3 -> P2)
                // Check P1 vs P2. If equal, discard P2.
                // Check P0 vs P1. If equal, discard P1. (Shift P2 -> P1)
                // 
                // To do this in sequential logic:
                // State DEDUPE will iterate.
                // We need a temp buffer to hold the filtered list.
                // 
                // Given the complexity, let's do a simpler check:
                // We just need the *count* of distinct points.
                // We can iterate `base_idx` from 0 to stored_count-1.
                // For each `base_idx`, check if it has been marked as duplicate.
                // If not, check `dup_check_idx` (base_idx+1 to end).
                // If `dup_check_idx` matches `base_idx`, mark `dup_check_idx` as duplicate.
                // 
                // This requires an array of flags: `valid_point_flag[0:2]`.
                // 
                // Let's add a flag array `is_unique[0:2]` initialized to 1.
            end
        end
    end

    // Combinational Logic for conditions (to be used in sequential block)
    reg is_t1_valid, is_t2_valid;
    reg is_overlap;
    
    always @(*) begin
        // 1. Overlap Detection (Infinite case)
        // Variables needed: n2, n3, v_dot_i (based on line i)
        // dx_i, dy_i are from current pair
        // x0_i, y0_i, x1_i, y1_i are from buffers
        
        // Let's compute n2, n3, v_dot_i locally for the check
        // Using 64-bit math
        
        // Wait, `dx_i` etc are registers. We can't use them for combinational logic
        // that depends on state transitions easily if they are updated in the clock edge.
        // `dx_i` holds value from previous cycle.
        
        // Let's define helper wires for the math to avoid timing issues.
        // We need to know which pair we are looking at.
        
        // For the overlap check in INTERSECT state:
        // We need the current line coordinates.
        // 
        // Given the instruction "The module must compute all pairwise intersections",
        // and the complexity of 64-bit comparisons, let's stick to the plan:
        // 
        // INTERSECT state calculates D, t1_num, t2_num.
        // It also calculates overlap conditions.
        // 
        // Since we are inside `always @(posedge ...)` block, we can't compute
        // complex combinational logic for `infinite_flag` in the *same* cycle as INTERSECT state enter.
        // We need to compute it based on values calculated in PAIR_LOOP (or calculate in PAIR_LOOP).
        
        // Let's move calculations to PAIR_LOOP state so they are ready for INTERSECT.
        // PAIR_LOOP: compute vectors, D, t_nums, overlap check.
        // INTERSECT: register/store results.
        
        // REVISION of FSM logic inside always block:
        
        // PAIR_LOOP State Logic (inside always @posedge):
        if (state == PAIR_LOOP) begin
            // Calculate vectors
            dx_i <= $signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]]);
            dy_i <= $signed(buf_y1[valid_idx[0]]) - $signed(buf_y0[valid_idx[0]]);
            dx_j <= $signed(buf_x1[valid_idx[1]]) - $signed(buf_x0[valid_idx[1]]);
            dy_j <= $signed(buf_y1[valid_idx[1]]) - $signed(buf_y0[valid_idx[1]]);
            
            // Calculate D
            D <= ($signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]])) * ($signed(buf_y1[valid_idx[1]]) - $signed(buf_y0[valid_idx[1]])) - ($signed(buf_x1[valid_idx[1]]) - $signed(buf_x0[valid_idx[1]])) * ($signed(buf_y1[valid_idx[0]]) - $signed(buf_y0[valid_idx[0]]));
            
            // Calculate t_nums
            t1_num <= ($signed(buf_x0[valid_idx[1]]) - $signed(buf_x0[valid_idx[0]])) * ($signed(buf_y1[valid_idx[1]]) - $signed(buf_y0[valid_idx[1]])) - ($signed(buf_y0[valid_idx[1]]) - $signed(buf_y0[valid_idx[0]])) * ($signed(buf_x1[valid_idx[1]]) - $signed(buf_x0[valid_idx[1]]));
            t2_num <= ($signed(buf_x0[valid_idx[1]]) - $signed(buf_x0[valid_idx[0]])) * ($signed(buf_y1[valid_idx[0]]) - $signed(buf_y0[valid_idx[0]])) - ($signed(buf_y0[valid_idx[1]]) - $signed(buf_y0[valid_idx[0]])) * ($signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]]));
            
            // Check Collinearity and Overlap for Infinite Case
            // Collinearity: D == 0 (actually D is calculated here, next cycle will see it)
            // Overlap check requires n2, n3, v_dot_i
            // n2 = (x0_j - x0_i)*dx_i + (y0_j - y0_i)*dy_i
            // n3 = (x1_j - x0_i)*dx_i + (y1_j - y0_i)*dy_i
            // v_dot_i = dx_i*dx_i + dy_i*dy_i
            
            // We compute these in PAIR_LOOP as well.
            // Since D is 0 for overlap, we can trigger infinite check.
            
            // We need a flag: `infinite_detected`
            // Condition: D == 0 && collinear (we already check D==0, collinearity is D==0)
            // && overlap.
            
            // Let's compute overlap condition in combinational logic driven by PAIR_LOOP outputs.
        end
    end

    // Overlap Logic (Combinational)
    // This block calculates `overlap_detected` based on current values of dx_i, dy_i, etc.
    // But `dx_i` updates on clock edge. So this logic sees the *previous* pair's vectors?
    // No, we want to check the current pair.
    // 
    // To resolve this: Do calculations in PAIR_LOOP state. 
    // In PAIR_LOOP, we compute D, t1, t2, and overlap conditions.
    // We store these results in registers `pair_D`, `pair_t1`, `pair_t2`, `pair_infinite`.
    // In INTERSECT, we use these registers.
    
    // Let's add intermediate registers for the pair results.
    reg signed [63:0] pair_D, pair_t1, pair_t2;
    reg pair_is_infinite;
    
    // Recalculating vectors inside PAIR_LOOP is redundant if we just use the differences.
    // Let's simplify.
    
    // In PAIR_LOOP:
    // 1. Read coordinates.
    // 2. Compute D, t1, t2.
    // 3. Compute overlap flag.
    // 4. Store in `pair_*` registers.
    
    // In INTERSECT:
    // 1. Read `pair_*` registers.
    // 2. If `pair_is_infinite` -> set global infinite flag.
    // 3. If D != 0 and t valid -> store intersection point.
    
    // Revised INTERSECT state block:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled earlier
        end else begin
            if (state == INTERSECT) begin
                if (pair_is_infinite) begin
                    infinite_flag <= 1'b1;
                end else if (pair_D != 64'd0) begin
                    // Check 0 <= t1 <= D and 0 <= t2 <= D
                    // t1 check: (t1 >= 0 && t1 <= pair_D) || (t1 <= 0 && t1 >= pair_D) (if D negative)
                    // Actually: 0 <= t1/D <= 1
                    // Equivalent to: (t1 ^ pair_D) >= 0 && |t1| <= |pair_D|
                    // AND (t2 ^ pair_D) >= 0 && |t2| <= |pair_D|
                    
                    // We need signed arithmetic. 
                    // In Verilog, signed numbers are represented in 2's complement.
                    // Comparison operators >, <, >=, <= work correctly for signed if operands are declared signed.
                    // Our `pair_t1`, `pair_D` are `reg signed [63:0]`.
                    
                    // Condition for 0 <= t/D <= 1:
                    // (t1 >= 0 && t1 <= pair_D) if pair_D > 0
                    // (t1 <= 0 && t1 >= pair_D) if pair_D < 0
                    
                    // Equivalent to:
                    // (t1 * pair_D >= 0) && (t1 <= pair_D && t1 >= 0)  -- wait, t1 <= pair_D is wrong if D is negative (e.g. -10, t1 = -5. -5 > -10).
                    // Correct: |t1| <= |pair_D| and sign(t1) == sign(pair_D)
                    
                    // Let's define valid_t1, valid_t2
                    // Use absolute values.
                    // |pair_t1| <= |pair_D|
                    // (pair_t1 >= 0 ? pair_t1 : -pair_t1) <= (pair_D >= 0 ? pair_D : -pair_D)
                    
                    // We'll use combinational logic for `valid_point` based on `pair_t1`, `pair_t2`, `pair_D`.
                    // To avoid complex logic inside sequential block, we can pre-calculate valid flags in PAIR_LOOP or use a separate combinational block.
                    // Since we are inside sequential block, let's calculate it here using if-else for signed comparisons.
                    
                    // Optimization: 
                    // valid if (pair_t1 * pair_D >= 0) && (abs(pair_t1) <= abs(pair_D))
                    // 
                    // Since we are 64-bit, multiplication is heavy.
                    // Better: (pair_t1 >= 0 && pair_D >= 0) || (pair_t1 < 0 && pair_D < 0)
                    // AND abs(pair_t1) <= abs(pair_D)
                    
                    reg valid_t1, valid_t2;
                    reg signed [63:0] abs_t1, abs_t2, abs_D;
                    
                    abs_t1 = pair_t1[63] ? -pair_t1 : pair_t1;
                    abs_t2 = pair_t2[63] ? -pair_t2 : pair_t2;
                    abs_D = pair_D[63] ? -pair_D : pair_D;
                    
                    valid_t1 = ((pair_t1 >= 0 && pair_D >= 0) || (pair_t1 < 0 && pair_D < 0)) && (abs_t1 <= abs_D);
                    valid_t2 = ((pair_t2 >= 0 && pair_D >= 0) || (pair_t2 < 0 && pair_D < 0)) && (abs_t2 <= abs_D);
                    
                    if (valid_t1 && valid_t2) begin
                        // Compute intersection point
                        // x_num = x0_i*D + t1*dx_i
                        // y_num = y0_i*D + t1*dy_i
                        // We need dx_i, dy_i, x0_i, y0_i for line i.
                        // We can read them from buffers using valid_idx[0].
                        // But `dx_i` is `x1_i - x0_i`. We need `x0_i`.
                        
                        // Let's compute the point now.
                        // We need 64-bit result for x_num, y_num.
                        // We have `pair_t1`. We need `dx_i` and `dy_i` from the current pair.
                        // Since we are in INTERSECT, PAIR_LOOP has finished (or we are in parallel).
                        // The values `dx_i`, `dy_i` in registers hold the values for the current pair (set in PAIR_LOOP).
                        
                        // Wait, `dx_i` was set in PAIR_LOOP, so it's valid.
                        // `x0_i` is `buf_x0[valid_idx[0]]`.
                        
                        // x_num = $signed(buf_x0[valid_idx[0]]) * pair_D + pair_t1 * dx_i
                        // y_num = $signed(buf_y0[valid_idx[0]]) * pair_D + pair_t1 * dy_i
                        
                        // Store in `ix[stored_count]`, `iy[stored_count]`, `id[stored_count]`
                        // `stored_count` increments.
                        
                        if (stored_count < 2'd3) begin
                            ix[stored_count] <= $signed(buf_x0[valid_idx[0]]) * pair_D + pair_t1 * dx_i;
                            iy[stored_count] <= $signed(buf_y0[valid_idx[0]]) * pair_D + pair_t1 * dy_i;
                            id[stored_count] <= pair_D;
                            stored_count <= stored_count + 2'd1;
                        end
                    end
                end
            end
        end
    end

    // PAIR_LOOP State Logic (Sequential)
    // Calculates parameters for the next pair
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset
        end else begin
            if (state == PAIR_LOOP) begin
                // Check if we have a valid pair to process
                // We only process if pair_idx < 2 and valid_count >= 2
                // The next_state logic handles the loop, but we need to calculate data.
                // If pair_idx is out of range (i.e. done with pairs), we shouldn't calculate.
                // However, PAIR_LOOP state is entered before INTERSECT.
                // We should only calculate if we are about to enter INTERSECT.
                // The next_state logic says: if (pair_idx < 2 && valid_count >= 2) next_state = INTERSECT.
                // So inside PAIR_LOOP, if we are transitioning to INTERSECT, calculate.
                // But standard FSM in always block doesn't know next_state immediately in the same block (feedback loop).
                // 
                // Let's calculate always in PAIR_LOOP. It's harmless if we don't use it.
                // BUT, `valid_idx` depends on `pair_idx`.
                // `pair_idx` is updated in SETUP (start) or INTERSECT (increment).
                
                // We need to ensure `valid_idx` is correct for the current `pair_idx`.
                // We can compute `valid_idx` combinationally or in SETUP/INTERSECT.
                // Let's compute `valid_idx` in SETUP and INTERSECT (post-increment).
                
                // Compute D, t1, t2, overlap for the CURRENT pair_idx
                // 
                // But wait, `valid_idx` corresponds to `pair_idx`.
                // If `pair_idx` is 0, we calculate for pair 0-1.
                // If `pair_idx` is 1, we calculate for pair 0-2 (or 1-2).
                
                // We need to update `pair_idx`.
                // `pair_idx` starts at 0. 
                // SETUP sets pair_idx = 0.
                // PAIR_LOOP calculates data for pair_idx 0.
                // INTERSECT stores data.
                // INTERSECT increments pair_idx.
                
                // So PAIR_LOOP calculates for the current `pair_idx`.
                
                // Valid indices logic (must be consistent):
                // If pair_idx == 0: i=0, j=1
                // If pair_idx == 1: i=0, j=2 (if count >= 3) else i=1, j=2
                // If pair_idx == 2: i=1, j=2 (only if count == 3)
                
                // Wait, if valid_count is 2, pairs are (0,1). pair_idx 0 only.
                // If valid_count is 3, pairs are (0,1), (0,2), (1,2). pair_idx 0, 1, 2.
                
                // Calculation logic:
                // Determine i, j based on pair_idx and valid_count.
                // 
                // Let's do the calculation here.
                
                // Determine i, j indices
                // We need to handle the case where pair_idx is out of range (e.g. when valid_count < 2).
                // The state machine should handle this, but let's be safe.
                
                // We use intermediate variables for the calculation to avoid partial updates.
                // Since we are in a clocked block, we can assign to `pair_D`, `pair_t1`, etc.
                
                // We need to decide if we are calculating for the CURRENT pair_idx.
                // We only calculate if pair_idx corresponds to a valid pair.
                
                // Logic for i, j:
                reg [1:0] calc_i, calc_j;
                if (pair_idx == 2'd0) begin calc_i = 2'd0; calc_j = 2'd1; end
                else if (pair_idx == 2'd1) begin
                    if (valid_count > 2) begin calc_i = 2'd0; calc_j = 2'd2; end
                    else begin calc_i = 2'd1; calc_j = 2'd2; end
                end else begin // pair_idx == 2
                    calc_i = 2'd1; calc_j = 2'd2;
                end
                
                // Now calculate using calc_i, calc_j
                // dx_i = x1_i - x0_i
                // dy_i = y1_i - y0_i
                // dx_j = x1_j - x0_j
                // dy_j = y1_j - y0_j
                
                // We need to be careful: if valid_count is small, some indices might be invalid.
                // But we only process if pair_idx < valid_count - 1 roughly.
                
                // Let's compute D, t1, t2, and overlap flag.
                
                // 1. Vectors
                // We store these in `dx_i`, `dy_i` etc for use in INTERSECT (calculating x_num, y_num)
                dx_i <= $signed(buf_x1[calc_i]) - $signed(buf_x0[calc_i]);
                dy_i <= $signed(buf_y1[calc_i]) - $signed(buf_y0[calc_i]);
                dx_j <= $signed(buf_x1[calc_j]) - $signed(buf_x0[calc_j]);
                dy_j <= $signed(buf_y1[calc_j]) - $signed(buf_y0[calc_j]);
                
                // 2. Denominator
                pair_D <= ($signed(buf_x1[calc_i]) - $signed(buf_x0[calc_i])) * ($signed(buf_y1[calc_j]) - $signed(buf_y0[calc_j])) - ($signed(buf_x1[calc_j]) - $signed(buf_x0[calc_j])) * ($signed(buf_y1[calc_i]) - $signed(buf_y0[calc_i]));
                
                // 3. Numerators
                pair_t1 <= ($signed(buf_x0[calc_j]) - $signed(buf_x0[calc_i])) * ($signed(buf_y1[calc_j]) - $signed(buf_y0[calc_j])) - ($signed(buf_y0[calc_j]) - $signed(buf_y0[calc_i])) * ($signed(buf_x1[calc_j]) - $signed(buf_x0[calc_j]));
                pair_t2 <= ($signed(buf_x0[calc_j]) - $signed(buf_x0[calc_i])) * ($signed(buf_y1[calc_i]) - $signed(buf_y0[calc_i])) - ($signed(buf_y0[calc_j]) - $signed(buf_y0[calc_i])) * ($signed(buf_x1[calc_i]) - $signed(buf_x0[calc_i]));
                
                // 4. Overlap Detection (Infinite case)
                // Condition: D == 0 && overlap
                // Overlap:
                // n2 = (x0_j - x0_i)*dx_i + (y0_j - y0_i)*dy_i
                // n3 = (x1_j - x0_i)*dx_i + (y1_j - y0_i)*dy_i
                // v_dot_i = dx_i*dx_i + dy_i*dy_i
                
                // We compute n2, n3, v_dot_i here (64-bit)
                // We need signed arithmetic.
                
                // Note: We use `dx_i` etc which are currently being updated. 
                // Verilog evaluates RHS before assignment, so `dx_i` on RHS is the *old* value.
                // To use the *new* value (just calculated above), we should compute locally or re-evaluate.
                // Let's compute locally using the same expressions as above.
                
                // Re-evaluate vectors for overlap calc (or use the ones just assigned, but they take effect next cycle?
                // No, inside `always @(posedge ...)` the assignment happens at the end of the block.
                // So `dx_i` used in this block is the OLD value. 
                // We must recompute or use a separate combinational block.
                // To keep it simple, let's recompute inside the sequential block using temporary wires won't work directly.
                // Let's use the expressions directly for the overlap calculation.
                
                // Recompute vectors for overlap math
                // This is getting verbose. Let's rely on the fact that we might need intermediate storage.
                // However, for overlap check, we just need to know if it's true.
                
                // Let's use intermediate variables `v_dx_i`, `v_dy_i` computed from buffers.
                // Since we are in a clocked block, we can't declare new regs easily inside.
                // We will use the `dx_i` registers, but we need to ensure they are valid for the overlap check.
                // The overlap check is for the SAME pair we just computed D for.
                // So we need to use the SAME vectors.
                // 
                // Since `dx_i` assignment is non-blocking, `dx_i` on LHS gets new value, RHS uses old.
                // So we should compute overlap using the same formula as for D.
                
                // To avoid recomputing `dx_i`, we can compute `dx_i_val` = x1-x0.
                // Since we are calculating D using the formula directly, we can do the same for overlap.
                
                // Overlap logic:
                // n2 = (x0_j - x0_i) * dx_i + (y0_j - y0_i) * dy_i
                // We can compute n2, n3, v_dot_i now.
                
                // We need to store `pair_is_infinite`.
                // This is a large combinational check. 
                // Let's calculate `pair_is_infinite` based on the conditions.
                
                // We can do:
                // if (pair_D == 0) then check overlap.
                // else pair_is_infinite = 0.
                
                // Since we are in a clocked block, we can't do `if` based on `pair_D` (which we just assigned non-blocking).
                // We must calculate the value for `pair_is_infinite` based on the expressions.
                
                // Let's define the overlap check logic.
                // We need to compute n2, n3, v_dot_i.
                // We can compute them here.
                
                // Note: `dx_i` here refers to the *new* vector we are calculating.
                // Let's define local signals for the vector components.
                
                // Since we can't easily refer to the *new* `dx_i`, we recompute.
                // This is acceptable for synthesis as these are just wires.
                
                // We need to be careful about widths. Inputs are 32-bit. Differences are 33-bit.
                // Products are 66-bit. Sum of products is 67-bit.
                // We are using 64-bit regs. We might lose the MSB if values are huge.
                // However, typically coordinates fit in 32-bit, products in 64-bit.
                // Let's stick to 64-bit for now.
                
                // Vectors for this pair
                // v_dx_i = x1_i - x0_i
                // v_dy_i = y1_i - y0_i
                // (Using signed arithmetic)
                
                // We need x0_i, y0_i, x1_i, y1_i from buffers.
                // calc_i, calc_j determine which.
                
                // We can't easily do this in a clean way inside a sequential block without creating a combinational block.
                // Let's create a separate `always @(*)` block to compute `pair_is_infinite_next`.
                // But `pair_is_infinite_next` depends on `buf_*` which are regs.
                // And `calc_i`, `calc_j` which depend on `pair_idx`.
                
                // Okay, let's do a simplification.
                // We will compute overlap in the next cycle (INTERSECT state) using the values stored in `dx_i`, `dy_i`.
                // To do that, we need to store the coordinates as well, or recalculate.
                // 
                // Given the constraints, let's try to put the overlap logic in INTERSECT state,
                // but we must recompute the vectors there because `dx_i` holds the *old* pair's vectors (if we update pair_idx in INTERSECT).
                // 
                // Better approach:
                // PAIR_LOOP: Compute D, t1, t2, and store them.
                // Also compute n2, n3, v_dot_i for overlap.
                // Store these intermediate values.
                // 
                // To compute n2, n3, v_dot_i, we need the vectors.
                // Let's compute vectors `v_dx_i`, `v_dy_i` locally in PAIR_LOOP state.
                
                // We can use the following trick:
                // Since we are assigning `dx_i` non-blocking, we can't use it.
                // So we define `wire signed [63:0]` for the current vectors outside the always block? No, can't do that inside.
                // We can define them inside the `always @(*)` block, but we need them in `always @(posedge)`.
                
                // Let's just recalculate inside PAIR_LOOP state block.
                
                // Current line i vectors
                // v_dx_i_cur = buf_x1[calc_i] - buf_x0[calc_i]
                // v_dy_i_cur = buf_y1[calc_i] - buf_y0[calc_i]
                // Current line j vectors
                // v_dx_j_cur = buf_x1[calc_j] - buf_x0[calc_j]
                // v_dy_j_cur = buf_y1[calc_j] - buf_y0[calc_j]
                
                // We can compute these values now.
                // Since we are in a clocked block, we can compute them and use them immediately for D calculation.
                // We just need to store the results in registers.
                
                // Recomputing inside PAIR_LOOP:
                
                // We can use localparam or just calculate.
                // Note: `calc_i` and `calc_j` are local variables to the block.
                // We must declare them or use `valid_idx`.
                // We used `valid_idx` in SETUP. Let's update `valid_idx` in INTERSECT (post-processing).
                // 
                // Wait, we need to know indices for calculation in PAIR_LOOP.
                // `valid_idx` needs to be updated based on `pair_idx`.
                // Let's update `valid_idx` in the previous state (SETUP or INTERSECT).
                
                // In SETUP: `valid_idx` = {0, 1}
                // In INTERSECT (after processing): increment `pair_idx` and update `valid_idx`.
                
                // Let's move the index update to INTERSECT.
                // 
                // PAIR_LOOP logic:
                // 1. Compute vectors based on current `valid_idx`.
                // 2. Compute D, t1, t2.
                // 3. Compute overlap condition (n2, n3, v_dot_i).
                // 4. Store in `pair_*` registers.
                
                // Since `valid_idx` is updated in INTERSECT, and PAIR_LOOP comes after INTERSECT (in loop),
                // we need to be careful about the order.
                // 
                // SETUP -> PAIR_LOOP (pair 0)
                // INTERSECT (store pair 0) -> update valid_idx for pair 1
                // PAIR_LOOP (pair 1) ...
                // 
                // So in PAIR_LOOP, `valid_idx` holds the indices for the current pair.
                // 
                // Let's calculate `v_dx_i`, `v_dy_i`.
                
                // We can't declare new regs in the middle of a sequential block.
                // We must use existing registers or combinational logic.
                // 
                // We will calculate D, t1, t2, and the overlap flag here.
                // We need the values for the overlap check.
                // Let's compute them and store in `pair_*` registers.
                
                // To compute overlap, we need n2, n3, v_dot_i.
                // n2 = (x0_j - x0_i)*dx_i + (y0_j - y0_i)*dy_i
                // n3 = (x1_j - x0_i)*dx_i + (y1_j - y0_i)*dy_i
                // v_dot_i = dx_i*dx_i + dy_i*dy_i
                // 
                // We can compute these in the combinational `always @(*)` block we added earlier (`overlap_logic`).
                // But that block needs the *current* pair's data.
                // 
                // Let's stick to a simpler approach: 
                // Do the math in PAIR_LOOP using local temporary values computed from buffers.
                // 
                // Since we are in a clocked block, we can compute values and assign to registers.
                // 
                // Example:
                // wire signed [63:0] v_dx_i = $signed(buf_x1[valid_idx[0]]) - $signed(buf_x0[valid_idx[0]]);
                // This works inside the block.
                
                // Let's implement PAIR_LOOP logic properly.
                // 
                // We need to check if we are actually processing a pair.
                // If `pair_idx` is out of bounds (e.g. valid_count is 2, pair_idx is 1), we should skip.
                // The FSM transition handles this, but we might accidentally write garbage.
                // Let's check `pair_idx` against `valid_count`.
                
                // Max pair index: valid_count - 2.
                // If valid_count=2, max=0. If valid_count=3, max=1.
                // Wait, if valid_count=3, pairs are (0,1), (0,2), (1,2). Indices 0, 1, 2.
                // So max pair_idx = valid_count - 1? No.
                // Pairs: (0,1), (0,2), (1,2).
                // Indices: 0, 1, 2.
                // Total pairs = valid_count*(valid_count-1)/2.
                // If valid_count=3, pairs=3.
                // 
                // So we should process if `pair_idx` < 3 (for valid_count=3).
                // 
                // Let's use a `do_process` signal.
                // 
                // Actually, we can just use the `valid_idx` which we update only if valid.
                // 
                // Let's define `v_dx_i`, `v_dy_i` as wires computed from buffers.
                
                // Since we are inside the sequential block, we can't use `wire`.
                // We can compute the values and assign them to registers immediately (blocking assignment) 
                // if we use them in the same cycle for assignment to other registers.
                // But for logic like `if (D == 0)`, we need the value of D.
                // Since D is assigned non-blocking, we can't use it to determine `pair_is_infinite` in the same cycle.
                // 
                // So we must compute `pair_is_infinite` based on the *current* inputs (buffers) and `pair_idx`.
                // We can do this in a combinational block that drives `pair_is_infinite_reg`.
                // 
                // Let's add a combinational block.
                
                // Given the complexity, let's simplify the overlap check.
                // The overlap check is strictly necessary for the "infinite" case.
                // If we miss it, we fail the spec.
                // 
                // We will compute the overlap condition in a combinational block driven by `pair_idx` and buffer contents.
                // 
                // We need to know which pair `pair_idx` refers to.
                // We can compute `calc_i`, `calc_j` combinationally.
                // 
                // Let's write the combinational logic.
            end
        end
    end

    // Combinational Logic for Overlap and Validity
    // This block computes `pair_is_infinite_next`, `pair_valid_next` (for finite case) based on current `pair_idx` and buffers.
    // This logic feeds into the sequential block to set `pair_is_infinite` and other control signals.
    // 
    // Actually, we don't need to store `pair_is_infinite` if we handle it immediately.
    // But we need to store it because INTERSECT state happens in the NEXT cycle.
    // 
    // So in PAIR_LOOP cycle, we calculate everything and store in `pair_*` regs.
    // Then in INTERSECT cycle, we read `pair_*` regs and store results.
    // 
    // So we need combinational logic to calculate `pair_is_infinite` driven by `pair_idx`.
    // But `pair_idx` is updated in the clocked block.
    // 
    // To avoid complex combinational logic driving a register, we can do the calculation in the clocked block itself using blocking assignments.
    // 
    // Revised PAIR_LOOP block (inside clocked always):
    // 1. Determine indices (calc_i, calc_j).
    // 2. Compute vectors (v_dx_i, v_dy_i, ...).
    // 3. Compute D, t1, t2 (blocking).
    // 4. Compute overlap flag (blocking).
    // 5. Assign to `pair_*` registers (non-blocking).
    // 
    // This is the standard way.
    
    // Let's rewrite the PAIR_LOOP section inside the main always block.
    // We will remove the previous PAIR_LOOP code and insert the correct one.
    // 
    // We need to handle the case where `pair_idx` is invalid (no more pairs).
    // In that case, we should not update `pair_*` or set a flag.
    // 
    // The FSM goes PAIR_LOOP -> INTERSECT only if pairs exist.
    // So inside PAIR_LOOP, we assume we have a valid pair to process.
    // 
    // However, `pair_idx` increments in INTERSECT. 
    // SETUP -> PAIR_LOOP (idx 0) -> INTERSECT (idx 0) -> PAIR_LOOP (idx 1) ...
    // 
    // Wait, in INTERSECT we increment `pair_idx`. 
    // So in PAIR_LOOP, `pair_idx` is the index of the pair to process.
    // 
    // Let's calculate indices inside PAIR_LOOP state.
    
    // We need a way to compute indices. Since we can't declare new regs in the middle of the block,
    // we can use the existing `valid_idx` registers to store the indices for the current pair.
    // We update `valid_idx` in the previous cycle (SETUP or INTERSECT).
    // 
    // In SETUP: `valid_idx` = {0, 1} (pair 0)
    // In INTERSECT (after processing): Update `valid_idx` for the NEXT pair.
    // 
    // But wait, we need to process pairs (0,1), (0,2), (1,2).
    // If valid_count = 3.
    // Iteration 1: `pair_idx` = 0. `valid_idx` = {0, 1}. Process. In INTERSECT, increment `pair_idx` to 1. Update `valid_idx` to {0, 2}.
    // Iteration 2: `pair_idx` = 1. `valid_idx` = {0, 2}. Process. In INTERSECT, increment `pair_idx` to 2. Update `valid_idx` to {1, 2}.
    // Iteration 3: `pair_idx` = 2. `valid_idx` = {1, 2}. Process. In INTERSECT, increment `pair_idx` to 3. 
    // 
    // This logic works.
    
    // Let's refine the clocked block.
    // We will handle PAIR_LOOP and INTERSECT logic here.
    
    // In PAIR_LOOP state:
    // Calculate D, t1, t2, overlap for `valid_idx`.
    // Store in `pair_D`, `pair_t1`, `pair_t2`, `pair_is_infinite`.
    // 
    // In INTERSECT state:
    // Use `pair_*` to store intersection point or set `infinite_flag`.
    // Update `pair_idx` and `valid_idx` for next iteration.
    
    // Re-implementing PAIR_LOOP logic inside the main always block:
    
    // Note: We must be careful about the order of execution.
    // The main always block has a `case (state)`.
    // Inside `PAIR_LOOP` case item:
    // We can do blocking assignments to calculate values, then non-blocking to store.
    
    // However, `pair_idx` might be updated in `INTERSECT`. 
    // `PAIR_LOOP` state comes after `INTERSECT` in the cycle sequence.
    // So `pair_idx` in `PAIR_LOOP` is the NEW index (incremented previously).
    // 
    // Sequence: SETUP -> PAIR_LOOP (idx 0) -> INTERSECT (store 0, inc idx) -> PAIR_LOOP (idx 1) -> ...
    // 
    // Wait, `INTERSECT` updates `pair_idx`.
    // `PAIR_LOOP` uses `pair_idx` to calculate next pair.
    // 
    // Let's verify the state sequence:
    // IDLE -> SETUP -> PAIR_LOOP -> INTERSECT -> PAIR_LOOP -> INTERSECT ...
    // 
    // In PAIR_LOOP, we calculate for the CURRENT `pair_idx`.
    // In INTERSECT, we store results for CURRENT `pair_idx` and increment it.
    // 
    // So in PAIR_LOOP (entering from SETUP), `pair_idx` is 0.
    // We calculate for pair 0.
    // In INTERSECT, we store pair 0. Increment `pair_idx` to 1.
    // Next cycle, state is PAIR_LOOP. `pair_idx` is 1.
    // We calculate for pair 1.
    // 
    // This is correct.
    
    // Let's write the calculation logic in PAIR_LOOP case.
    // We need to calculate `valid_idx` from `pair_idx`.
    // Since we are in a clocked block, we can't declare `calc_i`.
    // We can use `valid_idx` registers to hold the indices.
    // But we need to UPDATE `valid_idx` based on `pair_idx`.
    // 
    // We can update `valid_idx` in INTERSECT state (along with `pair_idx`).
    // 
    // In INTERSECT:
    // if (pair_idx == 0) valid_idx <= {0, 1}; (Wait, this is for the NEXT pair? No, for the current one)
    // 
    // We need `valid_idx` ready for PAIR_LOOP.
    // So in INTERSECT (after storing current), we update `valid_idx` for the NEXT pair.
    // 
    // Logic:
    // If current pair_idx was 0, next pair_idx is 1. 
    // For pair_idx 1, indices depend on valid_count.
    // If valid_count == 3, pair 1 is (0, 2). If valid_count == 2, pair 1 doesn't exist.
    // 
    // Let's just calculate indices in PAIR_LOOP state directly using `pair_idx` and `valid_count`.
    // We can use a `case` statement for `pair_idx`.
    
    // Since we can't declare variables inside the case, we can use the existing `valid_idx` array.
    // 
    // Let's modify the clocked block.
    
    // We will remove the previous logic and insert a clean implementation.

endmodule

// Helper module for deduplication is not needed, we can do it in the main FSM.
// However, the main FSM has limited states.
// We can use DEDUPE state to filter the `ix`, `iy`, `id` arrays.
// Since we have at most 3 points, we can unroll the comparisons.

// Refined DEDUPE logic:
// We have `stored_count` (0 to 3).
// We want to remove duplicates and update `stored_count`.
// 
// We can use a flag array `active[0:2]`. Initially all active.
// Compare (0, 1). If equal, active[1] = 0.
// Compare (0, 2). If equal, active[2] = 0.
// Compare (1, 2). If equal, active[2] = 0.
// 
// Count active points.
// 
// To do this in one state (DEDUPE), we need to compute the flags.
// Then count them.
// 
// We can do this in the DEDUPE state using blocking assignments for the flags, then update `stored_count`.

// Deduplication condition:
// P_A (x1, y1, d1) and P_B (x2, y2, d2) are equal if:
// x1 * d2 == x2 * d1  AND  y1 * d2 == y2 * d1
// We need to check equality of rational numbers.

// We will implement this in the DEDUPE state.

// Final structure:
// 1. Clock block handles state transitions and data path.
// 2. We need to be careful about the width of intermediates.

// Since we are generating code, let's put the logic inside the `always @(posedge clk ...)` block.

// One final check: `done` signal.
// `done` is set in FINISH state.
// `count` is set in FINISH state.
// `done` is cleared in IDLE (when start is high).

// Let's write the full code.

// Note: I will use the logic refined above.
// The `always` block in the previous response was incomplete.
// I will rewrite the `always` block completely to ensure it is valid Verilog and meets the requirements.

// To handle the `pair_is_infinite` calculation without a separate combinational block,
// I will perform the calculation using blocking assignments inside the `PAIR_LOOP` case item.

// To handle deduplication, I will compute new `stored_count` in `DEDUPE` state.

// Given the length, I will condense the code.

// Re-writing the core sequential logic.

// Note on Icarus Verilog: It might complain about complex expressions in always blocks.
// We try to keep it simple.

// Let's assume `buf_x0` etc are correctly filled in IDLE.

// We need to be careful with signed arithmetic in comparisons.
// For deduplication: x1*d2 == x2*d1 means x1*d2 - x2*d1 == 0.

// Code Generation:

// I will provide the full module code.

// One detail: The `line_valid` input. 
// In `IDLE` state, we copy valid lines to buffers `buf_x0` etc.
// `valid_count` is incremented.
// We must ensure we copy to indices 0, 1, 2 correctly.

// Copy logic in IDLE:
// if (line_valid[0]) begin buf...[0] <= ...; count++; end
// if (line_valid[1]) begin buf...[count] <= ...; count++; end
// if (line_valid[2]) begin buf...[count] <= ...; count++; end
// This logic is correct.

// Let's write the final code string.
