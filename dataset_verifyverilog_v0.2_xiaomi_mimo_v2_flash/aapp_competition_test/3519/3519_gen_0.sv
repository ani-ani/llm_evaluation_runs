module memory_game_expected_turns(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [31:0] result,
    output reg done
);

    // Fixed-point constants
    // Q16.16 format: Value * 65536
    localparam ONE = 32'h00010000;
    localparam TWO = 32'h00020000;

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_U = 3'b001;
    localparam ITERATE_V = 3'b010;
    localparam CALC_TRANSITION = 3'b011;
    localparam UPDATE_RESULT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [4:0] u;          // Current u (unmatched pairs)
    reg [4:0] v;          // Current v (known singles)
    reg [4:0] max_u;      // N stored
    reg [31:0] E [0:31][0:62]; // DP Table: E[u][v]. 
                               // u: 0..16, v: 0..32 (conservative bound, usually 2u)
                               // Actually v can be up to 2u, but to handle edge cases 32 is safe.

    // Multiplication/Division Registers
    reg [31:0] mul_a, mul_b;
    wire [63:0] mul_res = mul_a * mul_b; // Full product
    reg [31:0] div_num, div_den;
    wire [31:0] div_quotient; // Combinational divider approximation

    // Temporary storage for calculations
    reg [31:0] term1, term2;
    reg [31:0] temp_E; // Holds value of E(u', v') during transition lookup

    // Control flags
    reg computation_done;

    // --- Divider Module (Combinational Approximation) ---
    // Implements: result = (num * ONE) / den
    // Uses a simple iterative restoration algorithm or just relies on synthesis tool
    // provided DSP logic for division. Since explicit division is required but simplified,
    // we define a combinational block here. 
    // For robust Verilog without DSP inference assumptions, we use a pre-computed LUT approach
    // as suggested in the prompt, but the LUT logic is inside the FSM.
    // However, for generic 32-bit division, we need a logic block. 
    // Given the constraint "Use pre-calculated lookup table", we implement that logic.

    // Pre-calculated constants for Q16.16
    // 1/u for u=1..16
    function [31:0] get_inv_u;
        input [4:0] u_val;
        begin
            case(u_val)
                5'd1:  get_inv_u = 32'h00010000; // 1.0
                5'd2:  get_inv_u = 32'h00008000; // 0.5
                5'd3:  get_inv_u = 32'h00005555; // ~0.3333
                5'd4:  get_inv_u = 32'h00004000; // 0.25
                5'd5:  get_inv_u = 32'h00003333; // 0.2
                5'd6:  get_inv_u = 32'h00002AAA; // ~0.1666
                5'd7:  get_inv_u = 32'h00002492; // ~0.1428
                5'd8:  get_inv_u = 32'h00002000; // 0.125
                5'd9:  get_inv_u = 32'h00001C71; // ~0.1111
                5'd10: get_inv_u = 32'h00001999; // 0.1
                5'd11: get_inv_u = 32'h00001745; // ~0.0909
                5'd12: get_inv_u = 32'h00001555; // ~0.0833
                5'd13: get_inv_u = 32'h000013B1; // ~0.0769
                5'd14: get_inv_u = 32'h00001249; // ~0.0714
                5'd15: get_inv_u = 32'h00001111; // ~0.0666
                5'd16: get_inv_u = 32'h00001000; // 0.0625
                default: get_inv_u = 32'h0;
            endcase
        end
    endfunction

    // 1/(2u-1) for u=1..16
    function [31:0] get_inv_2u_minus_1;
        input [4:0] u_val;
        begin
            case(u_val)
                5'd1:  get_inv_2u_minus_1 = 32'h00010000; // 1/1 = 1
                5'd2:  get_inv_2u_minus_1 = 32'h00005555; // 1/3
                5'd3:  get_inv_2u_minus_1 = 32'h00003333; // 1/5
                5'd4:  get_inv_2u_minus_1 = 32'h00002492; // 1/7
                5'd5:  get_inv_2u_minus_1 = 32'h00001C71; // 1/9
                5'd6:  get_inv_2u_minus_1 = 32'h00001745; // 1/11
                5'd7:  get_inv_2u_minus_1 = 32'h000013B1; // 1/13
                5'd8:  get_inv_2u_minus_1 = 32'h00001111; // 1/15
                5'd9:  get_inv_2u_minus_1 = 32'h00000F0F; // 1/17
                5'd10: get_inv_2u_minus_1 = 32'h00000D79; // 1/19
                5'd11: get_inv_2u_minus_1 = 32'h00000C30; // 1/21
                5'd12: get_inv_2u_minus_1 = 32'h00000B21; // 1/23
                5'd13: get_inv_2u_minus_1 = 32'h00000A3D; // 1/25
                5'd14: get_inv_2u_minus_1 = 32'h0000097B; // 1/27
                5'd15: get_inv_2u_minus_1 = 32'h000008D3; // 1/29
                5'd16: get_inv_2u_minus_1 = 32'h00000842; // 1/31
                default: get_inv_2u_minus_1 = 32'h0;
            endcase
        end
    endfunction

    // Combinational logic for next state and datapath
    always @(*) begin
        // Default assignments
        // Note: Since no clock is explicitly defined for combinational logic in requirements,
        // we assume standard synchronous logic for registers and combinational for next logic.

        // We rely on the DSP/Logic for the "1/u" lookup implicitly by using the functions
        // inside the sequential block or pre-loading them. 
        // To keep it efficient and purely logic for control:
        
        // Note on division: The prompt mentions using a pre-calculated lookup table.
        // The logic below uses the functions defined above.
    end

    // Sequential Logic for State Machine and DP Computation
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 1'b0;
            u <= 0;
            v <= 0;
            // Initialize DP table to 0
            for (i = 0; i < 32; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    E[i][j] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        max_u <= N;
                        // Initialize E[0][0] = 0 implicitly (already cleared)
                        // Initialize base state for u=1..N 
                        // The problem asks for iterative DP. 
                        // We will fill table from u=1 to N, and for each u, v=0 to 2u.
                        // We start by setting up u=1.
                        state <= LOAD_U;
                        u <= 1;
                    end
                end

                LOAD_U: begin
                    // Prepare to compute states for current 'u'
                    v <= 0; 
                    state <= ITERATE_V;
                end

                ITERATE_V: begin
                    // Determine if we are done with this 'u'
                    if (v > (u << 1)) begin // If v > 2u
                        if (u >= max_u) begin
                            state <= DONE;
                            result <= E[max_u][0]; // Result is E(N, 0)
                        end else begin
                            u <= u + 1;
                            state <= LOAD_U;
                        end
                    end else begin
                        // Compute E(u, v)
                        state <= CALC_TRANSITION;
                    end
                end

                CALC_TRANSITION: begin
                    // Calculate Expected value for state (u, v)

                    if (v > 0) begin
                        // Case 1: v > 0
                        // Term A: (1/u) * (1 + E(u-1, v-1))
                        // Term B: ((u-1)/u) * [ (1/(2u-1))*(1+E(u-1, v-1)) + ((2u-2)/(2u-1))*(1+E(u, v+2)) ]

                        // Optimization: We need values from E table.
                        // E[u-1][v-1] and E[u][v+2].
                        // Since v iterates 0..2u, E[u][v+2] is valid if v+2 <= 2u, otherwise likely 0 or boundary.

                        // We compute this in steps or combine.
                        // Let's break down the logic into specific arithmetic steps.
                        // Since we are in a clocked block, we can use multi-cycle paths if needed,
                        // but let's try to formulate it for synthesis.

                        // Actually, calculating this combination in one cycle is heavy.
                        // Given the latency requirement (5000 cycles), we have plenty of time.
                        // Let's do it in sub-states or register intermediate results.

                        // To keep state count low, we can do:
                        // 1. Calculate E_term = 1 + E(u-1, v-1)
                        // 2. Calculate specific parts.
                        // But wait, the prompt implies a single FSM. 
                        // Let's compute the sum of terms.

                        // Term A: P_A * (1 + E_A)
                        // Term B1: P_B * P_B1 * (1 + E_B1)
                        // Term B2: P_B * P_B2 * (1 + E_B2)

                        // We have E(u, v) = TermA + TermB1 + TermB2

                        // Let's fetch needed E values first (combinational read)
                        // Note: E table updates in UPDATE_RESULT state.
                        // So reads here will get the correct previous values.

                        // We need to perform multiplies and adds. 
                        // To avoid complex combinational paths, we can register intermediates in this state
                        // or advance to a computation state. 
                        // However, the state machine structure provided is linear. 
                        // We will calculate the sum into a temporary register 'temp_E' using a sequence of operations.

                        // Step 1: Get Inv_u and Inv_2u_minus_1
                        // Step 2: Calculate E_val = 1 + E(prev)
                        // Step 3: Accumulate

                        // Since we are in CALC_TRANSITION, we perform the math.
                        // To keep the Verilog clean and synthesizable, we use intermediate registers
                        // defined at the top level.

                        // Let's define the math here:
                        // E[u][v] = (inv_u * (ONE + E[u-1][v-1]))
                        //         + (inv_u * (u-1)) * (
                        //             (inv_2u_m_1 * (ONE + E[u-1][v-1])) 
                        //             + ( (ONE - inv_2u_m_1) * (ONE + E[u][v+2]) )
                        //           );

                        // Note: (u-1)/u = u*inv_u - inv_u. But u is integer. 
                        // Better: ((u-1)*ONE)/u = inv_u * (u-1)*ONE. 
                        // BUT inv_u is Q16.16. 
                        // inv_u * (u-1) is tricky because (u-1) is integer. 
                        // (u-1)/u = 1 - inv_u. (Correct in Q16.16 if inv_u is precise).
                        // So (u-1)/u = ONE - inv_u.
                        // (2u-2)/(2u-1) = 1 - 1/(2u-1) = ONE - inv_2u_m_1.

                        // Let's simplify:
                        // P_A = inv_u
                        // P_B = ONE - inv_u
                        // P_B1 = inv_2u_m_1
                        // P_B2 = ONE - inv_2u_m_1

                        // We need E_A = 1 + E[u-1][v-1]
                        // We need E_B1 = 1 + E[u-1][v-1]
                        // We need E_B2 = 1 + E[u][v+2]

                        // Calculations:
                        // 1. TermA = P_A * E_A
                        // 2. TermB1 = P_B * P_B1 * E_A
                        // 3. TermB2 = P_B * P_B2 * E_B2

                        // Since we are in a clocked always block, we must ensure the operations
                        // don't take too many levels. 
                        // The requirement "Latency 5000 cycles" implies we can take multiple cycles per state.
                        // Let's break CALC_TRANSITION into sub-cycles using a counter or internal state.
                        // But to keep the code readable as a single module, we'll use an "ALU" style approach.
                        // We'll use 'mul_a', 'mul_b', 'temp_E' to accumulate.
                        // We need a sub-state machine for arithmetic.

                        // Sub-states for arithmetic:
                        // 0: Load Operands for E_A = 1 + E[u-1][v-1]
                        // 1: Wait for E_A
                        // 2: Load Operands for P_A * E_A -> Add to result
                        // 3: Load P_B * P_B1 * E_A -> Add to result
                        // 4: Load P_B * P_B2 * (1+E[u][v+2]) -> Add to result
                        // 5: Write to E[u][v]

                        // This makes the code very long. 
                        // Alternative: Use a helper counter within CALC_TRANSITION.
                        // Let's add a helper reg [3:0] calc_step;
                        // We will rely on the fact that we have many cycles.

                        // Let's introduce 'calc_step' inside the module.
                        // And modify the FSM to handle arithmetic steps.

                        // Re-evaluating requirements: "Efficient Verilog".
                        // A compact FSM with sequential arithmetic is usually preferred over
                        // a massive combinatorial chain for fixed-point.

                        // I will implement a sequential arithmetic flow within CALC_TRANSITION.
                        // I need a register 'step' to track progress.
                        // I will need to modify the state machine definition to include this.
                        // Since I cannot modify the JSON schema easily, I will declare the logic
                        // inside the always block using a helper variable.
                    end else begin
                        // Case 2: v == 0
                        // E(u, 0) = 1 + E(u, 2)
                        // This is simpler.
                    end
                end

                UPDATE_RESULT: begin
                    // Logic moved inside CALC_TRANSITION for better flow control
                    // or handled there directly.
                    // Actually, we can just write the result in the step where calculation finishes.
                    state <= ITERATE_V;
                    v <= v + 1;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // --- Arithmetic Logic Unit (Pipelined within state) ---
    // To avoid creating a huge state machine with 20 states, we use the "CALC_TRANSITION" state
    // with a local counter 'calc_step' to perform the multiplications/adds sequentially.
    // This ensures the design is small and efficient.

    reg [3:0] calc_step;
    reg [31:0] p_a, p_b, p_b1, p_b2, e_a, e_b2;

    // Re-defining the sequential block to include the arithmetic pipeline
    // We will override the CALC_TRANSITION logic from above.
    // We need to use an 'else if' structure or just re-write the specific case.
    // Since I must provide a single block of code, I will put the arithmetic logic here.

    // Because of the JSON format, I must provide the code as a single text block.
    // I will rewrite the CALC_TRANSITION logic to include the 'calc_step' mechanism.

    // Actually, to strictly adhere to the "Sequential Verilog module" requirement and ensure
    // it compiles and runs correctly, I will implement the arithmetic logic carefully.

    // The following logic is inserted into the main FSM block conceptually.
    // Since I cannot edit the previous block in the output generation process, I will merge them below
    // into a single cohesive always block for the final output.

    // Wait, I need to include the "calc_step" register and the logic. 
    // I will combine the logic now.
endmodule

// Re-writing the module fully to ensure correctness and synthesisability

module memory_game_expected_turns_final(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam ONE = 32'h00010000;

    // States
    localparam IDLE = 3'b000;
    localparam LOAD_U = 3'b001;
    localparam ITERATE_V = 3'b010;
    localparam CALCULATE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [4:0] u, v, max_u;

    // DP Table: E[u][v]
    // u: 0..16, v: 0..32 (v usually 0..2u, 32 is safe upper bound)
    reg [31:0] E [0:16][0:32];

    // Arithmetic Registers
    reg [3:0] step; // Sub-step for calculation
    reg [31:0] term1, term2, term3;
    reg [31:0] temp_val; // Temp for multiplies

    // Lookup Table Functions (Synthesizable as logic or LUT)
    function [31:0] inv_u;
        input [4:0] u_val;
        begin
            case(u_val)
                5'd1: inv_u = 32'h00010000; 5'd2: inv_u = 32'h00008000;
                5'd3: inv_u = 32'h00005555; 5'd4: inv_u = 32'h00004000;
                5'd5: inv_u = 32'h00003333; 5'd6: inv_u = 32'h00002AAA;
                5'd7: inv_u = 32'h00002492; 5'd8: inv_u = 32'h00002000;
                5'd9: inv_u = 32'h00001C71; 5'd10: inv_u = 32'h00001999;
                5'd11: inv_u = 32'h00001745; 5'd12: inv_u = 32'h00001555;
                5'd13: inv_u = 32'h000013B1; 5'd14: inv_u = 32'h00001249;
                5'd15: inv_u = 32'h00001111; 5'd16: inv_u = 32'h00001000;
                default: inv_u = 0;
            endcase
        end
    endfunction

    function [31:0] inv_2u_m_1;
        input [4:0] u_val;
        begin
            case(u_val)
                5'd1: inv_2u_m_1 = 32'h00010000; 5'd2: inv_2u_m_1 = 32'h00005555;
                5'd3: inv_2u_m_1 = 32'h00003333; 5'd4: inv_2u_m_1 = 32'h00002492;
                5'd5: inv_2u_m_1 = 32'h00001C71; 5'd6: inv_2u_m_1 = 32'h00001745;
                5'd7: inv_2u_m_1 = 32'h000013B1; 5'd8: inv_2u_m_1 = 32'h00001111;
                5'd9: inv_2u_m_1 = 32'h00000F0F; 5'd10: inv_2u_m_1 = 32'h00000D79;
                5'd11: inv_2u_m_1 = 32'h00000C30; 5'd12: inv_2u_m_1 = 32'h00000B21;
                5'd13: inv_2u_m_1 = 32'h00000A3D; 5'd14: inv_2u_m_1 = 32'h0000097B;
                5'd15: inv_2u_m_1 = 32'h000008D3; 5'd16: inv_2u_m_1 = 32'h00000842;
                default: inv_2u_m_1 = 0;
            endcase
        end
    endfunction

    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 1'b0;
            // Reset table
            for (i = 0; i <= 16; i = i + 1) begin
                for (j = 0; j <= 32; j = j + 1) begin
                    E[i][j] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        max_u <= N;
                        u <= 1;
                        step <= 0;
                        state <= LOAD_U;
                    end
                end

                LOAD_U: begin
                    // Reset v for the new u
                    v <= 0;
                    step <= 0;
                    state <= ITERATE_V;
                end

                ITERATE_V: begin
                    // Check loop bound: v <= 2*u
                    // Since u starts at 1, v goes 0, 2, 4... 
                    // But wait, transitions can set v+2. 
                    // We need to compute E(u,v) for all reachable v.
                    // v goes from 0 to 2*u.
                    if (v > (u << 1)) begin
                        if (u >= max_u) begin
                            state <= DONE;
                            result <= E[max_u][0];
                        end else begin
                            u <= u + 1;
                            state <= LOAD_U;
                        end
                    end else begin
                        state <= CALCULATE;
                        step <= 0;
                    end
                end

                CALCULATE: begin
                    // Multi-cycle arithmetic sequence
                    // We compute E[u][v] based on the formula
                    case (step)
                        0: begin
                            // Prepare common values
                            // If v > 0, we need E[u-1][v-1] and E[u][v+2]
                            // If v == 0, we need E[u][2]
                            // We also need the probabilities (lookup functions)
                            // We assume reads from E[] are combinational in this cycle
                            // and we register the operands for the multiply chain.

                            if (v == 0) begin
                                // E(u, 0) = 1 + E(u, 2)
                                // Result = ONE + E[u][2]
                                // Since E[u][2] is computed later in the loop (v=2), 
                                // we must handle the dependency. 
                                // Iteration order: v=0, 2, 4...
                                // At v=0, E[u][2] is NOT yet computed.
                                // This implies we cannot compute E(u,0) immediately in this order.
                                // OR, the state definition implies v is 'known single cards'.
                                // If v=0 (unknown), next state is v=2.
                                // So E(u,0) depends on E(u,2).
                                // We should iterate v in increasing order.
                                // But E(u,2) depends on E(u,4) (if no match) etc.
                                // This creates a long dependency chain.
                                // However, looking at the transitions for v>0:
                                // If v>0, we jump to (u-1, v-1) or (u, v+2).
                                // So E(u,v) depends on E(u, v+2). 
                                // This means we MUST compute from HIGHEST v downwards.
                                // Or use a solving method.
                                // Given the prompt says "iterative dynamic programming",
                                // let's assume we iterate v downwards from 2u to 0.
                                // This way E(u, v+2) is known (if v+2 <= 2u).

                                // REVISION: Change ITERATE_V to count down.
                                // Let's modify the logic in ITERATE_V and LOAD_U.
                                // Start v at 2*u. Decrement by 2.
                                // Then E(u, v) can use E(u, v+2).
                                // For E(u,0), we use E(u,2) which is already computed.

                                // Let's continue with the current step logic assuming we fixed the loop direction.
                                // I will assume v counts DOWN in the next JSON block logic to ensure dependency closure.

                                // Fix implemented in this step logic: 
                                // We need E[u][v+2]. If v+2 > 2u, it's effectively infinity (or 0 in our bounded array), 
                                // but the game guarantees a finish. 
                                // If v > 2u, the loop stops. So valid v are <= 2u.
                                // v+2 might be > 2u. In that case, probability of no match is 0? 
                                // No, if v is high, probability of match is high.
                                // Let's stick to the derived formula.

                                // Step 0: Calculate E_A and E_B2 values based on v.
                                if (v == 0) begin
                                    // E(u,0) = 1 + E(u,2)
                                    // We assume E[u][2] is valid here because we iterate v down.
                                    // But wait, if we are in CALCULATE, we haven't written E[u][v] yet.
                                    // We are computing it. 
                                    // Let's use the values from the table (which hold OLD values or NEW if computed in this loop).
                                    // Since we iterate DOWN, E[u][v+2] is already computed in previous iterations.
                                    // So it's safe.
                                    temp_val <= E[u][2]; // 1 + E(u,2) is computed in next step
                                    step <= 1; // Go to add ONE
                                end else begin
                                    // v > 0
                                    // We need E[u-1][v-1] and E[u][v+2]
                                    // And probabilities inv_u and inv_2u_m_1

                                    // Let's calculate Term A: inv_u * (1 + E[u-1][v-1])
                                    // Term B1: (ONE - inv_u) * inv_2u_m_1 * (1 + E[u-1][v-1])
                                    // Term B2: (ONE - inv_u) * (ONE - inv_2u_m_1) * (1 + E[u][v+2])

                                    // Optimization: Factor out (1 + E[u-1][v-1])
                                    // Part1 = (1 + E[u-1][v-1]) * [ inv_u + (ONE-inv_u)*inv_2u_m_1 ]
                                    // Part2 = (1 + E[u][v+2]) * [ (ONE-inv_u)*(ONE-inv_2u_m_1) ]

                                    // We start computing Part1.
                                    // First, load (1 + E[u-1][v-1])
                                    temp_val <= ONE + E[u-1][v-1];
                                    step <= 2; // Compute Part 1 base
                                end
                            end
                        end

                        1: begin // For v == 0 case
                            temp_val <= temp_val + ONE;
                            step <= 15; // Direct write
                        end

                        2: begin // Compute coeff for Part 1
                            // Coeff = inv_u + (ONE - inv_u) * inv_2u_m_1
                            // We need to compute (ONE - inv_u) * inv_2u_m_1
                            // Register inv_u and inv_2u_m_1 for this block? 
                            // Or re-calculate. Calculating costs logic.
                            // Let's use 'term1' to store the coefficient.
                            // term1 = inv_u 
                            // term2 = (ONE - inv_u) * inv_2u_m_1
                            // term3 = term1 + term2
                            // term3 = inv_u + (ONE-inv_u)*inv_2u_m_1

                            // We can do this in multiple steps.
                            // 2a: mul_a = (ONE - inv_u), mul_b = inv_2u_m_1
                            // 2b: acc = inv_u + mul_res[47:16] (approx)

                            // Simplified: We have 'temp_val' holding (1 + E[u-1][v-1])
                            // We need to multiply by coefficient.
                            // Let's compute the coefficient into 'term1'.

                            // Step 2a: (ONE - inv_u)
                            term1 <= ONE - inv_u(u);
                            step <= 3;
                        end

                        3: begin // Multiply (ONE - inv_u) * inv_2u_m_1
                            // mul_a = term1, mul_b = inv_2u_m_1(u)
                            // Store result in term2
                            // Result is Q16.16 * Q16.16 -> Q32.32. We take upper 32 bits (approx Q16.16)
                            // Actually, Q16.16 * Q16.16 = Q32.32. Result in [47:16] for Q16.16.
                            term2 <= (term1 * inv_2u_m_1(u)) >> 16;
                            step <= 4;
                        end

                        4: begin // Add inv_u to term2
                            // term1 = inv_u + term2
                            // This is the coefficient for Part 1.
                            term1 <= inv_u(u) + term2;
                            step <= 5;
                        end

                        5: begin // Multiply Part 1 Coeff * temp_val (which is 1+E[u-1][v-1])
                            // term1 (coeff) * temp_val (val)
                            // Result stored in term1
                            term1 <= (term1 * temp_val) >> 16;
                            step <= 6;
                        end

                        6: begin // Prepare Part 2
                            // We need (1 + E[u][v+2])
                            // If v+2 <= 2u, E[u][v+2] is valid.
                            // If v+2 > 2u, probability of no match is 0, so this term is 0.
                            // Check v+2 <= 2u ? (v <= 2u - 2)
                            // If v == 2u, Part2 is 0.
                            // If v == 2u-1 (odd, but v is even in DP? No, v is pairs? Wait.
                            // v is 'known single cards'. Wait, prompt says "v is number of known single cards".
                            // Pairs of cards. 
                            // Let's re-read: "u unmatched pairs, v known single cards".
                            // If v > 0, we have some known singles.
                            // If we flip a known card, we match it (Prob 1/u).
                            // Otherwise we flip a random unknown card.
                            // The logic in prompt seems to be derived from a specific simplified model.
                            // Assuming the formula is correct:

                            // If v > 0:
                            //   If v < 2u: Match found possible.
                            //   Else: No match possible (all others are known singles? No, v singles).
                            //   The prompt says "Else: No match".

                            // Let's calculate Part 2:
                            // Coeff = (ONE - inv_u) * (ONE - inv_2u_m_1)
                            // Val = 1 + E[u][v+2]
                            // Check if v+2 <= 2u.
                            // If v == 2u, Part2 = 0. 
                            // We can skip Part 2 calculation if v == 2u (since v+2 > 2u).

                            if (v == (u << 1)) begin
                                // v == 2u. No Part 2.
                                // Just use Part 1 (already in term1). 
                                // Wait, if v == 2u, is the formula valid? 
                                // "Else: No match (Prob (2u-2)/(2u-1))". 
                                // If v=2u, we are in the "Else" branch of "v < 2u". 
                                // So Part 2 is taken. But E[u][v+2] is out of bounds.
                                // In probability terms, if v=2u, the "No Match" probability calculation
                                // relies on the state transition. 
                                // If v=2u, all cards are known singles? 
                                // Actually, if we have 2u singles, we have 0 pairs left? No, u pairs left.
                                // 2u singles means we have seen all cards (u pairs -> 2u cards).
                                // If we have seen all cards, we just match them.
                                // The prompt logic is a simplification. 
                                // Let's assume if v >= 2u-1 (approx), the transition is deterministic.

                                // Let's stick to the formula but treat out-of-bounds E as 0.
                                // If v == 2u, v+2 is invalid. 
                                // However, the prompt implies a DP approach. 
                                // If v is large, the probability of "No match" decreases.
                                // Let's calculate Part 2 only if v+2 <= 2u.
                                // If v == 2u, we treat Part 2 as 0.
                                // So Final Result = Part 1.

                                // In this step (6), if v == 2u, we skip to write.
                                step <= 15; // Skip to write
                            end else begin
                                // Calculate Part 2 Coeff
                                term2 <= (term1 * (ONE - inv_2u_m_1(u))) >> 16; // re-using term1 (which held (ONE-inv_u))
                                // Wait, term1 was overwritten in step 5. 
                                // We need (ONE - inv_u) again. 
                                // Let's recalculate or store it. 
                                // To save logic, let's recompute (ONE - inv_u) in step 6 if needed.
                                // Actually, term1 is now Part1 Result. 
                                // We need Part2 Result separately.

                                // Let's use 'term3' to hold Part2 total.
                                // Step 6a: Compute Coeff2 = (ONE - inv_u) * (ONE - inv_2u_m_1)
                                // Step 6b: Mul Coeff2 * (1 + E[u][v+2])

                                term3 <= ((ONE - inv_u(u)) * (ONE - inv_2u_m_1(u))) >> 16;
                                step <= 7;
                            end
                        end

                        7: begin // Get 1 + E[u][v+2]
                            // We need E[u][v+2]. 
                            // Since we iterate v DOWN, E[u][v+2] is ready.
                            // We assume v+2 is valid because we checked v != 2u.
                            // But v+2 might be > 2u if v = 2u-1. 
                            // v steps by 2? No, v can be any number? 
                            // "v is number of known single cards". 
                            // If we turn a card, we might add 2 singles. 
                            // So v increments by 2? 
                            // The prompt: "E(u, v+2)". So increments by 2.
                            // So v is even. 
                            // If v < 2u, v+2 <= 2u+2. 
                            // If v = 2u-2, v+2 = 2u. Valid.
                            // If v = 2u, we handled in step 6.

                            temp_val <= ONE + E[u][v+2];
                            step <= 8;
                        end

                        8: begin // Multiply Part2 Coeff * Val
                            // term3 * temp_val
                            term3 <= (term3 * temp_val) >> 16;
                            step <= 9;
                        end

                        9: begin // Add Part 1 + Part 2
                            // term1 (Part 1) + term3 (Part 2)
                            temp_val <= term1 + term3;
                            step <= 15; // Go to write
                        end

                        15: begin // Write to E[u][v]
                            // temp_val holds the result (which is already 1 + ...)
                            // Wait, the formula is E = P * (1 + E'). 
                            // We calculated P * (1 + E'). 
                            // But the expectation is sum of P * (1 + E').
                            // So temp_val IS E(u,v).

                            E[u][v] <= temp_val;

                            // Next v (count down)
                            if (v >= 2) begin
                                v <= v - 2;
                                state <= ITERATE_V;
                            end else if (v == 0) begin
                                // Done with this u
                                if (u >= max_u) begin
                                    state <= DONE;
                                    result <= E[max_u][0];
                                end else begin
                                    u <= u + 1;
                                    state <= LOAD_U;
                                end
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule

// The prompt asked for 'memory_game_expected_turns'.
// The code below is the cleaned up, synthesizable version combining the logic.
// I have used the logic derived in the previous blocks.

module memory_game_expected_turns(
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam ONE = 32'h00010000;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam LOAD_U = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam DONE = 3'b011;

    // Registers
    reg [2:0] state;
    reg [4:0] u, v, max_u;
    reg [3:0] step;

    // DP Table: E[u][v] 
    // u: 0..16, v: 0..32 (max 2*u = 32)
    reg [31:0] E [0:16][0:32];

    // Helper Registers for Arithmetic
    reg [31:0] t1, t2, t3;
    reg [31:0] temp_res;

    // Look-up Tables (Inline Functions for Synthesis)
    function [31:0] get_inv_u;
        input [4:0] val;
        case(val)
            5'd1: get_inv_u = 32'h00010000; 5'd2: get_inv_u = 32'h00008000;
            5'd3: get_inv_u = 32'h00005555; 5'd4: get_inv_u = 32'h00004000;
            5'd5: get_inv_u = 32'h00003333; 5'd6: get_inv_u = 32'h00002AAA;
            5'd7: get_inv_u = 32'h00002492; 5'd8: get_inv_u = 32'h00002000;
            5'd9: get_inv_u = 32'h00001C71; 5'd10: get_inv_u = 32'h00001999;
            5'd11: get_inv_u = 32'h00001745; 5'd12: get_inv_u = 32'h00001555;
            5'd13: get_inv_u = 32'h000013B1; 5'd14: get_inv_u = 32'h00001249;
            5'd15: get_inv_u = 32'h00001111; 5'd16: get_inv_u = 32'h00001000;
            default: get_inv_u = 0;
        endcase
    endfunction

    function [31:0] get_inv_2u_m_1;
        input [4:0] val;
        case(val)
            5'd1: get_inv_2u_m_1 = 32'h00010000; 5'd2: get_inv_2u_m_1 = 32'h00005555;
            5'd3: get_inv_2u_m_1 = 32'h00003333; 5'd4: get_inv_2u_m_1 = 32'h00002492;
            5'd5: get_inv_2u_m_1 = 32'h00001C71; 5'd6: get_inv_2u_m_1 = 32'h00001745;
            5'd7: get_inv_2u_m_1 = 32'h000013B1; 5'd8: get_inv_2u_m_1 = 32'h00001111;
            5'd9: get_inv_2u_m_1 = 32'h00000F0F; 5'd10: get_inv_2u_m_1 = 32'h00000D79;
            5'd11: get_inv_2u_m_1 = 32'h00000C30; 5'd12: get_inv_2u_m_1 = 32'h00000B21;
            5'd13: get_inv_2u_m_1 = 32'h00000A3D; 5'd14: get_inv_2u_m_1 = 32'h0000097B;
            5'd15: get_inv_2u_m_1 = 32'h000008D3; 5'd16: get_inv_2u_m_1 = 32'h00000842;
            default: get_inv_2u_m_1 = 0;
        endcase
    endfunction

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            // Reset DP table
            for (i = 0; i <= 16; i = i + 1)
                for (j = 0; j <= 32; j = j + 1)
                    E[i][j] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        max_u <= N;
                        u <= 1;
                        state <= LOAD_U;
                    end
                end

                LOAD_U: begin
                    // Initialize v to max for this u (2*u) to iterate downwards
                    v <= u << 1; // 2*u
                    step <= 0;
                    state <= CALCULATE;
                end

                CALCULATE: begin
                    case (step)
                        0: begin // Start of calculation for (u, v)
                            if (v == 0) begin
                                // E(u, 0) = 1 + E(u, 2)
                                // Since we iterate down, E(u, 2) is already known
                                temp_res <= ONE + E[u][2];
                                step <= 15;
                            end else if (v > (u << 1)) begin
                                // Should not happen if controlled correctly, but safety
                                state <= LOAD_U; // Move to next u
                            end else begin
                                // v > 0
                                // We calculate Part 1 and Part 2
                                // Part 1 involves E(u-1, v-1)
                                // Part 2 involves E(u, v+2)

                                // We need to handle the case where v is close to 2u.
                                // If v == 2u, then in the formula:
                                // Else branch (No match) probability = (2u-2)/(2u-1). 
                                // But the transition is E(u, v+2). If v=2u, v+2 > 2u.
                                // In the prompt's "Else: No match", it implies v+2 increases.
                                // If we are at max capacity, we can't increase.
                                // However, the probability of "No match" is low if v is high.
                                // Let's stick to the math: calculate contributions.

                                // First, load E(u-1, v-1) + 1 into temp_val
                                temp_res <= ONE + E[u-1][v-1];
                                step <= 1;
                            end
                        end

                        1: begin // Calculate Part 1 Coefficients
                            // Coeff = inv_u + (ONE - inv_u) * inv_2u_m_1
                            // We need to store this.
                            // Let's store (ONE - inv_u) * inv_2u_m_1 in t1
                            t1 <= ((ONE - get_inv_u(u)) * get_inv_2u_m_1(u)) >> 16;
                            step <= 2;
                        end

                        2: begin // Add inv_u to t1
                            // t1 now holds the full Part 1 coefficient
                            t1 <= t1 + get_inv_u(u);
                            step <= 3;
                        end

                        3: begin // Multiply Part 1 coeff * (1+E[u-1][v-1])
                            // temp_res holds (1+E[u-1][v-1])
                            // Result -> t2 (Part 1 total)
                            t2 <= (t1 * temp_res) >> 16;
                            step <= 4;
                        end

                        4: begin // Prepare Part 2
                            // Check if v+2 > 2u. If so, Part 2 contribution is 0.
                            // v <= 2u. v+2 <= 2u+2. 
                            // If v == 2u, v+2 > 2u. 
                            // If v == 2u-1 (odd), but v decrements by 2, so v is even. 
                            // v is even. Max v = 2u.
                            if (v == (u << 1)) begin
                                // v == 2u. Part 2 invalid/0.
                                // Total E = Part 1 (t2).
                                temp_res <= t2;
                                step <= 15;
                            end else begin
                                // Calculate Coeff Part 2: (ONE - inv_u) * (ONE - inv_2u_m_1)
                                t1 <= ((ONE - get_inv_u(u)) * (ONE - get_inv_2u_m_1(u))) >> 16;
                                // Load Val Part 2: 1 + E[u][v+2]
                                // Since we iterate down, E[u][v+2] is ready.
                                temp_res <= ONE + E[u][v+2];
                                step <= 5;
                            end
                        end

                        5: begin // Multiply Part 2 coeff * val
                            // t1 * temp_res -> t3
                            t3 <= (t1 * temp_res) >> 16;
                            step <= 6;
                        end

                        6: begin // Sum Part 1 + Part 2
                            // t2 (Part 1) + t3 (Part 2)
                            temp_res <= t2 + t3;
                            step <= 15;
                        end

                        15: begin // Write Back to Table
                            E[u][v] <= temp_res;

                            // Update v (decrement by 2)
                            if (v >= 2) begin
                                v <= v - 2;
                                state <= LOAD_U; // Re-enter CALCULATE state logic, will reset step to 0
                                // Note: We jump back to LOAD_U to reset step=0, but we need to stay in calculation loop.
                                // Let's go to a temporary state or just reset step and stay in CALCULATE.
                                // Better: Go to a "NEXT_V" state or just reset step and stay in CALCULATE.
                                step <= 0;
                                state <= CALCULATE;
                            end else begin
                                // v == 0 done, move to next u
                                if (u >= max_u) begin
                                    state <= DONE;
                                    result <= E[max_u][0];
                                end else begin
                                    u <= u + 1;
                                    state <= LOAD_U;
                                end
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule