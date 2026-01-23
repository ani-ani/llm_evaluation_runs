module even_odd_palindrome (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] even_count,
    output reg [7:0] odd_count,
    output reg done
);

    // State encoding
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_NEXT = 3'b010;
    localparam COUNT_UP = 3'b011;
    localparam DONE = 3'b100;

    // Internal variables
    reg [7:0] current_num;
    reg is_palindrome;
    reg [7:0] temp_val;
    reg [3:0] digit_hundreds;
    reg [3:0] digit_tens;
    reg [3:0] digit_ones;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            even_count <= 8'b0;
            odd_count <= 8'b0;
            done <= 1'b0;
            current_num <= 8'b0;
            is_palindrome <= 1'b0;
            temp_val <= 8'b0;
            digit_hundreds <= 4'b0;
            digit_tens <= 4'b0;
            digit_ones <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end else begin
                        state <= IDLE;
                    end
                end

                INIT: begin
                    even_count <= 8'b0;
                    odd_count <= 8'b0;
                    current_num <= 8'd1;
                    state <= CHECK_NEXT;
                end

                CHECK_NEXT: begin
                    // Check if we are done with the range
                    if (current_num > n) begin
                        state <= DONE;
                    end else begin
                        // Extract digits logic
                        // We assume synthesizable combinational logic is derived from state
                        // To ensure synthesis compatibility, we perform operations here
                        // using a temporary variable 'temp_val' assigned in previous cycle or defaults
                        temp_val <= current_num; // Load current number for calculation
                        
                        // Calculate digits for the next state logic (combinational based on temp_val)
                        // Note: In a sequential block, we calculate digits of the *next* cycle's temp_val
                        // But here we want to check 'current_num'.
                        // So we calculate digits of 'current_num' in this cycle.
                        
                        // Determine palindrome and update counters immediately to avoid extra states
                        // Logic for 1-255 range
                        
                        if (current_num < 8'd10) begin
                            // Single digit: 1-9 (Note: 0 is not in range 1-n, but if n=0, loop doesn't start)
                            is_palindrome <= 1'b1;
                        end else if (current_num < 8'd100) begin
                            // Two digits: 10-99
                            digit_tens <= current_num / 10;
                            digit_ones <= current_num % 10;
                            // Comparison will be done in next cycle or combinational logic
                            // To save cycles, let's do it here using combinational logic
                            // However, synthesizable code often prefers state separation or registered outputs.
                            // Let's do the extraction in this cycle and check in next cycle (COUNT_UP)
                            // Or we can do it all in one state if we are careful.
                            // Let's use a combinational block for digit extraction and palindrome check
                            // to avoid adding too many states.
                            // But since requirements ask for specific states, let's stick to CHECK_NEXT -> COUNT_UP
                            // In CHECK_NEXT we just prepare the check.
                            // Actually, let's just do the check here for single/two digits.
                            // For three digits, we need to extract hundreds.
                            if (current_num[3:0] == current_num[7:4]) // This works for 10-99 if interpreted as BCD or simple binary
                            // Wait, standard binary comparison of digits is needed.
                            // 15 (00001111) -> tens=1, ones=5. Not equal.
                            // We need division/modulo or string extraction.
                            // Let's use the helper variables computed via combinational logic.
                            // Since this is a single always block, we assign next values.
                            // Let's rely on the previous cycle's assignments or do it now.
                            
                            // Let's move to a state that computes digits, then checks.
                            state <= COUNT_UP; // Optimization: do check in this state if possible, else add state.
                            // Let's stick to the requirement: CHECK_NEXT extracts digits.
                        end else begin
                            // Three digits: 100-255
                            digit_hundreds <= current_num / 100;
                            digit_ones <= current_num % 10;
                            state <= COUNT_UP;
                        end
                        
                        // To satisfy the strict state requirement:
                        // We will use a combinational block outside the always block or inline logic.
                        // But standard practice: Let's define the check logic.
                        
                        // Let's re-evaluate: The prompt asks for specific states.
                        // Let's separate digit extraction into CHECK_NEXT and decision/counting into COUNT_UP.
                    end
                end

                COUNT_UP: begin
                    // Perform the check based on current_num (which was valid when we left CHECK_NEXT)
                    // To make this synthesizable without combinational blocks dependent on state variables,
                    // we calculate the 'is_palindrome' signal in CHECK_NEXT or use logic here.
                    // Let's assume 'is_palindrome' was set in CHECK_NEXT or we calculate it now.
                    // Actually, to be safe and sequential, let's calculate digits in CHECK_NEXT.
                    // So, we need to adjust the flow slightly to be robust.
                    // Let's insert an intermediate state or calculation.
                    // Or, simpler: Do calculation in COUNT_UP based on current_num.
                    // The prompt says "In CHECK_NEXT state, extract digits...".
                    // Let's do the extraction in CHECK_NEXT into registers, then check in COUNT_UP.
                    
                    // Re-reading CHECK_NEXT: It should extract digits.
                    // So let's move the extraction logic to CHECK_NEXT state fully.
                    // And let's add a state for the actual check if necessary, but the prompt implies CHECK_NEXT does it.
                    // Let's merge CHECK_NEXT and COUNT_UP functionality slightly for efficiency, 
                    // or strictly follow: Extract in CHECK_NEXT, Count in COUNT_UP.
                    
                    // Correction: I will put the digit extraction in CHECK_NEXT.
                    // Then in COUNT_UP, I check the digits and increment.
                    
                    // However, I already put extraction in CHECK_NEXT above (partial logic).
                    // Let's assume the extraction happened (values stored in digit_hundreds, etc).
                    // Wait, if I store them in CHECK_NEXT, they are available in COUNT_UP.
                    // So let's implement CHECK_NEXT to set digit registers.
                    
                    // Re-implementation of CHECK_NEXT logic below:
                    // (Overwriting previous logic in CHECK_NEXT for clarity)
                    // In CHECK_NEXT:
                    //   if (current_num < 10) is_palindrome_reg = 1;
                    //   else if (current_num < 100) begin tens = /10; ones = %10; end
                    //   else begin hundreds = /100; ones = %10; end
                    //   state <= COUNT_UP;
                    
                    // Now in COUNT_UP:
                    // Check criteria
                    if (current_num < 8'd10) begin
                        is_palindrome <= 1'b1;
                    end else if (current_num < 8'd100) begin
                        // We need tens and ones. 
                        // Let's calculate them here since we didn't store them in registers to save area,
                        // or we stored them in CHECK_NEXT.
                        // Let's assume we calculate them now inside COUNT_UP for correctness if CHECK_NEXT didn't store them.
                        // But CHECK_NEXT specifically said "extract digits".
                        // Let's use the digit registers.
                        // But wait, we need to calculate them in CHECK_NEXT first!
                        // So, let's move the calculation to CHECK_NEXT.
                        // I will modify the CHECK_NEXT block to calculate digits.
                        // And COUNT_UP will just check.
                        // Wait, if I calculate in CHECK_NEXT, I need to store them.
                        // Let's store them in 'temp_val' or new regs.
                        // Actually, let's just do the math in COUNT_UP to avoid adding more registers.
                        // The prompt says: "In CHECK_NEXT state, extract digits...".
                        // This implies CHECK_NEXT should do the work.
                        // Let's follow the prompt strictly.
                        
                        // Logic for COUNT_UP (assuming digits were extracted in CHECK_NEXT into 'digit_ones', 'digit_tens', 'digit_hundreds'):
                        // But I didn't fully implement the extraction in CHECK_NEXT above because I changed my mind.
                        // Let's refine.
                        
                        // Let's reset the flow:
                        // IDLE -> INIT -> CHECK_NEXT -> COUNT_UP -> (CHECK_NEXT if not done) -> DONE
                        
                        // In CHECK_NEXT (Detailed logic):
                        //   temp_val <= current_num;
                        //   If < 10: is_palindrome = 1.
                        //   If 10-99: digit_tens = temp_val/10; digit_ones = temp_val%10.
                        //   If 100-255: digit_hundreds = temp_val/100; digit_ones = temp_val%10.
                        //   Move to COUNT_UP.
                        
                        // In COUNT_UP:
                        //   Check condition:
                        //   If < 10: Palindrome.
                        //   Else if < 100: Compare digit_tens and digit_ones.
                        //   Else: Compare digit_hundreds and digit_ones.
                        //   If Palindrome: Check even/odd (current_num[0]). Increment.
                        //   Then current_num <= current_num + 1.
                        //   Move to CHECK_NEXT.
                        
                        // Let's rewrite the whole always block cleanly.
                        
                        // -----------------------------------------------------
                        // CLEAN REWRITE OF THE ALWAYS BLOCK
                        // -----------------------------------------------------
                        
                        case (state)
                            IDLE: begin
                                done <= 1'b0;
                                if (start) state <= INIT;
                            end
                            INIT: begin
                                even_count <= 8'b0;
                                odd_count <= 8'b0;
                                current_num <= 8'd1;
                                state <= CHECK_NEXT;
                            end
                            CHECK_NEXT: begin
                                if (current_num > n) begin
                                    state <= DONE;
                                end else begin
                                    // Extract digits logic (combinational inside sequential for this state)
                                    // We need to extract digits to be used in COUNT_UP.
                                    if (current_num < 8'd10) begin
                                        is_palindrome <= 1'b1; // Single digit
                                    end else if (current_num < 8'd100) begin
                                        // Two digits
                                        // We can't use / and % in a single always block efficiently without DSPs or wait states.
                                        // But for values up to 255, synthesis tools will use logic.
                                        // To be strictly Verilog and efficient:
                                        digit_tens <= current_num / 10;
                                        digit_ones <= current_num % 10;
                                        is_palindrome <= 1'b0; // Default
                                    end else begin
                                        // Three digits
                                        digit_hundreds <= current_num / 100;
                                        digit_ones <= current_num % 10;
                                        is_palindrome <= 1'b0; // Default
                                    end
                                    state <= COUNT_UP;
                                end
                            end
                            COUNT_UP: begin
                                // Check palindrome based on data computed in CHECK_NEXT
                                if (current_num < 8'd10) begin
                                    // is_palindrome was set in CHECK_NEXT
                                    if (current_num[0] == 1'b0) even_count <= even_count + 1;
                                    else odd_count <= odd_count + 1;
                                end else if (current_num < 8'd100) begin
                                    if (digit_tens == digit_ones) begin
                                        if (current_num[0] == 1'b0) even_count <= even_count + 1;
                                        else odd_count <= odd_count + 1;
                                    end
                                end else begin
                                    if (digit_hundreds == digit_ones) begin
                                        if (current_num[0] == 1'b0) even_count <= even_count + 1;
                                        else odd_count <= odd_count + 1;
                                    end
                                end
                                
                                // Increment number
                                current_num <= current_num + 1;
                                state <= CHECK_NEXT;
                            end
                            DONE: begin
                                done <= 1'b1;
                                if (!start) state <= IDLE; // Wait for start to go low before accepting new start
                                else state <= DONE; // Stay high
                            end
                            default: state <= IDLE;
                        endcase
                    end
                end
                // Due to the structure of the 'always' block above, I need to fix the structure.
                // The code above is inside the else(begin ... end) of the first if(!rst_n).
                // I will rewrite the internal case statement properly.
                
                // Corrected Always Block Structure:
                // ... (previous code)
                // The logic above in 'else' is a bit mixed. Let's make it clean.
                // I will rewrite the content of the 'else' block.
                
                // REWRITING THE BODY OF THE ALWAYS BLOCK FROM HERE:
                
                // Default assignments or flow control:
                // We need to handle the states defined.
                
                // (Reset block ends above)
            endcase
        end
    end
    
    // To ensure the code above is correct and synthesizable, 
    // let's rewrite the entire always block cleanly in one go within the final code block below.
    // The above was a thought process. The final code below is the clean version.

endmodule

// Helper: The code provided above inside the always block was fragmented.
// Below is the correct, clean implementation of the module.
// I will overwrite the module body in the final output.

module even_odd_palindrome (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] even_count,
    output reg [7:0] odd_count,
    output reg done
);

    // State encoding
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_NEXT = 3'b010;
    localparam COUNT_UP = 3'b011;
    localparam DONE = 3'b100;

    // Internal variables
    reg [7:0] current_num;
    reg [7:0] digit_hundreds;
    reg [7:0] digit_tens;
    reg [7:0] digit_ones;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            even_count <= 8'b0;
            odd_count <= 8'b0;
            done <= 1'b0;
            current_num <= 8'b0;
            digit_hundreds <= 8'b0;
            digit_tens <= 8'b0;
            digit_ones <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    even_count <= 8'b0;
                    odd_count <= 8'b0;
                    current_num <= 8'd1;
                    state <= CHECK_NEXT;
                end

                CHECK_NEXT: begin
                    if (current_num > n) begin
                        state <= DONE;
                    end else begin
                        // Extract digits based on magnitude
                        if (current_num < 8'd10) begin
                            // Single digit, no extraction needed for comparison
                            // We can flag it or handle in COUNT_UP
                            // Let's set a flag if we had one, but we can infer in COUNT_UP
                            // Just proceed to count
                            digit_hundreds <= 0; // Reset for safety
                            digit_tens <= 0;
                            digit_ones <= current_num;
                        end else if (current_num < 8'd100) begin
                            // Two digits
                            digit_tens <= current_num / 10;
                            digit_ones <= current_num % 10;
                            digit_hundreds <= 0;
                        end else begin
                            // Three digits
                            digit_hundreds <= current_num / 100;
                            digit_ones <= current_num % 10;
                            digit_tens <= (current_num / 10) % 10; // Not strictly needed for palindrome check but good for debug
                        end
                        state <= COUNT_UP;
                    end
                end

                COUNT_UP: begin
                    // Check palindrome
                    if (current_num < 8'd10) begin
                        // 1-9 are palindromes
                        if (current_num[0] == 1'b0) even_count <= even_count + 1;
                        else odd_count <= odd_count + 1;
                    end else if (current_num < 8'd100) begin
                        // 10-99: compare tens and ones
                        if (digit_tens == digit_ones) begin
                            if (current_num[0] == 1'b0) even_count <= even_count + 1;
                            else odd_count <= odd_count + 1;
                        end
                    end else begin
                        // 100-255: compare hundreds and ones
                        if (digit_hundreds == digit_ones) begin
                            if (current_num[0] == 1'b0) even_count <= even_count + 1;
                            else odd_count <= odd_count + 1;
                        end
                    end

                    // Increment number
                    current_num <= current_num + 1;
                    state <= CHECK_NEXT;
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for reset or start to go low and high again
                    // Standard practice: stay here until reset or restart
                    if (!start) state <= IDLE; // Restart sequence when start goes low
                    else state <= DONE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
