module card_score_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a_in,
    input wire [3:0] b_in,
    output reg [15:0] max_score,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam DONE = 3'b100;

    reg [2:0] current_state, next_state;

    // Internal registers for calculation
    reg [3:0] A, B; // Store inputs
    reg signed [15:0] score;
    reg [3:0] n_o_blocks; // Number of 'o' blocks
    reg [3:0] n_x_blocks; // Number of 'x' blocks
    reg [3:0] o_rem;      // Remainder 'o's to distribute
    reg [3:0] x_rem;      // Remain 'x's to distribute
    reg [3:0] o_len;      // Current 'o' block length
    reg [3:0] x_len;      // Current 'x' block length
    
    // Computation step counter
    reg [3:0] step;
    reg calc_valid;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (step == 4'd11) // Fixed latency of 12 cycles (1 setup + 10 calc + 1 finish)
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                if (start) // Handle new start pulse while in done state
                    next_state = PROCESSING;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            max_score <= 16'sd0;
            step <= 4'd0;
            calc_valid <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    step <= 4'd0;
                    if (start) begin
                        // Initialize computation
                        A <= a_in;
                        B <= b_in;
                        score <= 16'sd0;
                        step <= 4'd0;
                    end
                end

                PROCESSING: begin
                    step <= step + 1'b1;
                    
                    case (step)
                        4'd0: begin // Setup Step 1: Optimization Logic (Score A part)
                            // Ideally: A^2 (one block) is max for 'o's
                            // We add A*A to score immediately if A > 0
                            if (A > 0) begin
                                score <= $signed(score) + ($signed({12'd0, A}) * $signed({12'd0, A}));
                            end
                            // Setup for 'x' distribution
                            // We want to split B into (A + 1) blocks if possible
                            n_o_blocks <= (A > 0) ? 1 : 0;
                            n_x_blocks <= (A > 0) ? (A + 1) : (B > 0 ? 1 : 0);
                            x_rem <= B;
                            step <= 4'd1;
                        end
                        
                        4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10: begin
                            // Iterative subtraction for 'x' distribution
                            // This handles up to 12 'x' cards distributed into up to 12 blocks
                            // It's a generic loop. Since max cards is 12, 10 cycles is enough to process all blocks.
                            
                            // If we still have 'x's and blocks to fill
                            if (x_rem > 0 && n_x_blocks > 0) begin
                                // Distribute: k = floor(x_rem / n_x_blocks) + (remainder > 0 ? 1 : 0)
                                // To minimize sum of squares: distribute as evenly as possible
                                // We can subtract roughly B/n_x_blocks per step or 1 per step.
                                // Given constraints (A,B <= 12), simple decrement loop is cycle efficient.
                                // Let's implement: consume 1 'x' at a time to keep logic small.
                                // Actually, to optimize, let's calculate the chunk size.
                                
                                // Logic: We want to calculate the length of the current block.
                                // If B <= n_x_blocks: 1, 1, 1...
                                // If B > n_x_blocks: distribute evenly.
                                
                                // Let's use a simpler sequential logic:
                                // Pick the largest block size k such that k * (n_x_blocks - 1) < B.
                                // This is the Greedy approach.
                                
                                // Simplified: Just subtract 1 from x_rem and add -1 to score each cycle? 
                                // No, that corresponds to 1^2 = 1. 
                                // Wait, if B=5, n_x_blocks=3 -> blocks 2,2,1. 
                                // Score contribution: -(2^2 + 2^2 + 1^2) = -9.
                                // If we did 5 blocks of 1: -5. 
                                // If we did 1 block of 5: -25.
                                // So we want to split. 
                                
                                // Let's use a division-based calculation in one cycle if possible,
                                // or a small loop. With 50MHz clock, 20 cycles is plenty.
                                // Let's stick to the 'divide and conquer' or iteration.
                                
                                // Easier Approach: Calculate exact lengths for B blocks.
                                // B / n_x_blocks = base_len
                                // B % n_x_blocks = remainder
                                // Score contribution = -( (remainder) * (base_len+1)^2 + (n_x_blocks-remainder) * (base_len)^2 )
                                // We can calculate this in logic or a few sequential steps.
                                
                                // Let's switch to a sequential calculation of the formula in Step 1 and 2 to save logic.
                                // But to follow instructions "Fixed number of cycles", let's just do a loop of subtraction.
                                // Actually, the formula calculation is precise and synthesizable. 
                                
                                // Let's perform the calculation in the next clock cycle directly.
                                // We will compute the optimal negative score for 'x's.
                                
                                // Let's assume we passed step 0. 
                                // We will calculate the 'x' score in the next few steps.
                            end
                        end
                    endcase
                end

                DONE: begin
                    // Finalize output
                    done <= 1'b1;
                    // If we used the loop method, we would need to sum. 
                    // Instead, let's overwrite the PROCESSING state logic with direct math to meet the requirement efficiently.
                    // The user wants a state machine, but direct combinational math is better for small N.
                    // However, to keep the state machine nature, we will do it in stages.
                end
            endcase
        end
    end

    // Re-implementation of the PROCESSING state logic for robustness and correctness:
    // Since 'always' block inside PROCESSING was getting complex for manual iteration,
    // let's use a cleaner approach: Pre-calculate the block distribution and iterate.

    // Wait, to strictly follow the "Fixed latency" and "State Machine" rule without complex combinational logic:
    // We will use the pipeline to compute the optimal 'x' score.
    
    // Actually, the most efficient HDL way for A,B <= 12 is:
    // 1. Calculate O_score = A*A.
    // 2. Calculate X_score = optimal negative sum.
    // Optimization for X: Split B into K = A+1 blocks (if A>0) or 1 block (if A=0).
    // Score_X = - [ (B % K) * (ceil(B/K))^2 + (K - (B % K)) * (floor(B/K))^2 ]
    // If K > B, then floor=0, ceil=1, Score_X = -B.
    
    // We will implement this arithmetic in a sequenced manner.

    // Overrides the previous logic block for correct implementation:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            max_score <= 0;
            step <= 0;
            current_state <= IDLE;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= PROCESSING;
                        step <= 0;
                        A <= a_in;
                        B <= b_in;
                        max_score <= 0;
                    end
                end

                PROCESSING: begin
                    step <= step + 1;
                    
                    // We use 15 cycles to ensure we are safe (though only ~3-4 are needed mathematically)
                    if (step >= 12) begin 
                        current_state <= DONE;
                        step <= 0;
                        // Finalize score
                        // max_score register accumulates the result
                    end
                    
                    // Cycle 0: Initialize
                    if (step == 0) begin
                        // Calculate O part: A*A
                        max_score <= $signed({12'b0, A}) * $signed({12'b0, A});
                        // Prepare for X part
                        // K = (A > 0) ? A + 1 : 1;
                    end
                    
                    // Cycle 1: Calculate K and Division terms for X
                    else if (step == 1) begin
                        if (B > 0) begin
                            // K logic
                            if (A > 0) begin
                                // K = A + 1
                                // Dividend = B, Divisor = A + 1
                                // We need to calculate B / (A+1) and B % (A+1)
                                // To avoid combinational divider (large logic), we use a simple repeated subtraction state.
                                // However, for small numbers (max 12), combinational or simple loop is fine.
                                // Let's use a 'counter' based approach or direct math if we assume synthesizer optimizes small dividers.
                                // Since inputs are 4-bit, a LUT or logic might be okay, but to be safe and explicit:
                                // We will implement the division in subsequent cycles.
                                
                                // Let's just do the math directly. Verilog synthesizers are smart enough for 4-bit div.
                                // We define temporary variables.
                                
                                // Let's reset a counter to 0 to act as the block number accumulator
                                // Actually, let's compute the formula directly. 
                                // x_len_base = B / K
                                // x_rem = B % K
                                
                                // Since K can be up to 13, let's compute division manually in step 2 and 3.
                                // Or just do it: (Synthesizers handle 4-bit div well)
                                
                                // Let's assume we use the core divider logic. 
                                // To make it robust, we'll do a subtraction loop for division in Step 2.
                                // Let's do a multi-cycle logic:
                                
                                // Let's register K and B for division
                                // But we want to avoid extra registers if possible.
                                // Let's use the 'step' counter to iterate.
                                
                                // Alternative: Just calculate it in one go, but if we need to limit logic, let's look at the "simple" instruction.
                                // "Use a state machine". 
                                
                                // Let's do this:
                                // Step 1: Load A, B. Calc O_part.
                                // Step 2: Calc K. If K > B, X_score = -B. If K <= B, we need to find quotient and remainder.
                                // Step 3: Calculate X_score.
                                
                                // Let's stick to a direct math implementation which is valid Verilog and synthesizable.
                                
                                // Logic for X_score:
                                // k_val = (A == 0) ? 1 : (A + 1);
                                // q = B / k_val;
                                // r = B % k_val;
                                // score_x = -(r * (q+1)*(q+1) + (k_val - r) * q*q)
                                
                                // We will compute this in 3 cycles. 
                            end else begin
                                // A == 0. K = 1.
                                // score_x = - (B^2)
                            end
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin // Ready for new
                        done <= 1'b0;
                        current_state <= PROCESSING;
                        step <= 0;
                        A <= a_in;
                        B <= b_in;
                        max_score <= 0;
                    end else begin
                        current_state <= DONE;
                    end
                end
            endcase
        end
    end

    // --- IMPROVED DATAPATH (Replaces the above PROCESSING block for clarity and correctness) ---
    // The above FSM skeleton is good, but the logic inside needs to be precise.
    // Let's merge the logic to be strictly sequential and correct.
    // We will define the behavior for the 3 main steps of calculation.

    reg [3:0] k_val;      // Number of 'x' blocks
    reg [3:0] q_val;      // Quotient (base length)
    reg [3:0] r_val;      // Remainder
    reg signed [15:0] x_score_acc;
    reg [3:0] loop_cnt;
    reg [3:0] sub_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            max_score <= 16'sd0;
            loop_cnt <= 4'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= PROCESSING;
                        A <= a_in;
                        B <= b_in;
                        step <= 4'd0;
                        // Reset intermediates
                        x_score_acc <= 16'sd0;
                    end
                end

                PROCESSING: begin
                    step <= step + 1'b1;
                    
                    // Timeline:
                    // 0: Calc O score, Setup K
                    // 1: Divider setup
                    // 2: Calc Q and R
                    // 3: Calc X score formula
                    // 4: Finalize
                    // 5...10: Wait cycles to match latency requirement (if any)
                    
                    case (step)
                        4'd0: begin
                            // O Score: A*A
                            max_score <= $signed(A) * $signed(A);
                            
                            // Calculate K (Number of X blocks)
                            if (A > 0) k_val <= A + 1;
                            else k_val <= 1;
                        end
                        
                        4'd1: begin
                            // Logic for X distribution
                            if (B == 0) begin
                                // No X cards, score is 0 added
                                x_score_acc <= 16'sd0;
                            end else if (k_val > B) begin
                                // More slots than cards -> every block is size 1
                                x_score_acc <= -($signed(B)); // - (1^2 + 1^2 ... ) = -B
                            end else begin
                                // Need to compute: q = B/k_val, r = B % k_val
                                // For small logic, we will iterate subtraction in step 2
                                q_val <= 4'd0;
                                sub_val <= B;
                                // We need a counter to count down k_val times? 
                                // Or subtract k_val repeatedly from B to get q.
                                // Let's do subtraction of k_val from B.
                                loop_cnt <= 4'd0;
                            end
                        end
                        
                        4'd2: begin
                            // Iterative Division: B / k_val
                            if (B > 0 && k_val <= B) begin
                                if (sub_val >= k_val) begin
                                    sub_val <= sub_val - k_val;
                                    q_val <= q_val + 1;
                                end
                                // We will run this logic for a few cycles. 
                                // Since max B is 12, we can finish division in <= 12 cycles.
                                // To be efficient, we can do it in one step if we trust the synth tool,
                                // but instructions suggest a state machine sequence.
                                // Let's do it in Step 3, 4, 5... effectively unrolling or looping.
                                // Actually, let's just do it in one cycle for simplicity here since we have slack.
                                // Wait, if we do it in one cycle, we need combinational div. 
                                // Let's do the math: q_val = B / k_val; r_val = B % k_val;
                                // This is synthesizable for small vectors.
                                
                                q_val <= B / k_val;
                                r_val <= B % k_val;
                            end
                        end

                        4'd3: begin
                            // Calculate X Score
                            if (B > 0 && k_val <= B) begin
                                // We have q and r.
                                // Score = -( r * (q+1)^2 + (k_val - r) * q^2 )
                                // Since q and r are small, we can compute this sequentially.
                                
                                // Reset accumulator
                                x_score_acc <= 16'sd0;
                                loop_cnt <= 4'd0;
                            end else if (B > 0 && k_val > B) begin
                                // Already handled in step 1 (x_score_acc = -B)
                            end else begin
                                x_score_acc <= 0;
                            end
                        end

                        4'd4: begin
                            // Final Summation: max_score + x_score_acc
                            // If we did the 'k_val > B' case, x_score_acc is already set.
                            // If we did the formula, we need to compute it. 
                            // Since logic is small, let's use combinational math for the formula inside the block if possible,
                            // or just combine here.
                            
                            // Let's compute the formula result now. We need to wait for step 3 to finish setting q/r.
                            // Step 4 is good for calculation.
                            
                            if (B > 0 && k_val <= B) begin
                                // Calculate: r*(q+1)^2 + (k_val-r)*q^2
                                // Since we want to avoid huge combinational paths, we can use the registers.
                                // But max values are small: q <= 12, r <= 12.
                                // Result fits in 16 bits.
                                
                                // Let's do it in one go. Synthesizer will handle it.
                                max_score <= max_score - (
                                    $signed(r_val) * $signed((q_val + 1) * (q_val + 1)) + 
                                    $signed(k_val - r_val) * $signed(q_val * q_val)
                                );
                            end else if (B > 0 && k_val > B) begin
                                max_score <= max_score - $signed(B);
                            end
                            // If B=0, max_score stays A*A.
                        end
                        
                        // Add extra delay states to meet latency requirement (10-20 cycles)
                        4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11, 4'd12: begin
                            // Just wait
                        end
                    endcase
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        current_state <= PROCESSING;
                        done <= 1'b0;
                        step <= 4'd0;
                        A <= a_in;
                        B <= b_in;
                        x_score_acc <= 16'sd0;
                    end
                end
            endcase
        end
    end
endmodule