module digit_sum_optimizer (
    input clk,
    input rst_n,
    input start,
    input [11:0] n,
    output reg [7:0] result,
    output reg done
);

    // States for the main controller
    localparam IDLE = 3'b000;
    localparam SETUP = 3'b001;
    localparam CALC_A = 3'b010;
    localparam CALC_B = 3'b011;
    localparam UPDATE = 3'b100;
    localparam FINISH = 3'b101;

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;

    // Datapath registers
    reg [11:0] a;
    reg [11:0] b;
    reg [7:0] max_sum;
    reg [7:0] current_sum;
    
    // Registers for digit summing helper
    reg [11:0] num_to_sum;
    reg [7:0] partial_sum;
    reg [3:0] digit;
    
    // Control signals for helper
    reg summing;
    reg summing_done;

    // State Transition Logic
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
                if (start) next_state = SETUP;
                else next_state = IDLE;
            end
            SETUP: begin
                next_state = CALC_A;
            end
            CALC_A: begin
                if (summing_done) next_state = CALC_B;
                else next_state = CALC_A;
            end
            CALC_B: begin
                if (summing_done) begin
                    if (a > n) next_state = FINISH;
                    else next_state = UPDATE;
                end else begin
                    next_state = CALC_B;
                end
            end
            UPDATE: begin
                next_state = SETUP;
            end
            FINISH: begin
                if (!start) next_state = IDLE; // Wait for start to go low to reset, or stay here
                else next_state = FINISH;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath and Helper Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a <= 12'b0;
            b <= 12'b0;
            max_sum <= 8'b0;
            current_sum <= 8'b0;
            result <= 8'b0;
            done <= 1'b0;
            summing <= 1'b0;
            num_to_sum <= 12'b0;
            partial_sum <= 8'b0;
            digit <= 4'b0;
            summing_done <= 1'b0;
        end else begin
            // Default assignments
            summing <= 1'b0;
            summing_done <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    // Reset values already handled by reset block
                end

                SETUP: begin
                    // Initialize variables for the loop or prepare to compute sum of 'a'
                    // We start the summing process for 'a' immediately
                    if (a == 12'b0 && max_sum == 8'b0) begin
                        // First iteration setup
                        a <= 12'b0;
                    end else begin
                        // Increment a for next iteration logic happens in previous UPDATE or initial setup
                        // In this state, we just setup for CALC_A. a is already set correctly from SETUP or IDLE
                    end
                    
                    // Prepare summing for 'a' (if not first time, a is incremented in UPDATE)
                    // But wait, SETUP is called before CALC_A. 
                    // If this is the start of the loop (a=0), we process 0. If a was incremented in UPDATE, we process next a.
                    num_to_sum <= a;
                    partial_sum <= 8'b0;
                    digit <= 4'b0;
                    summing <= 1'b1;
                    summing_done <= 1'b0;
                end

                CALC_A: begin
                    // Parallel BCD (actually base 10 from binary) summation state machine
                    if (num_to_sum == 12'b0) begin
                        // Done with this number
                        current_sum <= partial_sum; // Store S(a)
                        summing_done <= 1'b1;
                        summing <= 1'b0;
                    end else begin
                        // Extract last decimal digit logic (Shift and Subtract 10)
                        // To keep it simple and iterative, we subtract 10 repeatedly
                        // But standard digit sum requires extracting digits 0-9. 
                        // Let's use the subtraction method: while number >= 10, number -= 10, sum++.
                        // Or better: extract lower 4 bits (binary decimal) if we assume binary input? 
                        // The problem states S(x) is sum of decimal digits. Input is integer.
                        // For hardware efficiency on small range (0-4095), let's extract decimal digits properly.
                        // Easiest is repeated subtraction of 10 for the digit extraction part? No, that's slow.
                        // Let's use a 'extract last digit' approach: remainder of 10, then divide by 10.
                        // Since division is expensive, let's do the binary-to-decimal conversion in steps.
                        
                        // Optimization: Iterative shift-add for BCD is complex. 
                        // Simplest for 12-bit: just subtract 10 and increment sum until < 10.
                        // Wait, that is wrong. S(19) = 1+9=10. If we subtract 10 from 19 -> 9, sum=1. Correct.
                        // But if we do this in a loop for 100 cycles, it's slow. 
                        // We need a small state machine to do this efficiently per number.
                        // Actually, let's use a dedicated multi-cycle logic here.
                        
                        // Let's refine the SUM logic: A small loop inside CALC_A state.
                        // Actually, the description asks for a state machine that iterates a from 0 to n.
                        // It asks to compute S(a) using a helper state machine. 
                        // Since we are in CALC_A, let's perform one step of the summation.
                        
                        if (num_to_sum >= 12'd10) begin
                            num_to_sum <= num_to_sum - 12'd10;
                            partial_sum <= partial_sum + 8'd1;
                        end else begin
                            partial_sum <= partial_sum + num_to_sum; // Add the remainder (0-9)
                            num_to_sum <= 12'b0;
                        end
                    end
                end

                CALC_B: begin
                    // Here we need to compute S(b).
                    // Note: b = n - a. We should have calculated b in SETUP or previous step.
                    // Actually, we can compute b in the UPDATE state or just do it here.
                    
                    // Logic similar to CALC_A but for 'b'
                    if (num_to_sum == 12'b0 && !summing) begin
                        // Start summing B. 
                        // We need to set num_to_sum = n - a. 
                        // Let's do that transitionally.
                        num_to_sum <= n - a;
                        partial_sum <= 8'b0;
                        summing <= 1'b1;
                        summing_done <= 1'b0;
                    end else if (num_to_sum != 12'b0) begin
                        // Continue summing B
                        if (num_to_sum >= 12'd10) begin
                            num_to_sum <= num_to_sum - 12'd10;
                            partial_sum <= partial_sum + 8'd1;
                        end else begin
                            partial_sum <= partial_sum + num_to_sum;
                            num_to_sum <= 12'b0;
                        end
                    end else begin
                        // Finished summing B
                        // partial_sum now holds S(b). current_sum holds S(a).
                        summing_done <= 1'b1;
                    end
                end

                UPDATE: begin
                    // current_sum = S(a), partial_sum = S(b)
                    // Check max
                    if (current_sum + partial_sum > max_sum) begin
                        max_sum <= current_sum + partial_sum;
                    end
                    
                    // Increment a
                    a <= a + 12'd1;
                    
                    // If a > n, the check is done in the next state logic (CALC_B transition).
                end

                FINISH: begin
                    result <= max_sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
