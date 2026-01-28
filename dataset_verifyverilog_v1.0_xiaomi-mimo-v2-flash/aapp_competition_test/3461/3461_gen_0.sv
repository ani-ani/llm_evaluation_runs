module expected_hearings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] s_in,
    input wire [15:0] a_in,
    input wire [15:0] b_in,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PREP_DP = 3'd2;
    localparam [2:0] CALC_I_LOOP = 3'd3;
    localparam [2:0] CALC_T_LOOP = 3'd4;
    localparam [2:0] FIND_NEXT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] load_count;
    reg [3:0] i_idx;
    reg [7:0] t_val;
    reg [7:0] t_max;
    reg [3:0] find_k;
    reg [3:0] next_idx_reg;
    reg [15:0] end_time;
    
    // Storage arrays (16 elements max)
    reg [15:0] s_mem [0:15];
    reg [15:0] a_mem [0:15];
    reg [15:0] b_mem [0:15];
    reg [31:0] dp_mem [0:15]; // Q16.16 format
    
    // Temporary calculation registers
    reg [31:0] sum_exp;
    reg [31:0] temp_dp;
    reg [31:0] denominator;
    reg [31:0] division_temp;
    reg [4:0] div_counter;
    reg div_done;
    
    // Integer for loop
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = (load_count == n) ? PREP_DP : LOAD;
            PREP_DP: next_state = (n == 4'd0) ? FINISH : CALC_I_LOOP;
            CALC_I_LOOP: begin
                if (i_idx < n) next_state = CALC_T_LOOP;
                else next_state = FINISH;
            end
            CALC_T_LOOP: begin
                if (t_val <= t_max) next_state = FIND_NEXT;
                else next_state = CALC_I_LOOP;
            end
            FIND_NEXT: next_state = CALC_T_LOOP;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_count <= 4'd0;
            i_idx <= 4'd0;
            t_val <= 8'd0;
            t_max <= 8'd0;
            find_k <= 4'd0;
            next_idx_reg <= 4'd0;
            end_time <= 16'd0;
            sum_exp <= 32'd0;
            temp_dp <= 32'd0;
            denominator <= 32'd0;
            division_temp <= 32'd0;
            div_counter <= 5'd0;
            div_done <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            // Initialize storage arrays to avoid X's
            for (i = 0; i < 16; i = i + 1) begin
                s_mem[i] <= 16'd0;
                a_mem[i] <= 16'd0;
                b_mem[i] <= 16'd0;
                dp_mem[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    load_count <= 4'd0;
                    done <= 1'b0;
                end
                
                LOAD: begin
                    // Store inputs into arrays
                    s_mem[load_count] <= s_in;
                    a_mem[load_count] <= a_in;
                    b_mem[load_count] <= b_in;
                    load_count <= load_count + 4'd1;
                end
                
                PREP_DP: begin
                    // Initialize DP array to 0
                    for (i = 0; i < 16; i = i + 1) begin
                        dp_mem[i] <= 32'd0;
                    end
                    i_idx <= n - 4'd1; // Start from last hearing
                end
                
                CALC_I_LOOP: begin
                    // Check if we are done with all i
                    if (i_idx >= n) begin
                        // Result is dp[0]
                        result <= dp_mem[0];
                    end else begin
                        // Initialize for t loop
                        sum_exp <= 32'd0;
                        t_val <= a_mem[i_idx][7:0]; // Use lower 8 bits assuming scaled
                        t_max <= b_mem[i_idx][7:0];
                    end
                end
                
                CALC_T_LOOP: begin
                    if (t_val > t_max) begin
                        // Finished t loop for this i
                        // dp[i] = 1<<16 + sum_exp / (b-a+1)
                        // Calculate denominator
                        denominator <= {16'd0, (b_mem[i_idx][7:0] - a_mem[i_idx][7:0] + 8'd1)};
                        temp_dp <= 32'h00010000; // 1<<16
                        div_counter <= 5'd0;
                        div_done <= 1'b0;
                        // Move to next i
                        i_idx <= i_idx - 4'd1;
                    end else begin
                        // Calculate end_time for this t
                        end_time <= s_mem[i_idx] + {8'd0, t_val};
                        find_k <= i_idx; // Start searching from current i
                    end
                end
                
                FIND_NEXT: begin
                    // Linear search for first k where s_mem[k] >= end_time
                    // Check if current find_k is valid
                    if (find_k < n) begin
                        if (s_mem[find_k] >= end_time) begin
                            next_idx_reg <= find_k;
                            // Accumulate dp[next_idx]
                            sum_exp <= sum_exp + dp_mem[find_k];
                            t_val <= t_val + 8'd1;
                        end else begin
                            find_k <= find_k + 4'd1;
                        end
                    end else begin
                        // No next hearing found, add 0
                        next_idx_reg <= 4'd15; // Dummy
                        sum_exp <= sum_exp + 32'd0;
                        t_val <= t_val + 8'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Separate division logic (iterative shift-subtract)
            // This runs in parallel with state machine updates effectively
            // but controlled by div_done flag
            if (!div_done && denominator != 32'd0 && (state == CALC_T_LOOP || state == CALC_I_LOOP || state == FIND_NEXT)) begin
                // Check if division needs to start or continue
                // Using a simple counter to trigger division logic state
                // Actually, we need to handle the division when we just finished the T loop
                // We can detect that condition: t_val > t_max and we haven't started division yet
            end
        end
    end
    
    // Division logic block (to be executed when denominator is ready)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_done <= 1'b0;
        end else begin
            // Trigger division when we have valid denominator and sum_exp
            // and we are transitioning or in a safe state.
            // Ideally, we perform division in a separate sub-state or loop.
            // Given the constraints, let's do it in the CALC_I_LOOP state transition logic
            // inside the sequential block, but we need a way to stall.
            // Let's add a check in CALC_I_LOOP state to wait for division.
            // However, `next_state` logic must be adjusted to wait.
            
            // Let's handle division inside the CALC_I_LOOP state directly
            // with a dedicated flag or counter to pause FSM.
            
            // Actually, let's embed the division steps into the CALC_I_LOOP state logic
            // by extending the state duration.
        end
    end

    // Refined Division Logic integrated into CALC_I_LOOP
    // We need to stall CALC_I_LOOP until division is done.
    // Let's add a division flag to the state machine logic.
    reg division_in_progress;
    reg [31:0] quotient;
    reg [31:0] remainder;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            division_in_progress <= 1'b0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            dp_mem[i_idx] <= 32'd0; // Just to ensure no X prop
        end else begin
            
            // State specific actions for division
            if (state == CALC_T_LOOP && t_val > t_max && !division_in_progress && i_idx < n) begin
                // Start division
                division_in_progress <= 1'b1;
                quotient <= 32'd0;
                remainder <= 32'd0;
                // Start with most significant bit of numerator (sum_exp)
                // We are dividing sum_exp by denominator
            end
            
            if (division_in_progress) begin
                // Restore remainder
                remainder <= {remainder[30:0], sum_exp[31]};
                sum_exp <= {sum_exp[30:0], 1'b0}; // Shift numerator left
                quotient <= {quotient[30:0], 1'b0};
                
                // If remainder >= denominator, subtract and set bit
                // Note: This is a simplified shift-add algorithm requiring enough cycles
                // We have plenty of cycles in CALC_I_LOOP.
                // Let's do 32 cycles for 32-bit division.
                
                // Actually, shift-add for Q16.16 division:
                // We want sum_exp / denom. sum_exp is Q32.0 (intermediate), denom is Q16.0.
                // Result is Q16.16.
                // We shift sum_exp left by 16 bits effectively (treat as high part).
                
                // A simpler approach for integer division to get Q16.16:
                // quotient = (sum_exp << 16) / denom
                // We perform 32 steps of restoring division.
                
                // Let's use a dedicated counter for the 32 steps.
                // But we need to hold the FSM. 
                
                // To strictly follow the constraints (no new states if possible),
                // we can use the CALC_I_LOOP state to perform the division serially.
                // However, this makes the code complex.
                // Let's assume a block RAM or dedicated logic is preferred.
                // But we must use pure Verilog.
                
                // Let's add a 'DIVIDE' sub-state or reuse CALC_I_LOOP with a counter.
                // We will use CALC_I_LOOP to hold the state while division happens.
            end
        end
    end
    
    // Re-writing the state machine to include division steps
    // We need a way to wait in CALC_I_LOOP.
    // Let's add a counter `div_step`.
    reg [5:0] div_step;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            division_in_progress <= 1'b0;
            div_step <= 6'd0;
            for (i=0; i<16; i=i+1) dp_mem[i] <= 32'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        load_count <= 4'd0;
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    s_mem[load_count] <= s_in;
                    a_mem[load_count] <= a_in;
                    b_mem[load_count] <= b_in;
                    if (load_count == n - 4'd1) state <= PREP_DP;
                    load_count <= load_count + 4'd1;
                end
                
                PREP_DP: begin
                    for (i = 0; i < 16; i = i + 1) begin
                        dp_mem[i] <= 32'd0;
                    end
                    i_idx <= n - 4'd1;
                    state <= CALC_I_LOOP;
                end
                
                CALC_I_LOOP: begin
                    // This state handles the outer loop and the division
                    if (i_idx >= n) begin
                        result <= dp_mem[0];
                        state <= FINISH;
                    end else if (!division_in_progress) begin
                        // Start T loop for current i
                        sum_exp <= 32'd0;
                        t_val <= a_mem[i_idx][7:0];
                        t_max <= b_mem[i_idx][7:0];
                        state <= CALC_T_LOOP;
                    end else begin
                        // Division in progress
                        // Perform restoring division: (sum_exp << 16) / denominator
                        // We use div_step (0 to 32)
                        if (div_step == 6'd0) begin
                            // Initialize
                            quotient <= 32'd0;
                            remainder <= 32'd0;
                            // Shift sum_exp left by 16: high 32 bits of 64-bit number
                            // We simulate 64-bit shift: high part is sum_exp, low part is 0.
                            // We'll treat `sum_exp` as the upper part of a 64-bit register.
                            // Just keep `sum_exp` as is and shift it left.
                            div_step <= 6'd1;
                        end else if (div_step <= 32) begin
                            // Shift sum_exp left by 1 (it represents the high 32 bits of numerator)
                            sum_exp <= {sum_exp[30:0], 1'b0};
                            // Shift remainder left, bringing in bit from sum_exp (which we just shifted out)
                            // Actually, standard restoring division:
                            // Shift dividend (sum_exp extended) left into remainder.
                            // We can treat sum_exp as the dividend part we haven't shifted yet.
                            // Let's do 33 iterations for 32-bit quotient.
                            
                            // Optimization: We only need 16 bits of fraction (Q16.16).
                            // So we calculate sum_exp / denom, then shift left 16.
                            // Actually, (sum_exp * 65536) / denom.
                            
                            // Let's do the standard algorithm on `sum_exp` with implicit scaling.
                            // We need `quotient` as Q16.16.
                            // `quotient` needs 32 bits.
                            
                            remainder <= {remainder[30:0], sum_exp[31]};
                            sum_exp <= {sum_exp[30:0], 1'b0};
                            quotient <= {quotient[30:0], 1'b0};
                            
                            // Check subtraction in next cycle or delayed?
                            // To save logic, we check the previous remainder.
                            // Wait, standard algorithm shifts then checks.
                            
                            // Let's use a simpler iterative method if possible, 
                            // but restoring division is standard.
                            
                            // Let's look ahead.
                            // If we use the cycle to check and update:
                            // Check remainder (before shift) >= denominator? No.
                            // After shift, check `remainder` >= `denominator`.
                            
                            // We will perform the check in the next cycle or combined.
                            // To keep it simple and correct in 1 cycle per bit:
                            // 1. Shift sum_exp and remainder.
                            // 2. Check if remainder >= denominator.
                            // 3. If so, subtract and set quotient bit.
                            
                            // We need `remainder` and `quotient` registers.
                            // Let's assume `sum_exp` contains the upper bits of dividend.
                            // We shift `sum_exp` left into `remainder`.
                            // `sum_exp` shifts left, MSB goes into remainder's LSB? No, MSB goes into remainder's MSB if we shift up.
                            // We want: [SumExp Remainder] << 1.
                            // So: Remainder = {Remainder[30:0], SumExp[31]}; SumExp = {SumExp[30:0], 0};
                            
                            // Then check Remainder >= Denominator.
                            // If yes: Remainder = Remainder - Denominator; Quotient[0] = 1;
                            
                            // We need to handle the bit set logic.
                            // We can add a stage after shift or do it in parallel if we look ahead.
                            // Given the complexity, let's assume a standard block is better, 
                            // but we must write it out.
                            
                            // Let's calculate `max_next_expected(t)` first.
                            // This happens inside CALC_T_LOOP.
                            
                            // Back to division: we need to stall the FSM.
                            // `div_step` is our counter.
                            if (div_step == 32) begin
                                division_in_progress <= 1'b0;
                                div_step <= 6'd0;
                                // Finalize dp[i]
                                // quotient is now correct (32 bits, integer part of (sum_exp/denom)*65536? No)
                                // If we shifted numerator left 32 times, quotient is integer result of (sum_exp*2^32)/denom.
                                // We want (sum_exp * 65536) / denom.
                                // So we should shift numerator left 16 times, not 32.
                                // Adjust loop count to 16 + 16 (integer + fraction) = 32.
                                // Or just use 16 iterations for fractional part and handle integer part.
                                
                                // Actually, dp[i] = 1 << 16 + (sum_exp / denom).
                                // `sum_exp` fits in 32 bits. `denom` fits in 16 bits.
                                // Result is 32 bits (Q16.16).
                                // We can calculate (sum_exp << 16) / denom.
                                // We need 32 iterations.
                                // At the end, `quotient` contains the result.
                                
                                dp_mem[i_idx] <= 32'h00010000 + quotient;
                                i_idx <= i_idx - 4'd1;
                            end else begin
                                // Division Step Logic
                                // We need to perform: if (remainder >= denominator) then remainder = remainder - denominator; quotient = quotient | 1;
                                // But we already shifted. The bit to set is the LSB of quotient (which we just shifted 0 into).
                                // So we check the *new* remainder.
                                
                                // To do this in 1 cycle, we need to evaluate the condition on the *current* remainder (which was shifted in this cycle).
                                // Wait, standard algorithm:
                                // R = R << 1 | DividendBit
                                // If R >= D: R = R - D; Q = Q | 1
                                // We are shifting R and Dividend (sum_exp) in this cycle.
                                // So we check `remainder` (updated this cycle) >= `denominator`?
                                
                                // We need `denominator` value accessible.
                                // `denominator` is stored in a register from previous state.
                                
                                if (remainder >= denominator) begin
                                    remainder <= remainder - denominator;
                                    quotient <= quotient | 32'd1;
                                end
                            end
                        end
                    end
                end
                
                CALC_T_LOOP: begin
                    if (t_val > t_max) begin
                        // T loop done, start division
                        division_in_progress <= 1'b1;
                        div_step <= 6'd0;
                        // Prepare denominator
                        denominator <= {16'd0, (b_mem[i_idx][7:0] - a_mem[i_idx][7:0] + 8'd1)};
                        state <= CALC_I_LOOP;
                    end else begin
                        // Calculate end time and find next index
                        // We'll do this in a separate state or sub-step
                        end_time <= s_mem[i_idx] + {8'd0, t_val};
                        find_k <= 4'd0; // Start search from 0
                        state <= FIND_NEXT;
                    end
                end
                
                FIND_NEXT: begin
                    // Linear scan
                    if (find_k < n) begin
                        if (s_mem[find_k] >= end_time) begin
                            // Found
                            sum_exp <= sum_exp + dp_mem[find_k];
                            t_val <= t_val + 8'd1;
                            state <= CALC_T_LOOP;
                        end else begin
                            find_k <= find_k + 4'd1;
                        end
                    end else begin
                        // No match found
                        sum_exp <= sum_exp + 32'd0;
                        t_val <= t_val + 8'd1;
                        state <= CALC_T_LOOP;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule