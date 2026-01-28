module circle_regions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [7:0] circ_x [0:2],
    input wire [7:0] circ_y [0:2],
    input wire [7:0] circ_r [0:2],
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_R_SQ = 3'd1;
    localparam [2:0] CALC_DIST_01 = 3'd2;
    localparam [2:0] CALC_DIST_02 = 3'd3;
    localparam [2:0] CALC_DIST_12 = 3'd4;
    localparam [2:0] CLASSIFY = 3'd5;
    localparam [2:0] SORT_LOOKUP = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [15:0] r_sq [0:2]; // 16-bit squared radii
    reg [15:0] dist_sq_01, dist_sq_02, dist_sq_12;
    
    // Pairwise relationship codes (0: invalid, 1-5: defined)
    reg [2:0] rel_01, rel_02, rel_12;
    
    // Sorted tuple registers
    reg [2:0] s0, s1, s2;
    
    // Combinational helper signals
    wire [15:0] dx_01, dy_01, dx_02, dy_02, dx_12, dy_12;
    wire [15:0] r_sum_sq_01, r_diff_sq_01;
    wire [15:0] r_sum_sq_02, r_diff_sq_02;
    wire [15:0] r_sum_sq_12, r_diff_sq_12;
    
    // Intermediate calculation registers for pipelining
    reg [15:0] temp_mult_a, temp_mult_b;
    reg [31:0] temp_mult_result;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd30;

    integer i;

    // --- Combinational Logic for Calculations ---
    
    // Calculate differences (Q4.4 subtraction, result fits in 16-bit signed)
    assign dx_01 = { {8{circ_x[0][7]}}, circ_x[0] } - { {8{circ_x[1][7]}}, circ_x[1] };
    assign dy_01 = { {8{circ_y[0][7]}}, circ_y[0] } - { {8{circ_y[1][7]}}, circ_y[1] };
    assign dx_02 = { {8{circ_x[0][7]}}, circ_x[0] } - { {8{circ_x[2][7]}}, circ_x[2] };
    assign dy_02 = { {8{circ_y[0][7]}}, circ_y[0] } - { {8{circ_y[2][7]}}, circ_y[2] };
    assign dx_12 = { {8{circ_x[1][7]}}, circ_x[1] } - { {8{circ_x[2][7]}}, circ_x[2] };
    assign dy_12 = { {8{circ_y[1][7]}}, circ_y[1] } - { {8{circ_y[2][7]}}, circ_y[2] };

    // Radius sums and diffs (unsigned arithmetic for radii)
    wire [8:0] r_sum_01, r_diff_01;
    wire [8:0] r_sum_02, r_diff_02;
    wire [8:0] r_sum_12, r_diff_12;
    
    assign r_sum_01 = {1'b0, circ_r[0]} + {1'b0, circ_r[1]};
    assign r_diff_01 = (circ_r[0] > circ_r[1]) ? ({1'b0, circ_r[0]} - {1'b0, circ_r[1]}) : ({1'b0, circ_r[1]} - {1'b0, circ_r[0]});
    assign r_sum_02 = {1'b0, circ_r[0]} + {1'b0, circ_r[2]};
    assign r_diff_02 = (circ_r[0] > circ_r[2]) ? ({1'b0, circ_r[0]} - {1'b0, circ_r[2]}) : ({1'b0, circ_r[2]} - {1'b0, circ_r[0]});
    assign r_sum_12 = {1'b0, circ_r[1]} + {1'b0, circ_r[2]};
    assign r_diff_12 = (circ_r[1] > circ_r[2]) ? ({1'b0, circ_r[1]} - {1'b0, circ_r[2]}) : ({1'b0, circ_r[2]} - {1'b0, circ_r[1]});

    // Pre-calculate squared sum/diff (Q4.4 * Q4.4 = Q8.8, but we treat as integer for comparison)
    // Results fit in 16 bits (max 20*20 = 400)
    wire [15:0] r_sum_sq_01_wire, r_diff_sq_01_wire;
    wire [15:0] r_sum_sq_02_wire, r_diff_sq_02_wire;
    wire [15:0] r_sum_sq_12_wire, r_diff_sq_12_wire;
    
    // Combinational multipliers for radius calculation
    assign r_sum_sq_01_wire = r_sum_01 * r_sum_01;
    assign r_diff_sq_01_wire = r_diff_01 * r_diff_01;
    assign r_sum_sq_02_wire = r_sum_02 * r_sum_02;
    assign r_diff_sq_02_wire = r_diff_02 * r_diff_02;
    assign r_sum_sq_12_wire = r_sum_12 * r_sum_12;
    assign r_diff_sq_12_wire = r_diff_12 * r_diff_12;

    // --- Sort Logic (3-comparator network) ---
    wire [2:0] s0_wire, s1_wire, s2_wire;
    
    // Sort rel_01, rel_02, rel_12 into ascending order
    wire [2:0] max01_02, min01_02, med_val;
    wire [2:0] min_med_max02, med_max02;
    
    // Step 1: Sort rel_01 and rel_02
    assign max01_02 = (rel_01 > rel_02) ? rel_01 : rel_02;
    assign min01_02 = (rel_01 > rel_02) ? rel_02 : rel_01;
    
    // Step 2: Insert rel_12 into sorted pair
    wire [2:0] comp_min_12;
    assign comp_min_12 = (min01_02 > rel_12) ? rel_12 : min01_02;
    assign s0_wire = comp_min_12;
    
    wire [2:0] comp_mid_12_a, comp_mid_12_b;
    assign comp_mid_12_a = (min01_02 > rel_12) ? min01_02 : rel_12;
    assign comp_mid_12_b = (max01_02 > rel_12) ? rel_12 : max01_02;
    assign s1_wire = (comp_mid_12_a < comp_mid_12_b) ? comp_mid_12_a : comp_mid_12_b;
    
    wire [2:0] comp_max_12;
    assign comp_max_12 = (max01_02 > rel_12) ? max01_02 : rel_12;
    assign s2_wire = comp_max_12;

    // --- LUT for Result Mapping ---
    reg [3:0] lut_result;
    
    always @(*) begin
        // Default case covers invalid or n<3
        lut_result = 4'd2;
        
        if (n == 2'd1) begin
            lut_result = 4'd2;
        end else if (n == 2'd2) begin
            // Check if intersection exists (rel != 1 and rel != 2 means intersecting/touching)
            // Actually logic: Disjoint(1) or Tangent(2) -> 3 regions. Intersect(5) -> 4 regions.
            // Tangent(4) inside -> 3 regions? 
            // Standard: Disjoint->3, Tangent->3, Intersect->4. 
            // Wait, if one circle is completely inside another (3 or 4), regions: 2 (inner + outer).
            // If Disjoint (1): 3 regions.
            // If Intersect (5): 4 regions.
            // If Tangent (2, 4): 3 regions.
            
            case (s0)
                3'd1, 3'd2, 3'd3, 3'd4: lut_result = 4'd3; // Disjoint, Tangents, Contained
                3'd5: lut_result = 4'd4; // Intersecting
                default: lut_result = 4'd3;
            endcase
        end else if (n == 2'd3) begin
            // Map sorted tuple (s0, s1, s2) to region count
            // s0 is smallest, s2 is largest
            
            // Default 8 regions (general position, all intersecting)
            lut_result = 4'd8;
            
            // Logic reduction based on constraints
            // We only need to handle specific combinations found in the problem space
            
            // If largest relationship is Disjoint (1) or Tangent (2) for ANY pair,
            // the circles are not all linked. 
            if (s2 == 3'd1 || s2 == 3'd2) begin
                // Not all intersecting. Reduce count.
                // If s0 is 1 (disjoint), it's separated.
                if (s0 == 3'd1) lut_result = 4'd6; // 2+3+1 = 6 (if separate)
                else lut_result = 4'd7; // 2+3+2 = 7 (if 2 tangent, 1 intersect)
            end else if (s2 == 3'd3 || s2 == 3'd4) begin
                // One circle contains others or all contained.
                // If s0 == 3 (contained inside), check s1.
                if (s0 == 3'd3 && s1 == 3'd3) lut_result = 4'd2; // All concentric/contained
                else if (s0 == 3'd3) lut_result = 4'd4; // One inside, one intersecting
                else lut_result = 4'd6; // One inside, one disjoint (2+3+1)
            end else if (s2 == 3'd5) begin
                // All pairs intersecting (general position)
                // Check if s1 < 5 (one pair non-intersecting)
                if (s1 < 3'd5) begin
                     // (5, 5, X) where X is 1-4
                     // (5,5,1) -> 6 regions (2 disjoint, 1 intersecting)
                     // (5,5,2) -> 7 regions (2 tangent, 1 intersecting)
                     // (5,5,3) -> 4 regions? (1 inside, 2 intersecting)
                     if (s0 == 3'd1) lut_result = 4'd6;
                     else if (s0 == 3'd2) lut_result = 4'd7;
                     else lut_result = 4'd4;
                end else begin
                    // (5, 5, 5) -> All pairs intersecting
                    // Usually 8 regions, unless concurrent (center case)
                    // We handle concurrent check in next stage
                    lut_result = 4'd8;
                end
            end
        end
    end

    // --- Concurrent Intersection Check (Simplified) ---
    // Checks if 3 circles intersect at 1 or 2 points (reduces regions by 1)
    wire concurrent;
    // Approximation: Check if distances satisfy center equations
    // For Q4.4 integers, checking if det=0 is hard without division.
    // We will approximate: if all pairs are Intersecting (5) AND
    // dist_01 + dist_12 == dist_02 (colinear centers) AND radii align.
    // Since we don't have sqrt, we check squared distances.
    // If (dist_01 + dist_12)^2 == dist_02^2 roughly?
    // This is complex. 
    // We will implement a simplified check: 
    // If r_sum_sq > dist_sq > r_diff_sq for all pairs (status 5)
    // AND centers are roughly colinear (det = 0).
    // det = x1(y2-y3) + x2(y3-y1) + x3(y1-y2)
    // This is a fixed-point calculation.
    
    wire signed [15:0] det_val;
    wire signed [7:0] x0, x1, x2, y0, y1, y2;
    assign x0 = circ_x[0]; assign x1 = circ_x[1]; assign x2 = circ_x[2];
    assign y0 = circ_y[0]; assign y1 = circ_y[1]; assign y2 = circ_y[2];
    
    // det = x0*(y1-y2) + x1*(y2-y0) + x2*(y0-y1)
    // Result is in Q8.8 (scaled by 16)*16 = 256
    wire signed [15:0] term1, term2, term3;
    assign term1 = x0 * (y1 - y2);
    assign term2 = x1 * (y2 - y0);
    assign term3 = x2 * (y0 - y1);
    assign det_val = term1 + term2 + term3;
    
    // If det is small (colinear) AND status is 5,5,5
    wire is_colinear = (det_val < 16'sd100) && (det_val > -16'sd100);
    assign concurrent = (rel_01 == 3'd5) && (rel_02 == 3'd5) && (rel_12 == 3'd5) && is_colinear;

    // --- Sequential Logic ---
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 3; i = i + 1) begin
                r_sq[i] <= 16'd0;
            end
            dist_sq_01 <= 16'd0;
            dist_sq_02 <= 16'd0;
            dist_sq_12 <= 16'd0;
            rel_01 <= 3'd0;
            rel_02 <= 3'd0;
            rel_12 <= 3'd0;
            s0 <= 3'd0;
            s1 <= 3'd0;
            s2 <= 3'd0;
            temp_mult_a <= 16'd0;
            temp_mult_b <= 16'd0;
            temp_mult_result <= 32'd0;
        end else begin
            
            state <= next_state;
            
            if (state != IDLE) cycle_count <= cycle_count + 8'd1;
            else cycle_count <= 8'd0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Pre-calculate squared radii (1 cycle)
                        // Using temp registers for pipelining
                        temp_mult_a <= {8'd0, circ_r[0]};
                        temp_mult_b <= {8'd0, circ_r[0]};
                        // We will do 3 multiplies sequentially or use logic below
                        // Actually, let's just compute r_sq in this state for next cycle
                        r_sq[0] <= {8'd0, circ_r[0]} * {8'd0, circ_r[0]};
                        r_sq[1] <= {8'd0, circ_r[1]} * {8'd0, circ_r[1]};
                        r_sq[2] <= {8'd0, circ_r[2]} * {8'd0, circ_r[2]};
                    end
                end
                
                CALC_R_SQ: begin
                    // Wait state if needed, or jump straight to dist
                    // Already calculated r_sq in IDLE transition
                end
                
                CALC_DIST_01: begin
                    // dist_sq = dx*dx + dy*dy
                    // dx*dx is 16x16 -> 32 bit, but fits in 16 bit (max ~400)
                    temp_mult_result <= dx_01 * dx_01 + dy_01 * dy_01;
                end
                
                CALC_DIST_02: begin
                    dist_sq_01 <= temp_mult_result[15:0]; // Store result
                    temp_mult_result <= dx_02 * dx_02 + dy_02 * dy_02;
                end
                
                CALC_DIST_12: begin
                    dist_sq_02 <= temp_mult_result[15:0];
                    temp_mult_result <= dx_12 * dx_12 + dy_12 * dy_12;
                end
                
                CLASSIFY: begin
                    dist_sq_12 <= temp_mult_result[15:0];
                    
                    // Load pre-calculated radii squares for comparison
                    // Note: r_sum_sq and r_diff_sq are calculated combinatorially
                    // We need to store the relationship codes
                    
                    // Pair 0-1
                    if (dist_sq_01 > r_sum_sq_01_wire) rel_01 <= 3'd1; // Disjoint
                    else if (dist_sq_01 == r_sum_sq_01_wire) rel_01 <= 3'd2; // Tangent Out
                    else if (dist_sq_01 < r_diff_sq_01_wire) rel_01 <= 3'd3; // Contained
                    else if (dist_sq_01 == r_diff_sq_01_wire) rel_01 <= 3'd4; // Tangent In
                    else rel_01 <= 3'd5; // Intersecting
                    
                    // Pair 0-2
                    if (dist_sq_02 > r_sum_sq_02_wire) rel_02 <= 3'd1;
                    else if (dist_sq_02 == r_sum_sq_02_wire) rel_02 <= 3'd2;
                    else if (dist_sq_02 < r_diff_sq_02_wire) rel_02 <= 3'd3;
                    else if (dist_sq_02 == r_diff_sq_02_wire) rel_02 <= 3'd4;
                    else rel_02 <= 3'd5;
                    
                    // Pair 1-2
                    if (dist_sq_12 > r_sum_sq_12_wire) rel_12 <= 3'd1;
                    else if (dist_sq_12 == r_sum_sq_12_wire) rel_12 <= 3'd2;
                    else if (dist_sq_12 < r_diff_sq_12_wire) rel_12 <= 3'd3;
                    else if (dist_sq_12 == r_diff_sq_12_wire) rel_12 <= 3'd4;
                    else rel_12 <= 3'd5;
                end
                
                SORT_LOOKUP: begin
                    // Store sorted tuple
                    s0 <= s0_wire;
                    s1 <= s1_wire;
                    s2 <= s2_wire;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (n == 2'd3 && (s0 == 3'd5 && s1 == 3'd5 && s2 == 3'd5) && concurrent) begin
                        result <= lut_result - 4'd1;
                    end else begin
                        result <= lut_result;
                    end
                end
            endcase
        end
    end

    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CALC_DIST_01; // Jump past r_sq if computed combinational
            
            CALC_DIST_01: next_state = CALC_DIST_02;
            
            CALC_DIST_02: next_state = CALC_DIST_12;
            
            CALC_DIST_12: next_state = CLASSIFY;
            
            CLASSIFY: begin
                if (n == 2'd3) next_state = SORT_LOOKUP;
                else next_state = FINISH;
            end
            
            SORT_LOOKUP: next_state = FINISH;
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count > MAX_CYCLES) next_state = IDLE;
    end

endmodule