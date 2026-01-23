module carry_free_addition (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a,
    input wire [15:0] b,
    output reg [15:0] steps,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Registers for FSM state and counters
    reg [1:0] state;
    reg [15:0] k;
    reg [15:0] current_a;
    reg [15:0] current_b;

    // Intermediate values for calculation (combinational)
    wire [15:0] a_sub_k;
    wire [15:0] b_add_k;
    wire [15:0] a_add_k;
    wire [15:0] b_sub_k;

    assign a_sub_k = a - k;
    assign b_add_k = b + k;
    assign a_add_k = a + k;
    assign b_sub_k = b - k;

    // Carry detection logic
    // Helper macro to check a single decimal digit (0-9) pair
    // Uses subtraction to check if sum >= 10
    `define CHECK_DIGIT(val, shift) \
        (((val >> shift) & 10'h3FF) + 10'd10) < 10'd20 ? 1'b0 : 1'b1

    // Optimized bitwise check for all 5 decimal digits (since 16-bit max is 65535)
    // Checks bits 0-9 (1s), 10-19 (10s), 20-29 (100s), 30-39 (1000s), 40-49 (10000s)
    // However, since inputs are 16-bit, we only need to check up to bit 16.
    // The maximum range for a decimal digit in binary is bits 0-3 (0-9) is safe, but we need to ensure
    // we handle the BCD-like subtraction properly.
    // A simpler bitwise approach for "no carry": (A & B) == 0 is sufficient for binary addition.
    // BUT the requirement explicitly asks for decimal digit addition (0-9) logic.
    // We will implement the explicit decimal digit check using a combinational loop or explicit unrolled checks.

    wire no_carry_1; // 1s place (0-9)
    wire no_carry_10; // 10s place (10-19)
    wire no_carry_100; // 100s place (20-29)
    wire no_carry_1000; // 1000s place (30-39)
    wire no_carry_10000; // 10000s place (40-49)

    // We perform the check on BOTH possibilities (A-k+B+k and A+k+B-k) if we want to be strict.
    // However, the problem asks for min k such that (A-k + B+k) OR (A+k + B-k) works.
    // We will check the primary case (A-k + B+k) first, as it's the standard interpretation.
    // If we only check one, we might miss the optimal solution for the other, but usually k=0 is the starting point.
    // Let's check the range of A-k and B+k. Since A,B < 65536, k < 65536.
    // A-k can underflow (wrap around). To avoid complexity, we assume unsigned arithmetic.
    // If (A-k) > A, it underflowed. We must check if A >= k before doing A-k.
    // Similarly B+k > B checks overflow. B+k wraps 65535 -> 0.
    // The problem says "positive integers", so wrap around might not be considered valid.
    // We will enforce A >= k and B <= 65535 - k for the first check.
    // For the second check (A+k, B-k), we enforce B >= k and A <= 65535 - k.

    // Check 1: (A - k) + (B + k)
    wire check1_valid_range = (a >= k) && (b <= (16'hFFFF - k));
    wire [15:0] val_a1 = a - k;
    wire [15:0] val_b1 = b + k;
    
    // Check 2: (A + k) + (B - k)
    wire check2_valid_range = (b >= k) && (a <= (16'hFFFF - k));
    wire [15:0] val_a2 = a + k;
    wire [15:0] val_b2 = b - k;

    // Decimal digit check logic
    // We need to verify that for every decimal position, digit_a + digit_b < 10.
    // Since we are in binary, a direct bitwise check is: (a & b) == 0 is binary carry.
    // For decimal: we need to extract digits. 
    // Let's use a helper function (always_comb block) to avoid massive wire declarations.
    
    function automatic logic is_decimal_no_carry;
        input [15:0] x;
        input [15:0] y;
        integer i;
        logic [3:0] dx, dy;
        begin
            is_decimal_no_carry = 1'b1;
            // Check positions 0 (1s), 1 (10s), 2 (100s), 3 (1000s), 4 (10000s)
            for (i = 0; i < 5; i = i + 1) begin
                // Extract decimal digit (0-9) from binary representation by masking and shifting
                // Note: This is a BCD extraction from binary, which requires division/modulo logic usually.
                // However, checking condition "sum < 10" on raw binary is tricky if digits cross byte boundaries.
                // We must perform binary to decimal conversion properly.
                // Since synthesis requires clarity, we will unroll the logic for each decimal position.
                // But to keep code short and correct, let's use a LUT or simple subtraction check on the specific bits.
                // Given the instruction "Check each digit pair (0-9) independently", we must ensure we don't sum two digits > 9.
                // E.g. (15 + 15). 5+5=10 (carry). 
                // We can check: ((x % 10) + (y % 10) < 10) && ((x/10 % 10) + (y/10 % 10) < 10) ...
                // Division/Modulo by non-power-of-2 is expensive in hardware.
                // Let's use the provided "Optimization: Extract digits" hint.
                // We can extract bits for each decimal position.
                // 1s: bits 0-3 for each digit? No, we have binary numbers.
                // To get decimal 1s place of binary number N: N % 10.
                // Let's assume standard binary addition carry check is not what is requested.
                // The prompt explicitly wants "(digit_a + digit_b) must be < 10".
                // We will implement a pipelined or combinatorial BCD extractor.
            end
            // Wait, the prompt says "Simplified Algorithm... Check if digits add without carry".
            // And "Adapted Constraints... Carry detection: Check each digit pair (0-9) independently".
            // This implies BCD inputs or a BCD interpretation.
            // However, inputs are [15:0] unsigned integers (standard binary).
            // I will interpret this as checking the binary values as if they were BCD, or simply that
            // there are no carries in binary addition is usually the "carry free" definition (like Carry Save Adder).
            // BUT the explicit "0-9 digits" is the constraint.
            // Let's implement a checker that validates decimal digit boundaries.
            // We can use a pre-computed check: 
            // (x + y) does not have any bits set in positions where a carry would generate a decimal increment?
            // This is ambiguous. 
            // Let's go with the most robust interpretation for "decimal digit addition" in binary hardware:
            // We calculate the sum for each decade separately using modulo 10 arithmetic.
            // Since we cannot use dividers easily, we will use a loop that subtracts 10s.
            // Actually, to remain synthesizable and efficient, we will check the condition:
            // ((x % 10) + (y % 10) < 10) && ((x % 100) < 10) is not right.
            // 
            // REVISION: To avoid complex BCD logic in a "simple" module, and given the example is likely testing FSM logic,
            // I will implement the binary carry check (standard) but wrap it to look for "no carry".
            // However, the prompt insists on "0-9 digits".
            // Let's do this: We will verify the addition of the lower 4 bits (0-9) of the bytes.
            // To strictly follow "Check each digit pair", we need to verify the sum of the decimal values.
            // I will implement a combinational check that iterates through decimal places using subtraction.
            // This is the most faithful implementation of "check decimal digits".
            
            logic [15:0] ax, ay;
            ax = x;
            ay = y;
            
            // Check 1s
            if (((ax % 10) + (ay % 10)) >= 10) return 1'b0;
            ax = ax / 10;
            ay = ay / 10;
            // Check 10s
            if (((ax % 10) + (ay % 10)) >= 10) return 1'b0;
            ax = ax / 10;
            ay = ay / 10;
            // Check 100s
            if (((ax % 10) + (ay % 10)) >= 10) return 1'b0;
            ax = ax / 10;
            ay = ay / 10;
            // Check 1000s
            if (((ax % 10) + (ay % 10)) >= 10) return 1'b0;
            ax = ax / 10;
            ay = ay / 10;
            // Check 10000s
            if (((ax % 10) + (ay % 10)) >= 10) return 1'b0;
            
            return 1'b1;
        end
    endfunction

    wire check1_pass = check1_valid_range & is_decimal_no_carry(val_a1, val_b1);
    wire check2_pass = check2_valid_range & is_decimal_no_carry(val_a2, val_b2);
    wire valid_k = check1_pass | check2_pass;

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            steps <= 16'd0;
            done <= 1'b0;
            k <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k <= 16'd0;
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Check if current k is valid
                    if (valid_k) begin
                        steps <= k;
                        state <= DONE;
                        done <= 1'b1;
                    end else begin
                        // Increment k
                        k <= k + 1;
                        // Safety check for max iterations (65535)
                        if (k == 16'hFFFF) begin
                            // If we reach max, we stop at 65535 even if not valid (should not happen for positive integers)
                            steps <= 16'd65535;
                            state <= DONE;
                            done <= 1'b1;
                        end else begin
                            state <= PROCESSING;
                        end
                    end
                end

                DONE: begin
                    // Stay here until reset or new start
                    // If start is asserted again, we handle it in IDLE transition
                    if (start) begin
                        k <= 16'd0;
                        done <= 1'b0;
                        state <= PROCESSING;
                    end
                end
            endcase
        end
    end

endmodule

// Helper module to perform division and modulo by 10 in hardware
// Since Verilog functions can synthesize, the division (ax / 10) inside the function will
// be inferred as a divider by synthesis tools. For an FPGA/ASIC flow, this is acceptable
// for small bit widths. If extremely low area is needed, a digit-serial approach is better,
// but the unrolled function is cleaner for this request.
