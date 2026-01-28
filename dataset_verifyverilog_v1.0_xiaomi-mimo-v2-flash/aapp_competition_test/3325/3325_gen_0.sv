module WaterHeightCalculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x [0:7],
    input wire [15:0] y [0:7],
    input wire [15:0] D,
    input wire [15:0] L,
    output reg [31:0] water_height,
    output reg valid
);

    // Fixed-point constants (Q16.16)
    localparam [31:0] SCALE_1 = 32'h00010000; // 1.0 in Q16.16
    localparam [31:0] SCALE_1000 = 32'h03E80000; // 1000.0 in Q16.16
    localparam [31:0] MAX_Y_FIXED = 32'h00800000; // 128.0 in Q16.16
    localparam [31:0] ONE_HUNDRED = 32'h00640000; // 100.0 in Q16.16
    localparam [31:0] STEP_FIXED = 32'h00000400; // 0.015625 (~0.01cm precision over 128 range in 100 steps)
    localparam [31:0] ITERATIONS_MAX = 32'd100;

    // FSM States
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] FIND_BOUNDS      = 4'd1;
    localparam [3:0] SETUP_SEARCH     = 4'd2;
    localparam [3:0] INTEGRATE_INIT   = 4'd3;
    localparam [3:0] INTEGRATE_LOOP   = 4'd4;
    localparam [3:0] CHECK_VOLUME     = 4'd5;
    localparam [3:0] UPDATE_SEARCH    = 4'd6;
    localparam [3:0] DONE_STATE       = 4'd7;

    reg [3:0] state, next_state;
    reg [31:0] low, high, mid;
    reg [31:0] current_area, target_area;
    reg [7:0] iter_count;
    reg [7:0] y_step;
    reg [31:0] y_curr, y_prev;
    reg [31:0] width_curr, width_prev;
    reg [31:0] area_sum;
    reg [15:0] y_max;
    reg [15:0] max_idx;

    // Temp registers for intersection calculations
    reg [31:0] x_int0, x_int1;
    reg [31:0] x_left, x_right;
    reg [31:0] slice_area;
    reg [31:0] vol_compare;

    // Edge indices for intersection (simplified: assume top vertices are at max y)
    // Since we scale to depth D, we map polygon y to 0-D range.
    // But spec says polygon coordinates <= 128cm, D <= 100cm.
    // We assume polygon y is scaled to depth D.
    // Spec: "scaled to depth D". Polygon y values are scaled.
    // Input y is 0 to 128. Target H is 0 to max_y.
    // We need to find max_y from inputs.
    
    // Helper logic to find intersection of horizontal line (H) with edge (v0, v1)
    // x = x0 + (H - y0) * (x1 - x0) / (y1 - y0)
    // All Q16.16
    reg [31:0] edge_x0, edge_y0, edge_x1, edge_y1;
    reg [31:0] dx, dy, dh;
    reg signed [63:0] temp_mul;
    reg [31:0] temp_div;
    reg [7:0] edge_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            water_height <= 32'd0;
            valid <= 1'b0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            iter_count <= 8'd0;
            y_step <= 8'd0;
            current_area <= 32'd0;
            target_area <= 32'd0;
            area_sum <= 32'd0;
            y_curr <= 32'd0;
            y_prev <= 32'd0;
            width_curr <= 32'd0;
            width_prev <= 32'd0;
            x_int0 <= 32'd0;
            x_int1 <= 32'd0;
            x_left <= 32'd0;
            x_right <= 32'd0;
            slice_area <= 32'd0;
            y_max <= 16'd0;
            max_idx <= 8'd0;
            edge_idx <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        state <= FIND_BOUNDS;
                        // Find max y and corresponding index for top vertices
                        y_max <= 16'd0;
                        max_idx <= 8'd0;
                        edge_idx <= 8'd0; // Reset counter
                    end
                end

                FIND_BOUNDS: begin
                    // Scan inputs to find max Y (and store index)
                    if (edge_idx < 8) begin
                        // Compare y[edge_idx] with current y_max
                        if ($signed(y[edge_idx]) > $signed(y_max)) begin
                            y_max <= y[edge_idx];
                            max_idx <= edge_idx;
                        end
                        edge_idx <= edge_idx + 8'd1;
                    end else begin
                        state <= SETUP_SEARCH;
                        // Calculate target area: (L * 1000) / D
                        // Volume L (liters) = Area (cm^2) * D (cm) / 1000
                        // Area = (L * 1000) / D
                        // Fixed point: L * 1000
                        temp_mul <= $signed({16'd0, L}) * $signed(SCALE_1000); // Q16.16 * Q16.16 = Q32.32
                        // Wait one cycle for multiply (pipelined logic)
                    end
                end

                SETUP_SEARCH: begin
                    // temp_mul result is in upper 32 bits
                    // Divide by D
                    temp_div <= temp_mul[47:16] / {16'd0, D}; // Q32.16 / Q16.0 = Q16.16
                    // Init Binary Search
                    low <= 32'd0;
                    high <= {16'd0, y_max}; // Convert max y to Q16.16
                    iter_count <= 8'd0;
                    state <= INTEGRATE_INIT;
                    // Wait for division result if needed, or assume combinational
                    target_area <= temp_mul[47:16] / {16'd0, D};
                end

                INTEGRATE_INIT: begin
                    // Setup for trapezoidal integration over y
                    // 100 steps is fixed.
                    y_step <= 8'd0;
                    area_sum <= 32'd0;
                    y_prev <= low;
                    // Calculate width at y=low
                    // We need to calculate intersection of horizontal line at low with polygon edges
                    // To save logic, we will do this in the loop for both y_prev and y_curr
                    // But here we calculate width_prev once
                    width_prev <= 32'd0; // Assume closed base (width=0 at bottom if y=0)
                    // Actually, if low > 0, we need proper width. 
                    // Optimization: Search range is 0 to max_y. Base is at 0.
                    // If low is 0, width is 0 (unless base is not at 0? Spec says base vertices at y=0).
                    // Spec: "exactly two base vertices at y=0".
                    width_prev <= 32'd0; 
                    state <= INTEGRATE_LOOP;
                end

                INTEGRATE_LOOP: begin
                    if (y_step < 8'd100) begin
                        // Calculate y_curr
                        // y_curr = low + (step * (high - low)) / 100
                        // Simplified: y_curr = low + step * STEP (linear search over range)
                        // But binary search narrows range. We integrate over current [low, high].
                        // Use fixed 100 steps over current range.
                        // y_curr = low + (y_step * (high - low)) / 100
                        
                        temp_mul <= $signed({16'd0, y_step}) * $signed(high - low);
                        // We need to compute x intersections for y_curr
                        // Let's compute y_curr value first
                        
                        // Pass 1: Compute y_curr value and its width
                        // Re-use logic from previous cycle? No, compute fresh.
                        // We need a sub-state or sequential logic for width calculation.
                        // Since we have 100 steps, we can afford sequential width calc.
                        
                        // Current implementation: 1 cycle setup for width calc, next cycle compute width.
                        // To keep it simple: compute width in same cycle using pre-computed values.
                        // Actually, calculating intersection requires division. 
                        // Division takes cycles. We need to handle this.
                        // Let's assume combinational division for simplicity, 
                        // or add wait states. Given complexity, let's add logic to compute width.
                        
                        // Calculate y_curr = low + (step * range) / 100
                        // We need range = high - low.
                        // division by 100 is shift/arith.
                        
                        y_curr <= low + (temp_mul[47:16] / ONE_HUNDRED);
                        
                        // Now calculate width at y_curr.
                        // We need to iterate edges to find intersections.
                        edge_idx <= 8'd0;
                        x_int0 <= 32'h7FFFFFFF; // Min X init
                        x_int1 <= 32'h80000000; // Max X init
                        state <= INTEGRATE_LOOP; // Stay in loop, wait for width calc
                    end else begin
                        state <= CHECK_VOLUME;
                    end
                end
                
                // Sub-state for width calculation (triggered inside loop or separate)
                // Actually, let's break INTEGRATE_LOOP into sub-steps:
                // 1. Compute y_curr
                // 2. Iterate edges to find intersections (requires edge_idx loop)
                // 3. Accumulate area
                
                // Revised INTEGRATE_LOOP logic using edge_idx:
                // We need to extract this logic.
                // Let's use the edge_idx to scan edges for the CURRENT y_curr.
                // Since we are in a loop over y_step, we must complete edge scan for current y_step.
                
                // Re-defining INTEGRATE_LOOP to include edge scan:
                // Wait, Verilog is parallel. 
                // Let's make a dedicated CALC_WIDTH state that is called from INTEGRATE_LOOP.
                
                // Modification:
                // INTEGRATE_LOOP computes y_curr and transitions to CALC_WIDTH.
                // CALC_WIDTH scans edges and computes width. 
                // CALC_WIDTH returns to INTEGRATE_LOOP (which computes area) then increments step.
                
                // Let's refine the state machine structure.
                // Current state: INTEGRATE_LOOP (Step counter check)
                // If counter < 100:
                //   Compute y_curr
                //   State = CALC_WIDTH
                //   (Setup for width calc: edge_idx=0, found points=0)
                //   (Note: area calculation happens after width is found)
                
                // Let's implement CALC_WIDTH logic here.
                // If we are in CALC_WIDTH state:
                if (state == INTEGRATE_LOOP && y_step < 8'd100 && edge_idx < 8'd9) begin
                    // Calculate intersection for current edge (edge_idx, edge_idx+1)
                    // Vertices are cyclic.
                    // Edge i connects (i) and (i+1)%8
                    // But polygon has N vertices. We don't have N input.
                    // We can detect N by y=0 or wrap? 
                    // Spec says "up to 8 vertices". Input gives 8 slots.
                    // We must handle unused slots. 
                    // Strategy: Assume inputs are valid vertices (x,y != 0?)
                    // Or use a fixed number of edges (8 edges max).
                    
                    // Let's assume 8 edges for simplicity, connecting 0-1, 1-2 ... 7-0.
                    // Unused edges will have same y (or 0), resulting in no width contribution or dy=0.
                    // If dy == 0, we skip division.
                    
                    // Load edge
                    edge_x0 <= {16'd0, x[edge_idx]};
                    edge_y0 <= {16'd0, y[edge_idx]};
                    edge_x1 <= {16'd0, x[(edge_idx + 1) % 8]};
                    edge_y1 <= {16'd0, y[(edge_idx + 1) % 8]};
                    
                    // Check if horizontal line y_curr intersects this edge
                    // y0 <= y_curr <= y1 OR y1 <= y_curr <= y0
                    // Also handle dy != 0
                    // Since we are dealing with fixed point, direct comparison works.
                    
                    // We need a flag if intersection found.
                    // Since this is sequential logic within the state, we update x_int min/max.
                    
                    // Calculate intersection x
                    // dx = x1 - x0, dy = y1 - y0, dh = y_curr - y0
                    // x_int = x0 + (dx * dh) / dy
                    
                    // Check if dy is 0 (horizontal edge)
                    // If dy == 0, skip (unless y_curr == y0, but that's handled by vertices)
                    // Also check if y_curr is between y0 and y1 (inclusive)
                    
                    // Intermediate calculation
                    // We can't do all in one cycle. 
                    // Let's separate into MULT and DIV stages.
                    
                    // For this implementation, let's assume we check intersection in 2 cycles per edge.
                    // Cycle 1: Setup compare, check range. If in range, start multiply.
                    // Cycle 2: Finish multiply/divide, update x_int.
                    
                    // Simplified: Update x_int in CALC_WIDTH state.
                    // We will iterate edge_idx in CALC_WIDTH.
                    
                end

                // Let's create a new state CALC_WIDTH to handle the loop
                // State transition: INTEGRATE_LOOP -> CALC_WIDTH -> (if edge done) COMPUTE_AREA -> INTEGRATE_LOOP
                
            endcase
        end
    end

    // Re-implementing with cleaner sub-states
    // To be strictly correct with Verilog synthesis and ICARUS limitations:
    // We will implement a state machine that iterates edges inside CALC_WIDTH.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            water_height <= 32'd0;
            // ... reset all ...
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        state <= FIND_BOUNDS;
                        edge_idx <= 8'd0;
                        max_idx <= 8'd0;
                        y_max <= 16'd0;
                    end
                end

                FIND_BOUNDS: begin
                    if (edge_idx < 8) begin
                        if ($signed(y[edge_idx]) > $signed(y_max)) begin
                            y_max <= y[edge_idx];
                            max_idx <= edge_idx;
                        end
                        edge_idx <= edge_idx + 1;
                    end else begin
                        state <= SETUP_SEARCH;
                        // Calculate target area: (L * 1000) / D
                        // Use Q16.16 for L and D, result Area in cm^2 Q16.16
                        // L (liters) * 1000 = L_mL (mL). 
                        // Volume (mL) = Area (cm^2) * D (cm)
                        // Area = Volume / D
                        // Here L is input in liters (presumably Q0 or Q16.16?). 
                        // Spec says L is 16-bit unsigned. Let's treat as integer.
                        // Area (cm^2) = (L * 1000) / D
                        // Fixed point: L << 16 * 1000 / D
                        temp_mul <= {16'd0, L, 16'd0} * SCALE_1000; // Q16.16 * Q16.16 -> Q32.32
                        target_area <= 32'd0; // placeholder
                    end
                end

                SETUP_SEARCH: begin
                    // target_area = (L * 1000) / D
                    // temp_mul is L*1000 in Q32.32 (high 32 bits are Q16.16)
                    temp_div <= temp_mul[47:16] / {16'd0, D};
                    target_area <= temp_mul[47:16] / {16'd0, D};
                    
                    low <= 32'd0;
                    high <= {16'd0, y_max}; // Max height is max y coordinate
                    iter_count <= 8'd0;
                    state <= INTEGRATE_INIT;
                end

                INTEGRATE_INIT: begin
                    // Initialize trapezoidal integration for current mid height
                    // Current mid = (low + high) / 2
                    mid <= (low + high) >> 1;
                    
                    // Setup integration loop
                    y_step <= 8'd0;
                    area_sum <= 32'd0;
                    y_prev <= low; // Actually we integrate from 0 to H
                    // Wait, integration is from 0 to H.
                    // So y ranges from low to mid? 
                    // Binary search: we test height H (mid).
                    // We need to integrate area from y=0 to y=mid.
                    
                    y_curr <= 32'd0;
                    width_prev <= 32'd0; // Width at y=0 is 0 (base)
                    
                    state <= CALC_WIDTH_SETUP;
                end

                // We need to compute width at a specific y (y_in).
                // We will have a helper loop to scan edges.
                CALC_WIDTH_SETUP: begin
                    // Setup to calculate width at y = y_curr
                    edge_idx <= 8'd0;
                    x_int0 <= 32'h7FFFFFFF; // Min X
                    x_int1 <= 32'h80000000; // Max X
                    state <= CALC_WIDTH_LOOP;
                end

                CALC_WIDTH_LOOP: begin
                    if (edge_idx < 8) begin
                        // Load edge vertices
                        // Connect edge_idx to (edge_idx+1)%8
                        // Check for valid edge (dy != 0)
                        // Check if y_curr is within y range of edge (inclusive)
                        
                        // Let's compute intersection if valid.
                        // x_int = x0 + ( (x1-x0) * (y_in - y0) ) / (y1 - y0)
                        
                        // We'll use temp_mul and temp_div registers for math.
                        // Since this is sequential, we can do:
                        // 1. Check Range (combinational logic preferred or state logic)
                        // 2. Calculate intersection if in range
                        
                        // To save states, let's assume we iterate edges one by one.
                        // For each edge, we check if it crosses y_curr.
                        
                        // We need access to y0, y1, x0, x1.
                        // We can use the module inputs directly indexed by edge_idx.
                        
                        // Check if y_curr is between y0 and y1 (inclusive)
                        // Since y_curr is Q16.16, inputs are Q16.0 extended.
                        // We need to be careful with signed comparisons.
                        
                        // Note: Inputs are 16-bit signed. We extend to 32-bit for fixed point.
                        // y values are likely 0-128. 
                        
                        // Logic check:
                        // If (y_curr >= y0 && y_curr <= y1) || (y_curr >= y1 && y_curr <= y0)
                        
                        // We need to handle edge case where y_curr == y0 or y1.
                        // To avoid duplicate points, we usually use a convention (e.g. include start, exclude end)
                        // But for trapezoidal rule, we need points at boundaries.
                        
                        // Let's implement the check in combinational logic or a sub-state.
                        // Given ICARUS constraints, let's do it step by step in CALC_WIDTH_LOOP.
                        
                        // Wait, we are in a loop. We need to proceed to next state if edge is done.
                        // Let's separate CALC_WIDTH logic into specific steps per edge.
                        
                        // Actually, let's keep it simple: 
                        // Just calculate intersection for ALL edges (combinational block)
                        // and sum the intersections in a sequential loop.
                        // Combinational block is safer for FSM timing.
                        
                        // We will set up parameters and move to WAIT state.
                        // But since we are in a loop, let's assume we do one edge per clock (or faster).
                        
                        // Let's use combinational logic to find intersections.
                        // Defined outside always block.
                        
                    end else begin
                        // Done scanning edges
                        // Width = x_int1 - x_int0
                        if ($signed(x_int1) > $signed(x_int0)) begin
                            width_curr <= x_int1 - x_int0;
                        end else begin
                            width_curr <= 32'd0;
                        end
                        state <= COMPUTE_AREA;
                    end
                end

                COMPUTE_AREA: begin
                    // Add trapezoid area to sum
                    // Area += (width_prev + width_curr) * (y_curr - y_prev) / 2
                    // Use Q16.16 arithmetic.
                    // (A+B) is Q16.16, DeltaY is Q16.16. Product is Q32.32. /2 is shift.
                    
                    // We need to compute y_curr for this step.
                    // y_curr = 0 + (step * H) / 100 (where H = mid)
                    // We are integrating from 0 to mid.
                    
                    // Update y_curr for this step
                    // y_curr <= (step * mid) / 100
                    // We need to update this every step.
                    // It's better to compute y_curr inside INTEGRATE_INIT or CALC_WIDTH_SETUP.
                    // Let's compute it in INTEGRATE_INIT and update after step.
                    
                    // Wait, y_curr depends on step. 
                    // Let's compute it before CALC_WIDTH_SETUP.
                    
                    // Area Calculation:
                    temp_mul <= (width_prev + width_curr) * (y_curr - y_prev);
                    // Division by 2 happens via shift later
                    
                    state <= ACCUMULATE_AREA;
                end

                ACCUMULATE_AREA: begin
                    // Add to sum
                    // temp_mul is Q32.32. High 32 bits are Q16.16.
                    // Divide by 2 (shift right 1) -> Q15.16 or keep Q16.16 and mask?
                    // Area is scalar. Summing Q16.16 is fine.
                    // Add temp_mul[47:16] >> 1? No, (A+B)*H/2. 
                    // If we use Q16.16 for H, then (A+B) is Q16.16. Product is Q32.32.
                    // Divide by 2: Right shift 1 bit of Q32.32 -> Q31.32. We take high 32 bits.
                    // To keep Q16.16, we take bits [47:16] and shift right 1.
                    
                    area_sum <= area_sum + (temp_mul[47:16] >> 1);
                    
                    // Update previous values
                    y_prev <= y_curr;
                    width_prev <= width_curr;
                    
                    y_step <= y_step + 1;
                    
                    // Check if done integrating (100 steps)
                    if (y_step >= 8'd99) begin // We just did step 99? Or incrementing?
                        // If y_step starts at 0, we do 0..99 (100 steps).
                        // y_step increments AFTER calculation.
                        // So check if y_step == 99 (before increment) or check current value.
                        // Let's check if y_step == 99 (current) -> Next state is CHECK_VOLUME.
                        // Actually, y_step increments. Check if y_step == 100.
                        state <= CHECK_VOLUME;
                    end else begin
                        // Setup next y_curr
                        // y_curr = (step * mid) / 100
                        // We need to re-calculate y_curr for next step.
                        // Since we need to do this efficiently, let's calculate it here.
                        // step is y_step + 1 (next step)
                        // To save a cycle, we can use the fact that we are already in CALC_WIDTH_SETUP
                        // But we need to update y_curr first.
                        
                        state <= UPDATE_Y_CURR;
                    end
                end

                UPDATE_Y_CURR: begin
                    // Calculate next y_curr
                    // y_curr = ( (y_step) * mid ) / 100
                    // Note: y_step was incremented in ACCUMULATE_AREA.
                    // So y_step now points to the next slice index (1..100)
                    // But wait, integration is usually from 0 to H.
                    // Points are at 0, H/100, 2H/100, ..., H.
                    // So for slice i (from 0 to 99), y_i = i * H / 100.
                    // We computed y_prev at i-1, y_curr at i.
                    // In ACCUMULATE_AREA, we used y_curr (which was i) and y_prev (i-1).
                    // We need to update y_curr for the next iteration.
                    // So new y_curr = (y_step) * mid / 100.
                    
                    temp_mul <= {16'd0, y_step} * mid;
                    // Wait for multiply?
                    // We can do it in one cycle if we pipeline, or add state.
                    state <= WAIT_MULT_Y;
                end
                
                WAIT_MULT_Y: begin
                    temp_div <= temp_mul[47:16] / ONE_HUNDRED;
                    state <= APPLY_NEW_Y;
                end
                
                APPLY_NEW_Y: begin
                    y_curr <= temp_div;
                    state <= CALC_WIDTH_SETUP;
                end

                CHECK_VOLUME: begin
                    // Compare area_sum (current area at H=mid) with target_area
                    // Area * D = Volume (cm^3)
                    // We want Volume = L * 1000 (cm^3)
                    // target_area = (L * 1000) / D
                    // So we compare area_sum with target_area.
                    
                    if ($signed(area_sum) >= $signed(target_area)) begin
                        // Area is too large (or equal), so H is too high.
                        // New High = Mid
                        high <= mid;
                    end else begin
                        // Area is too small, H is too low.
                        // New Low = Mid
                        low <= mid;
                    end
                    
                    state <= UPDATE_SEARCH;
                end

                UPDATE_SEARCH: begin
                    // Check convergence or iteration count
                    // Precision: 0.01cm. 
                    // Range [0, 128]. Binary search 100 iterations is plenty.
                    // Or check if (high - low) < threshold.
                    
                    iter_count <= iter_count + 1;
                    
                    // Check iteration limit
                    if (iter_count >= ITERATIONS_MAX) begin // 100 iterations
                        state <= DONE_STATE;
                    end else begin
                        // Check precision threshold (optional but good)
                        // if ((high - low) < 0.01) ...
                        // Let's just use iteration count as per spec (100 iterations max)
                        state <= INTEGRATE_INIT;
                    end
                end

                DONE_STATE: begin
                    // Result is the final height.
                    // Usually the average of low and high, or just high/low.
                    // Let's output mid of last step or (low+high)/2.
                    water_height <= (low + high) >> 1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Logic for Width Calculation
    // This block computes intersection points for the current y_curr
    // It runs continuously, but state machine updates 'width_curr' only in CALC_WIDTH_LOOP
    // Actually, simpler to do this inside the FSM with temporary variables.
    
    // Re-writing CALC_WIDTH_LOOP to be robust and combinational-friendly
    // Since we can't easily do a loop inside the always block without creating sub-states for edge iteration,
    // let's assume we process all edges in one go using combinational logic derived from inputs.
    // But 'y_curr' changes every iteration.
    
    // Let's define a helper combinational block that takes y_in and returns width_out
    // But Verilog doesn't support functions that return arrays easily for synthesis if complex.
    
    // Let's stick to the sequential edge scan within CALC_WIDTH_LOOP but structure it properly.
    // We need to iterate edge_idx from 0 to 7.
    // Inside the loop, we need to compute x_int.
    
    // To avoid deep nesting, let's break CALC_WIDTH_LOOP into:
    // 1. LOAD_EDGE (read inputs)
    // 2. CHECK_INTERSECTION (combinational check if in range)
    // 3. CALC_X (compute x if in range)
    // 4. UPDATE_MIN_MAX (update x_int0/1)
    // 5. NEXT_EDGE (increment idx, loop)
    
    // Since we are limited by space and complexity, let's refine the CALC_WIDTH_LOOP state.
    // We will use the edge_idx register to iterate.
    // We will use a combinational always block to calculate intersection for the current edge.
    // This combinational block updates internal signals.
    // The sequential logic uses these signals to update x_int0/1.
    
    // Combinational block for intersection
    reg [31:0] calc_x0, calc_y0, calc_x1, calc_y1;
    reg [31:0] calc_dx, calc_dy, calc_dh;
    reg [31:0] calc_x_int;
    reg calc_valid;
    
    always @(*) begin
        // Default values from current edge_idx
        calc_x0 = {16'd0, x[edge_idx]};
        calc_y0 = {16'd0, y[edge_idx]};
        calc_x1 = {16'd0, x[(edge_idx + 1) % 8]};
        calc_y1 = {16'd0, y[(edge_idx + 1) % 8]};
        
        calc_valid = 1'b0;
        calc_x_int = 32'd0;
        
        // Check if y_curr is within the edge's y-range (inclusive)
        // We need to handle vertical/horizontal edges carefully.
        // Horizontal edges (dy=0): Ignore unless y_curr == y0, but that's a vertex.
        // Vertical edges (dx=0): Intersection is x0.
        
        // Note: y_curr is Q16.16, inputs are Q16.0 (shifted 16 bits)
        // We need to ensure consistent comparison.
        
        if (y_curr >= calc_y0 && y_curr <= calc_y1) begin
            // Normal order
        end else if (y_curr >= calc_y1 && y_curr <= calc_y0) begin
            // Reverse order (swap for calculation)
        end else begin
            // Not in range
            calc_valid = 1'b0;
            return; // Use return in combinational block? No, just assign defaults.
        end
        
        // If we are here, y_curr is in range.
        // Check dy != 0
        calc_dy = (calc_y1 > calc_y0) ? (calc_y1 - calc_y0) : (calc_y0 - calc_y1);
        
        if (calc_dy == 0) begin
            // Horizontal edge, ignore (width contribution handled by vertices)
            calc_valid = 1'b0;
        end else begin
            // Calculate intersection
            // x = x0 + (dx * (y_curr - y0)) / dy
            // Note: if y_curr == y0, x = x0. If y_curr == y1, x = x1.
            
            // Handle orientation for subtraction
            if (calc_y0 <= calc_y1) begin
                calc_dx = calc_x1 - calc_x0;
                calc_dh = y_curr - calc_y0;
            end else begin
                calc_dx = calc_x0 - calc_x1;
                calc_dh = y_curr - calc_y1;
            end
            
            // Perform calculation
            // Q16.16 * Q16.16 = Q32.32
            // We need a temporary multiplier register for this.
            // Since we can't easily do it combinatorially without long paths,
            // we might need to use the 'temp_mul' register used elsewhere.
            // But 'temp_mul' is used in the sequential FSM.
            // We can reuse it if we sequence properly.
            
            // For this specific FSM path:
            // We are in CALC_WIDTH_LOOP. We need to compute x_int.
            // We can perform the mult/div in sequential steps.
            
            // However, to keep the logic self-contained in the combinational block (for synthesis view):
            // We leave the math unimplemented here and rely on sequential logic to latch it.
            // Just set valid=1.
            
            calc_valid = 1'b1;
        end
    end

    // Corrected Sequential Logic for CALC_WIDTH_LOOP
    // We need to handle the math step-by-step to avoid overflow or multi-cycle operations in one state.
    
    // State Definitions:
    // IDLE
    // FIND_BOUNDS
    // SETUP_SEARCH
    // INTEGRATE_INIT
    // CALC_WIDTH_LOOP (iterate edges 0-7)
    //   -> CALC_WIDTH_LOAD (latch inputs, check range)
    //   -> CALC_WIDTH_MATH (compute intersection)
    //   -> CALC_WIDTH_UPDATE (update min/max)
    //   -> NEXT_EDGE
    // COMPUTE_AREA
    // CHECK_VOLUME
    // UPDATE_SEARCH
    // DONE_STATE
    
    // Let's rewrite the always block with these detailed states.
    // We need to handle the loops carefully.
    
    // Helper registers for edge math
    reg [31:0] edge_x0_reg, edge_y0_reg, edge_x1_reg, edge_y1_reg;
    reg [31:0] edge_dx_reg, edge_dh_reg;
    reg edge_in_range;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            water_height <= 32'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            iter_count <= 8'd0;
            y_step <= 8'd0;
            area_sum <= 32'd0;
            target_area <= 32'd0;
            y_curr <= 32'd0;
            y_prev <= 32'd0;
            width_curr <= 32'd0;
            width_prev <= 32'd0;
            x_int0 <= 32'd0;
            x_int1 <= 32'd0;
            edge_idx <= 8'd0;
            // Reset other temps
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        state <= FIND_BOUNDS;
                        edge_idx <= 8'd0;
                        max_idx <= 8'd0;
                        y_max <= 16'd0;
                    end
                end

                FIND_BOUNDS: begin
                    if (edge_idx < 8) begin
                        if ($signed(y[edge_idx]) > $signed(y_max)) begin
                            y_max <= y[edge_idx];
                        end
                        edge_idx <= edge_idx + 1;
                    end else begin
                        state <= SETUP_SEARCH;
                        edge_idx <= 8'd0;
                    end
                end

                SETUP_SEARCH: begin
                    // target_area = (L * 1000) / D
                    // L is 16-bit. Convert to Q16.16: L << 16
                    // Multiply by 1000 (Q16.16)
                    // Divide by D (16-bit integer)
                    temp_mul <= {16'd0, L, 16'd0} * SCALE_1000;
                    state <= SETUP_SEARCH_2;
                end

                SETUP_SEARCH_2: begin
                    target_area <= temp_mul[47:16] / {16'd0, D};
                    low <= 32'd0;
                    high <= {16'd0, y_max};
                    iter_count <= 8'd0;
                    state <= INTEGRATE_INIT;
                end

                INTEGRATE_INIT: begin
                    // mid = (low + high) >> 1
                    mid <= (low + high) >> 1;
                    y_step <= 8'd0;
                    area_sum <= 32'd0;
                    
                    // Initialize y_curr = 0, y_prev = 0
                    y_curr <= 32'd0;
                    y_prev <= 32'd0;
                    width_prev <= 32'd0; // Width at y=0 is 0
                    
                    edge_idx <= 8'd0;
                    x_int0 <= 32'h7FFFFFFF;
                    x_int1 <= 32'h80000000;
                    
                    state <= EDGE_LOAD;
                end

                // --- Integration Loop: Scan Edges ---
                EDGE_LOAD: begin
                    // Load edge parameters
                    edge_x0_reg <= {16'd0, x[edge_idx]};
                    edge_y0_reg <= {16'd0, y[edge_idx]};
                    edge_x1_reg <= {16'd0, x[(edge_idx + 1) % 8]};
                    edge_y1_reg <= {16'd0, y[(edge_idx + 1) % 8]};
                    
                    state <= EDGE_CHECK;
                end

                EDGE_CHECK: begin
                    // Check if y_curr is within [min(y0,y1), max(y0,y1)]
                    // Include equality for vertices, but ensure we don't double count.
                    // Use strict < for one side if needed, but inclusive is safer for closed polygon.
                    
                    if (edge_y0_reg <= edge_y1_reg) begin
                        if (y_curr >= edge_y0_reg && y_curr <= edge_y1_reg) begin
                            edge_in_range <= 1'b1;
                            edge_dx_reg <= edge_x1_reg - edge_x0_reg;
                            edge_dh_reg <= y_curr - edge_y0_reg;
                        end else begin
                            edge_in_range <= 1'b0;
                        end
                    end else begin
                        if (y_curr >= edge_y1_reg && y_curr <= edge_y0_reg) begin
                            edge_in_range <= 1'b1;
                            edge_dx_reg <= edge_x0_reg - edge_x1_reg;
                            edge_dh_reg <= y_curr - edge_y1_reg;
                        end else begin
                            edge_in_range <= 1'b0;
                        end
                    end
                    
                    // Check dy != 0 (avoid div by zero)
                    if (edge_y0_reg == edge_y1_reg) begin
                        edge_in_range <= 1'b0; // Ignore horizontal edges
                    end
                    
                    state <= EDGE_CALC;
                end

                EDGE_CALC: begin
                    if (edge_in_range) begin
                        // x_int = x_start + (edge_dx * edge_dh) / (y1 - y0)
                        // We need dy (absolute)
                        // Use temp_mul and temp_div
                        // Note: temp_mul is 64-bit signed.
                        
                        temp_mul <= $signed(edge_dx_reg) * $signed(edge_dh_reg);
                        // We need denominator. 
                        // We didn't latch dy. We can compute it again or latch it in EDGE_CHECK.
                        // Let's assume we latch it or compute it now.
                        // Since we are in EDGE_CALC, we can compute abs dy.
                        // To save registers, let's recompute abs dy from edge_y0/1.
                        
                        state <= EDGE_WAIT_DIV;
                    end else begin
                        // Skip to next edge
                        state <= NEXT_EDGE;
                    end
                end

                EDGE_WAIT_DIV: begin
                    // Compute division numerator / dy
                    // Numerator is temp_mul[47:16] (Q16.16)
                    // Denominator is abs(y1-y0) (Q16.0)
                    
                    // Calculate dy
                    if (edge_y0_reg > edge_y1_reg) begin
                        temp_div <= (edge_y0_reg - edge_y1_reg); // Store dy in temp_div temporarily
                    end else begin
                        temp_div <= (edge_y1_reg - edge_y0_reg);
                    end
                    
                    state <= EDGE_FINISH;
                end

                EDGE_FINISH: begin
                    // temp_div now holds dy (integer)
                    // temp_mul[47:16] holds numerator (Q16.16)
                    // Division
                    // result = numerator / dy
                    // Note: numerator is Q16.16, dy is Q0.0 (integer).
                    // Result is Q16.16.
                    
                    // Add x_start
                    // x_start was edge_x0_reg (if moving y0->y1) or edge_x1_reg (if y1->y0).
                    // We normalized direction in EDGE_CHECK so we start from lower y.
                    // Actually, we just calculated dx and dh based on direction.
                    // x_start is the one corresponding to y0 (the lower bound).
                    
                    // We need x_start. 
                    // If y0 < y1, x_start = x0. If y1 < y0, x_start = x1.
                    // We can use the condition check again or latch x_start.
                    // Let's latch x_start in EDGE_CHECK to be safe, or recompute here.
                    
                    // Let's recompute x_start in combinational logic or add a state.
                    // To save states, let's assume we have the correct x_start.
                    // If we normalized in EDGE_CHECK (y_curr >= y0 implies y0 is lower), then x_start is x0.
                    // But wait, if y0 > y1, we swapped dx. We should swap x_start too.
                    // In EDGE_CHECK: if (y0 <= y1) ... else ...
                    // So in else block, we used x0 - x1 (dx) and y_curr - y1 (dh).
                    // So x_start is x1.
                    
                    // It's tricky to keep track. Let's compute intersection directly:
                    // x_int = x0 + (dx * (y_curr - y0)) / (y1 - y0)
                    // We have x0, x1, y0, y1 in edge_x0_reg...
                    // We have dh = abs(y_curr - y_start).
                    // We have dx = abs(x_end - x_start).
                    // We need to know the sign of the result relative to x_start.
                    
                    // Let's use a simpler approach:
                    // (x1 - x0) * (y_curr - y0) / (y1 - y0) + x0
                    // We have all these values.
                    // We can compute (x1-x0)*(y_curr-y0) in EDGE_CALC.
                    // We have (y1-y0) in temp_div (absolute).
                    // We need to know if (y1-y0) is positive or negative to handle division correctly?
                    // No, integer division is positive.
                    // We need to know if we are moving from y0 to y1 or y1 to y0 to know which x is start.
                    
                    // Let's restart EDGE logic cleanly.
                    // In EDGE_CHECK, we determined if y_curr is in range.
                    // Let's just compute the intersection formula directly using original coordinates.
                    // x_int = x0 + ( (x1-x0) * (y_curr - y0) ) / (y1 - y0)
                    // We need to handle signed arithmetic correctly.
                    
                    // We will compute:
                    // Num = (x1-x0) * (y_curr - y0)
                    // Den = (y1 - y0)
                    // Then x_int = x0 + Num / Den
                    // Note: Num and Den are signed.
                    
                    // We can perform this in 2 cycles:
                    // Cycle 1: Compute Num and Den. Store Den.
                    // Cycle 2: Divide Num/Den. Add to x0.
                    
                    // Let's modify the states to handle this.
                    // Current state: EDGE_CALC
                    // Calculate (x1-x0) and (y_curr - y0)
                    
                    // Wait, we are in EDGE_CALC. 
                    // Let's assume we compute Num here.
                    
                    // (x1-x0) is signed 32-bit. (y_curr-y0) is signed 32-bit.
                    // Result is 64-bit.
                    
                    // We need to be careful with y_curr. y_curr is Q16.16. y0 is Q16.0.
                    // We need to align them. y0 << 16.
                    // So y0_fixed = {y0, 16'd0}.
                    
                    // Let's calculate Num = (x1-x0) * (y_curr - {y0, 16'd0})
                    // Den = ({y1, 16'd0} - {y0, 16'd0})
                    
                    // This is getting complex. Let's simplify: 
                    // Polygon y coordinates are 0-128. 
                    // If we treat them as fixed point 0-128.0 (Q16.16), then values are y<<16.
                    // y_curr is also Q16.16.
                    // So we can treat inputs as {y, 16'd0}.
                    
                    // Let's compute:
                    // dy = (y1 - y0) << 16
                    // dh = y_curr - (y0 << 16)
                    // dx = x1 - x0 (integer)
                    // Num = dx * dh
                    // Den = dy
                    // x_int = x0 + Num / Den
                    
                    // We can do this in 2 cycles.
                    // Cycle 1 (EDGE_CALC): Compute dx, dy, dh.
                    // Cycle 2 (EDGE_DIV): Compute Num, Div, Add.
                    
                    // Let's compute dx, dy, dh now.
                    // dy = (y1 - y0) * SCALE_1
                    temp_mul <= ($signed(edge_x1_reg) - $signed(edge_x0_reg)) * ($signed(y_curr) - $signed({edge_y0_reg[15:0], 16'd0}));
                    // We need dy for division.
                    // Store dy in temp_div (temporarily)
                    // Note: temp_mul is 64-bit. We need the lower 32 bits? No, high bits.
                    // dx is small. dh is Q16.16. Product is Q32.48? No.
                    // dx is Q16.0. dh is Q16.16. Product is Q32.16 (high 32 bits are Q16.16).
                    
                    // Let's use a separate register for dy calculation to avoid conflict with temp_mul.
                    // Actually, we can use the same temp_mul if we sequence carefully, or use temp_div.
                    // Let's use temp_div for dy.
                    temp_div <= ($signed({edge_y1_reg[15:0], 16'd0}) - $signed({edge_y0_reg[15:0], 16'd0}));
                    
                    state <= EDGE_DIV;
                end

                EDGE_DIV: begin
                    // temp_mul holds dx * dh (Q32.16). High 32 bits are Q16.16.
                    // temp_div holds dy (Q16.16).
                    // Result = (dx * dh) / dy
                    // Note: dy is not necessarily 1. It is (y1-y0)*SCALE_1.
                    // Division: Q32.16 / Q16.16 = Q16.16.
                    // Actually, we want result to be added to x0 (Q16.0).
                    // So we want result in Q16.16 or Q16.0.
                    // Let's do: Num = dx * dh (Q32.16). Num_high = Q16.16.
                    // Den = dy (Q16.16).
                    // Result = Num_high / Den_high? No.
                    // Num is in [47:16] of temp_mul.
                    // Den is in [31:0] of temp_div.
                    // Division of Q16.16 / Q16.16 gives integer result if we just take high bits.
                    // We want precise intersection.
                    // x_int = x0 + (dx * dh / dy)
                    // dh is Q16.16, dy is Q16.16. dh/dy is ratio 0..1.
                    // dx * ratio.
                    // So we need (dx * dh) / dy.
                    // dx is integer. dh is Q16.16. dy is Q16.16.
                    // Let's compute dh / dy first (ratio), then multiply by dx.
                    // dh/dy is Q16.16 / Q16.16 = Q16.16 (ratio).
                    // Then multiply by dx (integer). Result Q16.16.
                    // This might be more accurate.
                    
                    // Let's stick to the direct formula: (dx * dh) / dy.
                    // temp_mul[47:16] is dx*dh in Q16.16 (approx, actually Q32.16 -> high 32 bits are Q16.16).
                    // Wait. dx (16-bit) * dh (Q16.16) = 48-bit result. 
                    // Format: (dx * dh) >> 16 = Q16.16 value.
                    // So temp_mul[47:16] is the value we want to divide by dy.
                    // dy is Q16.16.
                    // So (Q16.16) / (Q16.16) = Q16.16 (ratio).
                    // Result * dx? No, we already multiplied by dx.
                    // So temp_mul[47:16] / temp_div = Q16.16 value.
                    // This value is the offset from x0.
                    
                    temp_mul <= temp_mul[47:16] / temp_div;
                    state <= EDGE_ADD_X0;
                end

                EDGE_ADD_X0: begin
                    // temp_mul[47:16] holds (dx * dh / dy) in Q16.16
                    // We need to add x0.
                    // x0 is Q16.0 (int).
                    // Result x_int is Q16.16.
                    
                    // We need to know which x0 to use (original x0 or x1)?
                    // We used edge_x0_reg as reference in formula x0 + ...
                    // But we need to ensure we are moving in correct direction.
                    // The formula works if we take x0 as the start vertex (lower y) and x1 as upper y.
                    // But we used raw inputs in temp_mul calculation.
                    // If y_curr is between y0 and y1, we need to know which is lower.
                    // Actually, the formula x0 + (x1-x0)*(y_curr-y0)/(y1-y0) works regardless of order,
                    // provided y0 and y1 are distinct and y_curr is between them.
                    // But division by (y1-y0) must handle sign correctly if we use signed division.
                    // We used absolute values for dy? No, in EDGE_DIV we used temp_div = dy.
                    // If y1 < y0, dy is negative. Division by negative number flips sign.
                    // But we computed dh = y_curr - y0.
                    // If y0 is larger, y_curr - y0 is negative.
                    // So sign handling is implicitly correct if we use signed arithmetic.
                    
                    // Add x0.
                    // x_int = temp_mul[31:0] + x0
                    // x0 is Q16.0. temp_mul is Q16.16. 
                    // We need to align x0. x0 << 16.
                    
                    // Store computed x_int in a temporary register.
                    // We compare x_int with x_int0 (min) and x_int1 (max).
                    
                    // Calculate x_int
                    // We need x0 (Q16.0) converted to Q16.16
                    // edge_x0_reg is Q16.0 (stored in lower 16 bits, upper 0).
                    // Wait, {16'd0, x[edge_idx]} is Q16.0.
                    // To add to temp_mul[31:0] (Q16.16), we shift x0 << 16.
                    // So x0_fixed = edge_x0_reg << 16.
                    
                    // We need a register for the calculated intersection point.
                    calc_x_int <= (edge_x0_reg << 16) + temp_mul[31:0];
                    
                    state <= EDGE_UPDATE_MINMAX;
                end

                EDGE_UPDATE_MINMAX: begin
                    // Update x_int0 and x_int1
                    if ($signed(calc_x_int) < $signed(x_int0)) begin
                        x_int0 <= calc_x_int;
                    end
                    if ($signed(calc_x_int) > $signed(x_int1)) begin
                        x_int1 <= calc_x_int;
                    end
                    
                    state <= NEXT_EDGE;
                end

                NEXT_EDGE: begin
                    if (edge_idx < 8'd7) begin
                        edge_idx <= edge_idx + 1;
                        state <= EDGE_LOAD;
                    end else begin
                        // Finished scanning all edges
                        // Compute width
                        if ($signed(x_int1) > $signed(x_int0)) begin
                            width_curr <= x_int1 - x_int0;
                        end else begin
                            width_curr <= 32'd0;
                        end
                        state <= COMPUTE_AREA;
                    end
                end

                COMPUTE_AREA: begin
                    // Area += (width_prev + width_curr) * (y_curr - y_prev) / 2
                    // width are Q16.0 (cm). y are Q16.16.
                    // Product = Q16.0 * Q16.16 = Q32.16. /2 = Q31.16.
                    // We accumulate area in Q16.16.
                    
                    // We need to be careful with widths. They are integers (cm).
                    // Convert to Q16.16: width << 16.
                    // width_prev_fixed = width_prev << 16.
                    
                    // Let's compute SumW = (width_prev + width_curr) in Q16.0
                    // DeltaY = (y_curr - y_prev) in Q16.16
                    // Product = SumW * DeltaY. Result is Q32.16. High 32 bits are Q16.16.
                    
                    temp_mul <= ($signed(width_prev) + $signed(width_curr)) * $signed(y_curr - y_prev);
                    state <= ACCUMULATE_AREA;
                end

                ACCUMULATE_AREA: begin
                    // temp_mul[47:16] is the product in Q16.16 (approx)
                    // Divide by 2.
                    area_sum <= area_sum + (temp_mul[47:16] >> 1);
                    
                    // Update previous
                    y_prev <= y_curr;
                    width_prev <= width_curr;
                    
                    // Check loop count
                    if (y_step >= 8'd99) begin
                        // Done integrating for this mid height
                        state <= CHECK_VOLUME;
                    end else begin
                        // Next step
                        y_step <= y_step + 1;
                        
                        // Calculate next y_curr = (y_step * mid) / 100
                        // y_step was incremented? No, increment now.
                        // y_step holds current index (0..99).
                        // We just used y_step. Next is y_step + 1.
                        // Wait, we incremented y_step at the start of loop or end?
                        // Let's increment here.
                        // Actually, we used y_step 0..99. 
                        // After step 0, we go to step 1.
                        // So calculate y for next step.
                        
                        // y_next = ((y_step + 1) * mid) / 100
                        // We need to be careful not to lose precision.
                        
                        temp_mul <= {16'd0, y_step + 1} * mid;
                        state <= UPDATE_Y_CURR;
                    end
                end

                UPDATE_Y_CURR: begin
                    // temp_mul holds (step+1) * mid
                    // Divide by 100
                    temp_div <= temp_mul[47:16] / ONE_HUNDRED;
                    state <= APPLY_NEW_Y;
                end

                APPLY_NEW_Y: begin
                    y_curr <= temp_div;
                    // Reset edge_idx for next integration step
                    edge_idx <= 8'd0;
                    x_int0 <= 32'h7FFFFFFF;
                    x_int1 <= 32'h80000000;
                    state <= EDGE_LOAD;
                end

                CHECK_VOLUME: begin
                    // Compare area_sum with target_area
                    if ($signed(area_sum) >= $signed(target_area)) begin
                        high <= mid;
                    end else begin
                        low <= mid;
                    end
                    state <= UPDATE_SEARCH;
                end

                UPDATE_SEARCH: begin
                    iter_count <= iter_count + 1;
                    if (iter_count >= ITERATIONS_MAX - 1) begin // Check if we reached limit
                        state <= DONE_STATE;
                    end else begin
                        state <= INTEGRATE_INIT;
                    end
                end

                DONE_STATE: begin
                    water_height <= (low + high) >> 1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
