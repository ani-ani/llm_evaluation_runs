module election_winner (
    input clk,
    input rst_n,
    input start,
    input [7:0] total_delegates,
    input [7:0] state_delegates_0,
    input [7:0] state_delegates_1,
    input [7:0] state_delegates_2,
    input [15:0] state_c_0,
    input [15:0] state_c_1,
    input [15:0] state_c_2,
    input [15:0] state_f_0,
    input [15:0] state_f_1,
    input [15:0] state_f_2,
    input [15:0] state_u_0,
    input [15:0] state_u_1,
    input [15:0] state_u_2,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);

    // State encoding
    localparam IDLE = 4'b0001;
    localparam CALCULATE_COSTS = 4'b0010;
    localparam SORT = 4'b0100;
    localparam SELECT = 4'b1000;

    reg [3:0] state;
    reg [3:0] next_state;

    // Storage for processed states
    reg [7:0]  proc_del [0:2];
    reg [31:0] proc_cost [0:2];
    reg        proc_valid [0:2];

    // Intermediate calculation registers
    reg signed [31:0] f_val;
    reg signed [31:0] c_val;
    reg signed [31:0] u_val;
    reg signed [31:0] diff;
    reg signed [31:0] raw_cost;
    reg signed [31:0] adj_cost;

    // Sort registers
    reg [7:0] s_del [0:2];
    reg [31:0] s_cost [0:2];
    reg [1:0] i; // sort loop counter
    reg [1:0] j; // sort loop counter
    reg swap;

    // Selection registers
    reg [7:0] acc_del;
    reg [31:0] acc_cost;
    reg [1:0] k; // selection loop counter
    reg [31:0] temp_cost [0:2];
    reg [7:0] temp_del [0:2];
    reg [1:0] min_idx;
    reg [31:0] min_val;
    reg [1:0] l; // min finding loop
    reg [31:0] temp_sum;

    // State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALCULATE_COSTS;
                else next_state = IDLE;
            end
            CALCULATE_COSTS: begin
                // 3 cycles to compute costs
                if (i == 2) next_state = SORT; // Use i as step counter here
                else next_state = CALCULATE_COSTS;
            end
            SORT: begin
                // Bubble sort - simplified control (runs fixed iterations)
                // Ideally we iterate 3 times to ensure sorted
                if (i == 3) next_state = SELECT;
                else next_state = SORT;
            end
            SELECT: begin
                // Greedy selection
                if (k == 3) next_state = DONE;
                else next_state = SELECT;
            end
            default: next_state = IDLE;
        endcase
    end

    // Logic for CALCULATE_COSTS, SORT, SELECT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 0;
            j <= 0;
            k <= 0;
            done <= 0;
            impossible <= 0;
            result <= 0;
            proc_valid[0] <= 0;
            proc_valid[1] <= 0;
            proc_valid[2] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    i <= 0;
                    j <= 0;
                    k <= 0;
                end

                CALCULATE_COSTS: begin
                    // Sequential computation for each state index 0, 1, 2
                    case (i)
                        0: begin
                            // F - C + U + 2 (Q16.16) -> Logic for state 0
                            f_val <= {16'h0000, state_f_0};
                            c_val <= {16'h0000, state_c_0};
                            u_val <= {16'h0000, state_u_0};
                            proc_del[0] <= state_delegates_0;
                        end
                        1: begin
                            diff <= f_val - c_val; // F - C
                            // Wait for next cycle logic or combine? Let's combine stages if possible, 
                            // but pipeline registers f_val, c_val, u_val.
                            // Actually, better to do calculation in steps if not enough time.
                            // Let's do calculations directly based on inputs for state 0
                            // But we are in a state machine, so we process sequentially.
                            // Recalculating state 0 here to keep logic contained in one block per cycle is tricky.
                            // Let's assume i acts as a step counter for state 0, then state 1, etc.
                            // Optimization: Process 3 states in 3 clock cycles total.
                            // Cycle 0: Load 0
                            // Cycle 1: Calc 0, Load 1
                            // Cycle 2: Calc 1, Load 2
                            // Cycle 3: Calc 2
                            // We need 4 cycles. Let's use i=0,1,2,3 for processing states.
                            
                            // Revised Logic for Calc:
                            // i=0: inputs state 0, wait
                            // i=1: calc state 0, inputs state 1, wait
                            // i=2: calc state 1, inputs state 2, wait
                            // i=3: calc state 2
                            // Let's stick to the request: "Maximum 256 clock cycles".
                            // We have plenty of time.
                        end
                    endcase
                end
                
                // Let's rewrite the combinational/sequential logic cleanly
            endcase
        end
    end

    // Detailed Calculation Logic
    // To ensure validity, we implement the calculation, sort, and select explicitly.
    // Since we can't nest sequential always blocks, we combine them.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            impossible <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            // Initialize sorted arrays to avoid latch
            s_del[0] <= 0; s_del[1] <= 0; s_del[2] <= 0;
            s_cost[0] <= 0; s_cost[1] <= 0; s_cost[2] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    i <= 0;
                    k <= 0;
                end

                CALCULATE_COSTS: begin
                    // Pipeline: Cycle 1 (i=0) -> State 0
                    if (i == 0) begin
                        // Cost = (F - C + U + 2) / 2
                        // F, C, U are Q16.16. +2 is essentially 2 * 2^16 if we consider the fractional part.
                        // Actually, input is Q16.16. F-C+U is Q16.16.
                        // The formula (F-C+U+2)/2 usually implies integer math on the vote counts.
                        // Assuming inputs are 16-bit fractionals, the integer part is upper 16 bits.
                        // To make Q16.16 logic work:
                        // Let's treat inputs as raw values.
                        // raw_diff = state_f_0 - state_c_0 + state_u_0 + 2.
                        // Note: The "2" addition in the formula likely refers to the integer 2, not scaled.
                        // Since result is Q16.16, we need to scale the constant 2.
                        // Scaled 2 = 2 * 65536 = 131072.
                        // Wait, the prompt says "Inputs are already in Q16.16".
                        // But the formula suggests integer inputs. Let's assume "2" means integer 2 
                        // added to the sum, which is Q16.16. This operation is ambiguous.
                        // Let's assume the formula is for integer inputs, but inputs are Q16.16.
                        // If inputs are Q16.16, we need to be careful. 
                        // "Simplified: Need to convince >= floor((F - C + U + 2) / 2) voters"
                        // If F, C, U are votes (Q16.16), the integer part is [31:16].
                        // Let's assume we are calculating in the integer domain.
                        // We take upper 16 bits of inputs, or treat the inputs as integers with high precision.
                        // To be safe and following typical electoral math (which is integer):
                        // Let's assume the inputs represent integer values stored in Q16.16 format (lower 16 bits zero).
                        // If the prompt meant fractional values, the division by 2 is standard.
                        // Let's calculate: diff = (F - C) + U.
                        // If diff < 0, cost = 0.
                        // Else cost = (diff + 2) / 2.
                        // We must output Q16.16. So if we calculate integer cost, we multiply by 65536.
                        // Or maybe the result is scaled. "Result in Q16.16 format, divide by 256 for final answer"
                        // This suggests we keep Q16.16 internally, or just keep integer precision.
                        // Let's stick to integer math on the upper bits for simplicity and robustness.
                        // Extract integer parts (upper 16 bits).
                        // However, the prompt says "inputs are already in Q16.16, no conversion needed".
                        // This implies the algorithm operates on the full 32-bit Q16.16 values.
                        // (F - C + U) is Q16.16.
                        // Adding 2 (integer) means adding 2 * 2^16 = 131072.
                        // Divide by 2 (right shift by 1) -> Q16.16 result.
                        // Let's implement this generic logic.
                        
                        // State 0 Calculation
                        if (state_f_0 >= state_c_0 + state_u_0) begin
                            // F >= C + U implies U < 0 (impossible) or just winning strictly?
                            // Logic: "If C >= F + U, state is won with 0 cost".
                            // Wait, "If C >= F + U" -> C >= F + U -> C - F - U >= 0 -> Need 0 cost.
                            // Otherwise, cost = (F - C + U + 2) / 2.
                            if ({16'h0000, state_c_0} >= ({16'h0000, state_f_0} + {16'h0000, state_u_0})) begin
                                proc_cost[0] <= 0;
                            end else begin
                                // Calculate (F - C + U + 2)
                                // Note: 2 in Q16.16 is 131072. 
                                // But the formula usually comes from integer votes. 
                                // Let's assume "2" is the integer 2 added to the integer part.
                                // To be safe, let's assume inputs are integers. 
                                // If inputs are Q16.16, we take the upper 16 bits.
                                // Let's re-read carefully: "Inputs are already in Q16.16, no conversion needed".
                                // But cost formula implies integer math. 
                                // Let's perform calculation on the full values but scaled appropriately.
                                // Let's assume the "2" is meant to be small compared to votes.
                                // Let's implement: cost = ( (F - C + U) + 2 ) >> 1.
                                // Wait, if F, C, U are scaled by 65536, then 2 must be scaled too if result is Q16.16.
                                // If result is Q16.16, 2 is 2 * 65536.
                                // Let's assume inputs are integers and we treat them as Q16.16.
                                // i.e. F = state_f_0 << 16? No, "inputs are Q16.16".
                                // So we have F_top = state_f_0.
                                // Let's do this: We want result in Q16.16.
                                // cost_int = (F_top - C_top + U_top + 2) >> 1.
                                // result = cost_int << 16.
                                // Let's extract top bits.
                                
                                // Actually, simplest approach for "Q16.16 format":
                                // Sum = state_f_0 - state_c_0 + state_u_0;
                                // Add 2 (scaled): Sum = Sum + 2 * 65536.
                                // Shift right 1: Cost = Sum >> 1.
                                // This preserves Q16.16 format.
                                // If F-C+U is negative, we already handled zero cost case.
                                proc_cost[0] <= ( ({16'h0000, state_f_0} - {16'h0000, state_c_0} + {16'h0000, state_u_0} + 32'd131072) >> 1 );
                            end
                            proc_del[0] <= state_delegates_0;
                            proc_valid[0] <= 1;
                            i <= 1; // Advance to next state
                        end
                    end else if (i == 1) begin
                        // State 1 Calc
                        if ({16'h0000, state_c_1} >= ({16'h0000, state_f_1} + {16'h0000, state_u_1})) begin
                            proc_cost[1] <= 0;
                        end else begin
                            proc_cost[1] <= ( ({16'h0000, state_f_1} - {16'h0000, state_c_1} + {16'h0000, state_u_1} + 32'd131072) >> 1 );
                        end
                        proc_del[1] <= state_delegates_1;
                        proc_valid[1] <= 1;
                        i <= 2;
                    end else if (i == 2) begin
                        // State 2 Calc
                        if ({16'h0000, state_c_2} >= ({16'h0000, state_f_2} + {16'h0000, state_u_2})) begin
                            proc_cost[2] <= 0;
                        end else begin
                            proc_cost[2] <= ( ({16'h0000, state_f_2} - {16'h0000, state_c_2} + {16'h0000, state_u_2} + 32'd131072) >> 1 );
                        end
                        proc_del[2] <= state_delegates_2;
                        proc_valid[2] <= 1;
                        // Reset i for Sort phase or use separate counter. 
                        // Let's use i for sorting now. Reset i to 0.
                        i <= 0;
                        // We transition to SORT state in next cycle automatically via next_state logic.
                    end
                end

                SORT: begin
                    // Bubble sort: Compare adjacent pairs (0,1) and (1,2)
                    // We need to iterate this a few times. Let's do 3 passes.
                    // Pass 0: (0,1), (1,2)
                    // Pass 1: (0,1), (1,2)
                    // Pass 2: (0,1), (1,2)
                    // Using 'i' as pass counter.
                    
                    // Initialize s arrays from proc at start of sort if i==0
                    if (i == 0) begin
                        s_cost[0] <= proc_cost[0]; s_del[0] <= proc_del[0];
                        s_cost[1] <= proc_cost[1]; s_del[1] <= proc_del[1];
                        s_cost[2] <= proc_cost[2]; s_del[2] <= proc_del[2];
                        i <= 1; // Start pass 1
                    end else begin
                        // Perform comparisons for current pass
                        // (0,1)
                        if (s_cost[0] > s_cost[1]) begin
                            s_cost[0] <= s_cost[1]; s_del[0] <= s_del[1];
                            s_cost[1] <= s_cost[0]; s_del[1] <= s_del[0];
                        end
                        // (1,2)
                        if (s_cost[1] > s_cost[2]) begin
                            s_cost[1] <= s_cost[2]; s_del[1] <= s_del[2];
                            s_cost[2] <= s_cost[1]; s_del[2] <= s_del[1];
                        end
                        
                        if (i < 3) i <= i + 1;
                        else i <= 0; // Done sorting
                    end
                end

                SELECT: begin
                    // Greedy selection: Pick cheapest until delegates >= total_delegates
                    // We need to process the sorted array (s_cost, s_del)
                    // We use 'k' as index for sorted items.
                    // We accumulate in 'acc_del' and 'acc_cost'.
                    
                    // Reset accumulators at first step
                    if (k == 0) begin
                        acc_del <= 0;
                        acc_cost <= 0;
                    end
                    
                    // Check if we still need delegates AND if the current state helps
                    // Only add if we haven't met requirement yet
                    if (acc_del < total_delegates) begin
                        // If the next state brings us closer (or just add it)
                        // Greedy means add if we need it, or accumulate all? 
                        // "Pick cheapest states until delegates >= total_delegates"
                        // So add if (acc_del < total_delegates).
                        // Note: Might overshoot, that's fine.
                        if (k < 3) begin
                            // Optimization: Check if adding this state is necessary? 
                            // Just add it if we haven't reached goal.
                            if (acc_del < total_delegates) begin
                                acc_del <= acc_del + s_del[k];
                                acc_cost <= acc_cost + s_cost[k];
                            end
                            k <= k + 1;
                        end else begin
                            // k >= 3 and still not enough delegates -> Impossible
                            // But we transition to DONE. Let's check impossible flag there.
                        end
                    end else begin
                        // Already have enough, we can stop early or continue. 
                        // Let's continue to consume cycles if needed, or jump to done.
                        // To keep it simple, let's just finish the loop or transition.
                        // We will transition when k reaches 3.
                        if (k < 3) k <= k + 1;
                    end

                    // Final check at end of loop (k=3)
                    if (k == 3) begin // Actually, logic inside sets k to 3 in next cycle, this block executes at k=3?
                        // No, if k==3 we are done. 
                        // Let's do the output logic here when we are done with the loop.
                        // We need to detect "Done" state.
                        // The next_state logic says if k==3 go to DONE.
                        // So this block runs when state=SELECT and k=0,1,2.
                        // When k increments to 3, next cycle is DONE.
                    end
                end

                default: begin // DONE (Implicit or explicit)
                    if (state == DONE) begin // This is not a valid case label usually, let's handle done outside or in default if we had a DONE state. 
                        // Since I didn't explicitly encode DONE in localparam, let's catch it or modify state machine.
                        // Actually, my localparam didn't include DONE. Let's assume the state machine goes to IDLE or a DONE state.
                        // Let's fix: IDLE -> CALC -> SORT -> SELECT -> DONE (Implicit IDLE).
                        // Let's assume next_state returns IDLE for DONE.
                    end
                end
            endcase
        end
    end

    // Handle Output and DONE state logic
    // Since I used IDLE as the "done" return, let's handle output generation in a separate always block or refine the one above.
    // To keep it clean: Let's use a specific DONE state or check 'k' and 'i' in IDLE/SELECT.
    
    // Correction: The state machine logic above jumps to DONE if k==3.
    // So we need a DONE state.
    // Let's modify the logic to explicitly include DONE.
    
    // Re-evaluating state machine for valid Verilog: 
    // State 0: IDLE
    // State 1: CALCULATE
    // State 2: SORT
    // State 3: SELECT
    // State 4: FINISH
    
    // Let's inject the DONE state logic into the existing FSM by checking conditions.
    // The previous logic "if (k==3) next_state = DONE" implies a DONE state exists.
    // I will define it now.

    // Rewriting the combinational next_state logic to be safe:
    // We will assume the user wants a standard FSM.

    // Let's restart the sequential block cleanly with the fixed state machine.

    // Redefining States to include DONE explicitly to avoid confusion.
    localparam S_IDLE = 3'd0;
    localparam S_CALC = 3'd1;
    localparam S_SORT = 3'd2;
    localparam S_SEL  = 3'd3;
    localparam S_DONE = 3'd4;

    reg [2:0] c_state, n_state;
    reg [1:0] calc_idx;
    reg [1:0] sort_pass;
    reg [1:0] sel_idx;

    // Next State Logic
    always @(*) begin
        case (c_state)
            S_IDLE: n_state = start ? S_CALC : S_IDLE;
            S_CALC: n_state = (calc_idx == 3) ? S_SORT : S_CALC;
            S_SORT: n_state = (sort_pass == 3) ? S_SEL : S_SORT;
            S_SEL:  n_state = (sel_idx == 3) ? S_DONE : S_SEL;
            S_DONE: n_state = S_IDLE; // Self-loop or return to idle
            default: n_state = S_IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_state <= S_IDLE;
            done <= 0;
            impossible <= 0;
            result <= 0;
            calc_idx <= 0;
            sort_pass <= 0;
            sel_idx <= 0;
            // Init arrays
            proc_valid[0] <= 0; proc_valid[1] <= 0; proc_valid[2] <= 0;
        end else begin
            c_state <= n_state;

            case (c_state)
                S_IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    calc_idx <= 0;
                    sort_pass <= 0;
                    sel_idx <= 0;
                end

                S_CALC: begin
                    // Process 3 states in 3 cycles (calc_idx 0, 1, 2). Transition when calc_idx == 3.
                    case (calc_idx)
                        0: begin // Calc State 0
                            // Check logic: If C >= F + U -> 0 cost.
                            // F, C, U are Q16.16. Let's assume they are integers (upper 16 bits zero).
                            // If inputs are truly fractional, the math holds if we treat them as integers.
                            // To be robust, let's assume inputs are integer values in Q16.16.
                            // We perform math on the full 32-bit words but assuming lower 16 bits are zero or negligible.
                            // Specifically, we take the logic: (F - C + U + 2) / 2.
                            // If F, C, U are scaled by 65536, then 2 must be scaled by 65536 too.
                            // But usually these "2" votes are integers. 
                            // Let's assume the prompt implies integer math on the vote counts.
                            // We'll take the upper 16 bits of inputs for the calculation.
                            
                            // Let's extract integer votes (upper 16 bits) to be safe with the formula.
                            // Inputs are [15:0], so they ARE the values. 
                            // If they are Q16.16, then value = input << 16.
                            // The prompt says "Inputs are already in Q16.16".
                            // And "Result in Q16.16 format, divide by 256 for final answer".
                            // Let's stick to the formula given: (F - C + U + 2) / 2.
                            // If we want Q16.16 output, we do:
                            // diff = F - C + U. (All Q16.16)
                            // if (C >= F + U) cost = 0.
                            // else cost = (diff + 131072) >> 1. (131072 is 2 in Q16.16)
                            
                            // However, if inputs are integers stored in Q16.16 (e.g. 1000 votes = 1000 << 16),
                            // then F-C+U is large.
                            // Let's assume inputs are the raw values. 
                            // We check: if (state_c_0 >= state_f_0 + state_u_0) -> 0 cost.
                            // Else cost = (state_f_0 - state_c_0 + state_u_0 + 2) / 2. 
                            // Wait, if inputs are Q16.16, +2 means +2 * 65536.
                            // Let's calculate: 
                            // temp_diff = state_f_0 + state_u_0 - state_c_0;
                            // If temp_diff[31] (negative) -> cost = 0. 
                            // Else cost = (temp_diff + 131072) >> 1.
                            
                            if (state_c_0 >= state_f_0 + state_u_0) begin
                                proc_cost[0] <= 0;
                            end else begin
                                proc_cost[0] <= (state_f_0 - state_c_0 + state_u_0 + 32'd131072) >> 1;
                            end
                            proc_del[0] <= state_delegates_0;
                        end
                        1: begin // Calc State 1
                            if (state_c_1 >= state_f_1 + state_u_1) begin
                                proc_cost[1] <= 0;
                            end else begin
                                proc_cost[1] <= (state_f_1 - state_c_1 + state_u_1 + 32'd131072) >> 1;
                            end
                            proc_del[1] <= state_delegates_1;
                        end
                        2: begin // Calc State 2
                            if (state_c_2 >= state_f_2 + state_u_2) begin
                                proc_cost[2] <= 0;
                            end else begin
                                proc_cost[2] <= (state_f_2 - state_c_2 + state_u_2 + 32'd131072) >> 1;
                            end
                            proc_del[2] <= state_delegates_2;
                        end
                    endcase
                    calc_idx <= calc_idx + 1;
                end

                S_SORT: begin
                    // Bubble Sort Logic
                    // We use s_cost/s_del as working registers.
                    // Initialize on first pass (sort_pass == 0)
                    if (sort_pass == 0) begin
                        s_cost[0] <= proc_cost[0]; s_del[0] <= proc_del[0];
                        s_cost[1] <= proc_cost[1]; s_del[1] <= proc_del[1];
                        s_cost[2] <= proc_cost[2]; s_del[2] <= proc_del[2];
                        sort_pass <= 1;
                    end else begin
                        // Perform comparisons: (0,1) then (1,2)
                        if (s_cost[0] > s_cost[1]) begin
                            s_cost[0] <= s_cost[1]; s_del[0] <= s_del[1];
                            s_cost[1] <= s_cost[0]; s_del[1] <= s_del[0];
                        end
                        if (s_cost[1] > s_cost[2]) begin
                            s_cost[1] <= s_cost[2]; s_del[1] <= s_del[2];
                            s_cost[2] <= s_cost[1]; s_del[2] <= s_del[1];
                        end
                        if (sort_pass < 3) sort_pass <= sort_pass + 1;
                    end
                end

                S_SEL: begin
                    // Greedy Selection
                    if (sel_idx == 0) begin
                        acc_del <= 0;
                        acc_cost <= 0;
                    end
                    
                    // Only add if we still need delegates
                    if (acc_del < total_delegates && sel_idx < 3) begin
                        acc_del <= acc_del + s_del[sel_idx];
                        acc_cost <= acc_cost + s_cost[sel_idx];
                    end
                    
                    sel_idx <= sel_idx + 1;
                end

                S_DONE: begin
                    // Determine final result and flags
                    if (acc_del >= total_delegates) begin
                        impossible <= 0;
                        // Result in Q16.16, divide by 256 for final answer scaling.
                        // "Divide by 256" -> Right shift 8.
                        // Result is already Q16.16. If we shift right 8, we lose precision.
                        // But the prompt explicitly asks for this.
                        // Example: 1000 voters (int) -> 1000*65536 (Q16.16). Divide by 256 -> 1000*256.
                        // This scaling seems odd but we follow instructions.
                        result <= acc_cost >> 8;
                        done <= 1;
                    end else begin
                        impossible <= 1;
                        result <= 0;
                        done <= 1;
                    end
                end
            endcase
        end
    end

endmodule
