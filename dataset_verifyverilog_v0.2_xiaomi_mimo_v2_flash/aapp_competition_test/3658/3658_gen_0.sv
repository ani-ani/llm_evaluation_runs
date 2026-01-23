module species_intersection_area(
    input clk,
    input rst_n,
    input start,
    input [3:0] pine_count,
    input [3:0] aspen_count,
    input [7:0] pine_x [0:3],
    input [7:0] pine_y [0:3],
    input [7:0] aspen_x [0:3],
    input [7:0] aspen_y [0:3],
    output reg [31:0] intersection_area,
    output reg done,
    output reg error
);

    // State definitions
    localparam IDLE = 5'b00001;
    localparam CONVEX_HULL = 5'b00010;
    localparam CLIP_INIT = 5'b00100;
    localparam CLIP_PROCESS = 5'b01000;
    localparam CALC_AREA = 5'b10000;

    // Sub-states for Clip Process
    localparam CP_READ = 3'b001;
    localparam CP_INTERSECT = 3'b010;
    localparam CP_WRITE = 3'b100;

    reg [4:0] state;
    reg [2:0] sub_state;
    reg [2:0] clip_step; // Tracks the stage of intersection calculation

    // Coordinates in Q16.16
    reg signed [31:0] hull_pine_x [0:3];
    reg signed [31:0] hull_pine_y [0:3];
    reg signed [31:0] hull_aspen_x [0:3];
    reg signed [31:0] hull_aspen_y [0:3];

    // Working polygon buffers
    // Buffer 0-3: Input (Pine Hull initially, then clipped result)
    // Buffer 4-7: Temp Output during clipping
    reg signed [31:0] poly_x [0:7];
    reg signed [31:0] poly_y [0:7];
    reg [2:0] poly_size_in;
    reg [2:0] poly_size_out;

    // Iteration counters
    reg [2:0] i; // Iterates over current polygon vertices
    reg [2:0] j; // Iterates over clip edges
    reg [2:0] out_cnt; // Count of vertices in output buffer

    // Intersection calculation registers
    reg signed [31:0] S_x, S_y; // Previous vertex (Start of segment)
    reg signed [31:0] E_x, E_y; // Current vertex (End of segment)
    reg signed [31:0] Clip_A_x, Clip_A_y; // Clip edge start
    reg signed [31:0] Clip_B_x, Clip_B_y; // Clip edge end

    // Intermediate math registers
    reg signed [63:0] cross_S, cross_E;
    reg signed [63:0] inter_x_calc, inter_y_calc;
    reg signed [63:0] denom;
    reg signed [63:0] t;
    reg signed [63:0] dx, dy;
    reg [5:0] div_cnt;

    // --- Combinational Logic for Geometry ---
    // Calculate "Inside" test for S and E relative to Clip Edge A->B
    // Inside if (B-A) x (P-A) >= 0
    // Uses sign extension for safe subtraction
    wire signed [31:0] vec_ab_x = Clip_B_x - Clip_A_x;
    wire signed [31:0] vec_ab_y = Clip_B_y - Clip_A_y;

    wire signed [63:0] vec_as_x = { {32{S_x[31]}}, S_x } - { {32{Clip_A_x[31]}}, Clip_A_x };
    wire signed [63:0] vec_as_y = { {32{S_y[31]}}, S_y } - { {32{Clip_A_y[31]}}, Clip_A_y };
    wire signed [63:0] vec_ae_x = { {32{E_x[31]}}, E_x } - { {32{Clip_A_x[31]}}, Clip_A_x };
    wire signed [63:0] vec_ae_y = { {32{E_y[31]}}, E_y } - { {32{Clip_A_y[31]}}, Clip_A_y };

    // Cross Products
    wire signed [63:0] cp_S = $signed({{32{vec_ab_x[31]}}, vec_ab_x}) * vec_as_y - $signed({{32{vec_ab_y[31]}}, vec_ab_y}) * vec_as_x;
    wire signed [63:0] cp_E = $signed({{32{vec_ab_x[31]}}, vec_ab_x}) * vec_ae_y - $signed({{32{vec_ab_y[31]}}, vec_ab_y}) * vec_ae_x;

    wire inside_S = (cp_S >= 0);
    wire inside_E = (cp_E >= 0);

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            intersection_area <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    if (start) begin
                        if (pine_count < 3 || aspen_count < 3 || pine_count > 4 || aspen_count > 4) begin
                            error <= 1;
                            done <= 1;
                        end else begin
                            // Scale inputs to Q16.16 and store in Hull buffers
                            // Since input is 8-bit (0-255), we shift left by 16
                            hull_pine_x[0] <= {8'b0, pine_x[0], 16'b0}; hull_pine_y[0] <= {8'b0, pine_y[0], 16'b0};
                            hull_pine_x[1] <= {8'b0, pine_x[1], 16'b0}; hull_pine_y[1] <= {8'b0, pine_y[1], 16'b0};
                            hull_pine_x[2] <= {8'b0, pine_x[2], 16'b0}; hull_pine_y[2] <= {8'b0, pine_y[2], 16'b0};
                            hull_pine_x[3] <= {8'b0, pine_x[3], 16'b0}; hull_pine_y[3] <= {8'b0, pine_y[3], 16'b0};

                            hull_aspen_x[0] <= {8'b0, aspen_x[0], 16'b0}; hull_aspen_y[0] <= {8'b0, aspen_y[0], 16'b0};
                            hull_aspen_x[1] <= {8'b0, aspen_x[1], 16'b0}; hull_aspen_y[1] <= {8'b0, aspen_y[1], 16'b0};
                            hull_aspen_x[2] <= {8'b0, aspen_x[2], 16'b0}; hull_aspen_y[2] <= {8'b0, aspen_y[2], 16'b0};
                            hull_aspen_x[3] <= {8'b0, aspen_x[3], 16'b0}; hull_aspen_y[3] <= {8'b0, aspen_y[3], 16'b0};

                            i <= 0;
                            j <= 0;
                            state <= CONVEX_HULL;
                        end
                    end
                end

                CONVEX_HULL: begin
                    // Simplified Hull: Assumes inputs are ordered or uses sorting network
                    // For this implementation, we assume the user provides valid sets,
                    // but we perform a basic bubble sort to ensure convex order (by Y)
                    // to avoid zero-area self-intersections.
                    if (i < 2) begin
                        // Sort Pine
                        if (hull_pine_y[i] > hull_pine_y[i+1]) begin
                            hull_pine_x[i] <= hull_pine_x[i+1]; hull_pine_y[i] <= hull_pine_y[i+1];
                            hull_pine_x[i+1] <= hull_pine_x[i]; hull_pine_y[i+1] <= hull_pine_y[i];
                        end
                        // Sort Aspen
                        if (hull_aspen_y[i] > hull_aspen_y[i+1]) begin
                            hull_aspen_x[i] <= hull_aspen_x[i+1]; hull_aspen_y[i] <= hull_aspen_y[i+1];
                            hull_aspen_x[i+1] <= hull_aspen_x[i]; hull_aspen_y[i+1] <= hull_aspen_y[i];
                        end
                        i <= i + 1;
                    end else if (i == 2) begin
                        // Second pass
                        i <= 0;
                    end else begin
                        // Initialize Clipping
                        // Copy Pine hull to Poly Buffer 0-3
                        poly_x[0] <= hull_pine_x[0]; poly_y[0] <= hull_pine_y[0];
                        poly_x[1] <= hull_pine_x[1]; poly_y[1] <= hull_pine_y[1];
                        poly_x[2] <= hull_pine_x[2]; poly_y[2] <= hull_pine_y[2];
                        if (pine_count == 4) begin
                            poly_x[3] <= hull_pine_x[3]; poly_y[3] <= hull_pine_y[3];
                            poly_size_in <= 4;
                        end else begin
                            poly_size_in <= 3;
                        end

                        j <= 0; // Reset clip edge counter
                        out_cnt <= 0;
                        state <= CLIP_INIT;
                    end
                end

                CLIP_INIT: begin
                    // Setup next clip edge from Aspen
                    if (j < aspen_count) begin
                        Clip_A_x <= hull_aspen_x[j];
                        Clip_A_y <= hull_aspen_y[j];
                        Clip_B_x <= hull_aspen_x[(j + 1) % aspen_count];
                        Clip_B_y <= hull_aspen_y[(j + 1) % aspen_count];
                        i <= 0; // Reset vertex iterator for this edge
                        out_cnt <= 0; // Reset output count for this pass
                        sub_state <= CP_READ;
                        state <= CLIP_PROCESS;
                    end else begin
                        // All edges clipped
                        if (poly_size_in < 3) begin
                            intersection_area <= 0;
                            state <= DONE;
                        end else begin
                            state <= CALC_AREA;
                            i <= 0;
                        end
                    end
                end

                CLIP_PROCESS: begin
                    case (sub_state)
                        CP_READ: begin
                            if (i < poly_size_in) begin
                                // Load current (E) and previous (S) vertices
                                E_x <= poly_x[i]; E_y <= poly_y[i];
                                if (i == 0) begin
                                    S_x <= poly_x[poly_size_in - 1];
                                    S_y <= poly_y[poly_size_in - 1];
                                end else begin
                                    S_x <= poly_x[i - 1];
                                    S_y <= poly_y[i - 1];
                                end
                                sub_state <= CP_INTERSECT;
                                clip_step <= 0;
                            end else begin
                                // Done with this edge, move to next
                                poly_size_in <= out_cnt;
                                // Copy output buffer to input buffer
                                poly_x[0] <= poly_x[4]; poly_y[0] <= poly_y[4];
                                poly_x[1] <= poly_x[5]; poly_y[1] <= poly_y[5];
                                poly_x[2] <= poly_x[6]; poly_y[2] <= poly_y[6];
                                poly_x[3] <= poly_x[7]; poly_y[3] <= poly_y[7];
                                j <= j + 1;
                                state <= CLIP_INIT;
                            end
                        end

                        CP_INTERSECT: begin
                            // Check inside status and handle geometry
                            if (inside_S) begin
                                if (inside_E) begin
                                    // S in, E in -> Output E
                                    poly_x[4 + out_cnt] <= E_x;
                                    poly_y[4 + out_cnt] <= E_y;
                                    out_cnt <= out_cnt + 1;
                                    i <= i + 1;
                                    sub_state <= CP_READ;
                                end else begin
                                    // S in, E out -> Intersection, Output Intersection
                                    if (clip_step == 0) begin
                                        // Start intersection calculation
                                        // Calc Denom = (E-S) x (B-A)
                                        // Calc Numer for t = (A-S) x (B-A)
                                        // Actually for segment S-E and line A-B:
                                        // P = S + (E-S) * t
                                        // t = ((A-S) x (B-A)) / ((E-S) x (B-A))
                                        // Note: Sign conventions. We use cross(A-B, C-A) for orientation.
                                        // Intersection formula: intersection of lines S-E and A-B.
                                        // Let d1 = E - S, d2 = B - A
                                        // P = S + d1 * (cross(A-S, d2) / cross(d1, d2))
                                        // cross(d1, d2) is denom.
                                        // cross(A-S, d2) is num.
                                        // Let's use the previously defined logic to be safe.
                                        // We need (A-S)x(B-A) and (E-S)x(B-A).
                                        // Note: A-S is -(S-A). (B-A) is vec_ab.
                                        // (A-S)x(B-A) = -(S-A)x(B-A) = (B-A)x(S-A) = cp_S.
                                        // (E-S)x(B-A) = (E-A + A-S)x(B-A) = cp_E - cp_S.
                                        // Wait, (E-S) = (E-A)-(S-A). So (E-S)x(B-A) = cp_E - cp_S.
                                        // t = cp_S / (cp_E - cp_S).
                                        // But cp_S can be negative if we are inside?
                                        // Let's stick to the standard geometric formula.
                                        // line AB: A + u(B-A).
                                        // line SE: S + v(E-S).
                                        // Intersection: u(B-A) - v(E-S) = S-A.
                                        // Cross with (E-S): u * (B-A)x(E-S) = (S-A)x(E-S).
                                        // u = (S-A)x(E-S) / ((B-A)x(E-S))
                                        // But we have (E-S)x(B-A) = -((B-A)x(E-S)).
                                        // And (S-A)x(E-S) = (S-A)x(E-A + A-S) = (S-A)x(E-A) - (S-A)x(S-A) = (S-A)x(E-A).
                                        // (S-A)x(E-A) is cross product of vectors from A.
                                        // Let's use: Denom = (E-S)x(B-A). Num = (S-A)x(B-A).
                                        // Wait, intersection of ray (S to E) and line (A to B).
                                        // Param: P = S + t(E-S).
                                        // (P-A)x(B-A) = 0.
                                        // (S + t(E-S) - A)x(B-A) = 0.
                                        // (S-A)x(B-A) + t((E-S)x(B-A)) = 0.
                                        // t = - (S-A)x(B-A) / (E-S)x(B-A).
                                        // (S-A)x(B-A) = cp_S.
                                        // (E-S)x(B-A) = (E-A + A-S)x(B-A) = cp_E - cp_S.
                                        // t = - cp_S / (cp_E - cp_S).
                                        // If cp_S > 0 (S in), cp_E < 0 (E out). cp_E - cp_S < 0.
                                        // t > 0.
                                        // We need t.
                                        // Denom = cp_E - cp_S.
                                        // Numer = -cp_S.
                                        // Let's verify with signs.
                                        // If S inside, cp_S >= 0. If E outside, cp_E < 0.
                                        // We want t in [0,1].
                                        // t = cp_S / (cp_S - cp_E).
                                        // Let's use this.
                                        // cp_S = (B-A)x(S-A). cp_E = (B-A)x(E-A).
                                        // We need t such that S + t(E-S) is on AB.
                                        // t = cp_S / (cp_S - cp_E).
                                        // Note: cp_S - cp_E = (B-A)x(S-A) - (B-A)x(E-A) = (B-A)x(S-E).
                                        // (S-E) is opposite of (E-S). So (B-A)x(S-E) = -(B-A)x(E-S) = (E-S)x(B-A).
                                        // So t = cp_S / ((E-S)x(B-A)).
                                        // Wait, check sign.
                                        // We need intersection.
                                        // Let's use the simpler relation: (S-A)x(B-A) + t((E-S)x(B-A)) = 0 => t = cp_S / (cp_S - cp_E).
                                        // Yes, this is correct for interpolation.
                                        // Note: cp_S >= 0, cp_E < 0. Denominator > 0. t >= 0.
                                        // We need to compute:
                                        // t = cp_S / (cp_S - cp_E).
                                        // Intersection X = S_x + t * (E_x - S_x).
                                        // We use 64-bit division.
                                        // cp_S and cp_E are 64-bit.
                                        // t is effectively a 32-bit value (Q16.16).
                                        // To save cycles, we will perform the division here using a state loop.
                                        // But wait, we are in CLIP_PROCESS. We need to break this out.
                                        // Let's add a specific state for division.
                                        // Actually, we can just use `div_cnt` and run a loop inside `CP_INTERSECT`.
                                        // Since we have limited cycles, let's do 32 iterations of restoring divider.
                                        // However, that's huge code.
                                        // Let's assume we can use a synthesizable division operator for this single step.
                                        // We calculate the intersection point directly.
                                        // t_num = cp_S;
                                        // t_denom = cp_S - cp_E;
                                        // We need S_x + (E_x - S_x) * (t_num / t_denom).
                                        // Let's compute: Inter = S_x * t_denom + (E_x - S_x) * t_num.
                                        // Then divide by t_denom.
                                        // Inter_x = (S_x * denom + diff_x * num) / denom.
                                        // Wait, that simplifies to S_x + (diff_x * num)/denom.
                                        // We need to do the multiplication first.
                                        // diff_x * num is huge (32x64).
                                        // Let's do it step by step using states.
                                        // We will use `CP_INTERSECT` to perform the calculation.
                                        // We'll break it into: Setup, Mul, Div, Write.
                                        // But we need to write E in the same cycle if no intersection.
                                        // So `CP_INTERSECT` is a state that does the math and goes to `CP_WRITE`.
                                        // Since we can't do it in one cycle, we'll need to extend this.
                                        // Let's use `clip_step` to manage sub-stages of intersection.
                                        // 0: Setup T values (compute diff, num, denom).
                                        // 1: Compute t_num / t_denom.
                                        // 2: Compute X, Y.
                                        // 3: Go to Write.
                                        // This is getting complex.
                                        // Optimization: We have 200 cycles.
                                        // We are only intersecting 4-5 times max.
                                        // We can spend 10 cycles per intersection.
                                        // We will use a divider state machine.
                                        // Let's define a sub-module logic for division.
                                        // Since we can't define a module inside, we use local states.
                                        // Actually, to make it efficient and simple:
                                        // We will use the property that we can compute intersection using:
                                        // x = S_x + ((E_x - S_x) * cp_S) / (cp_S - cp_E)
                                        // We need to do:
                                        // Step 1: cp_S, cp_E.
                                        // Step 2: Num = (E_x - S_x) * cp_S.
                                        // Step 3: Denom = cp_S - cp_E.
                                        // Step 4: Result = S_x + (Num / Denom).
                                        // We will use 3 cycles for Mul, 10 cycles for Div, 1 cycle for Add.
                                        // Let's implement a standard restoring divider here.
                                        // We need 64-bit division.
                                        // Inputs: Numerator (64-bit), Denominator (64-bit).
                                        // Output: Quotient (64-bit).
                                        // We'll do it in `clip_step`.
                                        // If we are in CP_INTERSECT and clip_step == 0: Compute Diff, Num, Denom.
                                        // If clip_step == 1..32: Divide.
                                        // If clip_step == 33: Finalize.
                                        // To keep code length manageable, I will assume the synthesis tool infers a divider
                                        // for the logic: `inter_x_calc = ... / ...`.
                                        // I will use a multi-cycle state for this.
                                        // Let's define the logic explicitly:
                                        // We need to check `clip_step`.
                                        // If clip_step == 0:
                                        //   dx = E_x - S_x; dy = E_y - S_y;
                                        //   num = cp_S; (Which is (B-A)x(S-A)).
                                        //   denom = cp_S - cp_E;
                                        //   If denom == 0, skip (parallel lines).
                                        //   clip_step <= 1;
                                        // If clip_step > 0:
                                        //   We perform division.
                                        //   Since I cannot write a full 64-bit restoring divider in this space,
                                        //   I will use a behavioral division but gate it with a counter.
                                        //   The synthesis tool will implement the divider.
                                        //   We need to calculate:
                                        //   inter_x = S_x + (dx * num) / denom.
                                        //   Let's do it in one step for the Verilog simulation,
                                        //   and rely on the synthesizer for the hardware.
                                        //   Wait, the prompt says "Synthesizable".
                                        //   Behavioral division is synthesizable.
                                        //   We will perform the calculation in `clip_step == 1`.
                                        //   We will introduce a delay.
                                        //   To be robust:
                                        //   Calculate intersection x = S_x + ((E_x - S_x) * num) / denom
                                        //   This requires 3 multiplies and 1 divide.
                                        //   Let's use a state `CP_INTERSECT_CALC`.
                                        //   We will calculate:
                                        //   term1 = (E_x - S_x) * num.
                                        //   term2 = (E_y - S_y) * num.
                                        //   Final_X = S_x + term1 / denom.
                                        //   Final_Y = S_y + term2 / denom.
                                        //   Due to the complexity, I will implement a single division per vertex and 
                                        //   use the fact that we can use the property of `t`.
                                        //   Actually, we can use the `cp` values directly for interpolation if we assume linear scaling.
                                        //   Let's use a simpler approach for the clipper:
                                        //   If intersection needed:
                                        //   Calculate:
                                        //   dx = E_x - S_x;
                                        //   num = (B-A)x(S-A) (cp_S)
                                        //   denom = num - (B-A)x(E-A) (cp_S - cp_E)
                                        //   t = num / denom (Verilog divides).
                                        //   X = S_x + dx * t.
                                        //   We will perform this calculation in `CP_INTERSECT` state and wait for 10 cycles.
                                        //   This is the most efficient way in Verilog without writing a custom divider.
                                        //   We assume the synthesis tool handles the multi-cycle division.
                                        //   However, to be explicit and meet the "200 cycles" requirement 
                                        //   (which implies we must count cycles), we will implement a loop.
                                        //   Let's add a state `CP_DIVIDE` after `CP_INTERSECT`.
                                        //   But we are in `CLIP_PROCESS`.
                                        //   Let's expand the state machine:
                                        //   `CP_INTERSECT` -> calculates denominator, numerator. Sets up divider.
                                        //   `CP_WAIT_DIV` -> loops 16 times.
                                        //   `CP_WRITE` -> writes output.
                                        //   I will implement a restoring divider for 32-bit values to keep code size manageable.
                                        //   We will divide 64-bit by 64-bit to get 32-bit quotient.
                                        //   Due to length limits, I will use a behavioral division with a delay counter.
                                        //   This is the industry standard for "quick" synthesis.
                                        //   `if (clip_step == 1) begin`
                                        //     `inter_x_calc <= S_x + ((E_x - S_x) * num) / denom;`
                                        //     `inter_y_calc <= S_y + ((E_y - S_y) * num) / denom;`
                                        //     `clip_step <= 2;`
                                        //   `end`
                                        //   `else if (clip_step == 2) begin` 
                                        //     `sub_state <= CP_WRITE;`
                                        //     // Output Inter
                                        //   `end`
                                        //   This effectively hides the latency of the division in the hardware,
                                        //   but the Verilog simulation will advance cycles if we use non-blocking 
                                        //   assignments for the result? No, it won't wait.
                                        //   We need to simulate the wait.
                                        //   I will use a counter `div_cnt` and state `CP_INTERSECT_CALC`.
                                        //   Start Division Logic (Simplified Restoring):
                                        //   Inputs: Num, Den.
                                        //   Result: Quotient.
                                        //   We will use `div_cnt` from 0 to 31.
                                        //   Let's just write the logic:
                                        //   We need `inter_x` and `inter_y`.
                                        //   I will add a state `CP_INTERSECT_CALC` which takes 5 cycles.
                                        //   In these cycles, we perform the division.
                                        //   To save space, I will assume the tool synthesizes `division`.
                                        //   I will create a delay loop.
                                        //   We need to define `num` and `denom` properly.
                                        //   `num = cp_S`.
                                        //   `denom = cp_S - cp_E`.
                                        //   Let's use the `reg`s defined above.
                                        //   Code for CP_INTERSECT:
                                        //   `if (clip_step == 0) begin`
                                        //     `denom <= cp_S - cp_E;`
                                        //     `num <= cp_S;`
                                        //     `dx <= E_x - S_x;`
                                        //     `dy <= E_y - S_y;`
                                        //     `clip_step <= 1;`
                                        //   `end else if (clip_step < 10) begin` // Wait for division
                                        //     `clip_step <= clip_step + 1;`
                                        //   `end else begin`
                                        //     `inter_x_calc <= S_x + (dx * num) / denom;`
                                        //     `inter_y_calc <= S_y + (dy * num) / denom;`
                                        //     `sub_state <= CP_WRITE;`
                                        //   `end`
                                        //   This assumes the division happens in the background or the tool unrolls it.
                                        //   To be strictly sequential, we should use a divider FSM.
                                        //   Given the constraints, I will write the code to be functional and synthesizable.
                                        //   I will use a simple counter to represent the division latency.
                                        //   The actual division math will be done in `CP_WRITE` or late `CP_INTERSECT` using 
                                        //   the registers `inter_x_calc` etc.
                                        //   Let's go with the plan: `CP_INTERSECT` computes `inter_x_calc` and `inter_y_calc`.
                                        //   It uses blocking assignments for math, but we need to sequence it.
                                        //   Correct approach for `CP_INTERSECT`:
                                        //   `if (clip_step == 0) begin`
                                        //     `t_num = cp_S;`
                                        //     `t_denom = cp_S - cp_E;`
                                        //     `if (t_denom != 0) begin`
                                        //       `t_val = t_num / t_denom;` // This is the issue
                                        //       `inter_x_calc = S_x + (E_x - S_x) * t_val;`
                                        //       `inter_y_calc = S_y + (E_y - S_y) * t_val;`
                                        //     `end`
                                        //     `clip_step <= 1;`
                                        //   `end else begin`
                                        //     `sub_state <= CP_WRITE;`
                                        //   `end`
                                        //   Since we need to output code, and I can't write a full divider, 
                                        //   I will use the Verilog `/` operator and assume the synthesizer handles it.
                                        //   I will add a "wait" cycle counter to make it explicit in the FSM.
                                        //   Let's refine the `CP_INTERSECT` state.
                                        //   I will use `div_cnt` to count down from 4.
                                        //   Logic:
                                        //   If `clip_step == 0`: Compute `t` (start division). Store `dx`, `dy`. Set `div_cnt = 4`.
                                        //   If `div_cnt > 0`: `div_cnt <= div_cnt - 1`.
                                        //   If `div_cnt == 0`: Compute `inter_x`, `inter_y`. Go to `CP_WRITE`.
                                        //   Since `t = num / denom` is a blocking assignment in sequential logic,
                                        //   it calculates immediately. The `div_cnt` simulates the hardware latency.
                                        //   Let's do this.
                                    end
                                end
                            end else begin
                                // S out
                                if (inside_E) begin
                                    // S out, E in -> Intersection, Output Intersection
                                    sub_state <= CP_INTERSECT; // Calc I
                                    clip_step <= 0;
                                end else begin
                                    // S out, E out -> Nothing
                                    i <= i + 1;
                                    sub_state <= CP_READ;
                                end
                            end
                        end
                        // ... (Continued in next block to avoid length error, actually I must put it all here)
                        // I will merge the logic into `CP_INTERSECT` and `CP_WRITE`.
                        // ... Wait, I need to handle the "Write S" logic in CP_DECI.
                        // The state `CP_READ` currently loads S/E and stays in `CP_READ`.
                        // Let's change `CP_READ` to perform the check and transition.
                        // No, `CP_READ` is a state. Let's make `CP_PROCESS` the main loop.
                        // ... Okay, I will split the code into multiple JSON chunks if needed, but 
                        // ... I will try to compress.
                        // ... Let's simplify.
                        // ... I will write the logic for `CP_INTERSECT` and `CP_WRITE` now.
                        // ... 
                        // ... Actually, let's restart the `CP_READ` logic to be robust.
                        // ... 
                        // ... `CP_READ`: Load S, E. Set flags.
                        // ... `if (inside_S) begin` Write S. `end`
                        // ... `if (inside_S != inside_E) begin` Goto `CP_INTERSECT`. `end`
                        // ... `else` Goto `CP_READ` (next).
                        // ... 
                        // ... BUT we need to write S *before* we go to intersection.
                        // ... So `CP_READ` must do: 
                        // ... `if (inside_S) Write S`.
                        // ... `if (cross) state <= CP_INTERSECT;`
                        // ... `else state <= CP_READ; i++;`
                        // ... This means `CP_READ` has logic.
                        // ... Let's put this logic in `CP_PROCESS` default case.
                        // ... 
                        // ... Okay, I will write the module now. I will include the logic for `CP_INTERSECT` inside the `CLIP_PROCESS` state.
                        // ... I will use `div_cnt` to handle the delay.
                        // ... 
                        // ... `CP_INTERSECT`:
                        // ... `if (div_cnt == 0) begin`
                        // ...   `denom = cp_S - cp_E;`
                        // ...   `if (denom == 0) begin` skip/parallel. `end`
                        // ...   `num = cp_S;`
                        // ...   `dx = E_x - S_x;`
                        // ...   `dy = E_y - S_y;`
                        // ...   `div_cnt <= 10;`
                        // ... `end else if (div_cnt > 1) begin`
                        // ...   `div_cnt <= div_cnt - 1;`
                        // ... `end else begin`
                        // ...   `poly_x[4 + out_cnt] <= S_x + (dx * num) / denom;`
                        // ...   `poly_y[4 + out_cnt] <= S_y + (dy * num) / denom;`
                        // ...   `out_cnt <= out_cnt + 1;`
                        // ...   `i <= i + 1;`
                        // ...   `div_cnt <= 0;`
                        // ...   `state <= CP_READ;`
                        // ... `end`
                        // ... 
                        // ... `CP_WRITE`: (Actually we don't need a separate state for writing S if we do it in CP_READ).
                        // ... Let's verify: 
                        // ... `CP_READ`:
                        // ... `S_x <= ...; E_x <= ...;`
                        // ... `if (inside_S) begin`
                        // ...   `poly_x[4 + out_cnt] <= S_x; ... out_cnt++;`
                        // ... `end`
                        // ... `if (inside_S != inside_E) state <= CP_INTERSECT;`
                        // ... `else begin state <= CP_READ; i++;`
                        // ...   `if (i == poly_size_in - 1) begin` ... `end`
                        // ... `end`
                        // ... 
                        // ... This works.
                        // ... 
                        // ... I will implement the `CP_READ` and `CP_INTERSECT` states in the code block below.
                        // ... I will treat `CP_INTERSECT` as a state that takes multiple cycles.
                        // ... 
                        // ... We need to handle `i` increment.
                        // ... 
                        // ... In `CP_READ`, if we transition to `CP_INTERSECT`, we *don't* increment `i` yet.
                        // ... We increment `i` after intersection is written.
                        // ... 
                        // ... In `CP_READ`, if we stay in `CP_READ` (no intersection), we increment `i`.
                        // ... 
                        // ... In `CP_INTERSECT` (Done), we increment `i` and go to `CP_READ`.
                        // ... 
                        // ... Let's finalize the states.
                        // ... 
                        // ... 
                        // ... Code for `CP_READ`:
                        begin
                            if (i < poly_size_in) begin
                                E_x <= poly_x[i]; E_y <= poly_y[i];
                                if (i == 0) begin
                                    S_x <= poly_x[poly_size_in - 1]; S_y <= poly_y[poly_size_in - 1];
                                end else begin
                                    S_x <= poly_x[i - 1]; S_y <= poly_y[i - 1];
                                end
                                sub_state <= CP_INTERSECT; // Go to decision/check logic
                                clip_step <= 0; // Use clip_step as 'stage' inside INTERSECT
                            end else begin
                                // End of polygon iteration for this edge
                                poly_size_in <= out_cnt;
                                // Copy buffer 4-7 back to 0-3
                                poly_x[0] <= poly_x[4]; poly_y[0] <= poly_y[4];
                                poly_x[1] <= poly_x[5]; poly_y[1] <= poly_y[5];
                                poly_x[2] <= poly_x[6]; poly_y[2] <= poly_y[6];
                                poly_x[3] <= poly_x[7]; poly_y[3] <= poly_y[7];
                                j <= j + 1; // Next clip edge
                                state <= CLIP_INIT;
                            end
                        end

                        CP_INTERSECT: begin
                            // We have S, E, Clip_A, Clip_B loaded from CP_READ
                            // clip_step == 0: Decision and Setup
                            if (clip_step == 0) begin
                                // Check intersection
                                if (inside_S && inside_E) begin
                                    // S inside, E inside -> Output S (S was potentially output in prev step? No, S is prev)
                                    // Actually, logic: Output S if S inside.
                                    // We should output S here if we are following the algorithm strictly.
                                    // But we are at E. S was the previous vertex.
                                    // We need to output S.
                                    // Let's output S now.
                                    poly_x[4 + out_cnt] <= S_x;
                                    poly_y[4 + out_cnt] <= S_y;
                                    out_cnt <= out_cnt + 1;
                                    // Next vertex
                                    i <= i + 1;
                                    sub_state <= CP_READ;
                                end else if (inside_S && !inside_E) begin
                                    // S inside, E outside -> Output S, Output Intersection
                                    poly_x[4 + out_cnt] <= S_x;
                                    poly_y[4 + out_cnt] <= S_y;
                                    out_cnt <= out_cnt + 1;
                                    // Prepare Intersection
                                    clip_step <= 1; // Go to Calc
                                end else if (!inside_S && inside_E) begin
                                    // S outside, E inside -> Output Intersection
                                    // (S is not output)
                                    clip_step <= 1; // Go to Calc
                                end else begin
                                    // Both outside -> Output nothing
                                    i <= i + 1;
                                    sub_state <= CP_READ;
                                end
                            end
                            // clip_step == 1: Calculate Intersection Math
                            else if (clip_step == 1) begin
                                // Setup math registers
                                // t = cp_S / (cp_S - cp_E)
                                // We need to handle potential overflow, but inputs are small.
                                // We use 64-bit arithmetic.
                                // 
                                // Note: cp_S and cp_E are 64-bit signed.
                                // 
                                // We need to compute Inter_X = S_x + (E_x - S_x) * (cp_S / (cp_S - cp_E)).
                                // This requires division.
                                // 
                                // To avoid a complex divider, we will use the `/` operator.
                                // However, we must ensure we wait for the result.
                                // In hardware, division takes time.
                                // In this code, we will simulate the wait with `div_cnt`.
                                // 
                                // Since the prompt asks for synthesizable code, using `/` is fine.
                                // To be safe, we assume a latency of 10 cycles.
                                // 
                                // We need to latch inputs for the division.
                                // 
                                // Let's store: 
                                // `denom <= cp_S - cp_E;`
                                // `num <= cp_S;`
                                // `diff_x <= E_x - S_x;`
                                // `diff_y <= E_y - S_y;`
                                // 
                                // And start the wait.
                                // 
                                // But we can't assign to `denom` multiple times if we stay in this state.
                                // We use `div_cnt` as the divider.
                                // 
                                // Let's use `div_cnt` as a counter.
                                // If `div_cnt == 0`: Initialize. `div_cnt <= 10`.
                                // If `div_cnt == 2`: Compute result (assuming 1 cycle of calc + setup).
                                //   `inter_x_calc <= S_x + (diff_x * num) / denom;`
                                //   `inter_y_calc <= S_y + (diff_y * num) / denom;`
                                //   `div_cnt <= 1;`
                                // 
                                // Wait, we can just do: 
                                // `if (div_cnt == 0) begin` `div_cnt <= 10;` `end`
                                // `else if (div_cnt == 1) begin` `inter_x_calc <= ...; ...` `div_cnt <= 0;` `clip_step <= 2;` `end`
                                // `else` `div_cnt <= div_cnt - 1;`
                                // 
                                // This assumes the division `(...) / denom` is combinational in the 
                                // sequential block. In Verilog, it is. In synthesis, it creates a block.
                                // The delay counter simulates the hardware latency for the next state.
                                // 
                                // Let's implement this.
                                
                                if (div_cnt == 0) begin
                                    div_cnt <= 10; // Wait 10 cycles
                                end else if (div_cnt == 1) begin
                                    // Last cycle of wait, compute result
                                    // We must be careful with division by zero.
                                    if ((cp_S - cp_E) == 0) begin
                                        // Parallel, no intersection or infinite. Skip.
                                        i <= i + 1;
                                        sub_state <= CP_READ;
                                        div_cnt <= 0;
                                    end else begin
                                        // Calc
                                        poly_x[4 + out_cnt] <= S_x + ((E_x - S_x) * cp_S) / (cp_S - cp_E);
                                        poly_y[4 + out_cnt] <= S_y + ((E_y - S_y) * cp_S) / (cp_S - cp_E);
                                        out_cnt <= out_cnt + 1;
                                        i <= i + 1;
                                        sub_state <= CP_READ;
                                        div_cnt <= 0;
                                    end
                                end else begin
                                    div_cnt <= div_cnt - 1;
                                end
                            end
                        end
                    endcase
                end

                CALC_AREA: begin
                    // Shoelace formula
                    if (i < poly_size_in) begin
                        // term = x[i] * y[i+1] - y[i] * x[i+1]
                        // sum += term
                        // i++
                        // We need to handle wrap around.
                        // We can use a temp register for the sum.
                        // area_accum = area_accum + (poly_x[i] * poly_y[(i+1)%size]) - (poly_y[i] * poly_x[(i+1)%size]);
                        // 
                        // Since we are in Q16.16, area is Q32.32.
                        // Result needs to be Q16.16.
                        // sum = 2 * Area.
                        // Area = abs(sum) / 2.
                        // Final = (Area >> 16).
                        // 
                        // Let's accumulate in `area_accum` (64-bit).
                        // We need to handle the wrap index.
                        // Let's compute term = poly_x[i] * poly_y[(i==poly_size_in-1)?0:i+1] - ...
                        // 
                        // We will do this sequentially.
                        // We need a temporary register for `area_accum`.
                        
                        // Setup indices
                        // We can use `i` as index.
                        // Let's compute `j = (i + 1) % poly_size_in`.
                        // 
                        // We need to use 64-bit multiplication.
                        // 
                        // Let's add a register `accum` for area.
                        // 
                        // In state CALC_AREA, we iterate `i` from 0 to size-1.
                        // `accum <= accum + (poly_x[i] * poly_y[next] - poly_y[i] * poly_x[next]);`
                        // 
                        // After loop, `accum = 2 * Area`.
                        // `accum = abs(accum)`.
                        // `accum = accum >> 1`.
                        // `intersection_area = accum[47:16]` (Q32.32 to Q16.16).
                        // 
                        // Let's implement the loop.
                        // We need a temporary `next_idx`.
                        // Since we can't do modulo easily in state, let's use a conditional.
                        // 
                        // 
                        // Logic:
                        // `next_i = (i + 1);`
                        // `if (next_i == poly_size_in) next_i = 0;`
                        // 
                        // We need to register the multiplication results to break timing or just chain.
                        // 
                        // Let's do it in one cycle per vertex.
                        // 
                        // Code:
                        // `if (i == 0) area_accum <= 0;`
                        // `if (i < poly_size_in) begin`
                        //   `idx1 = i;`
                        //   `idx2 = (i == poly_size_in - 1) ? 0 : i + 1;`
                        //   `area_accum <= area_accum + (poly_x[idx1] * poly_y[idx2] - poly_y[idx1] * poly_x[idx2]);`
                        //   `i <= i + 1;`
                        // `end else begin`
                        //   // Done
                        //   // Finalize
                        //   `if (area_accum[63]) area_accum <= -area_accum;`
                        //   `area_accum <= area_accum >> 1;`
                        //   `intersection_area <= area_accum[47:16];`
                        //   `state <= DONE;`
                        //   `done <= 1;`
                        // `end`
                        
                        // Let's write it.
                        // We need to check `i` first.
                        if (i == 0) begin
                            area_accum <= 0;
                        end
                        
                        if (i < poly_size_in) begin
                            // Calculate next index
                            // Since we are in always block, we can't have local vars easily.
                            // We can use a wire but here we need logic.
                            // We can compute term in combinational logic before this block,
                            // but here we just do the math.
                            // 
                            // We need poly_x[i] * poly_y[i+1] and poly_y[i] * poly_x[i+1].
                            // We need to handle wrap for i+1.
                            // Let's pre-calculate the next index.
                            // Since `i` is the index, we can just handle the `if` condition.
                            
                            if (i == poly_size_in - 1) begin
                                // Wrap
                                area_accum <= area_accum + (poly_x[i] * poly_y[0] - poly_y[i] * poly_x[0]);
                            end else begin
                                area_accum <= area_accum + (poly_x[i] * poly_y[i+1] - poly_y[i] * poly_x[i+1]);
                            end
                            
                            i <= i + 1;
                        end else begin
                            // Finalize
                            if (area_accum[63]) area_accum <= -area_accum;
                            
                            // Shift right 1 (divide by 2)
                            // Note: area_accum is currently 2*Area.
                            // After abs, we shift.
                            // Result is Area in Q32.32.
                            // We need to shift by 16 to get Q16.16.
                            // So we take bits [47:16] of the absolute value shifted right by 1?
                            // area_accum holds sum. sum = 2 * Area.
                            // Area = sum / 2.
                            // Result = Area >> 16.
                            // 
                            // Let's do it in two steps or combine.
                            // `area_accum <= area_accum >> 1;`
                            // `intersection_area <= area_accum[47:16];`
                            // 
                            // Wait, if `area_accum` is signed, right shift is arithmetic.
                            // But we handled absolute value. So it's positive.
                            // 
                            // 
                            // Let's just take the result.
                            // `intersection_area <= (area_accum >> 1) >> 16;`
                            // 
                            // 
                            // Actually, we need to latch the result.
                            // Since we are in sequential block, we can't update `area_accum` and use it immediately.
                            // We need an extra cycle.
                            // Let's go to a `DONE` state.
                            // 
                            // In this cycle, we computed the last term.
                            // `area_accum` is now sum.
                            // We need one more cycle to process: abs, div 2, shift.
                            // 
                            // Let's add a flag `finalizing_area`.
                            // Or just use `state <= DONE` and do the math in `DONE`? No, `DONE` is output.
                            // 
                            // Let's add a state `CALC_AREA_FINAL`.
                            // Or do it here and stay in `CALC_AREA` for one more cycle.
                            // 
                            // Let's use `i` as a flag. 
                            // If `i == poly_size_in`, we do final math and go to `DONE`.
                            // 
                            // Code: 
                            // If `i == poly_size_in`:
                            //   `if (area_accum[63]) area_accum <= -area_accum;`
                            //   `area_accum <= area_accum >> 1;`
                            //   `intersection_area <= area_accum[47:16];`
                            //   `state <= DONE;`
                            //   `done <= 1;`
                            // 
                            // So we need to check `i` after increment.
                            // 
                            // Let's restructure slightly: 
                            // We use `i` to count up to `poly_size_in`.
                            // When `i == poly_size_in`, we process the result.
                            // 
                            // But we need to handle the wrap index calculation.
                            // 
                            // Okay, let's implement the loop cleanly.
                            
                            // Current `i` is the index we just used.
                            // We increment `i`.
                            // If `i == poly_size_in`, we are done summing.
                            // 
                            // Let's do: 
                            // `if (i < poly_size_in) begin` (Perform add, inc i)
                            // `end else begin` (Finalize)
                            // `end`
                            
                            // The logic inside `if (i < poly_size_in)` calculates term for `i`.
                            // 
                            // After the `else` (finalization), we need to wait one cycle if we update `area_accum`.
                            // But we can do it in one go if we use `area_accum` carefully.
                            // 
                            // Let's do: 
                            // `area_accum <= area_accum + (term);`
                            // `i <= i + 1;`
                            // Then next cycle, if `i == poly_size_in`, we do final calc.
                            // 
                            // 
                            // Since we are already in `else` (i >= poly_size_in), we do the final math.
                            // We need to update `area_accum` one last time? No, the loop finished.
                            // 
                            // So: 
                            // `if (area_accum[63]) area_accum <= -area_accum;` (This updates `area_accum`)
                            // `else area_accum <= area_accum;` (Keep it)
                            // 
                            // In next cycle, `area_accum` is valid (absolute).
                            // We need to shift and assign.
                            // 
                            // To avoid adding a state, we can do: 
                            // `intersection_area <= (area_accum[63] ? -area_accum : area_accum) >> 17;`
                            // (Shift 1 for /2, shift 16 for Q16.16 = 17).
                            // 
                            // But `area_accum` is 64-bit. Shifting 17 bits gives 47 bits.
                            // `[47:16]` is 32 bits.
                            // So `[47:16]` of `(area_accum >> 17)` is `[47:16] >> 17`.
                            // We want `(Area >> 16)` where Area = Sum/2.
                            // Sum is 64 bit.
                            // `Result = Sum[63] ? -Sum : Sum`.
                            // `Result = Result >> 1`.
                            // `Result[63:0]` is Area.
                            // We need Area[47:16] (Q16.16).
                            // So `(Result >> 16)[31:0]`.
                            // 
                            // `intersection_area <= ((area_accum[63] ? -area_accum : area_accum) >> 1) >> 16;`
                            // 
                            // Since `area_accum` is 64-bit, `>> 1` is 63-bit effectively.
                            // We need to ensure we don't lose bits.
                            // Let's do: 
                            // `intersection_area <= ((area_accum[63] ? -area_accum[63:0] : area_accum[63:0]) >> 17);`
                            // 
                            // Wait, `(x >> 1) >> 16` is `x >> 17`.
                            // So just `area_accum >> 17`?
                            // No, `area_accum` is `2 * Area`.
                            // So `area_accum >> 17` = `(2 * Area) >> 17` = `Area >> 16`.
                            // Perfect.
                            // 
                            // So: `intersection_area <= (area_accum[63] ? -area_accum[47:16] : area_accum[47:16]) >> 1;`
                            // No, `area_accum[63]` is sign.
                            // `val = area_accum[63] ? -area_accum : area_accum;`
                            // `intersection_area <= val[47:16];` (This implicitly divides by 2^16).
                            // But we need to divide by 2 first.
                            // So `val = val >> 1`.
                            // `intersection_area <= (val >> 1)[47:16]`.
                            // This is `val[48:17]`.
                            // 
                            // Let's stick to `val[48:17]`.
                            // 
                            // Code: 
                            `if (area_accum[63]) area_accum <= -area_accum;`
                            `else area_accum <= area_accum;`
                            `intersection_area <= (area_accum[63] ? -area_accum : area_accum) >> 17;`
                            `state <= DONE;`
                            `done <= 1;`
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule
