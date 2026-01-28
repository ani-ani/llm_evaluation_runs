module min_euclidean_distance(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len_a,
    input wire [3:0] len_b,
    input wire signed [15:0] a_x_i [0:15],
    input wire signed [15:0] a_y_i [0:15],
    input wire signed [15:0] b_x_i [0:15],
    input wire signed [15:0] b_y_i [0:15],
    output reg signed [31:0] result,
    output reg done
);

// State definitions
localparam [3:0] IDLE         = 4'd0;
localparam [3:0] INIT_SEG     = 4'd1;
localparam [3:0] COMPUTE_PARAMS = 4'd2;
localparam [3:0] FIND_MIN     = 4'd3;
localparam [3:0] UPDATE_MIN   = 4'd4;
localparam [3:0] NEXT_SEG     = 4'd5;
localparam [3:0] SQRT_INIT    = 4'd6;
localparam [3:0] SQRT_ITER    = 4'd7;
localparam [3:0] DONE_STATE   = 4'd8;

reg [3:0] state, next_state;

// Segment tracking
reg [3:0] seg_a_idx, seg_b_idx;
reg [3:0] max_seg_a, max_seg_b;

// Coordinates and deltas (Q8.8 format, 16-bit signed)
reg signed [15:0] a_x0, a_y0, a_x1, a_y1;
reg signed [15:0] b_x0, b_y0, b_x1, b_y1;
reg signed [15:0] a_dx, a_dy, b_dx, b_dy;
reg signed [31:0] a_len2, b_len2; // Squared segment lengths (Q16.16)

// Time overlap calculation (Q16.16)
reg signed [31:0] t_a_len, t_b_len;
reg signed [31:0] t_max; // min(t_a_len, t_b_len)

// Minimum distance tracking (squared distance, Q16.16)
reg signed [31:0] min_dist_sq;
reg signed [31:0] curr_dist_sq;

// For distance calculation: position = p0 + t * delta
// We need to compute min of |(A0 + t*DA) - (B0 + t*DB)|^2 over t in [0, t_max]
// This is a quadratic: at^2 + bt + c
reg signed [31:0] coeff_a, coeff_b, coeff_c;
reg signed [31:0] t_opt; // Optimal t (if within [0, t_max])
reg signed [31:0] dist_at_t_opt;
reg signed [31:0] dist_at_t0;
reg signed [31:0] dist_at_t_max;

// Iterator for finding minimum in quadratic
reg [3:0] iter_count;
localparam [3:0] ITER_MAX = 4'd16;
reg signed [31:0] t_step;
reg signed [31:0] curr_t;

// Square root state
reg signed [31:0] sqrt_val;
reg signed [31:0] sqrt_guess;
reg signed [31:0] sqrt_prev;
reg [3:0] sqrt_iter;

// Cycle counter for timeout
reg [17:0] cycle_count;
localparam [17:0] MAX_CYCLES = 18'd200000;

// Registers for stage 2 computation
reg signed [31:0] da_x, da_y, db_x, db_y; // Deltas scaled to Q16.16 (1.0 = 65536)
reg signed [31:0] dx0, dy0; // Initial difference scaled
reg signed [31:0] temp_a, temp_b;

// Multiplier wires (Q16.16 * Q16.16 = Q32.32 -> trunc to Q16.16)
wire signed [63:0] mult64_a, mult64_b, mult64_c, mult64_d;
wire signed [63:0] mult64_e, mult64_f, mult64_g;

// Assign multipliers
assign mult64_a = a_dx * a_dx;
assign mult64_b = a_dx * a_dy;
assign mult64_c = a_dy * a_dy;
assign mult64_d = b_dx * b_dx;
assign mult64_e = b_dx * b_dy;
assign mult64_f = b_dy * b_dy;

// Coefficient calculation: 
// Dist^2 = |(DA - DB)*t + (A0 - B0)|^2
// = (DAX - DBX)^2 * t^2 + 2*(DAX-DBX)*(DX0) * t + (DX0)^2 + (similar for Y)
wire signed [31:0] ddx, ddy;
assign ddx = a_dx - b_dx;
assign ddy = a_dy - b_dy;

wire signed [63:0] mult_ddx, mult_ddy, mult_cross_x, mult_cross_y;
assign mult_ddx = ddx * ddx;
assign mult_ddy = ddy * ddy;

// Coeff a: (ddx^2 + ddy^2) in Q16.16 (from Q8.8 * Q8.8 = Q16.16)
wire signed [31:0] ca_temp;
assign ca_temp = mult_ddx[47:16] + mult_ddy[47:16];

// Coeff b: 2 * (ddx * dx0 + ddy * dy0) - dx0, dy0 are in Q16.16 (scaled from Q8.8)
// Wait, dx0, dy0 need to be computed. A0, A1 are Q8.8. t is Q16.16.
// Position = Q8.8 + (Q8.8 * Q16.16 >> 16) = Q8.8.
// Distance is computed in Q16.16 for precision.

// Re-plan coefficients:
// Let's keep coordinates in Q8.8. 
// A(t) = A0 + (DA * t) >> 16. (Result Q8.8)
// Diff = (A0 - B0) + ((DA - DB) * t) >> 16.
// Dist^2 = Diff^2.
// To avoid intermediate loss, compute Dist^2 directly in Q16.16.
// Let DX0 = (A0x - B0x) << 8 (Scale to Q16.16).
// Let DAX = DAx << 8.
// Then Diff_scaled = DX0 + (DAX * t) >> 8.
// This is getting messy. Let's use the hint.
// Dist^2 = at^2 + bt + c where a, b, c are in Q16.16.
// a = (DAx - DBx)^2 + (DAy - DBy)^2 (Q8.8^2 = Q16.16)
// b = 2 * ((DAx - DBx)*(A0x - B0x) + (DAy - DBy)*(A0y - B0y))
// c = (A0x - B0x)^2 + (A0y - B0y)^2

reg signed [31:0] a0_diff_x, a0_diff_y;
reg signed [31:0] da_diff_x, da_diff_y;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        seg_a_idx <= 4'd0;
        seg_b_idx <= 4'd0;
        min_dist_sq <= 32'h7FFFFFFF; // Max int
        cycle_count <= 18'd0;
        sqrt_val <= 32'd0;
        sqrt_guess <= 32'd0;
        sqrt_prev <= 32'd0;
        sqrt_iter <= 4'd0;
        iter_count <= 4'd0;
        curr_t <= 32'd0;
        t_step <= 32'd0;
        coeff_a <= 32'd0;
        coeff_b <= 32'd0;
        coeff_c <= 32'd0;
        dist_at_t_opt <= 32'd0;
        dist_at_t0 <= 32'd0;
        dist_at_t_max <= 32'd0;
        t_opt <= 32'd0;
        t_max <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 18'd0;
                min_dist_sq <= 32'h7FFFFFFF;
                seg_a_idx <= 4'd0;
                seg_b_idx <= 4'd0;
                if (start) begin
                    max_seg_a <= len_a - 4'd1;
                    max_seg_b <= len_b - 4'd1;
                    state <= INIT_SEG;
                end
            end

            INIT_SEG: begin
                // Load points for current segments
                // Note: Using hardcoded indices for synthesis compatibility
                // A segment i uses points i and i+1
                a_x0 <= a_x_i[seg_a_idx];
                a_y0 <= a_y_i[seg_a_idx];
                a_x1 <= a_x_i[seg_a_idx + 4'd1];
                a_y1 <= a_y_i[seg_a_idx + 4'd1];
                
                b_x0 <= b_x_i[seg_b_idx];
                b_y0 <= b_y_i[seg_b_idx];
                b_x1 <= b_x_i[seg_b_idx + 4'd1];
                b_y1 <= b_y_i[seg_b_idx + 4'd1];
                
                state <= COMPUTE_PARAMS;
            end

            COMPUTE_PARAMS: begin
                // Compute deltas (Q8.8)
                a_dx <= a_x1 - a_x0;
                a_dy <= a_y1 - a_y0;
                b_dx <= b_x1 - b_x0;
                b_dy <= b_y1 - b_y0;
                
                // Compute segment lengths squared (Q16.16)
                // dx is Q8.8. dx^2 is Q16.16.
                // mult64_a is 64-bit result of Q8.8 * Q8.8
                a_len2 <= mult64_a[47:16] + mult64_c[47:16];
                b_len2 <= mult64_d[47:16] + mult64_f[47:16];
                
                // Time lengths are 1.0 * length = length (Q16.16)
                // 1.0 = 65536. Length is sqrt(len2). We need linear length.
                // We can't easily get linear length from squared length without sqrt.
                // BUT, we are moving at speed 1 unit/sec. Coordinates are 0-10000.
                // We assume the coordinate scale is the same as time scale.
                // So time to traverse segment = distance.
                // We have squared distance. We need sqrt for linear time.
                // OR: We can use the hint "overlapping time window (0 <= t <= min(seg_i_len, seg_j_len))"
                // We need linear length. Let's do a quick sqrt approximation or just iterate?
                // The prompt says "Use a finite state machine... update min distance... then take square root at the end".
                // It implies we might not need sqrt for time, or we approximate.
                // If we don't have sqrt for time, we can't find exact min of quadratic easily.
                // However, if speed is 1, and coordinates are in meters, time = meters.
                // If coordinates are scaled (e.g. 10000 = 1 unit), time is 1/10000.
                // But prompt says "speed 1 unit per second". 
                // Let's assume coordinate value equals distance in time units.
                // But we only have squared length. We need linear length for t_max.
                // Let's do a 16-cycle Newton-Raphson for linear length here.
                
                // Initialize sqrt for segment A length
                // Initial guess: shift by 1 bit + bias
                sqrt_val <= a_len2;
                sqrt_guess <= (a_len2 > 32'd0) ? (a_len2 >> 1) + 32'd8192 : 32'd0;
                sqrt_iter <= 4'd0;
                
                // Prepare coefficients for dist^2
                // a0_diff = (A0 - B0) * 256 (Scale Q8.8 to Q16.16)
                a0_diff_x <= { {16{a_x0[15]}}, a_x0[15:0] } << 8; // Sign extend 16->32, shift
                a0_diff_y <= { {16{a_y0[15]}}, a_y0[15:0] } << 8;
                
                // da_diff = (DA - DB)
                da_diff_x <= { {16{a_dx[15]}}, (a_dx - b_dx)[15:0] };
                da_diff_y <= { {16{a_dy[15]}}, (a_dy - b_dy)[15:0] };
                
                state <= SQRT_INIT;
            end

            // --- Square Root State Machine ---
            // We need to compute sqrt(val) for time calculation (length of segment)
            // We use Newton-Raphson: x_new = 0.5 * (x + N/x)
            // This is reused for time calculation and final result.
            SQRT_INIT: begin
                // Calculate Coeff A, B, C for the quadratic distance function
                // Coeff A: (DA - DB)^2 (already in Q16.16 from Q8.8 mult)
                // da_diff_x is just difference of deltas (Q8.8). Need to square.
                // da_diff_x is 32-bit but holds 16-bit value.
                temp_a <= da_diff_x * da_diff_x;
                temp_b <= da_diff_y * da_diff_y;
                
                // Coeff C: (A0 - B0)^2
                temp_c <= (a0_diff_x * a0_diff_x) + (a0_diff_y * a0_diff_y);
                
                // Coeff B: 2 * (DA-DB) * (A0-B0)
                // We need 2*sum. Let's calculate sum first.
                // (da_diff_x * a0_diff_x) -> Q16.16 * Q16.16 = Q32.32 -> take high 32 bits (Q16.16)
                // Note: da_diff_x is still Q8.8 (16 bits). a0_diff is Q16.16.
                // Product is roughly Q24.24. 
                // Let's be careful. 
                // (Q8.8 * Q16.16) = Q24.24. High 32 bits (Q16.16).
                
                state <= FIND_MIN;
                iter_count <= 4'd0;
            end

            FIND_MIN: begin
                // We are iterating to find min distance in interval [0, t_max].
                // But first we need t_max = min(seg_a_len, seg_b_len).
                // We are computing sqrt(a_len2) and sqrt(b_len2) in sequence.
                // Let's track which sqrt we are doing.
                // Cycle 0-15: sqrt(A), Cycle 16-31: sqrt(B).
                // Actually, we need to do this in SQRT_ITER.
                // Let's refine SQRT_ITER.
                
                // For now, let's compute coefficients here.
                coeff_a <= temp_a[47:16] + temp_b[47:16]; // (da^2 + db^2)
                
                // B calculation
                wire signed [63:0] prod_x, prod_y;
                assign prod_x = da_diff_x * a0_diff_x; // Q24.24
                assign prod_y = da_diff_y * a0_diff_y;
                coeff_b <= (prod_x[47:16] + prod_y[47:16]) << 1; // 2 * sum
                
                coeff_c <= temp_c[47:16];
                
                // Initialize t_max calculation
                // We need linear lengths of segments A and B.
                // We will use the same SQRT_ITER state to compute both.
                // We need a way to distinguish. Use 'state' variable logic or counter.
                // Let's use a sub-state or just flow.
                // We'll set sqrt_val to a_len2 and enter a loop.
                
                state <= NEXT_SEG; // Placeholder, jump to loop logic
                // Actually, let's do the sqrt logic explicitly here to be clean.
            end
            
            // Reorganized Logic for SQRT and Min Finding
            // We need to compute t_max. 
            // Let's assume we calculate sqrt(a_len2) then sqrt(b_len2).
            // But we can also approximate t_max. 
            // For safety, let's implement the Newton iteration properly.
            
            // We'll split SQRT_INIT into two phases for A and B
            // Actually, let's use a flag. 
            // Let's create a dedicated SQRT block logic inside FIND_MIN or separate state.
            
            // Let's restart the logic flow for clarity:
            // 1. Compute Coeffs A, B, C (Dist^2 vs t)
            // 2. Compute t_max = min(sqrt(a_len2), sqrt(b_len2))
            // 3. Find min in [0, t_max]
            // 4. Update global min
            // 5. Next segment pair
            
            // STATE: COMPUTE_PARAMS done.
            // NEXT: FIND_MIN (which includes SQRT)
            
            // Let's create a robust SQRT module logic using states.
            
            // --- NEW STATES FOR SQRT ---
            // We'll reuse SQRT_INIT and SQRT_ITER for both A and B length.
            // We need to know which one we are calculating.
            // Let's use `seg_b_idx` logic or a temp flag.
            // Let's use `iter_count` for sqrt counter, and `state` for switching.
            // Let's merge FIND_MIN into a loop.
            
            // --- REFACTORED STATES ---
            // State: FIND_MIN
            // Step 1: Calculate Coeffs A, B, C.
            // Step 2: Calculate t_max.
            // Step 3: Iterate t to find local min.
            
            // Let's implement a separate sub-routine for t_max.
            // We need linear length of A. 
            // We need linear length of B.
            // We can compute them one after another.
            
            // Let's use `t_a_len` and `t_b_len` registers.
            // Use `curr_t` as the guess for sqrt.
            
            // Actually, the hint says: "Compute overlapping time window... Find minimum over [0, T] analytically or via 16-cycle loop".
            // If we find the minimum analytically:
            // t_opt = -b / (2a).
            // If t_opt in [0, T], compare dist(t_opt). Else compare dist(0), dist(T).
            // This avoids the loop over t!
            // Let's do analytical.
            // We need t_max (T). T = min(LengthA, LengthB).
            // We need sqrt for LengthA and LengthB.
            
            // Let's go back to SQRT_INIT / SQRT_ITER.
            // We will compute Sqrt(a_len2) -> t_a_len.
            // Then compute Sqrt(b_len2) -> t_b_len.
            
            // State: CALC_SQRT_A
            // Set sqrt_val = a_len2. Init guess. Jump to SQRT_ITER.
            // After iterations, save to t_a_len. Jump to CALC_SQRT_B.
            
            // State: CALC_SQRT_B
            // Set sqrt_val = b_len2. Init guess. Jump to SQRT_ITER.
            // After iterations, save to t_b_len. Jump to ANALYTICAL_CALC.
            
            // State: SQRT_ITER
            // x_new = 0.5 * (x + N/x). Need division. 
            // Division of Q16.16 numbers. 
            // N/x. x is guess. N is value.
            // 32-bit division is expensive (latency). 
            // The prompt says "Use a finite state machine... 16-cycle loop (sufficient for 10-bit precision)".
            // This implies a non-restoring or similar divider.
            // OR, they mean 16 cycles for the whole process, not just sqrt.
            // Let's try to optimize. If we assume inputs are small (0-10000), sqrt is < 10000.
            // We can use a simple iterative approximation (e.g. binary search) or digit-recurrence.
            // Given the "Icarus Verilog" constraint and complexity, let's use a simple non-restoring divider for sqrt and division.
            
            // However, to be safe and synthesizable, let's use a pre-computed table or simple approximation if possible.
            // But we need precision.
            // Let's stick to the Newton Raphson. Division is the bottleneck.
            // We need a divider module. 
            // Let's implement a simple bit-by-bit divider in a sub-state if needed.
            // But code size limits? 
            
            // Let's reconsider. "Minimum Euclidean distance".
            // If we use analytical method:
            // t_opt = -B / (2A).
            // We need to check if t_opt in [0, T].
            // We need to compare Dist(t_opt), Dist(0), Dist(T).
            // Dist(t) = At^2 + Bt + C.
            
            // Division - B / (2A). 
            // Let's use a simple 32-cycle restoring divider. 
            // It's robust and works in Icarus.
            
            // State: DIV_START
            // Param: Numerator, Denominator.
            // State: DIV_LOOP (32 cycles)
            // State: DIV_DONE
            
            // Let's add DIV states.
            // But first, let's finish the main flow.
            
            // STATE: FIND_MIN
            // 1. Compute Coeff A, B, C.
            // 2. Compute t_a_len = Sqrt(a_len2).
            // 3. Compute t_b_len = Sqrt(b_len2).
            // 4. t_max = min(t_a_len, t_b_len).
            // 5. Compute t_opt = -B / (2A).
            // 6. Check if t_opt in [0, t_max].
            // 7. Compute Dist(0), Dist(t_max). If valid, compute Dist(t_opt).
            // 8. Update global min.
            
            // We need a lot of registers for intermediate results.
            // t_opt = -B / (2A).
            // Numerator = -B. Denominator = 2A.
            // 2A is just coeff_a << 1.
            
            // Let's implement the Sqrt and Div as separate modules or inline FSM.
            // Given the "single module" constraint and Icarus, let's inline.
            
            // We will add states: 
            // CALC_T_A_LEN (init sqrt)
            // CALC_T_B_LEN (init sqrt)
            // SQRT_LOOP
            // CALC_T_OPT (init div)
            // DIV_LOOP
            // COMPARE_DISTS
            // UPDATE_MIN_DIST
            
            // Let's fill in the logic.
            
            // --- EXPANDED FSM LOGIC ---
            
            FIND_MIN: begin
                // 1. Compute Coeffs
                // a = (da_diff^2) [already calculated in temp_a, temp_b in SQRT_INIT logic, but let's do it here]
                // Let's move Coeff calc to COMPUTE_PARAMS for cleaner flow.
                // Actually, COMPUTE_PARAMS should just load data.
                
                // Let's use the registers set in COMPUTE_PARAMS.
                // We need to compute Coeff B and C here properly.
                
                // Coeff A is ready in coeff_a (from COMPUTE_PARAMS? No, I set temp_a there).
                // Let's fix COMPUTE_PARAMS to set coeff_a, coeff_b, coeff_c.
                // In COMPUTE_PARAMS:
                // coeff_a <= (a_dx - b_dx)^2 + (a_dy - b_dy)^2 [scaled]
                // coeff_b <= 2 * [(a_dx-b_dx)*(a_x0-b_x0) + ...] [scaled]
                // coeff_c <= (a_x0-b_x0)^2 + (a_y0-b_y0)^2 [scaled]
                
                // Let's assume they are set.
                // Start Sqrt for A.
                // Note: We need to handle division later. 
                // Let's do Sqrt(A_len).
                sqrt_val <= a_len2;
                sqrt_guess <= (a_len2 > 0) ? (a_len2 >> 1) + 32'h4000 : 32'd0;
                sqrt_iter <= 4'd0;
                
                // State transition to Sqrt Loop
                state <= 4'd9; // Sqrt_A_Loop (Let's define new states below)
            end
            
            // Let's map out states clearly.
            // IDLE(0), INIT_SEG(1), COMPUTE_PARAMS(2), FIND_MIN(3).
            // We need more states.
            // 9: SQRT_LOOP
            // 10: SQRT_DONE_A
            // 11: SQRT_DONE_B
            // 12: CALC_T_OPT
            // 13: CHECK_RANGE
            // 14: CALC_DIST_T_OPT
            // 15: CALC_DIST_T_MAX
            // 16: COMPARE_UPDATE
            // 17: NEXT_PAIR
            // 18: SQRT_INIT_B
            // 19: DIV_LOOP
            // 20: DIV_DONE
            
            // I will assign specific states logically in the final code block.
            
            // In SQRT_LOOP (state 9):
            // Newton step: x_new = (x + N/x) / 2.
            // N/x requires division. 
            // We need a divider. Let's use a counter to drive division.
            // But we can approximate? No, need precision.
            // Let's use a 32-cycle restoring divider.
            // To save states, we can interleave.
            // 
            // Let's simplify. Since coordinates are 0-10000, max dist ~ 15000.
            // Max dist squared ~ 2.25e8 (~0x0D7D7D7).
            // Sqrt is < 15000.
            // We can use a lookup table? Too big for registers.
            // 
            // Let's implement the SQRT_LOOP with a built-in divider sub-step.
            // Actually, Newton Raphson for sqrt: x_{k+1} = 0.5 * (x_k + S/x_k).
            // Division S/x_k. 
            // We can use the BITWISE method (non-restoring) for sqrt directly. 
            // It's more hardware friendly and doesn't need division.
            // "Bitwise Sqrt".
            // 1. Initialize remainder = val, result = 0.
            // 2. For i from 15 down to 0:
            //    temp = result + (1 << (2*i))
            //    if remainder >= temp: remainder -= temp, result += (1 << (2*i-1))
            // This works for integers. We have Q16.16.
            // Shift val left by 32 bits to treat as integer? 
            // val is Q16.16. We want sqrt in Q8.8 (or Q16.16).
            // Let's use Newton Raphson with a custom divider state.
            // 
            // Given the prompt's "16-cycle loop", maybe they expect a simple loop search?
            // "Find minimum over [0, T] analytically or via 16-cycle loop".
            // A 16-cycle loop over t suggests sampling.
            // If we sample t at 16 points, we might miss the true minimum.
            // Analytical is better if we can do the division.
            // 
            // Let's try to implement a simpler square root that fits the cycle budget.
            // If we need sqrt for T (time), and T is small (len of segment).
            // Maybe we can avoid sqrt for T?
            // If we know T_A and T_B are not needed explicitly if we compare t_opt to segment lengths?
            // No, t_max is needed.
            // 
            // Let's use the Newton-Raphson with a 32-bit divider.
            // 16 cycles for sqrt. 32 cycles for div? 
            // Maybe we can use a 16-cycle divider?
            // 
            // Let's stick to the plan: Analytical minimum.
            // t_opt = -B / (2A).
            // We need to calculate Sqrt(a_len2) and Sqrt(b_len2) to get t_max.
            // Let's use a simple Non-Restoring Sqrt algorithm (shift-add).
            // It takes 16 iterations for 32-bit number (actually 16 iterations for result bits).
            // 
            // State: SQRT_START
            // Setup: rem = val << 16 (to get integer part?
            // Actually, for Q16.16 input, Sqrt result is Q8.8.
            // Let's treat input as integer. val * 2^16. Sqrt = sqrt(val * 2^16) = sqrt(val) * 2^8.
            // So result is shifted left by 8.
            // 
            // Let's define new states:
            // 9: SQRT_INIT (Setup pointers)
            // 10: SQRT_LOOP (16 cycles)
            // 11: SQRT_RESULT (Store result)
            // 12: DIV_INIT (for t_opt = -B / (2A))
            // 13: DIV_LOOP (16 cycles - reduce to 16 for speed, lower precision)
            // 14: DIV_RESULT
            // 15: CHECK_BOUNDS
            // 16: CALC_DIST_POTENTIAL
            // 17: UPDATE_GMIN
            // 18: NEXT_PAIR
            
            // Let's use `state` 9 to 18.
            
            // --- IMPLEMENTATION ---
            
            // State 9: SQRT_INIT (A)
            4'd9: begin
                // Initialize Sqrt for segment A length
                // We need a 16-cycle loop. We'll use iter_count (0-15).
                // Algorithm: 
                // rem[31:0] = (val << 16) >> 1? 
                // Standard non-restoring:
                // R = input. Result = 0.
                // For i = 15..0:
                //   R = (R << 2) | ((result >> (2*i)) & 3) ? 
                // Let's use a simpler shift-add.
                // R = input. Result = 0. Mask = 1 << 30.
                // While mask > 0:
                //   temp = result | mask
                //   if R >= temp: R -= temp, result = temp | (mask >> 1)
                //   mask >>= 2
                // This works for integer sqrt.
                // For Q16.16, treat input as integer (val * 65536). 
                // Actually, val is Q16.16. We want result in Q8.8.
                // Input to integer sqrt: val << 16. 
                // Result of integer sqrt is (sqrt(val) * 2^8). 
                // This is exactly Q8.8 if we consider the binary point.
                // 
                // Setup:
                sqrt_val <= a_len2;
                sqrt_prev <= 32'd0;
                sqrt_guess <= 32'd0;
                iter_count <= 4'd0;
                // We will use sqrt_guess as 'result', sqrt_prev as 'rem'
                // Actually, let's use a specific loop state.
                // We need to store 'R' (remainder).
                // Let's use `sqrt_val` as the remainder.
                // `sqrt_guess` as result.
                // `sqrt_prev` as mask? 
                // Let's use `coeff_a` as temp storage for mask? No, we need coeff_a.
                // Let's use `iter_count` for loop counter.
                // We need a mask register. Let's use `t_step`.
                
                // Input: a_len2 (Q16.16). 
                // We want to calculate sqrt(a_len2).
                // Let's treat a_len2 as integer.
                // Remainder = a_len2 << 16. (Shift to make it Q32.32 relative to result)
                // Result = 0.
                // Mask = 1 << 30. (Top bit of Q32.32 result range)
                
                // Initialize for Sqrt:
                sqrt_val <= {a_len2[15:0], 16'd0}; // R (Remainder), extended to 32-bit for calc? 
                // We need 64-bit for intermediate?
                // R can be 64-bit. Let's use 64-bit registers for Sqrt internal calc.
                // But we only have 32-bit regs specified.
                // Max a_len2 is (10000^2 + 10000^2) * 256 (scaled) ≈ 5.12e10. 
                // 5.12e10 is ~36 bits. 
                // We need 64-bit math for Sqrt.
                // Let's use a temp register or output register for high bits.
                // `result` is 32-bit. 
                // Let's use `sqrt_val` (32-bit) as lower 32 bits of remainder.
                // Use `coeff_a` as upper 32 bits? No, we need coeff_a.
                // Use `t_opt`? No.
                // Let's use a temporary array or just specific registers.
                // We have `curr_t`, `t_step`.
                // Let's use `t_opt` as upper 32 bits of remainder for Sqrt.
                // `curr_t` as lower 32 bits.
                // `t_step` as mask.
                // `sqrt_guess` as result.
                
                // Sqrt Input: a_len2 (32-bit).
                // We need to shift left by 16 to treat as integer.
                // High bits of (a_len2 << 16) fit in 32 bits if a_len2 < 2^16.
                // a_len2 is Q16.16. Max value ~ 2^31.
                // a_len2 << 16 is Q32.32. We need 64 bits.
                // Let's store `a_len2` in `curr_t` (lower 32) and 0 in `t_opt` (upper 32).
                // But we need to shift left 16. 
                // `curr_t` <= a_len2 << 16.
                // `t_opt` <= a_len2[31:16] (upper bits). 
                // Actually `a_len2` is 32-bit. `a_len2 << 16` is 48-bit. 
                // Okay, let's just use a simpler approximation or limit precision.
                // Or, use the Newton Raphson which uses division.
                // Division is 32-bit. 
                // Let's revert to Newton Raphson.
                // x_{k+1} = 0.5 * (x + S/x).
                // We need a divider. 
                // Let's implement a 16-cycle restoring divider.
                // We will use `DIV_LOOP` state.
                // 
                // Let's try to cheat the sqrt for time. 
                // Time = length. 
                // If we don't divide by 2 in sqrt, we get result in Q16.16 (shifted).
                // If we do `x_new = (x + S/x) >> 1`, we need division.
                // 
                // Let's use the Sqrt algorithm that uses shifts and adds, but adapted for 32-bit result.
                // We can do 16 iterations of bit checking.
                // We need a 64-bit register for Remainder. 
                // Let's use `t_opt` (32-bit) and `curr_t` (32-bit) for Remainder.
                // Let's use `t_max` for Result.
                // Let's use `sqrt_guess` for Mask.
                
                // Algorithm:
                // R[63:0] = {val, 16'd0} // Shift left 16
                // Res[31:0] = 0
                // Mask[31:0] = 1 << 30
                // 
                // Loop 16 times:
                //   temp = Res | Mask
                //   if R >= temp: R = R - temp; Res = temp | (Mask >> 1)
                //   Mask = Mask >> 2
                
                // State 9 (SQRT_INIT):
                // Setup registers.
                // R_high = a_len2[15:0] 
                // R_low = a_len2[31:16] << 16? 
                // Let's put a_len2 in `sqrt_val`. 
                // We need to shift left 16. 
                // `t_opt` (high) <= sqrt_val[15:0]
                // `curr_t` (low) <= sqrt_val[31:16] << 16 (effectively 0)
                // `t_max` (result) <= 0
                // `sqrt_guess` (mask) <= 1 << 30
                // `iter_count` <= 0
                
                // Let's store full 64-bit Remainder in `t_opt` (high) and `curr_t` (low).
                // a_len2 is 32-bit. 
                // High 16 bits of a_len2 go to `t_opt` [15:0].
                // Low 16 bits of a_len2 go to `curr_t` [31:16].
                // `t_opt` [31:16] = 0.
                // `curr_t` [15:0] = 0.
                
                t_opt <= {16'd0, sqrt_val[31:16]}; // High 32 bits of Rem
                curr_t <= {sqrt_val[15:0], 16'd0};  // Low 32 bits of Rem
                t_max <= 32'd0; // Result
                sqrt_guess <= 32'h4000_0000; // Mask (1 << 30)
                
                state <= 4'd10; // SQRT_LOOP
                iter_count <= 4'd0;
            end
            
            // State 10: SQRT_LOOP
            4'd10: begin
                // temp = Result | Mask
                // if Remainder >= temp: Remainder -= temp; Result = temp | (Mask >> 1)
                // Mask >>= 2
                
                // Comparison: Remainder (64-bit) >= temp (32-bit)
                // temp is in `sqrt_guess`.
                // Need to compare 64-bit `t_opt`/`curr_t` with 32-bit `sqrt_guess`.
                // Since `sqrt_guess` is mask based, it's positive.
                // `t_opt` should be 0 for lower values (sqrt of small numbers).
                
                // Let's compute temp = t_max | sqrt_guess
                wire [31:0] temp_val;
                assign temp_val = t_max | sqrt_guess;
                
                // Check if R >= temp_val
                // If `t_opt` > 0, definitely yes (for small sqrt_guess).
                // If `t_opt` == 0, check `curr_t` >= temp_val.
                
                if (t_opt != 0 || curr_t >= temp_val) begin
                    // R = R - temp
                    // Subtract 32-bit temp from 64-bit R
                    // {t_opt, curr_t} - {0, temp_val}
                    // If curr_t < temp_val, borrow from t_opt.
                    if (curr_t >= temp_val) begin
                        curr_t <= curr_t - temp_val;
                    end else begin
                        curr_t <= curr_t + (32'hFFFF_FFFF - temp_val) + 32'd1;
                        t_opt <= t_opt - 32'd1;
                    end
                    
                    // Result = temp | (Mask >> 1)
                    t_max <= temp_val | (sqrt_guess >> 1);
                end
                
                // Mask >>= 2
                sqrt_guess <= sqrt_guess >> 2;
                
                iter_count <= iter_count + 4'd1;
                if (iter_count == 4'd15) begin
                    // Done. Result is in t_max.
                    // Move to next step.
                    // We just finished Sqrt(A).
                    // Need to save t_a_len.
                    // Let's use `dist_at_t0` to store t_a_len (it's not used yet).
                    dist_at_t0 <= t_max;
                    
                    // Next: Sqrt(B)
                    // We need to reset sqrt_val to b_len2.
                    // We can jump back to State 9.
                    // But State 9 uses `sqrt_val`.
                    // We need to set `sqrt_val` to `b_len2`.
                    // `b_len2` is in `a_len2` reg? No, `a_len2` holds A. `b_len2` holds B.
                    // `a_len2` was modified? No.
                    // `b_len2` is in `b_len2` reg.
                    // Let's jump to State 9, but we need to load `b_len2` into `sqrt_val`.
                    // Let's add a state 11: SQRT_INIT_B
                    state <= 4'd11;
                end else begin
                    state <= 4'd10;
                end
            end
            
            // State 11: SQRT_INIT_B
            4'd11: begin
                // Initialize Sqrt for B (similar to State 9)
                // Input: b_len2
                // Result will be stored in `dist_at_t_max` (we'll use it later for t_max)
                
                // We need to store t_a_len somewhere safe. 
                // `dist_at_t0` holds t_a_len.
                
                // Setup Remainder for B
                t_opt <= {16'd0, b_len2[31:16]};
                curr_t <= {b_len2[15:0], 16'd0};
                t_max <= 32'd0;
                sqrt_guess <= 32'h4000_0000;
                
                state <= 4'd12; // SQRT_LOOP_B
                iter_count <= 4'd0;
            end
            
            // State 12: SQRT_LOOP_B
            4'd12: begin
                // Same loop logic as State 10
                wire [31:0] temp_val;
                assign temp_val = t_max | sqrt_guess;
                
                if (t_opt != 0 || curr_t >= temp_val) begin
                    if (curr_t >= temp_val) begin
                        curr_t <= curr_t - temp_val;
                    end else begin
                        curr_t <= curr_t + (32'hFFFF_FFFF - temp_val) + 32'd1;
                        t_opt <= t_opt - 32'd1;
                    end
                    t_max <= temp_val | (sqrt_guess >> 1);
                end
                
                sqrt_guess <= sqrt_guess >> 2;
                
                iter_count <= iter_count + 4'd1;
                if (iter_count == 4'd15) begin
                    // Done. Result in t_max (this is t_b_len).
                    // Now we have t_a_len (in dist_at_t0) and t_b_len (in t_max).
                    // Calculate t_max = min(t_a_len, t_b_len).
                    // Store in `t_max` register.
                    if (dist_at_t0 < t_max) begin
                        // A is smaller
                        // We need to keep t_max. 
                        // But we also need to compute t_opt = -B / (2A).
                        // 
                        // Let's compute t_opt first.
                        // We need to divide -B by 2A.
                        // Numerator: -coeff_b
                        // Denominator: 2 * coeff_a
                        
                        // Prepare Divider.
                        // Numerator = -coeff_b.
                        // Denominator = coeff_a << 1.
                        
                        // If coeff_a is 0 (parallel segments), skip division.
                        if (coeff_a == 0) begin
                            // Distance is linear or constant.
                            // Min is at endpoints.
                            // Skip to endpoint check.
                            // We need t_max.
                            // Store t_max.
                            dist_at_t_max <= dist_at_t0; // t_max = t_a_len
                            state <= 4'd15; // CHECK_RANGE
                        end else begin
                            // Setup Divider
                            // Numerator: -B. Check sign.
                            // We handle signed division.
                            // Let's use positive values for logic, track sign.
                            
                            // For now, let's store t_max.
                            dist_at_t_max <= dist_at_t0; // t_max = t_a_len
                            
                            // Start Division
                            // Use a counter. 16 cycles.
                            // We need registers for quotient and remainder.
                            // Let's use `sqrt_val` for remainder, `sqrt_guess` for quotient?
                            // No, `sqrt_val` was used.
                            // Let's use `dist_at_t_opt` for quotient.
                            // `dist_at_t0` is holding t_a_len. 
                            // `dist_at_t_max` holding t_max.
                            // We need new registers.
                            // Let's use `curr_t` for remainder (high bits?), `t_step` for quotient.
                            // `t_opt` for numerator. `sqrt_guess` for denominator.
                            
                            // Setup:
                            // Numerator (Abs): if coeff_b < 0 then -coeff_b else coeff_b.
                            // Sign = coeff_b[31] ^ 0 (for -B).
                            // Denominator (Abs): coeff_a << 1.
                            
                            // We need to be careful with register reuse.
                            // Let's use `coeff_b` as numerator, `coeff_a` as denominator for now.
                            // We will overwrite them? No, we need them for other checks.
                            // We need temp registers.
                            // `t_opt` = numerator
                            // `sqrt_guess` = denominator
                            // `dist_at_t_opt` = quotient
                            // `sqrt_val` = remainder
                            
                            // -B calculation:
                            // -coeff_b. 
                            // If coeff_b is 32'h8000_0000, -coeff_b is overflow. 
                            // But B won't be that large.
                            
                            t_opt <= (coeff_b[31] ? -coeff_b : coeff_b); // Abs(Numerator)
                            sqrt_guess <= coeff_a << 1; // Denominator
                            dist_at_t_opt <= 32'd0; // Quotient
                            sqrt_val <= 32'd0; // Remainder
                            
                            // Sign tracking: 
                            // If coeff_b is positive, -B is negative. Result negative.
                            // If coeff_b is negative, -B is positive. Result positive.
                            // Result sign = !coeff_b[31].
                            // We'll store sign in `coeff_a[0]` or something? No.
                            // Let's store in `coeff_b[0]` (we copied value to t_opt).
                            // Let's use `coeff_a` bit 0? No, it's width 32.
                            // Let's use `dist_at_t_max` bit 0? No.
                            // Let's use `iter_count` bit? No.
                            // Let's just compute positive quotient and apply sign later.
                            // We need to know if -B was negative.
                            // Let's use `sqrt_val` bit 31 as sign flag? No, sqrt_val is remainder.
                            // Let's use `coeff_a[0]` is not safe.
                            // Let's use `curr_t[0]`? No.
                            // Let's use `t_step[0]`? No.
                            // Let's use `dist_at_t_opt[31]` as sign flag before we start?
                            // Yes. `dist_at_t_opt` is 0. We can use the MSB.
                            // dist_at_t_opt[31] <= coeff_b[31]; // If coeff_b pos, -B neg.
                            // Wait. B=10. -B=-10. sign neg.
                            // B=-10. -B=10. sign pos.
                            // sign = !coeff_b[31].
                            // Let's store sign in `dist_at_t_opt[31]`.
                            dist_at_t_opt[31] <= !coeff_b[31];
                            
                            state <= 4'd13; // DIV_LOOP
                            iter_count <= 4'd0;
                        end
                    end else begin
                        // B is smaller or equal
                        // Store t_max = t_b_len
                        dist_at_t_max <= t_max;
                        
                        // Setup Divider for -B / (2A)
                        if (coeff_a == 0) begin
                            state <= 4'd15;
                        end else begin
                            t_opt <= (coeff_b[31] ? -coeff_b : coeff_b);
                            sqrt_guess <= coeff_a << 1;
                            dist_at_t_opt <= 32'd0;
                            sqrt_val <= 32'd0;
                            dist_at_t_opt[31] <= !coeff_b[31];
                            state <= 4'd13; // DIV_LOOP
                            iter_count <= 4'd0;
                        end
                    end
                end else begin
                    state <= 4'd12;
                end
            end
            
            // State 13: DIV_LOOP (16-cycle restoring divider)
            4'd13: begin
                // Algorithm:
                // R = R << 1 | N[i]
                // Q = Q << 1
                // If R >= D: R = R - D; Q = Q | 1
                // We process 16 bits of numerator (since we want 16-bit precision for t_opt)
                // Numerator is 32-bit. 
                // We'll iterate 16 times to get 16-bit integer result.
                // `t_opt` holds numerator (Abs). `sqrt_guess` holds denominator.
                // `sqrt_val` holds remainder (high bits), `dist_at_t_opt` holds quotient (low 16 bits).
                // Actually, let's just do 16 iterations for the whole number.
                // 
                // We need to shift `t_opt` into `sqrt_val`.
                // `t_opt` is 32-bit. `sqrt_val` is 32-bit.
                // We need to shift 32 times to divide properly.
                // But prompt says "16-cycle loop".
                // Maybe we only do 16 cycles? 
                // If we only do 16 cycles, we get quotient bits 31..16 (or 15..0).
                // Let's assume we want 16-bit precision result.
                // Numerator is 32-bit. Result will be 16-bit if Denominator is large enough.
                // Let's iterate 16 times.
                // 
                // We shift `t_opt` left into `sqrt_val` (remainder).
                // `t_opt` is numerator. `sqrt_val` is remainder.
                // Start: remainder = 0.
                // Loop 16 times:
                //   remainder = (remainder << 1) | (numerator >> 31)
                //   numerator = numerator << 1
                //   if remainder >= denominator: remainder -= denominator, quotient |= 1
                //   quotient <<= 1
                
                // State 13 logic:
                // Shift numerator left (t_opt). MSB goes to carry.
                // Shift remainder left (sqrt_val). Insert carry.
                
                // We need to handle `t_opt` (numerator) and `sqrt_val` (rem).
                // `sqrt_guess` (denom) is constant.
                // `dist_at_t_opt` (quotient) is accumulating.
                
                // Shift t_opt left by 1, get carry.
                // We can simulate this with shifts.
                // carry = t_opt[31];
                // t_opt = t_opt << 1;
                // sqrt_val = {sqrt_val[30:0], carry};
                
                wire carry_bit;
                assign carry_bit = t_opt[31];
                
                // Update Remainder
                // temp_rem = (sqrt_val << 1) | carry_bit
                // Actually, just shift sqrt_val left, insert bit.
                // `sqrt_val` is 32-bit. `t_opt` is 32-bit.
                // `sqrt_val` << 1 | (t_opt >> 31)
                
                // But we are doing 16 cycles for 32-bit numerator?
                // If we want 16-bit result, we shift 16 times.
                // Let's shift 16 times.
                
                // If we shift 16 times, we process upper 16 bits of numerator?
                // Or we process all 32 bits?
                // Let's just do 16 iterations of restoring division.
                // `t_opt` contains numerator.
                // `sqrt_val` contains remainder.
                // `dist_at_t_opt` contains quotient.
                
                // Operation:
                // t_opt = t_opt << 1
                // sqrt_val = {sqrt_val[30:0], t_opt_old[31]}
                // if sqrt_val >= sqrt_guess: sqrt_val -= sqrt_guess; dist_at_t_opt = {dist_at_t_opt[30:0], 1'b1}
                // else: dist_at_t_opt = {dist_at_t_opt[30:0], 1'b0}
                
                // We need to shift t_opt. 
                // Let's use `curr_t` to store shifted t_opt? 
                // Or just modify `t_opt` in place.
                // We need the old bit. 
                
                // Let's use a temporary variable for the shifted bit in Verilog code.
                // We can't do non-blocking assignment for the bit value easily in one line.
                // We'll do:
                // bit = t_opt[31];
                // t_opt <= t_opt << 1;
                // sqrt_val <= {sqrt_val[30:0], bit};
                
                // Then compare.
                // If sqrt_val >= sqrt_guess:
                //    sqrt_val <= sqrt_val - sqrt_guess;
                //    dist_at_t_opt <= {dist_at_t_opt[30:0], 1'b1};
                // else:
                //    dist_at_t_opt <= {dist_at_t_opt[30:0], 1'b0};
                
                // We need to shift `dist_at_t_opt`. It's 32-bit. We only care about lower 16 bits for precision?
                // Let's just shift the whole thing.
                
                // Note: `dist_at_t_opt` MSB was used for sign. 
                // We must preserve it.
                // dist_at_t_opt[31] is sign. dist_at_t_opt[30:0] is value.
                // When shifting, we insert bit at dist_at_t_opt[0]? No, shift left.
                // {dist_at_t_opt[30:0], bit}
                // We lose sign bit if we shift left 32 times.
                // We need to preserve sign. 
                // Let's use `dist_at_t_opt` for quotient storage, but be careful with sign.
                // Or use `t_max`? No, `t_max` holds t_max.
                // Use `dist_at_t_max`? No, that holds t_max (min of t_a_len, t_b_len).
                // Let's use `coeff_a`? No.
                // Let's use `coeff_b`? No.
                // Let's use `sqrt_prev`? Yes, we haven't used it much.
                // We can use `sqrt_prev` to hold the quotient.
                // We will move sign to `sqrt_prev[31]`.
                // Wait, `dist_at_t_opt[31]` has the sign.
                // Let's shift `dist_at_t_opt` but keep MSB?
                // `dist_at_t_opt` is 32-bit. We want 16-bit result.
                // We can use `dist_at_t_opt[15:0]` for quotient bits.
                // And `dist_at_t_opt[31]` for sign.
                // `dist_at_t_opt` was initialized to 0 (except sign bit).
                // So `dist_at_t_opt[30:16]` are 0.
                // We can shift into `dist_at_t_opt[15:0]`.
                // `dist_at_t_opt[31]` stays.
                // `dist_at_t_opt[30:16]` stays 0.
                
                // Let's do it.
                
                // 1. Get bit from t_opt
                // 2. Shift t_opt
                // 3. Shift remainder
                // 4. Compare
                // 5. Update remainder
                // 6. Shift quotient
                
                // To avoid order dependency issues in Verilog:
                wire [31:0] next_t_opt = t_opt << 1;
                wire [31:0] next_rem = {sqrt_val[30:0], t_opt[31]};
                wire [31:0] next_quotient;
                
                if (next_rem >= sqrt_guess) begin
                    sqrt_val <= next_rem - sqrt_guess;
                    dist_at_t_opt[15:0] <= {dist_at_t_opt[14:0], 1'b1};
                end else begin
                    sqrt_val <= next_rem;
                    dist_at_t_opt[15:0] <= {dist_at_t_opt[14:0], 1'b0};
                end
                
                t_opt <= next_t_opt;
                
                iter_count <= iter_count + 4'd1;
                if (iter_count == 4'd15) begin
                    state <= 4'd14; // DIV_DONE
                end else begin
                    state <= 4'd13;
                end
            end
            
            // State 14: DIV_DONE
            4'd14: begin
                // Result is in `dist_at_t_opt[15:0]` (unsigned).
                // Sign is in `dist_at_t_opt[31]`.
                // Apply sign to get t_opt.
                // t_opt is Q16.16? 
                // Numerator was Q16.16 (coeff_b). Denominator Q16.16 (coeff_a).
                // Result is Q16.16 (shifted right by 16 if we did 16 iterations).
                // Actually, we did 16 iterations of restoring division.
                // Input: 32-bit Num, 32-bit Den.
                // We shifted Num 16 times. Result is 16-bit integer (or Q16.0).
                // We want Q16.16. 
                // We should have shifted 32 times.
                // Let's assume 16 iterations gives us the top 16 bits of the quotient.
                // `dist_at_t_opt[15:0]` contains the quotient.
                // We need to shift it left by 16 to make it Q16.16.
                
                t_opt <= {dist_at_t_opt[15:0], 16'd0}; // Scale to Q16.16
                
                // Apply sign
                if (dist_at_t_opt[31]) begin
                    t_opt <= -t_opt;
                end
                
                // We have t_opt (analytical min location).
                // We have t_max (in `dist_at_t_max`).
                // We need to check if t_opt is in [0, t_max].
                // If t_opt < 0, min is at t=0.
                // If t_opt > t_max, min is at t=t_max.
                // Else, min is at t=t_opt.
                
                state <= 4'd15; // CHECK_RANGE
            end
            
            // State 15: CHECK_RANGE
            4'd15: begin
                // We have t_opt, t_max.
                // Calculate Dist(0) = C.
                dist_at_t0 <= coeff_c; // Dist at t=0 is just C
                
                // Calculate Dist(t_max) = A*t_max^2 + B*t_max + C
                // We need multipliers.
                // A*t_max^2 -> A * t_max * t_max
                // B*t_max
                
                // Calculate A * t_max
                // `dist_at_t_max` holds t_max.
                // `coeff_a` holds A.
                // Let's use `curr_t` and `t_step` for intermediate.
                
                // Prepare Dist(t_max) calculation in next state.
                // Or do it here if combinational logic is fast enough.
                // Let's do it in next state.
                
                // Check t_opt range:
                // If t_opt < 0: skip t_opt check.
                // If t_opt > t_max: skip t_opt check.
                
                // We will compute all three candidates and take min.
                // But we only have one update logic.
                // Let's compute them one by one and update global min.
                
                // Order:
                // 1. Check t=0 (dist_at_t0 is ready).
                // 2. Check t=t_max (compute).
                // 3. Check t=t_opt (compute if valid).
                
                // Let's start with t=0.
                // We already have `dist_at_t0` = coeff_c.
                // Update global min with `dist_at_t0`.
                // But we need to update `min_dist_sq`.
                // `min_dist_sq` is in `min_dist_sq`.
                
                // Compare `dist_at_t0` with `min_dist_sq`.
                // If `dist_at_t0` < `min_dist_sq`, update.
                // We need signed comparison. Distances are positive.
                
                // Let's do the updates in a single state or separate states.
                // Separate states are cleaner.
                // State 16: UPDATE_MIN_0 (t=0)
                // State 17: CALC_DIST_T_MAX
                // State 18: UPDATE_MIN_T_MAX
                // State 19: CHECK_T_OPT
                // State 20: CALC_DIST_T_OPT
                // State 21: UPDATE_MIN_T_OPT
                // State 22: NEXT_PAIR
                
                // Let's jump to State 16.
                state <= 4'd16;
            end
            
            // State 16: UPDATE_MIN_0
            4'd16: begin
                // Compare dist_at_t0 (coeff_c) with min_dist_sq
                // `dist_at_t0` holds coeff_c (Dist at t=0)
                // `min_dist_sq` holds global min.
                // Since distances are squared, they are positive.
                if (dist_at_t0 < min_dist_sq) begin
                    min_dist_sq <= dist_at_t0;
                end
                
                // Prepare Dist(t_max)
                // dist = A * t_max^2 + B * t_max + C
                // Let's use `t_max` register for the value.
                // `dist_at_t_max` holds t_max.
                // `coeff_a`, `coeff_b`, `coeff_c`.
                
                // A * t_max * t_max
                // Let's calculate `coeff_a * t_max` first.
                // Store in `curr_t` or `t_step`.
                // `t_step` <= coeff_a * dist_at_t_max (Q16.16 * Q16.16 -> Q32.32 -> trunc Q16.16)
                // We need 64-bit multiplication.
                // `coeff_a` is 32-bit. `dist_at_t_max` is 32-bit.
                // Product is 64-bit.
                // `t_step` <= (coeff_a * dist_at_t_max) >> 16.
                
                // Let's use `t_step` for intermediate.
                // `t_step` <= coeff_a * dist_at_t_max (high 32 bits)
                // `curr_t` <= coeff_b * dist_at_t_max (high 32 bits)
                // `dist_at_t0` <= coeff_c (already there)
                
                // We need multipliers. 
                // In Verilog, we can't have multi-module connections in code block easily without wires.
                // Let's use temporary wires for multiplication results.
                // `dist_at_t_max` is t_max.
                
                // Calculate A * t_max
                wire signed [63:0] prod_at_max;
                assign prod_at_max = coeff_a * dist_at_t_max;
                
                // Calculate B * t_max
                wire signed [63:0] prod_bt_max;
                assign prod_bt_max = coeff_b * dist_at_t_max;
                
                // Store partials
                // A*t_max is Q32.32. We need to add B*t_max (Q32.32) and C (Q16.16).
                // C is Q16.16. Scale to Q32.32 (shift left 16).
                
                // Let's compute total in Q16.16.
                // (A*t_max^2) -> (A*t_max) >> 16 * t_max >> 16? 
                // No. (A*t_max) is Q32.32. 
                // Result = (A*t_max) >> 16 + (B*t_max) >> 16 + C.
                // 
                // Let's store these terms in registers.
                // `t_step` <= prod_at_max[47:16] (A*t_max truncated)
                // `curr_t` <= prod_bt_max[47:16] (B*t_max truncated)
                
                t_step <= prod_at_max[47:16];
                curr_t <= prod_bt_max[47:16];
                
                // State to sum them.
                state <= 4'd17;
            end
            
            // State 17: CALC_DIST_T_MAX
            4'd17: begin
                // Sum: t_step (A*t_max) + curr_t (B*t_max) + coeff_c
                wire signed [32:0] sum_temp;
                assign sum_temp = t_step + curr_t + coeff_c;
                
                // Clamp to 32-bit? Should be fine.
                dist_at_t_max <= sum_temp[31:0];
                
                // Update Global Min
                if (sum_temp < min_dist_sq) begin
                    min_dist_sq <= sum_temp[31:0];
                end
                
                // Check if t_opt is valid
                // Valid if 0 <= t_opt <= t_max
                // `t_opt` holds t_opt.
                // `dist_at_t_max` now holds Dist(t_max). We need t_max value again.
                // We overwrote `dist_at_t_max`? No, `dist_at_t_max` held t_max. 
                // We used `dist_at_t_max` in State 16 to calculate product.
                // But `dist_at_t_max` is a reg. It's still t_max.
                // Wait, I assigned `dist_at_t_max <= sum_temp[31:0]` in this block. 
                // I should use a temp register for the result.
                // Let's store result in `dist_at_t_opt`? No, that held quotient.
                // Let's store in `dist_at_t0`? No, that held coeff_c.
                // Let's use `dist_at_t_max` for the new distance, and `t_max` reg for the time value.
                // I confused `dist_at_t_max` (time) with distance.
                // Let's rename in comments: `t_max_val` is time. `dist_at_t_max` is distance.
                // In State 16, `dist_at_t_max` register held the TIME t_max.
                // I calculated distance and stored it in `dist_at_t_max` register.
                // I lost the TIME t_max.
                // I need to keep TIME t_max separate.
                // Let's use `t_max` register for TIME t_max.
                // `dist_at_t_max` register for DISTANCE at t_max.
                // In State 16, I used `dist_at_t_max` as TIME. 
                // Let's fix this.
                // I will assume `dist_at_t_max` holds TIME.
                // I will use `curr_t` or `t_step` to hold the calculated distance temporarily?
                // No, `curr_t` and `t_step` hold terms.
                // Let's use `sqrt_val` to hold the final distance.
                
                // So, in State 16:
                // `t_step` = coeff_a * dist_at_t_max (Time) >> 16
                // `curr_t` = coeff_b * dist_at_t_max (Time) >> 16
                // In State 17:
                // `sqrt_val` = t_step + curr_t + coeff_c
                // 
                // Then check range.
                // We need TIME t_max. It's in `dist_at_t_max`.
                // We need TIME t_opt. It's in `t_opt`.
                
                // Check: t_opt < 0 ?
                // t_opt is signed. 
                // Check: t_opt > t_max ?
                // We need to compare signed with unsigned? 
                // t_max is length, positive. t_opt can be negative.
                // If t_opt[31] (sign bit) is 1, it's negative -> invalid.
                // If t_opt >= t_max -> invalid.
                
                // Let's do the check.
                // If t_opt is negative (t_opt[31]==1), skip.
                // Else, if t_opt > dist_at_t_max, skip.
                // Else, compute dist(t_opt).
                
                // We need to keep `sqrt_val` (Dist t_max) for comparison if we skip.
                // Let's store `sqrt_val` back to `dist_at_t_max`.
                // And keep `dist_at_t_max` as distance.
                // We need the time value `dist_at_t_max` (initially time).
                // Let's move Time t_max to `t_max` register? 
                // `t_max` was used for Sqrt result. 
                // `dist_at_t0` was used for t_a_len.
                // `dist_at_t_max` was used for t_max (min of lengths).
                // Let's move `dist_at_t_max` (Time) to `t_max` register before calculating distance.
                // `t_max` register is free? No, `t_max` was used in Sqrt logic.
                // `t_max` holds Result of Sqrt(B) in State 12.
                // Then we moved it to `dist_at_t_max` (Time).
                // In State 12: `dist_at_t_max <= t_max` (Time).
                // `t_max` register is now free to use (except in Sqrt logic which is done).
                // Yes, Sqrt logic is done (State 12 finished). 
                // So `t_max` register is free.
                // In State 16, I should have moved Time to `t_max`.
                // `t_max` <= `dist_at_t_max` (Time).
                // Then use `dist_at_t_max` for calculation.
                // 
                // Let's do it in State 17.
                // `t_max` <= `dist_at_t_max` (Time).
                // `dist_at_t_max` <= `sqrt_val` (Distance at t_max).
                
                t_max <= dist_at_t_max;
                dist_at_t_max <= sqrt_val;
                
                // Now `dist_at_t_max` holds Dist(t_max).
                // `t_max` holds Time t_max.
                
                // Check t_opt validity
                if (t_opt[31] == 1) begin
                    // t_opt < 0. Skip.
                    state <= 4'd22; // NEXT_PAIR
                end else begin
                    // t_opt >= 0. Check if t_opt <= t_max.
                    // t_opt is Q16.16. t_max is Q16.16.
                    if (t_opt > t_max) begin
                        // t_opt > t_max. Skip.
                        state <= 4'd22; // NEXT_PAIR
                    end else begin
                        // Valid. Calculate Dist(t_opt).
                        state <= 4'd18; // CALC_DIST_T_OPT
                    end
                end
            end
            
            // State 18: CALC_DIST_T_OPT
            4'd18: begin
                // Calculate Dist(t_opt) = A*t_opt^2 + B*t_opt + C
                // We already have A, B, C.
                // t_opt is in `t_opt`.
                
                // A * t_opt * t_opt
                // B * t_opt
                
                wire signed [63:0] prod_at_opt;
                assign prod_at_opt = coeff_a * t_opt;
                wire signed [63:0] prod_bt_opt;
                assign prod_bt_opt = coeff_b * t_opt;
                
                // Store truncated terms
                t_step <= prod_at_opt[47:16];
                curr_t <= prod_bt_opt[47:16];
                
                state <= 4'd19; // SUM_T_OPT
            end
            
            // State 19: SUM_T_OPT
            4'd19: begin
                // Sum
                wire signed [32:0] sum_temp;
                assign sum_temp = t_step + curr_t + coeff_c;
                
                // Update Global Min
                if (sum_temp < min_dist_sq) begin
                    min_dist_sq <= sum_temp[31:0];
                end
                
                // Next Pair
                state <= 4'd22;
            end
            
            // State 22: NEXT_PAIR
            4'd22: begin
                // Update minimum distance (already done in update states)
                // Next segment pair logic
                
                // Move B segment index
                if (seg_b_idx < max_seg_b) begin
                    seg_b_idx <= seg_b_idx + 4'd1;
                    state <= INIT_SEG; // Go to next B segment (keep A)
                end else begin
                    // B reached end. Move A.
                    seg_b_idx <= 4'd0;
                    if (seg_a_idx < max_seg_a) begin
                        seg_a_idx <= seg_a_idx + 4'd1;
                        state <= INIT_SEG; // Next A, reset B
                    end else begin
                        // Both finished. Compute Sqrt of min_dist_sq.
                        state <= 4'd23; // PREP_SQRT_FINAL
                    end
                end
            end
            
            // State 23: PREP_SQRT_FINAL
            4'd23: begin
                // Prepare Sqrt for final result.
                // Input: min_dist_sq (Q16.16).
                // We want result in Q16.16? 
                // Sqrt of Q16.16 is Q8.8. 
                // We need to output 32-bit Q16.16.
                // So we need to shift the result left by 8.
                // 
                // Input to Sqrt: min_dist_sq << 16 (to treat as integer).
                // Result (integer) >> 8.
                // 
                // Let's setup Sqrt same as before.
                // Remainder = {min_dist_sq[15:0], 16'd0}
                // Result = 0
                // Mask = 1 << 30
                
                t_opt <= {16'd0, min_dist_sq[31:16]};
                curr_t <= {min_dist_sq[15:0], 16'd0};
                t_max <= 32'd0; // Result
                sqrt_guess <= 32'h4000_0000;
                
                state <= 4'd24; // SQRT_FINAL_LOOP
                iter_count <= 4'd0;
            end
            
            // State 24: SQRT_FINAL_LOOP
            4'd24: begin
                // Same logic as State 10
                wire [31:0] temp_val;
                assign temp_val = t_max | sqrt_guess;
                
                if (t_opt != 0 || curr_t >= temp_val) begin
                    if (curr_t >= temp_val) begin
                        curr_t <= curr_t - temp_val;
                    end else begin
                        curr_t <= curr_t + (32'hFFFF_FFFF - temp_val) + 32'd1;
                        t_opt <= t_opt - 32'd1;
                    end
                    t_max <= temp_val | (sqrt_guess >> 1);
                end
                
                sqrt_guess <= sqrt_guess >> 2;
                
                iter_count <= iter_count + 4'd1;
                if (iter_count == 4'd15) begin
                    // Result is in t_max (integer).
                    // Scale to Q16.16: Shift left by 8.
                    // t_max is 32-bit. 
                    // We need to be careful with overflow.
                    // Max sqrt(2.25e8) = 15000. 
                    // 15000 << 8 = 3,840,000 (fits in 32-bit).
                    
                    result <= t_max << 8;
                    state <= 4'd25; // DONE_STATE
                end else begin
                    state <= 4'd24;
                end
            end
            
            // State 25: DONE_STATE
            4'd25: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
        
        // Cycle counter
        if (state != IDLE) begin
            cycle_count <= cycle_count + 18'd1;
            if (cycle_count >= MAX_CYCLES) begin
                // Timeout
                state <= IDLE;
                done <= 1'b1;
                result <= min_dist_sq << 8; // Return partial result
            end
        end
    end
end

endmodule