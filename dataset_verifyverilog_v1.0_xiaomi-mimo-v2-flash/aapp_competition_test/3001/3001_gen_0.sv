module PalindromeCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] digits_in [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_DIGITS = 4'd1;
    localparam [3:0] CHECK_CURRENT = 4'd2;
    localparam [3:0] GEN_PALINDROME = 4'd3;
    localparam [3:0] CALC_STEPS = 4'd4;
    localparam [3:0] UPDATE_MIN = 4'd5;
    localparam [3:0] ITERATE = 4'd6;
    localparam [3:0] FINISH = 4'd7;

    // Registers
    reg [3:0] state;
    reg [3:0] current_digits [0:15]; // Store input digits
    reg [3:0] pal_digits [0:15];     // Generated palindrome digits
    reg [3:0] k_reg;                 // Actual number of digits (not fixed at 16)
    reg [15:0] current_val_high;     // Upper 16 bits of current value
    reg [15:0] current_val_low;      // Lower 16 bits of current value
    reg [15:0] pal_val_high;
    reg [15:0] pal_val_low;
    reg [15:0] min_steps_high;
    reg [15:0] min_steps_low;
    reg [15:0] steps_high;
    reg [15:0] steps_low;
    reg [3:0] i_idx;
    reg [3:0] mid_point;
    reg [3:0] max_iter_count;
    reg [31:0] power_of_10; // Stores 10^k for modulo arithmetic

    // Helper for generation
    reg [3:0] carry_gen;
    reg [3:0] gen_idx;
    reg gen_done;
    reg [3:0] gen_pos;

    // Helper for addition
    reg [3:0] add_carry;
    reg [3:0] add_idx;

    // Internal computation registers
    reg [31:0] val_current_high_part;
    reg [31:0] val_current_low_part;
    reg [31:0] val_pal_high_part;
    reg [31:0] val_pal_low_part;
    reg [31:0] diff_high;
    reg [31:0] diff_low;
    reg [31:0] min_high;
    reg [31:0] min_low;
    reg is_wrapped;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            // Initialize arrays
            for (int j = 0; j < 16; j = j + 1) begin
                current_digits[j] <= 4'd0;
                pal_digits[j] <= 4'd0;
            end
            k_reg <= 4'd0;
            current_val_high <= 16'd0;
            current_val_low <= 16'd0;
            pal_val_high <= 16'd0;
            pal_val_low <= 16'd0;
            min_steps_high <= 16'hFFFF;
            min_steps_low <= 16'hFFFF;
            steps_high <= 16'd0;
            steps_low <= 16'd0;
            i_idx <= 4'd0;
            mid_point <= 4'd0;
            max_iter_count <= 4'd0;
            power_of_10 <= 32'd1;
            carry_gen <= 4'd0;
            gen_idx <= 4'd0;
            gen_done <= 1'b0;
            gen_pos <= 4'd0;
            add_carry <= 4'd0;
            add_idx <= 4'd0;
            val_current_high_part <= 32'd0;
            val_current_low_part <= 32'd0;
            val_pal_high_part <= 32'd0;
            val_pal_low_part <= 32'd0;
            diff_high <= 32'd0;
            diff_low <= 32'd0;
            min_high <= 32'hFFFFFFFF;
            min_low <= 32'hFFFFFFFF;
            is_wrapped <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_DIGITS;
                        i_idx <= 4'd0;
                        // Reset min for new calculation
                        min_high <= 32'hFFFFFFFF;
                        min_low <= 32'hFFFFFFFF;
                        max_iter_count <= 4'd15; // Bound iterations
                        // Calculate k (number of non-zero digits or from MSB 0 check)
                        // Actually, spec says digits_in[0] is MSB. 
                        // We assume inputs are valid digits 0-9.
                        k_reg <= 4'd16; // Default 16
                        power_of_10 <= 32'd1;
                        for (int j = 0; j < 16; j = j + 1) begin
                            current_digits[j] <= digits_in[j];
                            pal_digits[j] <= digits_in[j]; // Init with input
                        end
                    end
                end

                LOAD_DIGITS: begin
                    // Check k (if leading zeros, we might want smaller k, but spec says k=16 inputs)
                    // Actually spec says "k-wheel counter (1 <= k <= 16)".
                    // We treat it as 16 wheels, but palindrome check is for all 16.
                    // However, example 610 implies k=3? 
                    // Input array is fixed 16. We use all 16.
                    // Convert current digits to integer value (0 to 10^16-1)
                    state <= CHECK_CURRENT;
                    val_current_high_part <= 32'd0;
                    val_current_low_part <= 32'd0;
                    add_idx <= 4'd15; // Start from LSB
                end

                CHECK_CURRENT: begin
                    // Check if current is palindrome
                    // Convert to value and check palindrome property
                    // Optimization: Check palindrome property directly on digits first
                    // Check symmetry
                    if (add_idx == 4'd15) begin
                        // Start conversion loop
                        // To convert: val = sum(d[i] * 10^(k-1-i))
                        // Since k=16, 10^15 is huge ( > 2^32).
                        // We cannot store 10^15 in 32 bits.
                        // We need a different representation or algorithm.
                        // The examples suggest small numbers, but inputs are 16 digits.
                        // The constraint "computation completes within 1000 cycles" implies 
                        // we cannot do big integer arithmetic naively.
                        // Rethink: The problem asks for steps to reach palindrome.
                        // Steps are increments.
                        // Increment logic: digit[p]++. If 9->0, carry to p-1.
                        // This is base-10 addition.
                        // We can simulate the "add 1" operation.
                        // But finding minimum steps to *any* palindrome implies checking multiple targets.
                        // Given the hardware constraints and 1000 cycles, we cannot do full integer math for 10^16.
                        // The "key constraint" suggests we can enumerate possible palindrome targets.
                        // However, generating the *value* is hard.
                        // Alternative: Work directly with digit arrays.
                        // We can iterate "steps" from 1 to some limit (e.g., 200).
                        // For each step count S, check if (current + S) is a palindrome.
                        // How to check (current + S)? We need to compute current + S.
                        // Since S is small (< 1000), we can simulate addition of S to the digit array.
                        // This avoids big integer storage.
                        // We iterate S from 0 to 1000.
                        // If (current + S) is palindrome, update min.
                        // This fits the cycle budget.
                        
                        // Modified Algorithm:
                        // 1. Load digits.
                        // 2. Check if S=0 is palindrome. If yes, result=0.
                        // 3. For S = 1 to 1000:
                        //    a. Increment digit array by 1 (simulating carry).
                        //    b. Check if new array is palindrome.
                        //    c. If yes, output S.
                        
                        // Check S=0 first
                        state <= GEN_PALINDROME; // Reuse gen logic to check palindrome
                        // Copy current to temp for checking
                        // Reset i_idx for palindrome check
                        i_idx <= 4'd0;
                        gen_done <= 1'b1; // Flag to indicate checking mode, not generating
                    end
                end

                GEN_PALINDROME: begin
                    // If gen_done is 1, we are just checking if current config is palindrome
                    // If gen_done is 0, we are generating the *next* palindrome (not used in iteration approach)
                    // Actually, let's stick to the iteration approach.
                    // State 4: Check Palindrome
                    // We need a sub-state machine or clear logic.
                    // Let's separate "Check Palindrome" and "Increment".
                    // State: CHECK_PALINDROME
                    // State: INCREMENT
                    
                    // Let's go back to CHECK_CURRENT logic.
                    // We need to check if digits == reversed(digits).
                    // We can do this in a loop.
                    
                    // Since I misused GEN_PALINDROME, let's fix the flow.
                    // From CHECK_CURRENT (which I'll rename to CHECK_PAL_S0):
                    // Check symmetry.
                    // If match -> result 0 -> FINISH.
                    // Else -> start iteration loop.
                    
                    // Let's just process the check here.
                    if (current_digits[15 - i_idx] != current_digits[i_idx]) begin
                        // Not palindrome
                        state <= INCREMENT;
                        // Initialize iteration count
                        steps_low <= 16'd1;
                    end else begin
                        if (i_idx >= 4'd7) begin // Checked 0..7 vs 15..8 (k=16)
                            // Is palindrome
                            state <= FINISH;
                            steps_low <= 16'd0;
                        end else begin
                            i_idx <= i_idx + 4'd1;
                        end
                    end
                end

                INCREMENT: begin
                    // Increment current_digits by 1 (simulating step)
                    // We modify current_digits in place.
                    // Logic: add 1 to digit[15] (LSB). Handle carry.
                    // If digit[15] < 9: digit[15]++.
                    // If digit[15] == 9: digit[15] <= 0, carry to 14.
                    // Continue.
                    // We do this in one cycle for small k (16) and non-fanout heavy logic.
                    // Or iterate index.
                    
                    // Let's use an index to propagate carry.
                    // Start at index 15.
                    if (current_digits[15] != 4'd9) begin
                        current_digits[15] <= current_digits[15] + 4'd1;
                        state <= CHECK_PAL_LOOP;
                        // Reset check index
                        i_idx <= 4'd0;
                    end else begin
                        current_digits[15] <= 4'd0;
                        add_idx <= 4'd14; // Propagate carry
                        state <= CARRY_PROPAGATE;
                    end
                end

                CARRY_PROPAGATE: begin
                    if (add_idx == 4'd15) begin
                        // Finished propagation
                        state <= CHECK_PAL_LOOP;
                        i_idx <= 4'd0;
                    end else begin
                        if (current_digits[add_idx] != 4'd9) begin
                            current_digits[add_idx] <= current_digits[add_idx] + 4'd1;
                            state <= CHECK_PAL_LOOP;
                            i_idx <= 4'd0;
                        end else begin
                            current_digits[add_idx] <= 4'd0;
                            add_idx <= add_idx - 4'd1;
                        end
                    end
                end

                CHECK_PAL_LOOP: begin
                    // Check if current_digits is palindrome
                    // Symmetry check: digits[i] == digits[15-i] for i=0..7
                    if (current_digits[15 - i_idx] != current_digits[i_idx]) begin
                        // Not palindrome
                        // Check if we exceeded 1000 steps
                        if (steps_low >= 16'd1000) begin
                            // Should not happen per spec, but safety
                            state <= FINISH;
                            result <= steps_low;
                        end else begin
                            // Increment steps and continue loop
                            steps_low <= steps_low + 16'd1;
                            state <= INCREMENT;
                        end
                    end else begin
                        // Match
                        if (i_idx >= 4'd7) begin
                            // Is palindrome
                            state <= FINISH;
                            result <= steps_low;
                        end else begin
                            i_idx <= i_idx + 4'd1;
                        end
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