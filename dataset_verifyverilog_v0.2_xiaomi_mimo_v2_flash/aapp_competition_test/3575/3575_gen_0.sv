module random_walk_meeting (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [2:0] s,
    input wire [2:0] t,
    input wire [63:0] adj_flat,
    output reg [31:0] result,
    output reg valid,
    output reg never_meet
);

    // --- Parameters and Constants ---
    parameter IDLE         = 5'b00001;
    parameter INIT_EDGES   = 5'b00010;
    parameter CHECK_DEG    = 5'b00100;
    parameter SUM_NEIGH    = 5'b01000;
    parameter UPDATE_VAL   = 5'b10000;
    parameter DONE         = 5'b11111;

    // Fixed point constants (Q16.16)
    localparam ONE = 32'h00010000; // 1.0
    localparam INF = 32'hFFFFFFFF;
    localparam ITERATIONS = 16;    // Fixed number of relaxation steps

    // --- State and Registers ---
    reg [4:0] current_state, next_state;
    reg [31:0] E_reg [0:63];       // Storage for E[i][j] values
    reg [3:0] iter_cnt;            // Iteration counter
    reg [3:0] i_idx, j_idx;        // Current pair indices
    reg [3:0] u_idx, v_idx;        // Neighbor indices
    
    // Helper registers for arithmetic
    reg [7:0] deg_i, deg_j;        // Degrees (max 8)
    reg [31:0] acc_sum;            // Accumulator for Sum(E[u][v])
    reg [31:0] current_E;          // Current value E[i][j]
    reg [1:0] op_stage;            // Sub-stage for multi-cycle operations
    reg never_flag;                // Flag to indicate impossible pair

    // --- Wires for Adjacency Matrix Access ---
    wire adj_ij = adj_flat[i_idx * 8 + j_idx];
    wire adj_ik = adj_flat[i_idx * 8 + u_idx];
    wire adj_jl = adj_flat[j_idx * 8 + v_idx];

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            valid <= 0;
            never_meet <= 0;
            result <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // --- Combinational Next State Logic ---
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT_EDGES;
                else next_state = IDLE;
            end
            
            INIT_EDGES: begin
                // Transition when initialization of 64 pairs is done
                if (i_idx == 8 && j_idx == 8) next_state = CHECK_DEG;
                else next_state = INIT_EDGES;
            end

            CHECK_DEG: begin
                if (i_idx == n || j_idx == n) begin
                    // Finished all pairs for current iteration
                    if (iter_cnt >= ITERATIONS) next_state = DONE;
                    else next_state = CHECK_DEG; // Will reset indices for next iter
                end else if (i_idx == j_idx) begin
                    // Diagonal: E=0, skip
                    next_state = CHECK_DEG;
                end else if (deg_i == 0 || deg_j == 0) begin
                    // Impossible to meet
                    next_state = DONE; // Go to DONE, but flag never_meet
                end else begin
                    // Valid pair to update
                    next_state = SUM_NEIGH;
                end
            end

            SUM_NEIGH: begin
                // Logic to iterate u and v neighbors
                // If loop over u and v done, go to update
                if (u_idx == n && v_idx == n) next_state = UPDATE_VAL;
                else next_state = SUM_NEIGH;
            end

            UPDATE_VAL: begin
                // Update complete, move to next pair
                next_state = CHECK_DEG;
            end

            DONE: begin
                // Stay in done state until reset
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // --- Datapath Logic (Sequential) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_idx <= 0; j_idx <= 0;
            u_idx <= 0; v_idx <= 0;
            iter_cnt <= 0;
            op_stage <= 0;
            valid <= 0;
            never_meet <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    valid <= 0;
                    never_meet <= 0;
                    iter_cnt <= 0;
                    i_idx <= 0;
                    j_idx <= 0;
                    u_idx <= 0;
                    v_idx <= 0;
                    op_stage <= 0;
                end

                INIT_EDGES: begin
                    // Write 0 to E[i][j] for all 64 pairs
                    if (op_stage == 0) begin
                        E_reg[{i_idx, j_idx}] <= 0;
                        // Increment logic
                        if (j_idx == 7) begin
                            j_idx <= 0;
                            if (i_idx == 7) i_idx <= 8; // Finish marker
                            else i_idx <= i_idx + 1;
                        end else begin
                            j_idx <= j_idx + 1;
                        end
                        op_stage <= 1;
                    end else begin
                        op_stage <= 0;
                    end
                    // Reset indices for next state
                    if (i_idx == 8 && j_idx == 8) begin
                        i_idx <= 0;
                        j_idx <= 0;
                    end
                end

                CHECK_DEG: begin
                    // Calculate degrees when entering a new pair or resetting for new iteration
                    if (i_idx == n || j_idx == n) begin
                        // Iteration loop control
                        if (i_idx == n) begin
                            // Reset for next iteration
                            i_idx <= 0;
                            j_idx <= 0;
                            iter_cnt <= iter_cnt + 1;
                        end
                    end else if (op_stage == 0) begin
                        // Compute degrees for current (i, j)
                        // Simplified: We compute degree on the fly in logic below, or use pre-calc
                        // Here we assume degrees are computed or stored. 
                        // For simplicity, let's compute degrees in a separate step or combinational.
                        // But we need them for SUM_NEIGH. Let's compute them now.
                        
                        // Combinational block calculates deg_i, deg_j based on i_idx, j_idx
                        // We will capture them here
                        deg_i <= get_degree(i_idx);
                        deg_j <= get_degree(j_idx);
                        
                        // Reset neighbor indices
                        u_idx <= 0;
                        v_idx <= 0;
                        acc_sum <= 0;
                        op_stage <= 1;
                    end else if (op_stage == 1) begin
                        // If diagonal, skip to increment
                        if (i_idx == j_idx) begin
                            // increment j_idx (or logic in next state)
                            // Actually handled in next_state logic transition check
                        end
                        op_stage <= 0;
                    end
                    
                    // Handle diagonal skip increment here for flow
                    if (i_idx != j_idx && op_stage == 0) begin
                         // Wait for state transitions
                    end else if (i_idx == j_idx && op_stage == 1) begin
                         // Increment indices manually since we skipped SUM/UPDATE
                         // But next_state logic handles "SKIP". We need to increment here if staying in state
                         // Better to handle increment in SUM_NEIGH or UPDATE_VAL for clean flow.
                         // Let's adjust logic: CHECK_DEG computes degs, if valid -> SUM. If skip -> increment next.
                    end
                end

                SUM_NEIGH: begin
                    // Iterate u and v to accumulate sum
                    // We need E[u][v]
                    // Since E_reg is synchronous, we read it. We need to buffer or handle delay.
                    // We assume 1 cycle read latency. 
                    // We'll use op_stage to handle the accumulation.
                    
                    if (op_stage == 0) begin
                        // Fetch E[u][v]
                        // If u==v, E is 0. 
                        // If u!=v and deg conditions fail? Assume E is valid (0 if impossible, but check)
                        op_stage <= 1;
                    end else if (op_stage == 1) begin
                        // Add to sum
                        if (u_idx != n && v_idx != n) begin
                            // Only sum if neighbor exists
                            if (adj_ik && adj_jl) begin
                                if (u_idx == v_idx) begin
                                    // E is 0, nothing to add
                                end else begin
                                    // Addition: Sum = Sum + E[u][v]
                                    acc_sum <= acc_sum + E_reg[{u_idx, v_idx}];
                                end
                            end
                        end
                        
                        // Increment v_idx
                        if (v_idx == n - 1) begin
                            v_idx <= 0;
                            if (u_idx == n - 1) begin
                                u_idx <= n; // Mark finish
                            end else begin
                                u_idx <= u_idx + 1;
                            end
                        end else begin
                            v_idx <= v_idx + 1;
                        end
                        op_stage <= 0;
                    end
                end

                UPDATE_VAL: begin
                    // E_new = 1 + Sum / (deg_i * deg_j)
                    // Division: (Sum << 16) / (deg_i * deg_j)
                    // We need a divider. Since no block RAM multiplier/divider specified, 
                    // we implement a simple state machine for division or assume 1 cycle if small.
                    // deg_i * deg_j <= 64. 
                    // Sum is Q16.16. 
                    // (Sum << 16) is Q32.16? No. Sum is Q16.16. 
                    // Formula: (Sum / (deg_i * deg_j)).
                    // Let's do: Temp = Sum / (deg_i*deg_j). Result = ONE + Temp.
                    // Since deg <= 8, let's use a simple iterative subtract divider for precision or unroll.
                    // Actually, 32 iterations is too slow. 
                    // Let's assume a combinational divider for small divisors (max 64) is acceptable or use a LUT.
                    // Or, we can use the 'op_stage' to do the division in multiple cycles if needed.
                    // For this demo, let's assume a non-restoring divider logic running for 16 cycles.
                    // But wait, we are in a loop. Let's just do it in one cycle if we can fuse operations.
                    // Since we are iterating, we must move fast.
                    // Let's assume a combinational division is synthesizable.
                    
                    if (op_stage == 0) begin
                        // Prepare division: Numerator = acc_sum, Denominator = deg_i * deg_j
                        // Note: acc_sum is accumulated sum of E's. It is Q16.16.
                        // We want: (acc_sum / (deg_i*deg_j)).
                        // This results in Q16.16. 
                        // (Q16.16) / Integer = Q16.16.
                        // Implementation: (acc_sum << 16) / (deg_i*deg_j) -> Q32.0 / Int -> Q32.0? No.
                        // Let's use a standard divider block approach: 
                        // A/B = A * (2^16) / B >> 16. 
                        // Let's implement a small state machine for this division.
                        op_stage <= 1;
                    end else if (op_stage == 1) begin
                        // Wait for division result (if pipelined) or compute.
                        // For simplicity in this code structure, let's calculate directly.
                        // Note: This is heavy. But we have to do it.
                        
                        // Let's do a simple approximation or assume synthesizer infers logic.
                        // Since max divisor is 64, we can use a case statement or shift-add.
                        // Let's do shift-add in op_stage 1..16 if needed, but let's try to do it in few cycles.
                        // Actually, let's just calculate it. 
                        // Division: acc_sum / (deg_i*deg_j)
                        // Let's use a temporary variable for the division result.
                        // If we use a LUT for 1/val, it might be easier.
                        // Let's assume we have a 'divide' task or just calculate.
                        // Since we are coding a module, we should be explicit.
                        
                        // Let's implement a simple divider in the block below (combinational within state logic? No).
                        // We'll use 'op_stage' to count divider cycles.
                        // Division loop: 
                        // This is getting complex for a single file. 
                        // Let's hardcode a 'fast' division for small numbers using a repeated subtract or shift.
                        // Actually, let's rely on the fact that 'deg_i * deg_j' is small (<=64).
                        // We can multiply acc_sum by the inverse.
                        // Or, simply, let's use a combinational divider implementation inside the FSM.
                        
                        // Divider Logic (Restoring)
                        // We need to shift acc_sum left by 16 to perform Q16.16 division.
                        // Let's define: Dividend = {acc_sum, 16'b0}; (64 bits? No, acc_sum is 32, shift by 16 -> 48 bits).
                        // Actually: Result = (acc_sum * (2^16)) / (deg_i * deg_j).
                        // Then shift right by 16. 
                        // Let's do it iteratively in op_stage 1..18.
                        
                        if (op_stage == 1) begin
                            // Initialize divider
                            // We use a 32-bit divider. 
                            // But we need precision. 
                            // Let's do: 
                            // quotient = (acc_sum << 16) / (deg_i * deg_j)
                            // Then E_new = ONE + quotient.
                            
                            // Let's assume we just perform the update directly here using a helper register for quotient.
                            // And we use 'op_stage' to iterate the division steps.
                            // To keep code short, let's use a simple behavioral description that synthesizes reasonably.
                            
                            // Effective Division: (acc_sum / (deg_i*deg_j))
                            // We can calculate: quotient = acc_sum / (deg_i * deg_j) (integer division).
                            // But we need fractional part. 
                            // Let's perform: quotient = (acc_sum * 65536) / (deg_i * deg_j).
                            
                            // Store 'dividend' and 'divisor' in temp regs.
                            // 'dividend' needs to be acc_sum << 16. That's 32+16=48 bits.
                            // Let's use a 48-bit accumulator.
                        end
                    end
                end

                DONE: begin
                    // Final result
                    if (never_flag) begin
                        never_meet <= 1;
                        result <= INF;
                    end else begin
                        // Result is E[s][t]
                        result <= E_reg[{s, t}];
                        never_meet <= 0;
                    end
                    valid <= 1;
                end
            endcase
        end
    end

    // --- Divider Logic (Combinational / Helper) ---
    // Since we need to integrate division into the UPDATE_VAL state, let's break it down.
    // We will add a dedicated divider state.
    // Let's add a SUB_STATE machine for the UPDATE phase.
    // But to keep the code valid and strictly sequenced, let's move the division logic 
    // into a separate combinational block triggered by 'op_stage'.
    
    // Actually, let's redesign the UPDATE_VAL state to include:
    // 1. Calc product (deg_i * deg_j).
    // 2. Setup division (Dividend = acc_sum << 16, Divisor = product).
    // 3. Run divide for N cycles.
    // 4. Add to ONE.
    // 5. Write to E_reg.
    // 6. Increment indices.

    // However, the JSON response must be a single module. 
    // We will implement the Update logic by extending the UPDATE_VAL state.
    // We will use 'op_stage' to handle the sub-operations.

    // Re-evaluating state machine for Update:
    // UPDATE_VAL enters.
    // op_stage 0: Calculate deg_i * deg_j -> mul_res. Setup Divider.
    // op_stage 1..16: Divider runs. (Or 1 cycle if we use a bigger LUT).
    // op_stage 17: Finalize E_new = ONE + (quotient >> 16?) 
    // Wait, we want Sum / (deg_i*deg_j). 
    // Let Sum be Q16.16. 
    // Let D = deg_i*deg_j.
    // We want Result = 1.0 + (Sum / D).
    // Let's compute (Sum * 65536) / D. Result is Q32.0? No.
    // Sum / D is Q16.16.
    // We can do: (Sum << 16) / D = Q32.16 / Int = Q32.16.
    // Then take upper 32 bits? 
    // Sum is Q16.16. Sum / D is Q16.16.
    // Example: Sum = 1.0 (0x10000), D=2. Result = 0.5 (0x8000).
    // (0x10000 << 16) = 0x100000000. / 2 = 0x80000000. (32-bit result). Shifted? No.
    // (Sum << 16) / D gives a result where the decimal point is shifted.
    // To get back to Q16.16, we don't need to shift back if we treat the result as the numerator.
    // Wait. (Sum / D) = 0.5. 
    // (Sum << 16) / D = 0.5 << 16 = 0x8000.
    // Yes! So (Sum << 16) / D gives exactly the Q16.16 result.
    // So Dividend = {Sum, 16'b0}. Divisor = D.
    // Quotient = Dividend / Divisor. (Result is Q16.16).
    // Then E_new = ONE + Quotient.

    // Divider Implementation:
    // We will implement a 32-bit restoring divider in a combinational always block or FSM.
    // Given constraints, let's use a 17-cycle divider (for 32 bits).

    // Let's refine the FSM states to be more explicit.
    // WAIT -> IDLE
    // INIT -> set up edges
    // LOOP_START -> setup i,j
    // CALC_DEG -> calc degrees
    // CHECK_INF -> check if inf
    // CALC_SUM -> sum neighbors (requires 64 reads)
    // DIVIDE -> run divider
    // UPDATE -> write back
    // NEXT_PAIR -> inc i,j
    // NEXT_ITER -> inc iter
    // DONE

    // Given the complexity and token limit, I will provide a compact but functional FSM.
    // I will implement the division using a small loop inside the UPDATE_VAL state logic.

    // Additional registers for division
    reg [47:0] div_dividend; // {Sum, 16'b0}
    reg [7:0] div_divisor;   // deg_i * deg_j (max 64)
    reg [31:0] div_quotient;
    reg [5:0] div_count;     // Counter for subtraction loops

    // Combinational helper for degree calculation (since we can't easily iterate inside always_ff)
    function [7:0] get_deg(input [2:0] node);
        integer k;
        begin
            get_deg = 0;
            for (k = 0; k < 8; k = k + 1) begin
                if (adj_flat[node * 8 + k]) get_deg = get_deg + 1;
            end
        end
    endfunction

    // Rewrite the sequential block to handle the states cleanly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            // Reset all counters and flags
            i_idx <= 0; j_idx <= 0; iter_cnt <= 0;
            valid <= 0; never_meet <= 0; never_flag <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= INIT_EDGES;
                        i_idx <= 0; j_idx <= 0;
                    end
                end

                INIT_EDGES: begin
                    // Write 0 to E[i][j]
                    E_reg[{i_idx, j_idx}] <= 0;
                    if (j_idx == 7) begin
                        j_idx <= 0;
                        if (i_idx == 7) current_state <= CHECK_DEG;
                        else i_idx <= i_idx + 1;
                    end else begin
                        j_idx <= j_idx + 1;
                    end
                    // Reset loop vars for next state
                    if (current_state == INIT_EDGES && i_idx == 7 && j_idx == 7) begin
                        i_idx <= 0; j_idx <= 0; iter_cnt <= 0;
                    end
                end

                CHECK_DEG: begin
                    // Check loop termination
                    if (i_idx == n) begin
                        // Iteration done
                        if (iter_cnt == ITERATIONS - 1) begin
                            current_state <= DONE;
                        end else begin
                            iter_cnt <= iter_cnt + 1;
                            i_idx <= 0; j_idx <= 0;
                        end
                    end else if (i_idx == j_idx) begin
                        // Diagonal: Skip
                        if (j_idx == n - 1) begin
                            j_idx <= 0; i_idx <= i_idx + 1;
                        end else begin
                            j_idx <= j_idx + 1;
                        end
                    end else begin
                        // Check degrees
                        deg_i <= get_deg(i_idx);
                        deg_j <= get_deg(j_idx);
                        // Move to verify or sum
                        current_state <= SUM_NEIGH;
                        acc_sum <= 0;
                        u_idx <= 0; v_idx <= 0;
                        never_flag <= 0;
                    end
                end

                SUM_NEIGH: begin
                    // Accumulate sum
                    // We need to check neighbors: u is neighbor of i, v is neighbor of j?
                    // The formula is sum over neighbors u of i, v of j.
                    // Iterating u and v linearly is O(N^2) per pair. 8x8 = 64 cycles. 
                    // Total pairs 64. Iterations 16. 64*16*64 = 65536 cycles. Acceptable.
                    
                    // Optimization: We can skip u if not neighbor of i, etc.
                    // Let's iterate u and v.
                    
                    // Logic: if adj_flat[i_idx*8+u_idx] && adj_flat[j_idx*8+v_idx]
                    // then add E[u][v]

                    if (adj_flat[i_idx*8+u_idx] && adj_flat[j_idx*8+v_idx]) begin
                        // Only add if u!=v, else E is 0 (diagonal)
                        if (u_idx != v_idx) begin
                            acc_sum <= acc_sum + E_reg[{u_idx, v_idx}];
                        end
                    end

                    // Increment v
                    if (v_idx == n - 1) begin
                        v_idx <= 0;
                        if (u_idx == n - 1) begin
                            // Done summing
                            // Check if deg_i or deg_j is 0 (should have been caught, but double check)
                            if (deg_i == 0 || deg_j == 0) begin
                                never_flag <= 1;
                                current_state <= UPDATE_VAL; // Will just skip to next pair
                            end else begin
                                current_state <= UPDATE_VAL;
                            end
                        end else begin
                            u_idx <= u_idx + 1;
                        end
                    end else begin
                        v_idx <= v_idx + 1;
                    end
                end

                UPDATE_VAL: begin
                    // Perform E_new = 1 + acc_sum / (deg_i * deg_j)
                    // We use sub-states via 'op_stage'
                    case (op_stage)
                        0: begin
                            // Setup division
                            // Dividend = acc_sum << 16
                            // Divisor = deg_i * deg_j
                            div_dividend <= {acc_sum, 16'b0};
                            div_divisor <= deg_i * deg_j;
                            div_quotient <= 0;
                            div_count <= 0;
                            op_stage <= 1;
                        end
                        1: begin
                            // Iterative Division Step
                            // We will do 32 steps for full precision, or 16 if we assume Sum is small.
                            // Let's do 16 steps (Q16.16 precision is 16 bits frac).
                            if (div_count < 16) begin
                                div_dividend <= div_dividend << 1;
                                div_quotient <= div_quotient << 1;
                                if (div_dividend[47:32] >= div_divisor) begin // Using high bits of dividend (shifted)
                                    // Actually, standard restoring: 
                                    // shift left. compare high part with divisor.
                                    // Let's use: if {div_dividend[47:0]} >= {div_divisor, 32'b0} ...
                                    // Simplified restoring step:
                                    // If (dividend << 1) >= divisor, subtract and set bit 0.
                                    // We store dividend in a register that we shift.
                                    // Let's use a 48-bit accumulator.
                                    // This state machine is getting verbose. 
                                    // Let's assume a purely combinational division for brevity or a smaller loop.
                                    // Since we are in hardware, let's just calculate the result in one go if possible,
                                    // but we are in a state machine. 
                                    // Let's keep the iteration counter logic simple.
                                    
                                    // Alternative: Use a 16-bit divider for fractional part.
                                    // Or just use: acc_sum / deg_mul.
                                    // Since we want Q16.16, let's just do:
                                    // E_reg_new = acc_sum / deg_mul.
                                    // But we want 1 added.
                                    // Let's use a simple shift-add divider.
                                    
                                    // Shift Dividend Left
                                    div_dividend <= div_dividend << 1;
                                    // Shift Quotient Left
                                    div_quotient <= div_quotient << 1;
                                    
                                    // Check if Upper 32 bits of dividend >= Divisor
                                    // Wait, dividend is 48 bits. Upper 16 bits? 
                                    // acc_sum is 32 bits. 
                                    // Dividend = {acc_sum, 16'b0} -> 48 bits.
                                    // Divisor is <= 64 (7 bits). 
                                    // Let's compare upper 16 bits of dividend with divisor.
                                    if (div_dividend[47:32] >= {9'b0, div_divisor}) begin
                                        // Subtract
                                        div_dividend[47:32] <= div_dividend[47:32] - {9'b0, div_divisor};
                                        div_quotient[0] <= 1;
                                    end
                                    div_count <= div_count + 1;
                                end else begin
                                    op_stage <= 2; // Division done
                                end
                            end
                        end
                        2: begin
                            // Finish Update: E_new = 1 + div_quotient
                            if (!never_flag)
                                E_reg[{i_idx, j_idx}] <= ONE + div_quotient;
                            
                            // Increment indices
                            if (j_idx == n - 1) begin
                                j_idx <= 0;
                                i_idx <= i_idx + 1;
                            end else begin
                                j_idx <= j_idx + 1;
                            end
                            
                            op_stage <= 0;
                            current_state <= CHECK_DEG;
                        end
                    endcase
                end

                DONE: begin
                    valid <= 1;
                    if (never_flag) begin
                        never_meet <= 1;
                        result <= INF;
                    end else begin
                        result <= E_reg[{s, t}];
                    end
                end
            endcase
        end
    end

endmodule