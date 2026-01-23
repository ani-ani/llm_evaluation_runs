module func_count(
    input clk,
    input rst_n,
    input start,
    input [15:0] p_in,
    input [15:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_K = 3'b001;
    localparam CALC_ORDER = 3'b010;
    localparam MOD_EXP = 3'b011;
    localparam POWER_LOOP = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // Q16.16 conversion constants
    // Scale 1 to Q16.16: 1 << 16 = 32'h00010000
    localparam [31:0] ONE_Q16 = 32'h00010000;
    localparam [31:0] ZERO_Q16 = 32'h00000000;

    // Working registers
    reg [31:0] p;           // p in Q16.16
    reg [31:0] k;           // k in Q16.16
    reg [31:0] exp_val;     // exponent in Q16.16 (stores int value)
    reg [31:0] order;       // order in Q16.16
    reg [31:0] base_val;    // base for exponentiation
    reg [31:0] res_reg;     // result accumulator
    
    // Loop counters
    reg [31:0] i;           // generic counter
    reg [31:0] cnt;         // secondary counter
    
    // Temporary variables for arithmetic
    reg [63:0] temp_mul;
    reg [31:0] temp_mod;
    
    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            p <= 32'b0;
            k <= 32'b0;
            exp_val <= 32'b0;
            order <= 32'b0;
            base_val <= 32'b0;
            res_reg <= 32'b0;
            i <= 32'b0;
            cnt <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs scaled to Q16.16
                        p <= {p_in, 16'b0};
                        k <= {k_in, 16'b0};
                        state <= CHECK_K;
                    end
                end

                CHECK_K: begin
                    // Check if k == 0 (Q16.16)
                    if (k == 32'h00000000) begin
                        // Case 1: k = 0
                        // Calculate p^(p-1)
                        // p-1
                        exp_val <= p - ONE_Q16;
                        base_val <= p;
                        res_reg <= ONE_Q16;
                        i <= 32'd0; // bit index
                        state <= POWER_LOOP;
                    end else if (k == ONE_Q16) begin
                        // Case 2: k = 1
                        // Calculate p^p
                        exp_val <= p;
                        base_val <= p;
                        res_reg <= ONE_Q16;
                        i <= 32'd0;
                        state <= POWER_LOOP;
                    end else begin
                        // Case 3: k > 1
                        // Calculate Order and then p^((p-1)/o)
                        // Initialize order calc
                        // We need k (base) and p (modulus)
                        // curr = k mod p
                        // cnt = 1
                        // Strategy: Multiply k by itself repeatedly mod p until 1
                        
                        // Initialize accumulator for power calc: k^1 mod p
                        // We use res_reg as current value, i as counter (order)
                        // Note: We need to preserve k and p
                        
                        // Start with val = k, order = 1
                        res_reg <= k;
                        order <= ONE_Q16; // Counter
                        state <= CALC_ORDER;
                    end
                end

                CALC_ORDER: begin
                    // Check if res_reg (current power of k) == 1
                    if (res_reg == ONE_Q16) begin
                        // Found order. It is stored in 'order'
                        // Calculate e = (p - 1) / order
                        // p is Q16.16. p-1 is p - ONE_Q16.
                        // order is Q16.16.
                        // Since inputs are small integers, we can do integer division.
                        // Extract integers:
                        // Division: (p_int / order_int) << 16
                        // We perform division on upper 16 bits values directly on Q16.16 operands
                        // Just use integer division logic on the values.
                        
                        exp_val <= (p - ONE_Q16) / order;
                        base_val <= p;
                        res_reg <= ONE_Q16;
                        i <= 32'd0;
                        state <= POWER_LOOP;
                    end else begin
                        // res_reg = res_reg * k mod p
                        // Integer parts: (res_reg[31:16] * k[31:16]) mod p[31:16]
                        // Using 64-bit to prevent overflow before mod
                        temp_mul = (res_reg[31:16] * k[31:16]);
                        temp_mod = temp_mul % p[31:16];
                        res_reg <= {temp_mod, 16'b0};
                        
                        // Increment order
                        order <= order + ONE_Q16;
                        state <= CALC_ORDER;
                    end
                end

                POWER_LOOP: begin
                    // Square-and-Multiply (Binary Exponentiation)
                    // Loop through bits of exponent (exp_val).
                    // Exponent is integer, stored in upper 16 bits.
                    // Bits are in exp_val[31:16].
                    // Iteration count: 16 (for 16-bit exponent).
                    
                    if (i < 16) begin
                        // Always Square: res_reg = res_reg * res_reg mod base_val
                        temp_mul = (res_reg[31:16] * res_reg[31:16]);
                        temp_mod = temp_mul % base_val[31:16];
                        res_reg <= {temp_mod, 16'b0};
                        
                        // Check bit of exponent at position (15 - i) or (i) depending on direction
                        // Let's scan from MSB (15) to LSB (0).
                        // i = 0 checks bit 15, i = 15 checks bit 0.
                        if (exp_val[31 - i]) begin
                            // If bit is set, multiply by base
                            // res_reg = res_reg * base_val mod base_val
                            // Note: After squaring, res_reg is new accumulator. We multiply by original base.
                            // Wait, standard binary expo:
                            // res = 1
                            // for each bit b:
                            //   res = res * res
                            //   if b==1: res = res * base
                            
                            // Correct logic for sequential hardware:
                            // We need to multiply the result (which we just squared) by the original base (base_val)
                            // But wait, we are squaring the accumulator. If bit is 1, we multiply accumulator by original base.
                            
                            // Re-read accumulator after square:
                            // temp_sq = res_reg * res_reg mod p
                            // if bit set: res_reg = temp_sq * base_val mod p
                            
                            // Let's do the multiply step directly here
                            temp_mul = (res_reg[31:16] * base_val[31:16]);
                            temp_mod = temp_mul % base_val[31:16];
                            res_reg <= {temp_mod, 16'b0};
                        end
                        
                        i <= i + 1;
                        state <= POWER_LOOP;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= res_reg;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule