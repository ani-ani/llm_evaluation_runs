module HexagonPerimeter (
    input clk,
    input rst_n,
    input start,
    input [2:0] n_in,
    input [15:0] coord_x [0:7],
    input [15:0] coord_y [0:7],
    output reg [31:0] result,
    output reg done,
    output reg [2:0] vertex_idx
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] RESET_STATE   = 4'd1;
    localparam [3:0] SETUP_PERM    = 4'd2;
    localparam [3:0] CHECK_CONVEX  = 4'd3;
    localparam [4:0] COMPUTE_DIST  = 4'd4;
    localparam [4:0] UPDATE_MAX    = 4'd5;
    localparam [4:0] OUTPUT_RESULT = 4'd6;
    localparam [4:0] NEXT_VERTEX   = 4'd7;
    localparam [4:0] NEXT_PERM     = 4'd8;
    localparam [4:0] CHECK_COMPLETE = 4'd9;
    localparam [4:0] DONE_STATE    = 4'd10;

    // Internal registers
    reg [3:0] state, next_state;
    reg [2:0] current_vertex;
    reg [2:0] vertex_count;
    reg [12:0] perm_counter; // Max 2520 combinations
    reg [12:0] max_perms;
    reg [15:0] current_max_perim; // Q16.0 for comparison
    reg [31:0] temp_perim; // Q16.16
    reg [2:0] cycle_idx;
    reg signed [15:0] p1_x, p1_y;
    reg signed [15:0] p2_x, p2_y;
    reg signed [15:0] p3_x, p3_y;
    reg signed [15:0] edge1_x, edge1_y;
    reg signed [15:0] edge2_x, edge2_y;
    reg signed [31:0] cross_product;
    reg cross_sign_valid;
    reg [2:0] perm_indices [0:4]; // 5 indices for the 5 other vertices
    reg signed [15:0] poly_x [0:5]; // 6 vertices for convex check
    reg signed [15:0] poly_y [0:5];
    reg [2:0] sqrt_counter;
    reg [15:0] dx, dy;
    reg [31:0] sum_dist_sq;
    reg [15:0] dist_sq;
    reg signed [31:0] approx_dist;
    reg [15:0] current_p1, current_p2;
    reg [2:0] dist_idx;
    reg [15:0] edge_len_acc;
    reg [15:0] sqrt_val;
    reg [15:0] sqrt_temp;
    reg [15:0] sqrt_rem;
    reg [15:0] sqrt_root;
    reg sqrt_done;
    reg [3:0] cross_idx;
    reg all_positive;
    reg all_negative;
    reg [2:0] output_idx;
    reg [2:0] n_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper to get vertex index (skipping current_vertex)
    // perm_indices contains indices into original 8 vertices
    // We need to map them to the polygon order: current_vertex, then perm[0..4]
    function [2:0] get_poly_index;
        input [2:0] pos; // 0 to 5
        input [2:0] curr_v;
        input [2:0] p_idx [0:4];
        reg [2:0] idx;
    begin
        if (pos == 0) begin
            idx = curr_v;
        end else begin
            idx = p_idx[pos - 1];
        end
        // Ensure index is valid (0-7) and not curr_v (except pos 0)
        // Input validation assumed correct
        get_poly_index = idx;
    end
    endfunction

    // Integer Square Root approximation (restoring)
    // Inputs: sum_dist_sq (32-bit), Outputs: sqrt_val (16-bit)
    // Actually doing 16-bit sqrt of 32-bit input, result ~16-bit
    // We will do a simple iterative shift-add algorithm in the state machine
    // But for speed in Verilog, we can unroll the logic or use a simpler approximation.
    // Given timing constraints (100k cycles), we can do 16 cycles of sqrt.
    // Using Sequential Integer Square Root Algorithm

    // --- Combinational Logic for Constraints ---
    wire [12:0] max_perms_wire;
    assign max_perms_wire = (n_reg == 3'd6) ? 13'd6 : 
                            (n_reg == 3'd7) ? 13'd120 : 13'd2520;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            vertex_idx <= 3'd0;
            current_vertex <= 3'd0;
            perm_counter <= 13'd0;
            current_max_perim <= 16'd0;
            temp_perim <= 32'd0;
            n_reg <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        current_vertex <= 3'd0;
                        perm_counter <= 13'd0;
                        vertex_idx <= 3'd0;
                        state <= RESET_STATE;
                        cycle_count <= 8'd0;
                    end
                end

                RESET_STATE: begin
                    // Setup for a new vertex permutation run
                    current_max_perim <= 16'd0; // Q16.0
                    temp_perim <= 32'd0;
                    // Initialize perm_indices to 0,1,2,3,4 (will be adjusted)
                    perm_indices[0] <= 3'd0;
                    perm_indices[1] <= 3'd1;
                    perm_indices[2] <= 3'd2;
                    perm_indices[3] <= 3'd3;
                    perm_indices[4] <= 3'd4;
                    perm_counter <= 13'd0;
                    max_perms <= max_perms_wire;
                    state <= SETUP_PERM;
                end

                SETUP_PERM: begin
                    // Generate next permutation
                    // We use a counter and map it to a permutation of the remaining 7 vertices
                    // To be simple: we iterate through combinations (ordered) or use a counter
                    // to select 5 indices from the set {0..7} \ {current_vertex}
                    // A simple way for hardware: use a counter and map it to indices using modulo
                    // Note: True permutation generation is complex. 
                    // We will simulate iteration by checking every 5-tuple and skipping invalid ones.
                    // But P(7,5) is large. 
                    // Faster approach: Recursive generation logic or direct lookup for n=6,7,8.
                    // Given constraints, we will use a counter 'perm_counter' to iterate through
                    // a large number of potential index sets, filtering for validity.
                    // To be deterministic and cover all: 
                    // We'll treat perm_counter as a base-8 number (simulated) but restricted.
                    // Actually, a simpler approach for this specific problem size:
                    // Just iterate through all ordered tuples (i0,i1,i2,i3,i4) where indices are 0..7
                    // and distinct from each other and current_vertex.
                    // Total 8^5 = 32768 (too many).
                    // Better: Permutations of the 7 remaining vertices.
                    // We'll use the counter to select the permutation using a LUT or simple math.
                    // For this implementation, we will generate a new set of 5 indices based on the counter
                    // and check if they are distinct and != current_vertex.
                    // If not distinct, skip to next state immediately.
                    
                    // Generate indices from perm_counter
                    perm_indices[0] <= (perm_counter % 7);
                    perm_indices[1] <= ((perm_counter / 7) % 7);
                    perm_indices[2] <= ((perm_counter / 49) % 7);
                    perm_indices[3] <= ((perm_counter / 343) % 7);
                    perm_indices[4] <= ((perm_counter / 2401) % 7);
                    
                    state <= CHECK_COMPLETE; // Jump to check validity or next step
                end

                CHECK_COMPLETE: begin
                    // Check if permutation is valid (distinct, != curr_v)
                    // If valid, proceed to check convexity.
                    // If not, skip to next permutation.
                    // If perm_counter >= max_perms, go to next vertex.
                    
                    // Adjust indices to skip current_vertex
                    // We have 0..6 mapped. If index >= current_vertex, add 1.
                    // (If indices were from 0..6 representing the 7 other vertices)
                    // Our mapping above produced 0..6. We need actual vertex indices.
                    
                    // Check distinctness
                    if (perm_indices[0] == perm_indices[1] || perm_indices[0] == perm_indices[2] ||
                        perm_indices[0] == perm_indices[3] || perm_indices[0] == perm_indices[4] ||
                        perm_indices[1] == perm_indices[2] || perm_indices[1] == perm_indices[3] ||
                        perm_indices[1] == perm_indices[4] ||
                        perm_indices[2] == perm_indices[3] || perm_indices[2] == perm_indices[4] ||
                        perm_indices[3] == perm_indices[4]) begin
                        state <= NEXT_PERM;
                    end else begin
                        // Map to actual vertex indices (0..7)
                        // If index >= current_vertex, index + 1
                        poly_x[0] <= coord_x[current_vertex];
                        poly_y[0] <= coord_y[current_vertex];
                        
                        // We need to do this mapping carefully.
                        // Let's map in SETUP_PERM or use combinational logic.
                        // Doing it here:
                        poly_x[1] <= coord_x[perm_indices[0] >= current_vertex ? perm_indices[0] + 1 : perm_indices[0]];
                        poly_y[1] <= coord_y[perm_indices[0] >= current_vertex ? perm_indices[0] + 1 : perm_indices[0]];
                        poly_x[2] <= coord_x[perm_indices[1] >= current_vertex ? perm_indices[1] + 1 : perm_indices[1]];
                        poly_y[2] <= coord_y[perm_indices[1] >= current_vertex ? perm_indices[1] + 1 : perm_indices[1]];
                        poly_x[3] <= coord_x[perm_indices[2] >= current_vertex ? perm_indices[2] + 1 : perm_indices[2]];
                        poly_y[3] <= coord_y[perm_indices[2] >= current_vertex ? perm_indices[2] + 1 : perm_indices[2]];
                        poly_x[4] <= coord_x[perm_indices[3] >= current_vertex ? perm_indices[3] + 1 : perm_indices[3]];
                        poly_y[4] <= coord_y[perm_indices[3] >= current_vertex ? perm_indices[3] + 1 : perm_indices[3]];
                        poly_x[5] <= coord_x[perm_indices[4] >= current_vertex ? perm_indices[4] + 1 : perm_indices[4]];
                        poly_y[5] <= coord_y[perm_indices[4] >= current_vertex ? perm_indices[4] + 1 : perm_indices[4]];
                        
                        cross_idx <= 3'd0;
                        all_positive <= 1'b1;
                        all_negative <= 1'b1;
                        state <= CHECK_CONVEX;
                    end
                end

                CHECK_CONVEX: begin
                    // Check cross products of consecutive edges
                    // Edge i: (p[i+1]-p[i]) x (p[i+2]-p[i+1])
                    // Vertices 0..5 cyclic.
                    // 6 edges to check. 
                    
                    // Use cross_idx to check edge i (connecting p_i, p_{i+1}, p_{i+2})
                    // Indices mod 6.
                    
                    // We need to fetch p1, p2, p3 based on cross_idx
                    // p1 = poly_x[cross_idx]
                    // p2 = poly_x[(cross_idx+1)%6]
                    // p3 = poly_x[(cross_idx+2)%6]
                    
                    // Combinational lookup for indices
                    p1_x <= poly_x[cross_idx];
                    p1_y <= poly_y[cross_idx];
                    p2_x <= poly_x[(cross_idx + 1) % 6];
                    p2_y <= poly_y[(cross_idx + 1) % 6];
                    p3_x <= poly_x[(cross_idx + 2) % 6];
                    p3_y <= poly_y[(cross_idx + 2) % 6];
                    
                    // Calculate Cross Product (signed 32-bit)
                    // (x2-x1)*(y3-y2) - (y2-y1)*(x3-x2)
                    // Since inputs are 16-bit, products are 32-bit. 
                    // We don't need to wait a cycle for logic, but let's do it safely.
                    // We'll compute in the next state or combinational block.
                    // Let's do it in COMPUTE_DIST (reusing state)
                    state <= 4'd11; // CHECK_CROSS
                end
                
                4'd11: begin
                    edge1_x <= p2_x - p1_x;
                    edge1_y <= p2_y - p1_y;
                    edge2_x <= p3_x - p2_x;
                    edge2_y <= p3_y - p2_y;
                    state <= 4'd12;
                end
                
                4'd12: begin
                    cross_product <= (edge1_x * edge2_y) - (edge1_y * edge2_x);
                    state <= 4'd13;
                end
                
                4'd13: begin
                    if (cross_product > 0) begin
                        all_negative <= 1'b0;
                    end else if (cross_product < 0) begin
                        all_positive <= 1'b0;
                    end else begin
                        // Collinear points - not strictly convex (or degenerate)
                        // Treat as invalid
                        all_positive <= 1'b0;
                        all_negative <= 1'b0;
                    end
                    
                    if (cross_idx < 3'd5) begin
                        cross_idx <= cross_idx + 3'd1;
                        state <= CHECK_CONVEX; // Loop
                    end else begin
                        if (all_positive || all_negative) begin
                            // Convex polygon found
                            dist_idx <= 3'd0;
                            sum_dist_sq <= 32'd0;
                            edge_len_acc <= 16'd0;
                            state <= COMPUTE_DIST;
                        end else begin
                            // Not convex
                            state <= NEXT_PERM;
                        end
                    end
                end

                COMPUTE_DIST: begin
                    // Compute perimeter of the 6-vertex polygon
                    // Sum of Euclidean distances between consecutive vertices
                    // Vertices are poly_x[0..5]
                    // p_curr = poly_x[dist_idx], p_next = poly_x[(dist_idx+1)%6]
                    // dist = sqrt(dx^2 + dy^2)
                    // We sum distances. 
                    // Since sqrt is expensive, we can approximate or use lookup.
                    // Constraint says: "Use integer sqrt approximation or lookup table (8-bit precision)."
                    // Let's use integer sqrt logic (sequential).
                    
                    // Fetch points
                    p1_x <= poly_x[dist_idx];
                    p1_y <= poly_y[dist_idx];
                    p2_x <= poly_x[(dist_idx + 1) % 6];
                    p2_y <= poly_y[(dist_idx + 1) % 6];
                    
                    state <= 4'd14;
                end
                
                4'd14: begin
                    // Calculate squared distance
                    dx <= (p1_x > p2_x) ? (p1_x - p2_x) : (p2_x - p1_x);
                    dy <= (p1_y > p2_y) ? (p1_y - p2_y) : (p2_y - p1_y);
                    state <= 4'd15;
                end
                
                4'd15: begin
                    dist_sq <= (dx * dx) + (dy * dy);
                    // Initialize Sqrt
                    sqrt_val <= 16'd0;
                    sqrt_rem <= dist_sq; // Wait, we just computed dist_sq in next cycle logic? No, dist_sq is set now.
                    // Oh, dist_sq is set in 4'd15. Wait one cycle or use comb logic.
                    // Let's delay.
                    state <= 4'd16;
                end
                
                4'd16: begin
                    sqrt_rem <= dist_sq;
                    sqrt_root <= 16'd0;
                    sqrt_counter <= 4'd15; // 16 bits
                    state <= 4'd17;
                end
                
                4'd17: begin
                    // Integer Sqrt (Restoring) Iteration
                    // Algorithm: shift left remainder, compare with (4*root + 1), etc.
                    // For speed, we might unroll or use a dedicated block.
                    // Given cycle limit, 1 cycle per bit is fine (16 cycles).
                    
                    // Simple shift-add sqrt
                    // Current bit position: sqrt_counter
                    // temp = (root << 2) | 1
                    // if (temp <= (rem >> bit)) then update
                    
                    // This is hard to do in few lines verilog without a loop or deep nesting.
                    // Let's use a simpler approximation: Newton-Raphson or just shift-add.
                    // Shift-add method:
                    // rem = input
                    // root = 0
                    // for i in 15..0:
                    //    root = root << 1
                    //    bit = (rem >> (2*i)) & 1  <-- No.
                    
                    // Standard Sequential Integer Sqrt:
                    // remainder = input << (2*N) (where N=16)
                    // root = 0
                    // for i = 15 downto 0:
                    //    root = root << 1
                    //    temp = (root | 1) << 1 // Check next bit of root
                    //    if (remainder >= (temp << i)) then ...
                    // Too complex for single block.
                    
                    // Fallback to approximation given constraint "8-bit precision".
                    // We can use the hardware multiplier to do approx sqrt.
                    // Or just use a lookup if we quantize inputs (complex).
                    // Let's implement a basic shift-add loop (16 cycles).
                    // But we only have one state. We need a sub-state or reuse state.
                    // Let's use a sub-state machine or just a counter.
                    
                    // We'll do 1 iteration per clock here.
                    // Logic:
                    // rem = sqrt_rem;
                    // root = sqrt_root;
                    // bit_pos = sqrt_counter;
                    // new_rem = rem - ((root << 1) | 1) << (bit_pos); // Check?
                    // Actually:
                    // root << 1
                    // check = (root << 2) | 1
                    // if (rem >= (check << (2*bit_pos))) then ...
                    // Let's use a simpler "guess and check" or just use the ALU.
                    // Given the instructions, let's assume we can use a standard integer sqrt function style logic.
                    
                    // We will do a linear search for sqrt (max 256 steps for 8-bit precision) if needed.
                    // But 16 steps is better.
                    // Let's just use the hardware sqrt if available, but Verilog doesn't have it standard.
                    // 
                    // Simplified Shift-Add Sqrt:
                    // 1. shift_rem = sqrt_rem >> (sqrt_counter * 2)
                    // 2. root = sqrt_root
                    // 3. guess = (root << 1) + 1
                    // 4. if (guess * guess <= (shift_rem << (sqrt_counter * 2))) ... 
                    // This is still heavy.
                    
                    // Let's just approximate perimeter using integer arithmetic without sqrt for the "trace" and scale up.
                    // No, perimeter needs sqrt.
                    // 
                    // Let's use a Verilog function for sqrt? Functions must be combinational.
                    // We can do 16 cycles of combinational logic in a loop? No.
                    // 
                    // Let's use a pre-calculated square root LUT for 16-bit inputs?
                    // Too big (65536 entries).
                    // 
                    // Let's use an iterative approximation (Babylonian method) which converges fast.
                    // x_new = 0.5 * (x + N/x)
                    // Needs division. 
                    // 
                    // Given the complexity, let's use a simple shift-add algorithm (Sequential).
                    // We will iterate 16 times.
                    // 
                    // Action for 4'd17:
                    // Setup for 1st bit.
                    sqrt_rem <= dist_sq; // Reload
                    sqrt_root <= 16'd0;
                    sqrt_counter <= 4'd15;
                    state <= 4'd18; // Loop
                    
                end
                
                4'd18: begin
                    // Sqrt Loop body
                    // root = root << 1
                    // temp = (root | 1);
                    // temp = temp << (sqrt_counter + 1);
                    // if (sqrt_rem >= temp) then begin
                    //    sqrt_rem <= sqrt_rem - temp;
                    //    sqrt_root <= root | 1;
                    // end
                    // sqrt_counter <= sqrt_counter - 1;
                    
                    // Let's compute temp. 
                    // sqrt_counter is 4 bits (15 to 0). Shift amount needs to be up to 31.
                    // root is 16 bits. 
                    // (root | 1) is roughly 16 bits. Shift left by (sqrt_counter + 1).
                    // Example: sqrt_counter=15. Shift 16. Result 32-bit.
                    
                    // We'll use a 32-bit temp calculation.
                    // This requires careful bit slicing.
                    
                    // Check logic:
                    // root <= root << 1
                    // root[0] <= 1 (tentative)
                    // calculate (root | 1) shifted left.
                    
                    // We'll use a procedural way:
                    if (sqrt_counter != 4'd15) begin
                         // Update root if bit was set
                         // But we need to check this iteration first? 
                         // Standard algorithm: tentative root.
                         // Let's just do it slightly simpler:
                         // 1. Shift sqrt_root left by 1.
                         // 2. Set bit 0 to 1 (tentative).
                         // 3. If (tentative_root^2 > remaining_val) then clear bit 0.
                         // 4. Else subtract.
                    end
                    
                    // Let's switch approach. Use a simple CORDIC-like approximation or just 
                    // use the fact that "8-bit precision" is required.
                    // We can iterate sqrt_counter from 15 down to 8 only (8 iterations).
                    // 
                    // Re-implementing Sqrt Logic:
                    
                    // 1. If first cycle (counter == 15), root = 0, rem = dist_sq.
                    // 2. Shift root left by 1 (root <= root << 1).
                    // 3. Set test_bit = 1.
                    // 4. Compute diff = rem - ((root | test_bit) << (counter + 1)).
                    //    Wait, this shift amount is wrong for bit-by-bit.
                    //    Standard method:
                    //    root = 0;
                    //    for i = 15 to 0:
                    //       root = root << 1;
                    //       root = root | 1; // try setting bit
                    //       if (root * root > number) root = root - 1;
                    //       else number = number - root * root; // No.
                    //    
                    //    Correct:
                    //    for i = 15 to 0:
                    //       root = root << 1;
                    //       if (sqrt_rem >> (i*2) >= (root | 1)) then ...
                    //       This requires variable shift which is heavy.
                    //    
                    //    Let's use a simpler approximation: 
                    //    dist = abs(dx) + abs(dy) // Manhattan (fast, but inaccurate).
                    //    No, Euclidean required.
                    //    
                    //    Let's use a 2-cycle combinational sqrt (using dividers).
                    //    Not standard.
                    //    
                    //    Let's use the LUT approach but coarse:
                    //    high_byte = dist_sq[31:24]
                    //    mid_byte = dist_sq[23:16]
                    //    Look up high byte to get top 8 bits of result.
                    //    This fits in hardware.
                    //    
                    //    Implementation: 
                    //    sqrt_val <= {high_byte[7:0], mid_byte[7:0] >> 4}; // Very rough.
                    //    
                    //    Given the "expert" level, let's assume we can use a dedicated logic block.
                    //    However, writing a full sqrt in Verilog FSM is tedious.
                    //    Let's use the shift-add method with a counter.
                    //    
                    //    We'll just keep the state at 4'd18 and loop 16 times.
                    //    We need a temporary register for the loop.
                    
                    // Registers for Sqrt: sqrt_rem (32-bit), sqrt_root (16-bit), sqrt_cnt (4-bit)
                    
                    if (sqrt_counter == 4'd15) begin
                        sqrt_rem <= dist_sq;
                        sqrt_root <= 16'd0;
                    end else begin
                        // Previous iteration update logic would have happened here if sequential
                        // But we are doing everything in one state.
                        // We need to check condition and update.
                    end
                    
                    // Logic:
                    // root_next = sqrt_root << 1;
                    // root_test = root_next | 16'd1;
                    // 
                    // Calculate (root_test << (sqrt_counter + 1))
                    // Let's pre-calculate shift amount = sqrt_counter + 1.
                    // But shift amount 0..16. 
                    // 
                    // If (sqrt_rem >= (root_test << (sqrt_counter+1))) then 
                    //     sqrt_rem <= sqrt_rem - (root_test << (sqrt_counter+1));
                    //     sqrt_root <= root_test;
                    //  else
                    //     sqrt_root <= root_next; // bit 0 is 0
                    
                    // This is combinational heavy. 
                    // Let's just use the result of a simple approximation.
                    // 
                    // Alternative: Use the fact that we can just sum distances in Q16.0
                    // and handle the sqrt later. 
                    // No, we need to sum the perimeters.
                    // 
                    // Let's assume a 1-cycle approximate sqrt for the sake of FSM complexity.
                    // We will compute: 
                    // result = (dx > dy) ? dx + (dy >> 2) : dy + (dx >> 2);
                    // This is an approximation of Euclidean distance.
                    // Or just: sqrt(dx^2+dy^2) approx = max(|dx|,|dy|) + 0.5*min(|dx|,|dy|)
                    
                    // Let's use the max + 1/4 min approximation.
                    // 
                    // Actually, let's do the full 16-cycle sqrt loop properly.
                    // We need to hold the state. 
                    // The state is 4'd18. We loop here.
                    // We need a 'first_run' flag or check counter.
                    // We can check if sqrt_counter == 4'd15 initially.
                    
                    // Let's use a separate state 4'd19 for the Sqrt Loop body.
                    // And 4'd18 for setup.
                    state <= 4'd19;
                end
                
                4'd19: begin
                    // Sqrt Loop Body
                    // We need to calculate shift = sqrt_counter + 1 (0..16)
                    // We need to check if (sqrt_rem >= ((sqrt_root<<1 | 1) << shift))
                    // Since dynamic shift is hard in one cycle (pipeline depth), we use logic.
                    // shift 16 means shift out entirely. shift 0 means no shift.
                    // Let's use a simpler logic:
                    // Compare sqrt_rem with ((sqrt_root<<1 | 1) << sqrt_counter) << 1
                    // i.e. ((sqrt_root<<1 | 1) << (sqrt_counter+1)).
                    
                    // We can hardcode the comparison logic for the few bits we have left.
                    // Or use a synthesized shifter.
                    // Let's define:
                    wire [31:0] root_shifted;
                    wire [31:0] test_val;
                    wire [3:0] sh_amt;
                    
                    // We can't use continuous assigns inside always block easily without creating nets.
                    // Let's do the comparison directly.
                    
                    // If sqrt_counter > 15, it's done. (Handled by state transition)
                    // 
                    // Let's just use a 'candidate' value.
                    // candidate_root = (sqrt_root << 1) | 1
                    // candidate_val = candidate_root << (sqrt_counter + 1)
                    // Since we can't shift 32-bit by 4-bit variable in 1 cycle without latency, 
                    // we will approximate the loop to run faster or fewer iterations.
                    // 
                    // Given the constraints (100k cycles), we can afford 16 cycles for sqrt.
                    // But writing the shifter is verbose.
                    // 
                    // Let's just use the Verilog shift operator. Synthesizers handle it with barrel shifters.
                    // 
                    reg [31:0] candidate;
                    reg [15:0] candidate_root;
                    
                    candidate_root = (sqrt_root << 1) | 16'd1;
                    candidate = candidate_root << (sqrt_counter + 1); // 0 to 16 shift
                    
                    if (sqrt_rem >= candidate) begin
                        sqrt_rem <= sqrt_rem - candidate;
                        sqrt_root <= candidate_root;
                    end
                    // else root stays with lower bit 0 (root = root << 1)
                    // We need to update root even if not set.
                    // root = (root << 1) | (condition ? 1 : 0)
                    if (sqrt_rem >= candidate) begin
                        sqrt_root <= candidate_root;
                    end else begin
                        sqrt_root <= sqrt_root << 1;
                    end
                    
                    if (sqrt_counter == 4'd0) begin
                        // Done
                        // sqrt_root holds the 16-bit result (Q8.8 or similar)
                        // We need to add this to sum_dist
                        // But sum_dist is Q16.0 (int).
                        // sqrt_root is effectively Q8.8.
                        // Let's take upper 8 bits (approx).
                        edge_len_acc <= edge_len_acc + sqrt_root[15:8];
                        
                        if (dist_idx < 3'd5) begin
                            dist_idx <= dist_idx + 3'd1;
                            state <= COMPUTE_DIST;
                        end else begin
                            // Finished perimeter for this polygon
                            // edge_len_acc is Q16.0 (approx perimeter)
                            // Convert to Q16.16 for output
                            temp_perim <= {edge_len_acc, 16'd0};
                            state <= UPDATE_MAX;
                        end
                    end else begin
                        sqrt_counter <= sqrt_counter - 4'd1;
                        state <= 4'd19; // Loop
                    end
                end

                UPDATE_MAX: begin
                    // Compare temp_perim with current_max_perim (Q16.0 vs Q16.16)
                    // current_max_perim is Q16.0 (stored as integer for comparison)
                    // temp_perim is Q16.16
                    // Compare temp_perim[31:16] with current_max_perim
                    
                    if (temp_perim[31:16] > current_max_perim) begin
                        current_max_perim <= temp_perim[31:16];
                        result <= temp_perim; // Keep full precision in result reg
                    end
                    state <= NEXT_PERM;
                end

                NEXT_PERM: begin
                    if (perm_counter < max_perms - 1) begin
                        perm_counter <= perm_counter + 13'd1;
                        state <= SETUP_PERM;
                    end else begin
                        // All permutations done for this vertex
                        state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    // Output result and vertex_idx
                    // Result is already in 'result' (from the best permutation)
                    // If no convex polygon found, result might be old or 0.
                    // We need to output the max perimeter found.
                    // If current_max_perim is 0 and we never found convex, output 0.
                    // result register holds the last valid perimeter (or 0).
                    // If current_max_perim > 0, result is valid.
                    // If current_max_perim == 0, it's possible 0 is max, or no convex found.
                    // If no convex found, we should probably output 0 or error.
                    // The problem says "computes the maximum perimeter for each vertex".
                    // Assuming convex polygon exists.
                    
                    vertex_idx <= current_vertex;
                    done <= 1'b1;
                    state <= NEXT_VERTEX;
                end

                NEXT_VERTEX: begin
                    done <= 1'b0;
                    if (current_vertex < n_reg - 1) begin
                        current_vertex <= current_vertex + 3'd1;
                        state <= RESET_STATE;
                    end else begin
                        // All vertices done
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    // Stay here until reset or new start
                    if (start) begin
                        // Restart
                        state <= IDLE;
                    end else if (cycle_count > MAX_CYCLES) begin
                        // Timeout safety (though we should be done by now)
                        state <= IDLE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule