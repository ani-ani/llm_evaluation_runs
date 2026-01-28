module polygon_clipper (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input signed [31:0] xa, ya, xb, yb,
    input signed [15:0] arr_x [0:99],
    input signed [15:0] arr_y [0:99],
    output reg signed [31:0] result_area,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CALC_DIST   = 4'd1;
    localparam [3:0] CHECK_SIDE  = 4'd2;
    localparam [3:0] INTERSECT   = 4'd3;
    localparam [3:0] ADD_VERTEX  = 4'd4;
    localparam [3:0] CALC_AREA   = 4'd5;
    localparam [3:0] FINISH      = 4'd6;

    reg [3:0] state, next_state;
    reg [7:0] i;
    reg [7:0] out_count;
    reg signed [31:0] ref_dist;
    reg signed [31:0] edge_x0, edge_y0, edge_x1, edge_y1;
    reg signed [31:0] dist0, dist1;
    reg signed [31:0] interp_x, interp_y;
    reg signed [63:0] sum_x, sum_y; // Accumulators for shoelace
    reg signed [31:0] poly_x [0:99];
    reg signed [31:0] poly_y [0:99];
    reg [7:0] poly_count;
    
    // Computation registers
    reg signed [31:0] dx, dy;
    reg signed [63:0] num, den, temp_val;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_area <= 32'd0;
            done <= 1'b0;
            i <= 8'd0;
            out_count <= 8'd0;
            ref_dist <= 32'd0;
            edge_x0 <= 32'd0;
            edge_y0 <= 32'd0;
            edge_x1 <= 32'd0;
            edge_y1 <= 32'd0;
            dist0 <= 32'd0;
            dist1 <= 32'd0;
            interp_x <= 32'd0;
            interp_y <= 32'd0;
            sum_x <= 64'd0;
            sum_y <= 64'd0;
            poly_count <= 8'd0;
            dx <= 32'd0;
            dy <= 32'd0;
            num <= 64'd0;
            den <= 64'd0;
            temp_val <= 64'd0;
            cycle_count <= 16'd0;
            // Initialize poly arrays
            for (int k = 0; k < 100; k = k + 1) begin
                poly_x[k] <= 32'd0;
                poly_y[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 8'd0;
                    out_count <= 8'd0;
                    sum_x <= 64'd0;
                    sum_y <= 64'd0;
                    poly_count <= 8'd0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        // Calculate reference distance (vertex 0)
                        dx <= arr_x[0] - xa;
                        dy <= arr_y[0] - ya;
                    end
                end

                CALC_DIST: begin
                    // Line normal vector: (yb - ya, xa - xb) for determinant
                    // Distance = (x - xa) * (yb - ya) - (y - ya) * (xb - xa)
                    // result is Q32.0 (signed integer)
                    dx <= arr_x[i] - xa;
                    dy <= arr_y[i] - ya;
                end

                CHECK_SIDE: begin
                    // Calculate distance for current vertex i
                    // dx, dy already set in previous state
                    // det = (dx * (yb - ya)) - (dy * (xb - xa))
                    // Multiply Q16.16 by Q16.16 -> Q32.32, we take Q32.0 (shift right 16)
                    temp_val <= ($signed(dx) * ($signed(yb) - $signed(ya))) - 
                                 ($signed(dy) * ($signed(xb) - $signed(xa)));
                    
                    if (i == 0) begin
                        ref_dist <= temp_val[47:16]; // Store reference dist
                        // Initial edge setup
                        edge_x0 <= arr_x[0];
                        edge_y0 <= arr_y[0];
                    end
                end

                INTERSECT: begin
                    // dist0 is the signed distance of prev vertex
                    // dist1 is the signed distance of current vertex
                    // If signs differ, compute intersection
                    // Intersection Formula (Q16.16 precision):
                    // t = dist0 / (dist0 - dist1)
                    // P_int = P0 + t * (P1 - P0)
                    // Scale t by 2^16 (fix representation)
                    
                    if ((dist0[31] ^ dist1[31]) && (dist0 != 0) && (dist1 != 0)) begin
                        // Calculate t = dist0 / (dist0 - dist1)
                        // Multiply numerator by 2^16 for fixed point
                        num <= {32'd0, dist0[31:0]}; // Extend to 64 bit, effectively shifted by 16
                        den <= $signed(dist0) - $signed(dist1);
                        
                        // Wait for division (combinational division assumed for synthesis or simple state wait)
                        // Here we handle in combinational logic style via state
                        // Division: result = num / den (Result is Q16.16)
                        // Note: den is Q32.0 (scaled difference), num is Q32.0 (scaled dist0)
                        // Result t is Q0.16 (if we shift logic correctly)
                        // Actually, let's do: t = dist0 / (dist0 - dist1)
                        // dist values are Q32.0 from temp_val[47:16].
                        // To get Q16.16 result, shift numerator left 16.
                        // num = dist0 << 16
                        // den = dist0 - dist1
                        // result = num / den
                        
                        num <= {dist0[31:0], 16'd0}; // dist0 * 2^16
                        den <= $signed(dist0) - $signed(dist1);
                    end else if (dist0[31] == ref_dist[31]) begin
                        // Current point is on the same side as reference (inside)
                        // Add P1 to list
                        edge_x1 <= arr_x[i];
                        edge_y1 <= arr_y[i];
                        poly_x[out_count] <= arr_x[i];
                        poly_y[out_count] <= arr_y[i];
                        out_count <= out_count + 8'd1;
                    end else if (dist1[31] == ref_dist[31]) begin
                        // Crossing into the valid region
                        // P0 was outside, P1 is inside. Add Intersection then P1
                        // Calc intersection now
                        num <= {dist0[31:0], 16'd0};
                        den <= $signed(dist0) - $signed(dist1);
                    end
                    // Note: If both outside, do nothing
                end

                ADD_VERTEX: begin
                    // Calculate intersection coordinates
                    // t = num / den (Q16.16)
                    // P_int = P0 + t * (P1 - P0)
                    // t is in Q16.16. P0 is Q16.16.
                    // t * (P1 - P0) -> Q16.16 * Q16.16 = Q32.32. Take top 32 bits -> Q16.16
                    
                    if ((dist0[31] ^ dist1[31]) && (dist0 != 0) && (dist1 != 0)) begin
                        // Intersection logic
                        // Only if we are crossing or entering
                        // Check logic: If P0 outside, P1 inside: Add Intersection then P1
                        // If P0 inside, P1 outside: Add Intersection
                        
                        // We need to compute t again or store it. 
                        // Stored in temp_val from division (simulated)
                        // Since division is implicit, we use the calculated values
                        // Actually, let's use a variable 't' computed in INTERSECT or combinational
                        // To keep it sequential: we wait for division.
                        // Assuming simple division block for now (latency 1 or combinational)
                        
                        // Let's calculate P_int = P0 + t * (P1 - P0)
                        // t = num / den. 
                        
                        // Calculate delta = P1 - P0
                        dx <= edge_x1 - edge_x0;
                        dy <= edge_y1 - edge_y0;
                    end
                    
                    // Logic for adding vertices based on sides
                    // We need to handle the 2 cases carefully
                    // Case A: P0 Outside, P1 Inside. Add Intersection, then P1
                    // Case B: P0 Inside, P1 Outside. Add Intersection.
                    // Case C: Both Inside. Add P1 (handled in INTERSECT)
                    // Case D: Both Outside. Do nothing.
                end

                CALC_AREA: begin
                    // Accumulate Shoelace sum
                    // Area += x[i] * y[i+1] - x[i+1] * y[i]
                    // Using the generated polygon in poly_x/poly_y
                    // This state loops through the generated vertices
                    
                    // Note: Shoelace formula requires cyclic connection (last to first)
                    // The polygon array 'poly_x' contains the vertices of the clipped polygon.
                    // Size is 'out_count'.
                    // Loop i from 0 to out_count-1
                    // sum += x[i] * y[i+1] - x[i+1] * y[i]
                    
                    // We calculate this in the FSM or a separate block.
                    // Since N is small, we can do it sequentially.
                    // sum_x accumulates x[i] * y[i+1]
                    // sum_y accumulates y[i] * x[i+1]
                end

                FINISH: begin
                    done <= 1'b1;
                    // Final calculation: Area = 0.5 * |sum_x - sum_y|
                    // Sum is in Q32.16 (since inputs Q16.16 multiplied -> Q32.32, we tracked top bits or scaled)
                    // Let's say sum_x and sum_y are Q48.16 accumulators.
                    // Result Area = 0.5 * abs( (sum_x >> 16) - (sum_y >> 16) )
                    // Divide by 2 (shift right 1) and shift right 16 for fractional bits.
                    // Result is Q16.16.
                    
                    temp_val <= (sum_x - sum_y);
                    if (temp_val[63]) temp_val <= ~temp_val + 64'd1; // Absolute value
                    // temp_val is now Q48.16 roughly. 
                    // Area = temp_val / 2 (shift right 1) then take [47:16]
                    result_area <= temp_val[48:17]; // Shift right 17 (divide by 2 and keep Q16.16)
                    // Shift right 17: 
                    // Div by 2 (>>1) -> [62:0]
                    // Keep Q16.16 -> bits [47:16]
                    // So [62:0] -> [47:16] is a shift of 16. Total shift 17.
                    // Wait, if input is Q16.16, mult is Q32.32. 
                    // Sum is 64 bit. Upper 48 bits represent integer, lower 16 fractional.
                    // 0.5 * abs(diff).
                    // diff is Q32.16. /2 is Q31.16. Mask to Q16.16 (lower 32 bits)
                    result_area <= temp_val[48:17];
                end
            endcase
        end
    end

    // Combinational Logic for State Transitions and Division
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (N == 8'd0) next_state = FINISH;
                    else next_state = CALC_DIST;
                end
            end

            CALC_DIST: begin
                next_state = CHECK_SIDE;
            end

            CHECK_SIDE: begin
                // Wait one cycle for distance calculation result
                next_state = INTERSECT;
            end

            INTERSECT: begin
                // Determine what to do with edge (i-1 -> i)
                // Logic:
                // dist0 is distance of i-1 (stored in global or previous calculation)
                // dist1 is distance of i (just calculated in CHECK_SIDE stage)
                // We need to access dist0. 
                // Let's maintain dist0 and dist1 properly.
                // In state INTERSECT, we calculate dist1 for current i.
                // We need dist0 from previous i.
                // Let's assume dist0 and dist1 are maintained.
                
                // Actually, the previous state logic needs refinement.
                // We need to store distances for the edge.
                
                // Let's refine the flow:
                // 1. Calculate Dist(i)
                // 2. Evaluate Edge(i-1, i)
                // 3. Update i
                
                // Let's restructure the sequential part in the always block
                // and handle transitions here.
                
                // We need to handle the polygon traversal.
                // The state INTERSECT handles the edge logic.
                // It decides if we add vertices.
                // Then it moves to next i or to CALC_AREA.
                
                // To fix the logic:
                // In CALC_DIST, we computed dist for vertex i.
                // In INTERSECT, we check the edge (i-1, i).
                // We need to ensure dist0 corresponds to i-1 and dist1 to i.
                
                // Let's look at the Loop structure.
                // i goes 0 to N-1.
                // Vertex indices: v[i] and v[(i+1)%N].
                // But the problem says vertices 0 to N-1. Edge i connects v[i] to v[(i+1)%N].
                // We process edges 0 to N-1.
                // Edge 0: v[0] -> v[1]
                // Edge N-1: v[N-1] -> v[0]
                
                // Let's stick to the provided code flow but fix the control.
                
                if (i < N) begin
                    // We are processing vertex i.
                    // dist1 is now calculated for vertex i.
                    // We need to check edge (i-1, i) for i > 0.
                    // For i=0, we just store dist0 = dist1 and continue to i=1?
                    // No, we need to process edges.
                    
                    // Revised Algorithm:
                    // 1. Calculate dist for v[0]. Set dist0 = dist.
                    // 2. Loop i from 1 to N:
                    //    a. Calculate dist for v[i]. Set dist1 = dist.
                    //    b. Process edge (v[i-1], v[i]) with dist0, dist1.
                    //    c. Set dist0 = dist1.
                    //    d. Increment i.
                    // 3. Close loop (Edge v[N-1] -> v[0]).
                    //    Need to handle v[0] separately or store its dist.
                    
                    // Let's use the state machine to do this.
                    // We will add a state FETCH_PREV for the wrap-around logic.
                    
                    // Actually, simpler:
                    // Store distances in an array `dist_arr[0:99]`? 
                    // No, memory constraints. 
                    // Let's just store `ref_dist` (for v0) and current dist.
                    
                    // Let's define the transitions:
                    // IDLE -> CALC_DIST (i=0)
                    // CALC_DIST -> CHECK_SIDE
                    // CHECK_SIDE -> INTERSECT (Calculate dist1)
                    // INTERSECT -> ADD_VERTEX or NEXT_EDGE
                    // ADD_VERTEX -> NEXT_EDGE
                    // NEXT_EDGE -> CALC_DIST (if i < N) or CALC_AREA (if i == N and done with wrap)
                    // But wait, we need to process the last edge v[N-1] -> v[0].
                    // So we need an extra step after loop finishes.
                    
                    // Let's add a state NEXT_EDGE to handle the loop logic.
                    next_state = ADD_VERTEX; // Default fallthrough to ADD_VERTEX if intersection needed
                    
                    // Determine action based on sides in INTERSECT state
                    // If crossing, go to ADD_VERTEX to calculate intersection
                    // If not crossing, go to NEXT_EDGE directly
                end else begin
                    // i >= N. Finished input vertices.
                    // Process wrap-around edge: v[N-1] -> v[0]
                    // We need dist of v[N-1] (last calc) and dist of v[0] (stored in ref_dist).
                    // Let's handle this in a separate state WRAP_EDGE.
                    // But wait, the loop structure needs to be clear.
                    
                    // Let's try a linear FSM flow:
                    // 1. Start. Calc Dist(v0). Store in dist0. 
                    // 2. Loop: i = 1 to N.
                    //    - Calc Dist(vi) -> dist1.
                    //    - Check Edge(v[i-1], v[i]).
                    //    - If crossing, Calc Intersect.
                    //    - If inside, Add Vertex.
                    //    - dist0 = dist1.
                    // 3. End Loop.
                    // 4. Check Edge(v[N-1], v[0]). dist0 = last_dist, dist1 = ref_dist.
                    //    - Logic same.
                    // 5. Calculate Area.
                    
                    // To implement in this FSM:
                    // State INTERSECT handles the decision.
                    // We need to know if we are in the initial step (i=0) or loop.
                    // Let's add a flag or use state distinction.
                    
                    // Let's stick to the existing states but add logic.
                    // We need to calculate the intersection coordinates if crossing.
                    // So INTERSECT -> INTERSECT_COORD or ADD_VERTEX.
                    // Let's merge INTERSECT and ADD_VERTEX logic.
                    
                    // Refinement:
                    // State INTERSECT: calculates dist1 (if i < N). 
                    // Then decides: 
                    //   If crossing -> go to INTERSECT_COORD (calc t, then calc x,y) -> ADD_VERTEX
                    //   If entering -> go to ADD_VERTEX (add intersection, then add v[i])
                    //   If leaving -> go to ADD_VERTEX (add intersection)
                    //   If inside -> go to NEXT_EDGE (add v[i])
                    //   If outside -> go to NEXT_EDGE
                    // This is getting complex for a single state.
                    
                    // Let's simplify: 
                    // We will process edges 0..N-1 in a loop.
                    // We need to calculate intersection if signs differ.
                    // If signs differ, we add intersection point.
                    // If current point is inside, we add it.
                    
                    // We will use `i` as the current vertex index being processed as the END of the edge.
                    // Edge is from `i-1` to `i` (with wrap for i=0).
                    // Start:
                    // i=0. 
                    //   Dist(v0) -> dist0 (global for current vertex). 
                    //   We need to start the loop with i=1.
                    
                    // Revised Control Flow:
                    // 1. IDLE: if start, go to PREP_LOOP. i=0.
                    // 2. PREP_LOOP: 
                    //    - Calculate dist for v[0]. Store in `dist_prev`.
                    //    - If v[0] inside, add v[0] to poly list.
                    //    - i = 1.
                    //    - Go to LOOP_CALC_DIST.
                    // 3. LOOP_CALC_DIST:
                    //    - If i == N, go to WRAP_EDGE.
                    //    - Calculate dist for v[i] -> `dist_curr`.
                    //    - Go to LOOP_PROCESS.
                    // 4. LOOP_PROCESS:
                    //    - Check edge (v[i-1], v[i]) with dist_prev, dist_curr.
                    //    - If crossing: Calculate Intersection -> Add to poly.
                    //    - If curr inside: Add v[i] to poly.
                    //    - `dist_prev` = `dist_curr`.
                    //    - i++.
                    //    - Go to LOOP_CALC_DIST.
                    // 5. WRAP_EDGE:
                    //    - `dist_curr` = `ref_dist` (dist of v[0]).
                    //    - `edge_x0` = v[N-1], `edge_y0` = v[N-1]
                    //    - `edge_x1` = v[0], `edge_y1` = v[0]
                    //    - Go to LOOP_PROCESS (or similar logic).
                    //    - After processing, go to CALC_AREA.
                    // 6. CALC_AREA: Compute shoelace.
                    // 7. FINISH.
                    
                    // Let's implement this flow.
                    // We need to add PREP_LOOP and WRAP_EDGE states.
                    // And separate states for INTERSECTION calculation.
                    
                    // Due to complexity, let's try to fit into existing states with some modification.
                    // State IDLE -> CALC_DIST (for v0)
                    // State CHECK_SIDE -> store dist0, check if v0 inside -> add v0. i=1. -> LOOP_START
                    // State LOOP_START: if i==N -> WRAP. else CALC_DIST (for v[i]).
                    // State INTERSECT: check edge (v[i-1], v[i]) -> if cross -> INTERSECT_COORD. else if inside -> ADD_VERT.
                    // 
                    // Let's just write the code for the flow described.
                    // We need to be careful with variable naming.
                    
                    // The provided states are: IDLE, CALC_DIST, CHECK_SIDE, INTERSECT, ADD_VERTEX, CALC_AREA, FINISH.
                    // We can reuse CHECK_SIDE for both initial check and loop check.
                    // We need to distinguish initial vs loop.
                    // Let's use `poly_count` as a flag or `i`.
                    
                    // Let's adjust the code structure in the ALWAYS block to be more explicit.
                end
                
                // To strictly follow the instruction "Use exactly the states provided if possible", 
                // but the logic requires a loop. 
                // I will modify the state transitions in the combinational block to fit the algorithm.
                // I will add comments to explain the flow.
                
                // Let's define the transitions:
                // IDLE -> CALC_DIST (Start processing v0)
                // CALC_DIST -> CHECK_SIDE
                // CHECK_SIDE -> 
                //    if (i == 0) -> NEXT_VERTEX (Init loop)
                //    else -> INTERSECT (Process edge i-1, i)
                // INTERSECT -> ADD_VERTEX (if crossing or entering)
                // ADD_VERTEX -> NEXT_VERTEX
                // NEXT_VERTEX -> 
                //    if (i < N) -> CALC_DIST
                //    else if (i == N) -> WRAP_EDGE
                //    else -> CALC_AREA
                // WRAP_EDGE -> INTERSECT (Process edge N-1, 0)
                // 
                // The provided states don't have NEXT_VERTEX or WRAP_EDGE.
                // I will create them in the always block logic implicitly or use existing states.
                // Actually, I will just implement the logic in the `next_state` assignments.
                
                // Let's list the states I will actually use:
                // IDLE, CALC_DIST, CHECK_SIDE, INTERSECT, ADD_VERTEX, CALC_AREA, FINISH.
                // I need to handle the loop control. 
                // I will use `state` transitions to mimic the loop.
                
                // Transitions:
                // IDLE -> CALC_DIST (if start)
                // CALC_DIST -> CHECK_SIDE
                // CHECK_SIDE -> INTERSECT
                // INTERSECT -> ADD_VERTEX (if we need to add intersection) or NEXT_STEP
                // ADD_VERTEX -> NEXT_STEP
                // NEXT_STEP -> CALC_DIST (if i < N) or CALC_AREA (if i >= N)
                // CALC_AREA -> FINISH
                
                // I will rename INTERSECT to PROCESS_EDGE to be clearer.
                // Let's stick to the provided names but interpret them flexibly.
                // State INTERSECT: calculate t (if crossing).
                // State ADD_VERTEX: add vertex (intersection or current).
                // State CHECK_SIDE: calculate dist for current vertex.
                
                // Refined Flow:
                // 1. IDLE: wait for start.
                // 2. CALC_DIST: calculate distance for vertex i. (Initially i=0)
                // 3. CHECK_SIDE: 
                //    - Store distance.
                //    - If i == 0: store ref_dist, check if inside -> add v0. i=1. -> Goto 2.
                //    - If i > 0: check edge (v[i-1], v[i]). -> Goto 4.
                // 4. INTERSECT:
                //    - If crossing: calculate intersection. -> Goto 5.
                //    - If not crossing and inside: add v[i]. -> Goto 6.
                //    - If not crossing and outside: -> Goto 6.
                //    - If leaving: calculate intersection. -> Goto 5.
                // 5. ADD_VERTEX: add the intersection point (or whatever vertex is pending).
                // 6. NEXT: i++.
                //    - If i < N: Goto 2.
                //    - If i == N: calculate dist for v[0] again? No, we have it in ref_dist.
                //      Process wrap edge (v[N-1], v[0]). -> Goto 4 (special handling).
                //    - If done wrap: Goto CALC_AREA.
                // 
                // This requires more than the 7 states provided if we want clarity.
                // But the instruction says "generate an efficient Verilog module... using provided details".
                // It doesn't forbid adding localparams. It just gives example states.
                // I will add necessary states to make it robust.
                // Added: WRAP, NEXT.
                
                // Let's re-list states for the code:
                // IDLE, CALC_DIST, CHECK_SIDE, INTERSECT, ADD_VERTEX, CALC_AREA, FINISH.
                // I will use the existing states and add logic to handle the loops.
                // Actually, I will add a state `NEXT` to handle the loop increment and conditionals.
                // And `WRAP` for the final edge.
                
                // Let's refine the transitions in the combinational block.
                
            end
            
            // ... (Transitions defined in the combinational block below)
        endcase
    end
    
    // Separate combinational block for state transitions and division logic
    // to keep the sequential block cleaner and handle division latency (if any).
    // Assuming combinational division for now (synthesis might unroll it or use DSP).
    // Division for intersection: t = dist0 / (dist0 - dist1). 
    // Since we need to do this inside a state, we might need to wait or compute fast.
    // For synthesizable code, we often use a loop or a pipeline.
    // With N<=100 and cycle limit 1000, a sequential divider is acceptable.
    // But implementing a full divider is huge. 
    // We will use the "/" operator. Verilog synthesis handles it.
    
    // Re-declare state registers for clarity if needed, but we used the ones above.
    // Let's add the missing states in the localparams (I'll edit the initial block or just redefine here)
    // Since I cannot edit the initial block text easily in this format, I will add them dynamically.
    // Wait, I can just add more localparams. 
    
    localparam [3:0] NEXT = 4'd7;
    localparam [3:0] WRAP = 4'd8;
    
    // Update the always block logic to include these states.
    // I will rewrite the always block to be correct and robust.
    // The previous always block was a sketch. I will now provide the full implementation.

endmodule

// The module above has a flawed structure for the loop. 
// Let's rewrite the entire module cleanly with the correct logic flow.
// The previous code was a draft. The final output should be correct.

module polygon_clipper_final (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input signed [31:0] xa, ya, xb, yb,
    input signed [15:0] arr_x [0:99],
    input signed [15:0] arr_y [0:99],
    output reg signed [31:0] result_area,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CALC_DIST   = 4'd1; // Calculate signed distance for current vertex
    localparam [3:0] CHECK_LOOP  = 4'd2; // Check if we are at start, loop, or end
    localparam [3:0] PROCESS_EDGE = 4'd3; // Handle clipping logic for the edge
    localparam [3:0] ADD_VERTEX  = 4'd4; // Add vertex to output list
    localparam [3:0] NEXT_VERTEX = 4'd5; // Increment counter and loop control
    localparam [3:0] CALC_AREA   = 4'd6; // Compute shoelace area
    localparam [3:0] FINISH      = 4'd7; // Done signal

    reg [3:0] state, next_state;
    reg [7:0] i; // Current vertex index (end of edge)
    reg [7:0] out_idx; // Index for output polygon
    
    // Storage for geometry
    reg signed [31:0] poly_x [0:99]; // Q16.16
    reg signed [31:0] poly_y [0:99]; // Q16.16
    reg signed [31:0] dist_prev; // Distance of previous vertex
    reg signed [31:0] dist_curr; // Distance of current vertex
    reg signed [31:0] ref_dist;  // Distance of vertex 0
    reg signed [31:0] x_prev, y_prev; // Coords of previous vertex
    reg signed [31:0] x_curr, y_curr; // Coords of current vertex
    
    // Computation registers
    reg signed [63:0] temp_sum; // For shoelace accumulation
    reg signed [31:0] t_val; // Intersection parameter t (Q16.16)
    reg signed [31:0] int_x, int_y; // Intersection coordinates
    
    // Helper wires for calculations
    wire signed [31:0] line_dx = xb - xa;
    wire signed [31:0] line_dy = yb - ya;
    wire signed [63:0] dist_calc; // Result of determinant
    
    // Combinational distance calculation: (x-xa)*(yb-ya) - (y-ya)*(xb-xa)
    // Inputs: x_curr, y_curr
    assign dist_calc = ($signed({{32{x_curr[15]}}, x_curr}) - $signed({{32{xa[15]}}, xa})) * $signed(line_dy) - 
                       ($signed({{32{y_curr[15]}}, y_curr}) - $signed({{32{ya[15]}}, ya})) * $signed(line_dx);
    // Result is Q32.32. We take Q32.0 (shift right 16)
    wire signed [31:0] current_dist = dist_calc[47:16];
    
    // Combinational Intersection calculation
    // t = dist_prev / (dist_prev - dist_curr)
    // Need to handle division.
    // For synthesizable Verilog, we can use the / operator.
    // t needs to be Q16.16. 
    // numerator: dist_prev << 16
    // denominator: dist_prev - dist_curr
    wire signed [63:0] num_t = {dist_prev[31:0], 16'd0};
    wire signed [31:0] den_t = dist_prev - dist_curr;
    wire signed [31:0] t_calc = (den_t == 0) ? 32'd0 : (num_t / den_t);
    
    // P_int = P_prev + t * (P_curr - P_prev)
    wire signed [31:0] dx_edge = x_curr - x_prev;
    wire signed [31:0] dy_edge = y_curr - y_prev;
    wire signed [63:0] delta_x = $signed({{32{dx_edge[15]}}, dx_edge}) * $signed(t_val);
    wire signed [63:0] delta_y = $signed({{32{dy_edge[15]}}, dy_edge}) * $signed(t_val);
    // delta is Q32.32 (input Q16.16 * Q16.16). We want Q16.16 result.
    wire signed [31:0] int_x_calc = x_prev + delta_x[47:16];
    wire signed [31:0] int_y_calc = y_prev + delta_y[47:16];
    
    // Cycle counter
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_area <= 32'd0;
            done <= 1'b0;
            i <= 8'd0;
            out_idx <= 8'd0;
            dist_prev <= 32'd0;
            dist_curr <= 32'd0;
            ref_dist <= 32'd0;
            x_prev <= 32'd0;
            y_prev <= 32'd0;
            x_curr <= 32'd0;
            y_curr <= 32'd0;
            t_val <= 32'd0;
            temp_sum <= 64'd0;
            cycle_count <= 16'd0;
            // Initialize poly arrays
            for (int k = 0; k < 100; k = k + 1) begin
                poly_x[k] <= 32'd0;
                poly_y[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 8'd0;
                    out_idx <= 8'd0;
                    temp_sum <= 64'd0;
                    cycle_count <= 16'd0;
                end
                
                CALC_DIST: begin
                    // Capture coordinates for current vertex i
                    // Note: arr_x and arr_y are Q16.16 (signed 16-bit inputs in spec, but Q16.16 implies 32-bit usually)
                    // The spec says "16-bit signed Q16.16". This is ambiguous (16-bit vs 32-bit storage).
                    // Typically Q16.16 needs 32 bits. 
                    // Assuming inputs are 32-bit holding Q16.16 values, or 16-bit inputs need sign extension.
                    // Given "16-bit signed Q16.16", I will assume they are 16-bit inputs representing Q0.16 or Q1.15.
                    // BUT the canal parameters are 32-bit. 
                    // Spec: "Vertices (arr_x[0:99], arr_y[0:99] as 16-bit signed Q16.16)".
                    // This is impossible for 16-bit registers. Likely a typo in prompt meaning 32-bit.
                    // I will treat them as 32-bit signals. If they were 16-bit, I'd need to shift left 16.
                    // However, the input definition says `input signed [15:0] arr_x`. 
                    // I must adhere to the interface. 
                    // IF 16-bit input: value is integer part? or fractional?
                    // Q16.16 means 16 integer, 16 fractional. Needs 32 bits.
                    // I will assume the prompt meant 32-bit inputs but wrote 16-bit by mistake, OR 
                    // I must treat them as Q0.16 (which fits 16 bits) and scale up.
                    // Given the context of "fixed-point precision Q16.16", it's safer to assume 32-bit storage or scale.
                    // I will treat the 16-bit inputs as the lower 16 bits of a Q16.16 number (so integer part is 0).
                    // Wait, if inputs are 16-bit, they can't hold integer values > 32767.
                    // Let's check the interface again: `input signed [15:0] arr_x [0:99]`.
                    // I will interpret these 16 bits as the Q16.16 value shifted right by 16? No, that truncates.
                    // I will treat them as 16-bit inputs and pad them to 32-bit for calculation.
                    // Pad with 16 zeros in lower bits (making them Q16.0 in the lower 16, effectively Q0.16 in the upper?)
                    // No, standard Q16.16 is 32 bits.
                    // To be safe: I will assume the 16-bit input is the INTEGER part (Q16.0) and fractional is 0.
                    // OR, I will assume it's Q0.16 and shift left 16.
                    // Given the mix with 32-bit canal params, I will LEFT SHIFT the 16-bit inputs by 16 bits to convert to Q16.16.
                    // Input is `signed [15:0]`. 
                    // `x_curr <= {arr_x[i], 16'd0};` 
                    // This seems the most logical way to bridge 16-bit input to Q16.16 internal calc.
                    
                    x_curr <= {arr_x[i], 16'd0};
                    y_curr <= {arr_y[i], 16'd0};
                end
                
                CHECK_LOOP: begin
                    // Calculate distance for current vertex
                    dist_curr <= current_dist;
                    
                    if (i == 8'd0) begin
                        // Initialization
                        ref_dist <= current_dist;
                        dist_prev <= current_dist;
                        x_prev <= x_curr;
                        y_prev <= y_curr;
                        
                        // If vertex 0 is inside, add it
                        // Inside means same sign as reference (or on line)
                        if (current_dist[31] == ref_dist[31] || current_dist == 0) begin
                            poly_x[out_idx] <= x_curr;
                            poly_y[out_idx] <= y_curr;
                            out_idx <= out_idx + 8'd1;
                        end
                    end else begin
                        // Normal loop iteration
                        // We already have dist_prev and dist_curr ready
                        // Handled in PROCESS_EDGE
                    end
                end
                
                PROCESS_EDGE: begin
                    // Logic to decide if we add intersection or vertex
                    // We need to check signs of dist_prev and dist_curr
                    
                    // Crossing? (Different signs and neither is zero)
                    if ((dist_prev[31] != dist_curr[31]) && (dist_prev != 0) && (dist_curr != 0)) begin
                        // Calculate intersection
                        // t = dist_prev / (dist_prev - dist_curr)
                        // We use the combinational wire t_calc
                        t_val <= t_calc;
                        // Note: t_val needs to be valid for the next cycle if we do ADD_VERTEX immediately
                        // But here we just store it. 
                    end
                end
                
                ADD_VERTEX: begin
                    // Add intersection if crossing
                    if ((dist_prev[31] != dist_curr[31]) && (dist_prev != 0) && (dist_curr != 0)) begin
                        poly_x[out_idx] <= int_x_calc;
                        poly_y[out_idx] <= int_y_calc;
                        out_idx <= out_idx + 8'd1;
                    end
                    
                    // Add current vertex if it is inside
                    // "Inside" means same side as reference (ref_dist)
                    // But we are clipping to the side of the reference point.
                    // So if dist_curr has same sign as ref_dist (or is 0), it's inside.
                    if (dist_curr[31] == ref_dist[31] || dist_curr == 0) begin
                        poly_x[out_idx] <= x_curr;
                        poly_y[out_idx] <= y_curr;
                        out_idx <= out_idx + 8'd1;
                    end
                    
                    // Update previous for next iteration
                    dist_prev <= dist_curr;
                    x_prev <= x_curr;
                    y_prev <= y_curr;
                end
                
                NEXT_VERTEX: begin
                    i <= i + 8'd1;
                end
                
                CALC_AREA: begin
                    // Compute Shoelace: Sum over k=0 to m-1 (x[k]*y[k+1] - x[k+1]*y[k])
                    // Cyclic: index m connects to 0.
                    // We do this incrementally to save logic or sequentially.
                    // Here we do it sequentially in this state (or loop inside state).
                    // Since we are in a state machine, let's loop via states or a counter.
                    // Let's use `i` as the index for summation.
                    
                    if (i < out_idx) begin
                        // We need x[i], y[i], x[i+1], y[i+1]
                        // If i is last, i+1 is 0.
                        // We can calculate term and add to temp_sum.
                        // term = x[i] * y[i+1] - x[i+1] * y[i]
                        // Multiplication Q16.16 * Q16.16 -> Q32.32. We accumulate the top 32 bits (or full 64).
                        
                        // To avoid complex indexing logic in one cycle, we will just do one term per cycle.
                        // We need to handle the wrap around for i = out_idx - 1.
                        
                        // Let's calculate term in combinational logic based on i.
                        // We will update temp_sum here.
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Normalize result.
                    // temp_sum is accumulation of 64-bit products.
                    // Area = 0.5 * |Sum|.
                    // Sum is Q32.32 (roughly). 
                    // We need to shift right by 17 to get Q16.16 (divide by 2 and shift fraction).
                    // Abs value first.
                    if (temp_sum[63]) temp_sum <= ~temp_sum + 64'd1;
                    
                    // Result = temp_sum >> 17
                    result_area <= temp_sum[48:17];
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_DIST;
            end
            
            CALC_DIST: begin
                next_state = CHECK_LOOP;
            end
            
            CHECK_LOOP: begin
                if (i == 0) begin
                    // Initial vertex processed, move to next
                    next_state = NEXT_VERTEX;
                end else begin
                    // Process the edge (prev, curr)
                    next_state = PROCESS_EDGE;
                end
            end
            
            PROCESS_EDGE: begin
                // Always go to ADD_VERTEX to handle logic
                next_state = ADD_VERTEX;
            end
            
            ADD_VERTEX: begin
                next_state = NEXT_VERTEX;
            end
            
            NEXT_VERTEX: begin
                if (i < N - 8'd1) begin
                    next_state = CALC_DIST;
                end else if (i == N - 8'd1) begin
                    // Last vertex processed? No, i is incremented in NEXT_VERTEX.
                    // Let's rethink the loop control.
                    // i is index of current vertex.
                    // Loop 0..N-1.
                    // i=0: Init. -> NEXT (i=1)
                    // i=1..N-1: Process edge i-1, i. -> NEXT (i++)
                    // When i==N: We are done with input vertices.
                    // Now we need to process the closing edge: (N-1, 0).
                    // We have dist of N-1 in dist_prev. We need dist of 0 in dist_curr.
                    // We have ref_dist.
                    // So we can set dist_curr = ref_dist, x_curr = poly_x[0] (if added) or arr_x[0].
                    // Then go to PROCESS_EDGE for the wrap.
                    // After that, go to CALC_AREA.
                    
                    // Let's adjust the check.
                    // In NEXT_VERTEX, i is already incremented.
                    // Wait, in my logic above, I incremented i in NEXT_VERTEX state block.
                    // Let's move the increment to the transition or ensure order.
                    // In the sequential block, i <= i + 1 happens at the end of the cycle.
                    // In the combinational block, i is still the OLD value.
                    // So in NEXT_VERTEX, i is the index of the vertex we JUST processed.
                    // If i == N-1, we just processed the last input vertex.
                    // Next is Wrap Edge.
                    // If i == N, we just processed the Wrap Edge.
                    // Next is CALC_AREA.
                    
                    // Let's refine the checks:
                    // If i == N-1: We processed vertex N-1. Next is Wrap Edge (needs N-1 and 0).
                    // But we need to setup inputs for Wrap Edge.
                    // So go to a specific WRAP state (or reuse CALC_DIST with modified inputs?).
                    // Since we don't have a WRAP state, we can reuse PROCESS_EDGE if we set up vars manually.
                    // But PROCESS_EDGE expects curr/prev to be set.
                    // Let's add a WRAP state or use CALC_DIST cleverly.
                    // CALC_DIST calculates dist for arr_x[i]. We can't use that for vertex 0.
                    // So let's just add a WRAP state. 
                    // I'll define it locally as a next_state value.
                    
                    if (i == N) begin
                        // i is N (which is out of range 0..N-1). 
                        // This means we finished the loop and the wrap (if handled).
                        // But wait, the loop logic needs to be precise.
                        
                        // Let's restart the logic for NEXT_VERTEX transition:
                        // 1. i=0 -> Processed v0. -> next_state CALC_DIST (for v1). (i becomes 1 in CALC_DIST?
                        // No, i is updated in NEXT_VERTEX.
                        // Let's simplify: Update i in the STATE TRANSITION or always block?
                        // Usually it's safer in the always block.
                        
                        // Let's assume i was incremented in the previous state (ADD_VERTEX) or NEXT_VERTEX.
                        // Actually, let's keep i update in the always block for state NEXT_VERTEX.
                        
                        // Logic:
                        // i=0: IDLE -> CALC_DIST (i=0) -> CHECK_LOOP -> NEXT_VERTEX (i=1)
                        // i=1: NEXT_VERTEX -> CALC_DIST (i=1) -> CHECK_LOOP -> PROCESS_EDGE -> ADD_VERTEX -> NEXT_VERTEX (i=2)
                        // ...
                        // i=N-1: NEXT_VERTEX -> CALC_DIST (i=N-1) -> CHECK_LOOP -> PROCESS_EDGE -> ADD_VERTEX -> NEXT_VERTEX (i=N)
                        // i=N: NEXT_VERTEX. Here i == N.
                        // We need to process edge (N-1, 0).
                        // We have dist_prev (from v[N-1]). We need dist_curr (from v[0]).
                        // We have x_prev, y_prev (from v[N-1]). We need x_curr, y_curr (from v[0]).
                        // We can load these manually.
                        // Then go to PROCESS_EDGE.
                        // After PROCESS_EDGE -> ADD_VERTEX -> NEXT_VERTEX (i=N+1).
                        // i=N+1 -> CALC_AREA.
                        
                        // So in NEXT_VERTEX when i == N:
                        // Load dist_curr = ref_dist.
                        // Load x_curr = poly_x[0] (or arr_x[0])?
                        // Note: poly_x[0] might not be valid if v0 was outside.
                        // But ref_dist was calculated from arr_x[0]. So use arr_x[0].
                        // Then go to PROCESS_EDGE.
                        
                        next_state = 4'd8; // WRAP state
                    end else begin
                        next_state = CALC_DIST;
                    end
                end else begin
                    // i >= N (initially? No)
                    // If i was incremented to N, we go to WRAP.
                    // If i > N, we go to CALC_AREA.
                    next_state = CALC_DIST;
                end
            end
            
            // Handing the WRAP state (mapped to code 8)
            4'd8: begin // WRAP
                next_state = PROCESS_EDGE;
            end
            
            CALC_AREA: begin
                if (i < out_idx) begin
                    next_state = CALC_AREA; // Stay here until done
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                if (!start) next_state = IDLE; // Wait for start to go low to reset?
                // Usually done is a pulse, so return to IDLE.
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Special override for the loop start
        // In CHECK_LOOP, if i==0, we go NEXT_VERTEX.
        // In NEXT_VERTEX (state), we update i.
        // If i was 0, now i is 1.
        // Transition from NEXT_VERTEX:
        // If i < N, go CALC_DIST.
        // If i == N (impossible after i=0->1 unless N=1), go WRAP.
        // If N=1, we process v0, then i=1. i==N (1). Go WRAP.
        // Edge (0, 0)? No, edge (N-1, 0) = (0,0).
        // This logic seems correct.
    end

    // Specific logic for CALC_AREA state to compute sums sequentially
    // We need a separate counter for the area summation loop since 'i' is used for input loop.
    // Let's use a new register `area_idx`.
    reg [7:0] area_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            area_idx <= 8'd0;
        end else begin
            if (state == CALC_AREA) begin
                if (area_idx < out_idx) begin
                    // Calculate term for area_idx
                    // We need x[area_idx], y[area_idx], x[area_idx+1], y[area_idx+1]
                    // Handle wrap for last index
                    // Use temporary variables for multiplication to avoid timing issues or just accumulate
                    // Accumulation in temp_sum (64-bit)
                    
                    // We'll compute in combinational logic and update temp_sum in the sequential block
                    // Or compute directly here if we insert a stall cycle. 
                    // For efficiency, let's do combinational calculation of the term.
                    // But accessing arrays in combinational logic with index variable is okay.
                    
                    // Let's compute term = x[i] * y[i+1] - x[i+1] * y[i]
                    // We need to handle i+1 wrapping to 0.
                    
                    // To keep it simple and sequential (1 term per cycle):
                    // We can use a combinational wire for the term, then add to temp_sum.
                    
                    // Note: Updating area_idx here ensures we do one term per cycle.
                    area_idx <= area_idx + 8'd1;
                end
            end else begin
                area_idx <= 8'd0;
            end
        end
    end
    
    // Combinational logic for Shoelace term
    wire signed [31:0] x_i = poly_x[area_idx];
    wire signed [31:0] y_i = poly_y[area_idx];
    wire signed [31:0] x_next = (area_idx == out_idx - 8'd1) ? poly_x[0] : poly_x[area_idx + 8'd1];
    wire signed [31:0] y_next = (area_idx == out_idx - 8'd1) ? poly_y[0] : poly_y[area_idx + 8'd1];
    
    wire signed [63:0] term1 = $signed({{32{x_i[15]}}, x_i}) * $signed({{32{y_next[15]}}, y_next});
    wire signed [63:0] term2 = $signed({{32{x_next[15]}}, x_next}) * $signed({{32{y_i[15]}}, y_i});
    wire signed [63:0] term_diff = term1 - term2;
    
    // Update temp_sum in the sequential block if we are in CALC_AREA and valid
    // We need to modify the always block to handle this accumulation.
    // Since I cannot easily insert into the middle of the previous always block without rewriting it fully,
    // I will add the accumulation logic there conceptually.
    // In the CALC_AREA state of the sequential always block:
    // if (state == CALC_AREA && area_idx < out_idx) temp_sum <= temp_sum + term_diff;

endmodule

// To ensure clean code, I will provide the final consolidated module.
// I will merge the logic into a single module with clear state definitions.
// I will add the missing state WRAP (4'd8) explicitly.

module polygon_area (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input signed [31:0] xa, ya, xb, yb,
    input signed [15:0] arr_x [0:99],
    input signed [15:0] arr_y [0:99],
    output reg signed [31:0] result_area,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CALC_DIST   = 4'd1;
    localparam [3:0] CHECK_LOOP  = 4'd2;
    localparam [3:0] PROCESS_EDGE = 4'd3;
    localparam [3:0] ADD_VERTEX  = 4'd4;
    localparam [3:0] NEXT_VERTEX = 4'd5;
    localparam [3:0] WRAP_EDGE   = 4'd6; // Special state for final edge
    localparam [3:0] CALC_AREA   = 4'd7;
    localparam [3:0] FINISH      = 4'd8;

    reg [3:0] state, next_state;
    reg [7:0] i; 
    reg [7:0] out_idx;
    reg [7:0] area_idx;
    
    // Storage
    reg signed [31:0] poly_x [0:99];
    reg signed [31:0] poly_y [0:99];
    reg signed [31:0] dist_prev, dist_curr, ref_dist;
    reg signed [31:0] x_prev, y_prev, x_curr, y_curr;
    reg signed [31:0] t_val;
    reg signed [63:0] temp_sum;
    
    // Wires for calculations
    wire signed [31:0] line_dx = xb - xa;
    wire signed [31:0] line_dy = yb - ya;
    
    // Distance: (x-xa)*(yb-ya) - (y-ya)*(xb-xa)
    // Input 16-bit values are converted to Q16.16 by left shifting 16 bits.
    wire signed [31:0] curr_x_q16 = {arr_x[i], 16'd0};
    wire signed [31:0] curr_y_q16 = {arr_y[i], 16'd0};
    wire signed [63:0] dist_calc_val = 
        ($signed({{32{curr_x_q16[15]}}, curr_x_q16}) - $signed({{32{xa[15]}}, xa})) * $signed(line_dy) - 
        ($signed({{32{curr_y_q16[15]}}, curr_y_q16}) - $signed({{32{ya[15]}}, ya})) * $signed(line_dx);
    wire signed [31:0] current_dist = dist_calc_val[47:16];
    
    // Intersection t: dist_prev / (dist_prev - dist_curr)
    wire signed [63:0] num_t = {dist_prev[31:0], 16'd0};
    wire signed [31:0] den_t = dist_prev - dist_curr;
    wire signed [31:0] t_calc = (den_t == 0) ? 32'd0 : (num_t / den_t);
    
    // Intersection Point
    wire signed [31:0] dx_edge = x_curr - x_prev;
    wire signed [31:0] dy_edge = y_curr - y_prev;
    wire signed [63:0] delta_x = $signed({{32{dx_edge[15]}}, dx_edge}) * $signed(t_val);
    wire signed [63:0] delta_y = $signed({{32{dy_edge[15]}}, dy_edge}) * $signed(t_val);
    wire signed [31:0] int_x_calc = x_prev + delta_x[47:16];
    wire signed [31:0] int_y_calc = y_prev + delta_y[47:16];
    
    // Shoelace Term
    wire signed [31:0] x_i = poly_x[area_idx];
    wire signed [31:0] y_i = poly_y[area_idx];
    wire signed [31:0] x_next = (area_idx == out_idx - 8'd1 && out_idx > 0) ? poly_x[0] : poly_x[area_idx + 8'd1];
    wire signed [31:0] y_next = (area_idx == out_idx - 8'd1 && out_idx > 0) ? poly_y[0] : poly_y[area_idx + 8'd1];
    wire signed [63:0] s_term1 = $signed({{32{x_i[15]}}, x_i}) * $signed({{32{y_next[15]}}, y_next});
    wire signed [63:0] s_term2 = $signed({{32{x_next[15]}}, x_next}) * $signed({{32{y_i[15]}}, y_i});
    wire signed [63:0] s_diff = s_term1 - s_term2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_area <= 32'd0;
            done <= 1'b0;
            i <= 8'd0;
            out_idx <= 8'd0;
            area_idx <= 8'd0;
            dist_prev <= 32'd0;
            dist_curr <= 32'd0;
            ref_dist <= 32'd0;
            x_prev <= 32'd0;
            y_prev <= 32'd0;
            x_curr <= 32'd0;
            y_curr <= 32'd0;
            t_val <= 32'd0;
            temp_sum <= 64'd0;
            for (int k = 0; k < 100; k = k + 1) begin
                poly_x[k] <= 32'd0;
                poly_y[k] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 8'd0;
                    out_idx <= 8'd0;
                    area_idx <= 8'd0;
                    temp_sum <= 64'd0;
                end
                
                CALC_DIST: begin
                    // Capture coordinates (scaled to Q16.16)
                    x_curr <= {arr_x[i], 16'd0};
                    y_curr <= {arr_y[i], 16'd0};
                end
                
                CHECK_LOOP: begin
                    // Store calculated distance
                    dist_curr <= current_dist;
                    
                    if (i == 0) begin
                        // Initialize reference
                        ref_dist <= current_dist;
                        dist_prev <= current_dist;
                        x_prev <= x_curr;
                        y_prev <= y_curr;
                        
                        // If vertex 0 is inside, add it
                        if (current_dist[31] == ref_dist[31] || current_dist == 0) begin
                            poly_x[out_idx] <= x_curr;
                            poly_y[out_idx] <= y_curr;
                            out_idx <= out_idx + 8'd1;
                        end
                    end
                end
                
                ADD_VERTEX: begin
                    // Add intersection if crossing
                    if ((dist_prev[31] != dist_curr[31]) && (dist_prev != 0) && (dist_curr != 0)) begin
                        poly_x[out_idx] <= int_x_calc;
                        poly_y[out_idx] <= int_y_calc;
                        out_idx <= out_idx + 8'd1;
                    end
                    
                    // Add current vertex if inside
                    if (dist_curr[31] == ref_dist[31] || dist_curr == 0) begin
                        poly_x[out_idx] <= x_curr;
                        poly_y[out_idx] <= y_curr;
                        out_idx <= out_idx + 8'd1;
                    end
                    
                    // Update previous
                    dist_prev <= dist_curr;
                    x_prev <= x_curr;
                    y_prev <= y_curr;
                end
                
                WRAP_EDGE: begin
                    // Setup for edge (last, 0)
                    // We need dist_curr = ref_dist (already calculated)
                    // But we need to set x_curr, y_curr to vertex 0 coords.
                    // Note: dist_prev was updated in ADD_VERTEX for the last vertex.
                    // We need to ensure dist_curr is ref_dist.
                    // In the transition to WRAP_EDGE, we should have set dist_curr.
                    // Let's assume it's handled or update it here if needed.
                    // Actually, better to calculate it or store it.
                    // We stored ref_dist.
                    dist_curr <= ref_dist;
                    // x_curr/y_curr should be vertex 0 coordinates.
                    // We need to be careful: vertex 0 might have been added or not.
                    // But we have x_prev/y_prev from the initial load or last update.
                    // We need to reload vertex 0 data.
                    x_curr <= {arr_x[0], 16'd0};
                    y_curr <= {arr_y[0], 16'd0};
                    // dist_prev is already the distance of the last vertex (N-1).
                end
                
                CALC_AREA: begin
                    if (area_idx < out_idx) begin
                        temp_sum <= temp_sum + s_diff;
                        area_idx <= area_idx + 8'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (temp_sum[63]) begin
                        // Negative, take absolute value
                        temp_sum <= ~temp_sum + 64'd1;
                    end
                    // Wait one cycle for abs to settle? No, combinational abs is better but we are in seq logic.
                    // Let's do the shift and assignment in the next cycle or combinational output.
                    // To save cycles, let's do it here.
                    // Note: temp_sum was just negated if needed. 
                    // We need to wait for the negation to complete. 
                    // Actually, let's calculate the result directly.
                    // If we are in FINISH, the previous cycle calculated the sum.
                    // So we can compute the result now.
                    // But we need to handle the sign check properly.
                    // Let's use a wire for the absolute value.
                end
            endcase
        end
    end
    
    // Combinational Abs and Shift for Result
    wire signed [63:0] final_sum = temp_sum[63] ? (~temp_sum + 64'd1) : temp_sum;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled above
        end else begin
            if (state == FINISH) begin
                // Perform shift right 17 (divide by 2 and remove fraction)
                // final_sum is Q32.32 (sum of Q16.16 products). 
                // Area = 0.5 * |Sum|.
                // Sum is approx Q32.32. Shift right 17 gives Q15.15? 
                // Let's be precise.
                // Inputs are Q16.16. 
                // Product is Q32.32. 
                // Sum is Q32.32 (accumulated).
                // Area = 0.5 * |Sum|.
                // Result needs to be Q16.16.
                // |Sum| is effectively Q32.32. 
                // 0.5 * Q32.32 = Q31.32.
                // We want Q16.16. We need to shift right by 15 (to get integer part) + 16 (to get fractional)?
                // No, Q31.32 to Q16.16 is shift right by 15.
                // Wait, standard Shoelace: Area = 0.5 * |Sum|.
                // Sum of (x_i * y_{i+1}) has magnitude of ~Range^2.
                // If inputs are 16-bit integers (scaled to Q16.0), sum is Q32.0.
                // Here inputs are Q16.16. Sum is Q32.32.
                // 0.5 * Sum = Q31.32.
                // To get Q16.16, we shift right by 15 (drop integer bits) and keep 16 fraction bits.
                // Total shift right 15? No.
                // Let's look at the code: 
                // `result_area <= final_sum[48:17];`
                // final_sum is 64 bits. 
                // Indices 63..0.
                // [48:17] is 32 bits.
                // Let's verify: 
                // We want to discard lower 16 bits (fractional part of sum) -> shift 16.
                // We want to divide by 2 -> shift 1.
                // Total shift 17.
                // So we take bits [63-17 : 16-17]? No.
                // Bits [63:0].
                // Shift right 17: effective bits [63:17].
                // We want 32 bits of result (Q16.16).
                // So take [48:17]. (48-17+1 = 32 bits).
                // Yes, that looks correct.
                
                result_area <= final_sum[48:17];
            end
        end
    end

    // State Transition Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CALC_DIST;
            
            CALC_DIST: next_state = CHECK_LOOP;
            
            CHECK_LOOP: begin
                if (i == 0) next_state = NEXT_VERTEX;
                else next_state = PROCESS_EDGE;
            end
            
            PROCESS_EDGE: next_state = ADD_VERTEX;
            
            ADD_VERTEX: next_state = NEXT_VERTEX;
            
            NEXT_VERTEX: begin
                if (i < N - 8'd1) begin
                    next_state = CALC_DIST;
                end else if (i == N - 8'd1) begin
                    // Just processed vertex N-1. 
                    // Next is Wrap Edge.
                    next_state = WRAP_EDGE;
                end else begin
                    // i >= N (should be N after increment)
                    // Just processed Wrap Edge.
                    next_state = CALC_AREA;
                end
            end
            
            WRAP_EDGE: next_state = PROCESS_EDGE;
            
            CALC_AREA: begin
                if (area_idx < out_idx) next_state = CALC_AREA;
                else next_state = FINISH;
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end
    
    // Update i in NEXT_VERTEX state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 8'd0;
        end else begin
            if (state == NEXT_VERTEX) begin
                i <= i + 8'd1;
            end else if (state == IDLE) begin
                i <= 8'd0;
            end
        end
    end

endmodule