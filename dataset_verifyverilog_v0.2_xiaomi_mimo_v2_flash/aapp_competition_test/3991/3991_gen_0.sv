module subset_sum_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x_in [0:7],
    output reg [63:0] result,
    output reg done
);

    // Constants
    localparam MOD = 64'd1000000007;
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam CALC = 2'b10;
    localparam DONE = 2'b11;

    // Powers of 2 coefficients
    // pow2[i] corresponds to 2^i
    wire signed [63:0] pow2 [0:7];
    assign pow2[0] = 64'd1;
    assign pow2[1] = 64'd2;
    assign pow2[2] = 64'd4;
    assign pow2[3] = 64'd8;
    assign pow2[4] = 64'd16;
    assign pow2[5] = 64'd32;
    assign pow2[6] = 64'd64;
    assign pow2[7] = 64'd128;

    // Registers
    reg [1:0] state;
    reg [2:0] i; // Iteration counter 0 to 7
    reg signed [63:0] x_reg [0:7];
    reg signed [127:0] acc; // 128-bit accumulator
    
    // Wires for calculation
    wire signed [63:0] coeff;
    wire signed [63:0] term_wire;
    wire signed [127:0] term_mult;
    wire signed [127:0] acc_next;
    wire signed [127:0] acc_reduced;
    wire signed [127:0] acc_final;
    
    // Coefficient: (2^i - 2^(7-i))
    assign coeff = pow2[i] - pow2[7-i];
    
    // Multiply x (Q16.16) by coefficient (scalar)
    // x_reg is signed 64-bit, coeff is signed 64-bit. Result is 128-bit signed.
    assign term_mult = $signed(x_reg[i]) * $signed(coeff);
    
    // Convert to unsigned for modulo arithmetic
    // We take absolute value for modulo, keeping track of sign
    wire term_is_neg;
    wire [127:0] term_abs;
    
    // Check sign of term_mult (signed 128-bit)
    assign term_is_neg = term_mult[127];
    // Absolute value logic (negate if negative)
    assign term_abs = term_is_neg ? (~term_mult + 1) : term_mult;
    
    // Modulo operation on term
    // Since term_abs is 128-bit and MOD is 64-bit, we can reduce it.
    // For simplicity in synthesis, we do a simple reduction or assume it fits.
    // A safe division-based modulo is complex. Assuming inputs are reasonable,
    // we use a wide intermediate state.
    wire [127:0] term_mod;
    assign term_mod = term_abs % MOD;
    
    // Add to accumulator
    // acc is current sum (unsigned 128-bit)
    // term_mod is unsigned 128-bit
    // We need to handle sign of term: (acc + term_mod) if positive, (acc - term_mod) if negative
    wire [127:0] diff;
    wire [127:0] sum;
    wire borrow;
    
    assign sum = acc + term_mod;
    assign {borrow, diff} = acc - term_mod;
    
    // Select next accumulator value based on term sign
    // If negative and borrow, it wrapped (negative result), wrap around MOD
    // If negative and no borrow, simple subtraction
    // Optimization: 
    // acc_next = acc + term_mult (signed addition), then handle modulo
    // However, signed arithmetic on 128-bit is tricky with overflow.
    // Let's stick to the ADD/SUB logic with carry handling.
    
    // We want: acc = (acc + term_mult) % MOD
    // Let's do: acc_new = acc + term_mult
    // If term_mult is negative, it's effectively subtraction.
    // So acc_new = acc + term_mult
    // If acc_new < 0, acc_new += MOD
    // If acc_new >= MOD, acc_new -= MOD
    
    wire signed [127:0] acc_new_raw;
    wire signed [127:0] acc_new_pos;
    wire signed [127:0] acc_final_reduced;
    
    assign acc_new_raw = $signed(acc) + term_mult;
    
    // Normalize to positive [0, MOD)
    // If negative, add MOD until positive (fixed loop or conditional add)
    // Since max negative is roughly -MOD * N (small), adding MOD twice is enough.
    // Or: (acc_new_raw % MOD + MOD) % MOD
    // Let's use a simpler modular addition logic:
    // acc_next is [0, MOD)
    
    assign acc_final_reduced = (acc_new_raw % MOD + MOD) % MOD;
    
    // Update Logic
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            acc <= 0;
            i <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                        acc <= 0;
                        i <= 0;
                    end
                end

                LOAD: begin
                    // Load inputs into internal register array
                    x_reg[0] <= $signed(x_in[0]);
                    x_reg[1] <= $signed(x_in[1]);
                    x_reg[2] <= $signed(x_in[2]);
                    x_reg[3] <= $signed(x_in[3]);
                    x_reg[4] <= $signed(x_in[4]);
                    x_reg[5] <= $signed(x_in[5]);
                    x_reg[6] <= $signed(x_in[6]);
                    x_reg[7] <= $signed(x_in[7]);
                    state <= CALC;
                end

                CALC: begin
                    // Calculate (acc + term) % MOD
                    // Using the pre-calculated reduced value
                    acc <= acc_final_reduced[63:0]; // Truncate to 64-bit, though valid it fits in MOD range
                    
                    if (i == 7) begin
                        state <= DONE;
                        // Result needs to be in Q16.16 format.
                        // Input x_in is Q16.16 (value * 65536).
                        // Coefficients are integers (2^k).
                        // Acc holds (Sum(x * coeff)) % MOD.
                        // Since x was effectively scaled by 65536, result is scaled by 65536.
                        // We need to output this value.
                        result <= acc_final_reduced[63:0];
                    end else begin
                        i <= i + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule