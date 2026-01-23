module expected_max_dice (
    input clk,
    input rst_n,
    input start,
    input [15:0] m,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state;
    reg [15:0] i_loop;          // Outer loop counter (1 to m)
    reg [15:0] j_loop;          // Inner loop counter (0 to n-1)
    reg [31:0] base;            // Q16.16: (i-1)/m
    reg [31:0] power;           // Q16.16: base^j_loop
    reg [31:0] accumulator;     // Q16.16: sum of P_max_ge_i
    reg [31:0] term;            // Q16.16: 1 - power
    reg [31:0] m_fixed;         // Q16.16: m
    reg [31:0] one_fixed;       // Q16.16: 1.0
    reg [31:0] temp_mul_high;   // 48-bit temporary for multiplication (upper 32 bits)
    reg [63:0] temp_mul_full;   // 64-bit full product
    
    // Helper logic for multiplication (32.32 result from two Q16.16 inputs)
    wire [63:0] mul_result;
    assign mul_result = $signed(base) * $signed(base);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'h0;
            done <= 1'b0;
            i_loop <= 16'h0;
            j_loop <= 16'h0;
            base <= 32'h0;
            power <= 32'h0;
            accumulator <= 32'h0;
            term <= 32'h0;
            m_fixed <= 32'h0;
            one_fixed <= 32'h0;
            temp_mul_high <= 32'h0;
            temp_mul_full <= 64'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize constants
                        m_fixed <= {m, 16'h0};            // m << 16
                        one_fixed <= 32'h00010000;        // 1.0 in Q16.16
                        accumulator <= 32'h0;
                        i_loop <= 16'h1;                 // Start i = 1
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    // Outer Loop: Iterate i from 1 to m
                    if (i_loop <= m) begin
                        
                        // Inner Loop: Calculate Power
                        if (j_loop == 16'h0) begin
                            // Initialization for new i
                            // Calculate base = (i_loop - 1) / m
                            // Q16.16: Numerator is ((i_loop - 1) << 16)
                            // Division is Numerator / m
                            if (i_loop > 16'h1) begin
                                base <= ({(i_loop - 1'b1), 16'h0}) / m_fixed;
                            end else begin
                                base <= 32'h0; // (1-1)/m = 0
                            end
                            power <= 32'h00010000; // 1.0 (base^0)
                            j_loop <= 16'h1;
                        end else if (j_loop <= n) begin
                            // Compute power = power * base
                            // Full 64-bit product: [63:32] [31:16] [15:0]
                            // Q16.16 * Q16.16 = Q32.32 (stored in 64-bit reg)
                            temp_mul_full <= $signed(power) * $signed(base);
                            
                            // Wait 1 cycle for multiplication pipeline
                            // (Logic split across cycles to meet timing/area constraints)
                            // In a real FPGA, this might be 2 cycles. Here we use j_loop increment 
                            // implicitly to create a pipeline stage or we just update next cycle.
                            // Given the specific prompt instructions to use loops, we'll do the update 
                            // effectively in the next state processing or combine operations if possible.
                            // To strictly follow 'multiply n times', we need a pipeline.
                            // Let's insert a dedicated pipeline state or register update.
                            // Actually, combinational multiplication + registered storage is standard.
                            // Since we update j_loop <= j_loop + 1, we need to store the result.
                            power <= temp_mul_full[47:16]; // Shift Q32.32 -> Q16.16 (rounding/truncate)
                            j_loop <= j_loop + 1'b1;
                        end else begin
                            // Inner loop done (j_loop > n)
                            // Calculate term = 1.0 - power
                            term <= one_fixed - power;
                            
                            // Reset j_loop for next i
                            j_loop <= 16'h0;
                            
                            // We need a cycle to commit the addition to accumulator
                            // to keep the logic distributed. 
                            // However, to keep it compact, let's do addition here and increment i.
                            // But wait, we just finished power calc. We need to add to accumulator.
                            // Let's do the addition in the *same* cycle we compute 1-power, 
                            // provided term is combinational or we use the registered 'term'.
                            // Since term is registered, it was updated in the previous cycle of the "else if" block.
                            // Wait, if we just computed term, it needs to be added.
                            // Let's add a small "Commit" micro-state or just overlap.
                            // Overlap strategy: 
                            // We are in ELSE (j_loop > n). 
                            // 1. Add 'term' to accumulator (term was updated in previous cycle of this else-if chain or we use logic).
                            // Let's restructure: The 'term' calculation happened in the previous cycle of j_loop exhaustion.
                            // So if we are here, 'term' holds the value for current i.
                            // No, wait. In the logic flow:
                            // Cycle X: j_loop == n. power updated. j_loop increments to n+1.
                            // Cycle X+1: j_loop > n. Enter this block. term = 1 - power (where power is from X). 
                            // Then we add to accumulator.
                            // 
                            // Optimization: Do the add immediately when term is ready, then increment i.
                            // But to avoid state explosion, we can do:
                            // 1. When j_loop == n: compute power. 
                            // 2. When j_loop == n+1: compute term, add to accumulator, increment i, reset j_loop.
                            // 
                            // Let's try a cleaner FSM approach with a helper state "ADD_STAGE".
                            // Or, we can do it in CALCULATE itself if we control the flow carefully.
                            
                            // Current Logic inside CALCULATE:
                            // If j_loop == 0: init power/base
                            // Else if j_loop <= n: multiply
                            // Else (j_loop > n): 
                            //    This block implies we are done with power.
                            //    But we need to calculate 1-power and add.
                            //    Since 'term' was just computed in the previous check (or needs to be).
                            //    Let's change the structure slightly to avoid an extra state.
                            //    
                            //    Actually, we can do this:
                            //    If j_loop == n: 
                            //       power = power * base
                            //       term = 1 - power
                            //       accumulator = accumulator + term
                            //       i_loop++
                            //       j_loop = 0
                            //    Else:
                            //       power = power * base
                            //       j_loop++
                            //       
                            //    Let's refine the conditions to combine steps.
                            //    Re-writing the inner loop logic:
                            //    
                            //    If j_loop == 0: init
                            //    Else if j_loop < n: power = power * base; j_loop++
                            //    Else if j_loop == n: power = power * base; accumulator += (1 - power); i_loop++; j_loop = 0;
                            //    
                            //    This requires checking j_loop == n specifically.
                            //    Let's implement this refined control flow.
                            
                            // Implementation of refined control flow:
                            if (j_loop < n) begin
                                // Still multiplying
                                temp_mul_full <= $signed(power) * $signed(base);
                                power <= temp_mul_full[47:16];
                                j_loop <= j_loop + 1'b1;
                            end else begin
                                // j_loop == n (We finished multiplying n times? Wait.
                                // j_loop counts 1 to n. 
                                // If n=5: 
                                // j_loop=1: power*=base (1 time)
                                // ...
                                // j_loop=5: power*=base (5th time). 
                                // Now we have base^5. 
                                // So we need to add (1 - power) and move to next i.
                                
                                // So condition is: if j_loop == n
                                // But we need to calculate power first.
                                
                                // Let's use the state machine to add a specific "Add" state if code gets messy, 
                                // but let's try to fit in one state with proper registers.
                                
                                // Actually, the code block structure in "always_ff" is rigid.
                                // Let's revert to the previous logic but add a specific check for completion.
                                // 
                                // Re-reading the prompt: "use a loop (counter for n iterations) to multiply".
                                // This implies an inner loop. 
                                // We will just use the 'j_loop' counter and when it exceeds n, we add.
                            end
                        end
                    end else begin
                        // Outer loop done (i_loop > m)
                        state <= DONE;
                        result <= accumulator;
                    end
                    
                    // FIX for the logic inside CALCULATE state:
                    // The above logic was getting nested. Let's rewrite the CALCULATE block explicitly for clarity and correctness.
                end
                
                // To make the code synthesizable and correct according to the loop description, 
                // let's split the CALCULATE state logic slightly or use a more explicit counter logic 
                // inside the single CALCULATE state. 
                // 
                // Actually, to ensure robustness, let's use a small sub-FSM or just carefully ordered logic.
                // The previous logic had ambiguity in the 'else if (j_loop <= n)' block regarding the exact step of addition.
                // 
                // Let's refine the CALCULATE state block code to be precise:
                // (This replacement logic is placed inside the CALCULATE case item).
                // 
                // Refined Logic for CALCULATE state:
                // 1. If i_loop > m: goto DONE.
                // 2. If j_loop == 0: 
                //      - Compute base. 
                //      - power = 1.0. 
                //      - j_loop = 1.
                // 3. Else if j_loop < n:
                //      - power = power * base.
                //      - j_loop++.
                // 4. Else (j_loop == n):
                //      - power = power * base (final multiplication).
                //      - accumulator += (1 - power).
                //      - i_loop++.
                //      - j_loop = 0.
                
                // Note: The multiplication power * base takes a cycle to complete (if sequential) or 
                // is combinational. If combinational, we can update 'power' and 'accumulator' in the same cycle,
                // but we need to ensure we use the *old* power for the accumulator addition.
                // If 'power' is updated combinationally, we need a temporary variable.
                // Since we are in a clocked process, 'power' is a register. 
                // The multiplication logic needs to be handled carefully.
                // 
                // Let's rewrite the CALCULATE state logic completely to be robust.
                // I will overwrite the previous logic in the JSON output.

            endcase
        end
    end
    
    // Logic correction for CALCULATE state to handle the loop iterations correctly
    // We combine the logic into the always block above or add another block.
    // It's cleaner to fix the logic inside the always block. 
    // Since I cannot edit the previous text block in the stream, I will add a second always block or 
    // just output the fully corrected module.
    
    // Fully Corrected Module Logic:
    // (I will regenerate the module body with the correct logic to avoid the 're-reading' ambiguity).

endmodule

// Corrected Implementation Strategy used in the code above (conceptually) but ensuring variables are correct.
// To be perfectly clear, here is the corrected explicit logic for the CALCULATE state:

module expected_max_dice_corrected (
    input clk,
    input rst_n,
    input start,
    input [15:0] m,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [15:0] i_loop;
    reg [15:0] j_loop;
    reg [31:0] base;          // Q16.16
    reg [31:0] power;         // Q16.16
    reg [31:0] accumulator;   // Q16.16
    reg [31:0] m_fixed;
    wire [63:0] mult_out;     // Q32.32
    
    assign mult_out = $signed(power) * $signed(base);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            i_loop <= 0;
            j_loop <= 0;
            base <= 0;
            power <= 0;
            accumulator <= 0;
            m_fixed <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        m_fixed <= {m, 16'h0};
                        accumulator <= 0;
                        i_loop <= 1;
                        state <= CALCULATE;
                        j_loop <= 0;
                    end
                end

                CALCULATE: begin
                    if (i_loop <= m) begin
                        // --- Inner Loop Logic ---
                        if (j_loop == 0) begin
                            // Init base and power for this i
                            if (i_loop == 1) base <= 0;
                            else base <= ({(i_loop - 1'b1), 16'h0}) / m_fixed;
                            power <= 32'h00010000; // 1.0
                            j_loop <= 1;
                        end 
                        else if (j_loop < n) begin
                            // Multiply power by base
                            power <= mult_out[47:16]; // Q32.32 -> Q16.16
                            j_loop <= j_loop + 1'b1;
                        end 
                        else if (j_loop == n) begin
                            // Final multiply, then add to accumulator
                            power <= mult_out[47:16];
                            // Add (1.0 - power) to accumulator
                            // Note: power is the OLD power here, we need the NEW power.
                            // Wait, if j_loop == n, we need to compute base^n.
                            // If we just did the multiplication, 'mult_out' is the new value.
                            // So we use the result of this multiplication.
                            accumulator <= accumulator + (32'h00010000 - mult_out[47:16]);
                            
                            j_loop <= 0;
                            i_loop <= i_loop + 1'b1;
                        end
                    end else begin
                        // i_loop > m
                        result <= accumulator;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0; // Pulse done low after one cycle, or keep high? 
                    // Usually done is kept high until reset or new start. 
                    // Let's keep it high until start or reset.
                    if (start) begin // Optional: restart if start comes again
                         // But typically we wait for IDLE transition. 
                         // Let's go to IDLE to wait for explicit reset or start sequence.
                         state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule

// Note: The above module contains the corrected logic. 
// I will output the requested single module 'expected_max_dice' with the robust logic.

module expected_max_dice (
    input clk,
    input rst_n,
    input start,
    input [15:0] m,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [15:0] i_loop;
    reg [15:0] j_loop;
    reg [31:0] base;          // Q16.16
    reg [31:0] power;         // Q16.16
    reg [31:0] accumulator;   // Q16.16
    reg [31:0] m_fixed;
    
    // 64-bit product of two Q16.16 numbers gives Q32.32
    wire [63:0] mult_out;
    assign mult_out = $signed(power) * $signed(base);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'h0;
            done <= 1'b0;
            i_loop <= 16'h0;
            j_loop <= 16'h0;
            base <= 32'h0;
            power <= 32'h0;
            accumulator <= 32'h0;
            m_fixed <= 32'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        m_fixed <= {m, 16'h0}; // m in Q16.16
                        accumulator <= 32'h0;
                        i_loop <= 16'h1; // Start at i=1
                        j_loop <= 16'h0; // Reset inner loop
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    if (i_loop <= m) begin
                        // --- Inner Loop Logic for Power Calculation ---
                        if (j_loop == 16'h0) begin
                            // Step 1: Initialize base and power for current i
                            // base = (i-1) / m
                            if (i_loop > 16'h1) begin
                                base <= ({(i_loop - 1'b1), 16'h0}) / m_fixed;
                            end else begin
                                base <= 32'h0;
                            end
                            power <= 32'h00010000; // 1.0 in Q16.16
                            j_loop <= 16'h1;
                        end else if (j_loop < n) begin
                            // Step 2: Multiply power by base
                            // mult_out is Q32.32, we take upper 32 bits (Q16.16)
                            power <= mult_out[47:16];
                            j_loop <= j_loop + 1'b1;
                        end else if (j_loop == n) begin
                            // Step 3: Final multiply and Accumulate
                            // We have done n multiplications. 
                            // The current 'power' is base^(j-1). We need base^n.
                            // So we multiply once more.
                            power <= mult_out[47:16];
                            // Add (1.0 - base^n) to accumulator
                            // Note: mult_out[47:16] is the NEW power (base^n)
                            accumulator <= accumulator + (32'h00010000 - mult_out[47:16]);
                            
                            // Move to next i
                            i_loop <= i_loop + 1'b1;
                            j_loop <= 16'h0;
                        end
                    end else begin
                        // All i processed
                        result <= accumulator;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Wait in DONE state until reset or restart
                    // To restart, user must pull start low then high, or we can handle it here.
                    // Usually done stays high. 
                    // If start is asserted again (low to high), we can go back to IDLE or CALCULATE.
                    // Let's stay in DONE until reset (or optionally if start is low, go to IDLE? No, usually reset is used).
                    // Let's stay high. 
                    if (start) begin // Simple logic to restart if needed, or just wait for reset
                        // To restart cleanly, we can go back to IDLE logic if start is pulsed.
                        // But standard FSM waits for reset. 
                        // Let's assume the user needs to reset or we automatically reset if start is asserted again? 
                        // Usually: Reset -> IDLE -> Start -> Calc -> Done -> (Hold)
                        // Let's hold done high.
                    end
                end
            endcase
        end
    end
endmodule