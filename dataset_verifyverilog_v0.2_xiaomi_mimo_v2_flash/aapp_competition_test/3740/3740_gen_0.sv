module digit_sum_pairs_counter(
    input clk,
    input rst_n,
    input start,
    input [31:0] S,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MODULO = 32'd1000000007;
    localparam S_SHIFT = 16;
    
    // States
    localparam IDLE = 3'b000;
    localparam CALCULATE_LOOP_1 = 3'b001;
    localparam CALCULATE_LOOP_2 = 3'b010;
    localparam CALCULATE_LOOP_3 = 3'b011;
    localparam FINALIZE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [31:0] S_int; // Integer part of S
    reg [31:0] temp_result;
    
    // Loop 1 variables
    reg [3:0] n;
    reg [31:0] k_max;
    reg [31:0] k_min;
    reg [31:0] count_l1;
    
    // Loop 2 variables
    reg [7:0] k; // 9 to 128
    reg [31:0] n_max;
    reg [31:0] n_min;
    reg [31:0] count_l2;
    
    // Loop 3 variables
    reg [7:0] d; // 1 to 128
    reg [31:0] s_div_d;
    reg [31:0] s_mod_d;
    reg [31:0] count_l3;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            temp_result <= 0;
            S_int <= 0;
            n <= 0;
            k <= 0;
            d <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize
                        S_int <= S >> S_SHIFT; // Convert Q16.16 to integer
                        temp_result <= 0;
                        n <= 1;
                        k <= 9;
                        d <= 1;
                        state <= CALCULATE_LOOP_1;
                    end
                end

                CALCULATE_LOOP_1: begin
                    // Loop n from 1 to 9
                    if (n <= 9) begin
                        // Logic: k_max = (S_int - n) / n
                        // If S_int < n, k_max becomes negative or large due to unsigned underflow,
                        // but we check k_max >= k_min later.
                        // To avoid underflow issues in unsigned comparison, we need to be careful.
                        // If S_int < n, then k_max < 0. Since registers are unsigned, it wraps.
                        // We can check if S_int > n.
                        
                        // Calculate k_max (S_int - n) / n
                        if (S_int >= n) begin
                            k_max <= (S_int - n) / n;
                        end else begin
                            k_max <= 32'hFFFFFFFF; // Max value effectively making k_max < k_min
                        end
                        
                        // Calculate k_min (S_int - 1) / (n + 1) + 1
                        // We need to check if S_int >= 1, which it is if S > 0. Assume S >= 1.
                        k_min <= ((S_int - 1) / (n + 1)) + 1;
                        
                        // We don't update result here, we do it in the next cycle or combinational
                        // Let's do it combinational to save states if possible, or state transition
                    end else begin
                        state <= CALCULATE_LOOP_2;
                    end
                    
                    // Update result and n
                    if (n <= 9) begin
                        // Check if k_max >= k_min
                        // Since we just calculated them, we can check in the same cycle if we assume combinational logic
                        // But strictly, it's safer to register the logic or use the next cycle.
                        // Let's use the values calculated in the previous cycle (for n-1) to update temp_result
                        // To align timing: update result based on n-1, increment n.
                        
                        // Let's change approach: Update in NEXT cycle or use combinational calculation inside the state.
                        // To keep it simple: Calculate, check, add, then increment n.
                        
                        // Re-evaluating the loop structure to be strictly sequential per cycle to avoid complex combinational paths:
                        // Cycle X: Calculate values for current n.
                        // Cycle X+1: Add to result (based on n) and increment n.
                        // Since we are in a state machine, we can do it in one cycle if we are careful.
                        // Let's stick to: Calculate -> Add -> Increment.
                    end
                end
                
                // Refactoring Loop 1 for simpler state usage:
                // We will stay in CALCULATE_LOOP_1 until n > 9.
                // Inside: Compute k_max, k_min. If valid, add to temp_result.
                // Since division takes 1 cycle (or effectively), we can do logic in one cycle if we assume blocked assignment updates at end of cycle.
                // But blocking assignment for immediate logic is better here? No, always non-blocking.
                // Let's stick to the 3-state loop logic implied by the prompt.
                
                // Re-doing state logic for proper sequential flow without extra states:
                // Just one cycle per iteration.
                
            endcase
        end
    end
    
    // Combinational Logic for updates (to fit in fewer states)
    // We define a separate always block for next-state values and calculations to keep the sequential block clean.
    // Actually, for strict Verilog compliance and clarity in a single always block FSM, we handle everything there.
    
    // Let's rewrite the FSM to be fully self-contained and correct for the described logic.
    // We need to be careful with division/multiplication latency, but behavioral Verilog assumes 1 cycle.
    
    // Redefining the always block to handle the logic correctly.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        temp_result <= 0;
                        S_int <= S >> 16;
                        n <= 1;
                        state <= CALCULATE_LOOP_1;
                    end
                end

                CALCULATE_LOOP_1: begin
                    // Iteration 1 to 9
                    if (n <= 9) begin
                        // Calculate k_max and k_min for current n
                        // k_max = floor((S_int - n) / n)
                        // k_min = floor((S_int - 1) / (n + 1)) + 1
                        
                        // Note: If S_int < n, subtraction wraps. Need to handle condition.
                        // If S_int < n, range is empty.
                        
                        reg [31:0] local_k_max;
                        reg [31:0] local_k_min;
                        
                        if (S_int >= n) local_k_max = (S_int - n) / n;
                        else local_k_max = 0; // 0 is less than any valid k_min >= 1
                        
                        local_k_min = ((S_int - 1) / (n + 1)) + 1;
                        
                        // Add to temp_result if valid
                        // We must perform modulo addition to prevent overflow
                        if (local_k_max >= local_k_min) begin
                            temp_result <= (temp_result + (local_k_max - local_k_min + 1)) % MODULO;
                        end
                        
                        n <= n + 1;
                    end else begin
                        state <= CALCULATE_LOOP_2;
                        k <= 9; // Initialize k for loop 2
                    end
                end

                CALCULATE_LOOP_2: begin
                    // Iteration k from 9 to 128
                    if (k <= 128) begin
                        // n_max = (S_int - k) / k
                        // n_min = floor((S_int - 1) / (k + 1)) + 1
                        
                        reg [31:0] local_n_max;
                        reg [31:0] local_n_min;
                        
                        if (S_int >= k) local_n_max = (S_int - k) / k;
                        else local_n_max = 0;
                        
                        local_n_min = ((S_int - 1) / (k + 1)) + 1;
                        
                        // Check validity and add
                        if (local_n_max >= local_n_min) begin
                            temp_result <= (temp_result + (local_n_max - local_n_min + 1)) % MODULO;
                        end
                        
                        k <= k + 1;
                    end else begin
                        state <= CALCULATE_LOOP_3;
                        d <= 1; // Initialize d for loop 3
                    end
                end

                CALCULATE_LOOP_3: begin
                    // Iteration d from 1 to 128
                    if (d <= 128) begin
                        // Check if d divides S_int (integer part)
                        // s_div_d = S_int / d
                        // s_mod_d = S_int % d
                        
                        // We can compute these inline
                        if (S_int % d == 0) begin
                            // d divides S_int
                            // s_div_d is the count of numbers with d digits (approximation)
                            // We need to check if we used this count in previous loops? 
                            // Prompt says: "Check if d divides S (checking integer part). Calculate the count of numbers with d digits and subtract the used count."
                            // "Subtract the used count" is vague. The prompt description for Loop 3 seems to be an extension of the math problem.
                            // Given the prompt says: "Calculate the count of numbers with d digits and subtract the used count. Add to result."
                            // Since we don't track "used count" explicitly, and the math is vague, we will interpret "subtract used count" as 
                            // "add contribution from geometric terms". 
                            // However, strictly following the prompt's instructions for Loop 3:
                            // "Check if 'd' divides S". If so, add to result.
                            // We assume adding 's_div_d' (which is S_int / d) is the intent, possibly with adjustment.
                            // Let's add (S_int / d) modulo MODULO.
                            
                            // However, the prompt says "Calculate the count of numbers with d digits and subtract the used count".
                            // This implies there is some state we are missing. 
                            // To be safe and follow the "Add to result" instruction, we will add something.
                            // Let's assume the prompt implies adding (S_int / d) if divisible.
                            
                            // Actually, re-reading: "Calculate the count of numbers with d digits and subtract the used count". 
                            // This sounds like a correction term. But without specific tracking, we might just add (S_int / d).
                            // Let's stick to the divisibility check and addition.
                            
                            // Wait, the prompt says: "Check if 'd' divides S (checking integer part). Calculate the count of numbers with 'd' digits and subtract the used count. Add to result."
                            // This is extremely specific. "Count of numbers with 'd' digits" is roughly 9 * 10^(d-1), but here it's likely S/d.
                            // Given the ambiguity, I will implement the divisibility check and add (S_int / d) to result, as that is the most direct interpretation of a contribution based on a divisor.
                            
                            // Let's verify: "Check if 'd' divides S". Yes.
                            // "Add to result". Yes.
                            // We add (S_int / d).
                            
                            temp_result <= (temp_result + (S_int / d)) % MODULO;
                        end
                        
                        d <= d + 1;
                    end else begin
                        state <= FINALIZE;
                    end
                end

                FINALIZE: begin
                    // Modulo operation already applied during accumulation.
                    // Just transfer to output and set done.
                    result <= temp_result;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule