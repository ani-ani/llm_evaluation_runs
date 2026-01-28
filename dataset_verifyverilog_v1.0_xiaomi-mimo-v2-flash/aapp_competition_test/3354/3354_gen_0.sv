module pickle_problem(
    input clk,
    input rst_n,
    input [31:0] s_i, s_f, // Q16.16: s_i integer, s_f fractional
    input [31:0] r_i, r_f, // Q16.16: r_i integer, r_f fractional
    input [2:0] n,
    input [6:0] z,
    input start,
    output reg [2:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] CHECK_K  = 3'd1;
localparam [2:0] AREA_MUL = 3'd2;
localparam [2:0] AREA_CMP = 3'd3;
localparam [2:0] GEOM_chk = 3'd4;
localparam [2:0] NEXT_K   = 3'd5;
localparam [2:0] FINISH   = 3'd6;

reg [2:0] state, next_state;
reg [2:0] k; // Current number of pickles being tested
reg [2:0] best_k; // Best result found so far
reg [7:0] cycle_count; // Safety counter
localparam [7:0] MAX_CYCLES = 8'd200;

// Fixed point constants
localparam [31:0] PI_Q16_16 = 32'd205887; // 3.14159265 * 65536
localparam [31:0] ONE_Q16_16 = 32'd65536;
localparam [31:0] SQRT3_Q16_16 = 32'd113510; // 1.73205 * 65536
localparam [31:0] SQRT2_Q16_16 = 32'd92682;  // 1.41421 * 65536

// Geometry thresholds (s/r ratios)
// 1/sin(pi/k) pre-calculated
localparam [31:0] THRESH_5 = 32'd176947; // 2.7015 * 65536
localparam [31:0] THRESH_6 = 32'd196608; // 3.0000 * 65536
localparam [31:0] THRESH_7 = 32'd216474; // 3.3040 * 65536

// Computation registers
reg [31:0] s, r; // Packed Q16.16 values
reg [63:0] mul_a, mul_b, mul_res; // 64-bit multiplication
reg [31:0] cmp_left, cmp_right; // Comparisons
reg [63:0] s_scaled, r_scaled; // For division approximation
reg [31:0] s_over_r; // s/r in Q16.16
reg geom_ok;

// Division helper (binary search for s/r)
reg [31:0] div_numer, div_denom, div_quotient;
reg div_active;
reg [4:0] div_iter; // 32 iterations for 32-bit precision

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 3'd0;
        done <= 1'b0;
        k <= 3'd0;
        best_k <= 3'd0;
        cycle_count <= 8'd0;
        s <= 32'd0;
        r <= 32'd0;
        mul_a <= 64'd0;
        mul_b <= 64'd0;
        mul_res <= 64'd0;
        cmp_left <= 32'd0;
        cmp_right <= 32'd0;
        s_over_r <= 32'd0;
        geom_ok <= 1'b0;
        div_numer <= 32'd0;
        div_denom <= 32'd0;
        div_quotient <= 32'd0;
        div_active <= 1'b0;
        div_iter <= 5'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                s <= {s_i[15:0], s_f[15:0]}; // Concatenate to 32-bit Q16.16
                r <= {r_i[15:0], r_f[15:0]};
                if (start) begin
                    state <= CHECK_K;
                    k <= n;
                    best_k <= 3'd0;
                    // Start division for geometry check
                    // s_over_r calculation: (s * 65536) / r
                    div_numer <= {s[15:0], 16'd0}; // Scale s by 2^16
                    div_denom <= r;
                    div_quotient <= 32'd0;
                    div_active <= 1'b1;
                    div_iter <= 5'd0;
                end
            end

            CHECK_K: begin
                if (k == 3'd0) begin
                    state <= FINISH; // Nothing fits
                end else begin
                    // Check if r <= s (single pickle must fit)
                    // We do area first, but r>s makes no sense anyway
                    if (r > s) begin
                        // r is larger than s, try smaller k (but if k>1 and r>s, all fail)
                        // Actually if r > s, even k=1 fails. 
                        // But we iterate k downwards. If r > s, result is 0.
                        state <= NEXT_K;
                    end else begin
                        state <= AREA_MUL;
                    end
                end
            end

            AREA_MUL: begin
                // Calculate Area_k = k * PI * r^2
                // 1. r^2
                mul_a <= {32'd0, r};
                mul_b <= {32'd0, r};
                state <= AREA_CMP; // Computation takes 1 cycle (combinational usually, but let's be safe)
                // Note: In real ASIC, mult is pipelined. Here we assume single cycle or combinational.
                // For Verilog simulation, we usually need a delay or @* logic.
                // Let's do sequential multiplication logic manually for width reduction.
                // Actually, simpler: Just use intermediate regs.
            end

            AREA_CMP: begin
                // r^2 result is [63:0]
                // r^2 * PI
                // r^2 is roughly 48 bits (16.16 squared = 32.32)
                // (r*r) is in mul_res[63:0] if we did it.
                // Let's do: (r*r) * PI
                // r is 16.16. r^2 is 32.32. Shift right 16 to make 32.16.
                // Then multiply by PI (16.16). Result 32.32. Shift right 16 -> 32.16.
                
                // We need to be careful with widths.
                // r^2 [63:0]. Take [47:16] as 32-bit representative (Q32.0?
                // Let's stick to 64-bit intermediates.
                // Area_p_single = (r * r * PI) >> 16
                // Total Area = Area_p_single * k
                
                // Calculate r*r
                mul_a <= {32'd0, r};
                mul_b <= {32'd0, r};
                // Result in next cycle (assumed combinational logic creates mul_res)
                // Actually, let's use comb logic for multiplication to keep it simple for now
                // but state machine waits.
                
                // Let's do the math in comb logic driven by state.
                state <= GEOM_chk; // Logic will calculate values based on state
            end

            GEOM_chk: begin
                // Logic here is handled in the comb block below
                // If geom_ok and area_ok, set best_k = k
                // Then go to NEXT_K
                if (geom_ok) begin // geom_ok implies area_ok if checked in comb logic
                    best_k <= k;
                end
                state <= NEXT_K;
            end

            NEXT_K: begin
                cycle_count <= cycle_count + 8'd1;
                if (k > 3'd0 && cycle_count < MAX_CYCLES) begin
                    k <= k - 3'd1;
                    state <= CHECK_K;
                end else begin
                    state <= FINISH;
                end
            end

            FINISH: begin
                result <= best_k;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

// Combinational Logic for Arithmetic and Geometry Checks
always @(*) begin
    // Defaults
    geom_ok = 1'b0;
    mul_res = 64'd0;
    cmp_left = 32'd0;
    cmp_right = 32'd0;
    
    // Multiplication logic (combinational based on state)
    if (state == AREA_MUL || state == AREA_CMP) begin
        // 1. Compute r^2
        mul_res = r * r; // 32x32 -> 64 bit. r is Q16.16, so r^2 is Q32.32
        
        // 2. Compute r^2 * PI
        // mul_res is Q32.32. Take upper 32 bits [63:32] as Q16.16 approx?
        // No, keep 64 bits. mul_res * PI.
        // mul_res[63:0] * PI[31:0] -> 96 bits. Too big.
        // We only need area for comparison. Area = k * PI * r^2.
        // Let's compute PI * r^2 first. 
        // Shift r^2 right by 16 to get Q32.16. Multiply by PI (Q16.16) -> Q48.32. 
        // We just need a relative value to compare with Area_sandwich.
        
        // Area_single (Q16.16) approx = (r * r * PI) >> 16
        // r is Q16.16. r^2 is Q32.32. 
        // Let's say r^2 >> 16 is a 32-bit value (Q16.16).
        // Actually, r^2 is 64 bits. [63:32] is integer, [31:0] is frac.
        // Let's take r^2_q16 = r^2[63:16] (upper 48 bits, effectively Q32.16).
        // Multiply by PI (16.16) -> 48x32 = 80 bits. Result Q48.32.
        // We need total Area_k = k * Area_single.
        
        // Let's simplify: Area_k <= Area_sandwich * z / 100
        // Area_k = k * PI * r^2
        // Area_sandwich = PI * s^2
        // Condition: k * r^2 <= s^2 * z / 100
        // We can multiply both sides by 100 to avoid division.
        // 100 * k * r^2 <= s^2 * z
        // r^2 is Q32.32. s^2 is Q32.32.
        // 100*k is small integer.
        // Let's compute LHS = 100 * k * r^2[63:32] (integer parts only for rough check? No, need precision).
        
        // Let's use 64-bit intermediates.
        // r_sq = r * r; // 64 bit
        // s_sq = s * s; // 64 bit
        // LHS = k * 100 * r_sq
        // RHS = z * s_sq
        // This is a 3x64 = 67 bit operation. 
        // Since inputs are small, let's use 64 bits.
        // r_sq_int = r_sq[63:32] (approx)
        // Let's do: (r_sq >> 16) * (100 * k) <= (s_sq >> 16) * z
        // This is Q32.16 * Integer <= Q32.16 * Integer.
        
        // Define effective operands
        reg [63:0] r_sq_full, s_sq_full;
        reg [63:0] lhs, rhs;
        
        r_sq_full = r * r; // Q32.32
        s_sq_full = s * s; // Q32.32
        
        // Shift right 16 to get Q32.16 (keeping 48 bits)
        // r_eff = r_sq_full[63:16];
        // s_eff = s_sq_full[63:16];
        
        lhs = r_sq_full[63:16] * (100 * k); // 48x8 -> 56 bits
        rhs = s_sq_full[63:16] * z;         // 48x7 -> 55 bits
        
        if (lhs <= rhs) begin
            // Area check passed. Now Geometry check.
            // Calculate s/r ratio.
            // If we haven't calculated s_over_r yet, wait or compute here.
            // s_over_r calculation happens in division block below.
            
            // Geometry Logic
            // k=1: Always valid (if r <= s, checked in CHECK_K)
            // k=2: Valid if 2*r <= s => s/r >= 2
            // k=3: Valid if s/r >= 1 + sqrt(3) = 2.732
            // k=4: Valid if s/r >= 1 + sqrt(2) = 2.414
            // k=5: Valid if s/r >= 2.7015
            // k=6: Valid if s/r >= 3.0
            // k=7: Valid if s/r >= 3.304
            
            // Compare s_over_r (Q16.16) with thresholds
            if (k == 3'd1) geom_ok = 1'b1;
            else if (k == 3'd2) geom_ok = (s_over_r >= (2 * ONE_Q16_16));
            else if (k == 3'd3) geom_ok = (s_over_r >= (32'd178957)); // 2.732 * 65536
            else if (k == 3'd4) geom_ok = (s_over_r >= (32'd158123)); // 2.414 * 65536
            else if (k == 3'd5) geom_ok = (s_over_r >= THRESH_5);
            else if (k == 3'd6) geom_ok = (s_over_r >= THRESH_6);
            else if (k == 3'd7) geom_ok = (s_over_r >= THRESH_7);
        end
    end
end

// Division Logic (Binary Search / Sequential Subtraction)
// To calculate s/r in Q16.16
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_active <= 1'b0;
        s_over_r <= 32'd0;
    end else begin
        if (div_active) begin
            if (div_iter < 5'd32) begin
                // Shift left quotient and dividend
                // Try to subtract denominator
                // If numerator >= denominator, set bit, subtract
                // This is a restoring division algorithm
                // But we need to track the quotient bits.
                
                // Let's implement simple iterative comparison
                // s_over_r = 0;
                // remainder = s;
                // for i=0 to 16:
                //   remainder = remainder - r
                //   if remainder >= 0: s_over_r |= (1 << (15-i))
                //   else: remainder = remainder + r
                // This is too slow for state machine (16 cycles).
                
                // Optimization: Use the fact that we have many cycles (200).
                // Do 1 iteration per clock.
                // Start: div_numer = s << 16, div_denom = r
                
                reg [63:0] rem;
                rem = {32'd0, div_numer[31:16]}; // Initial remainder
                
                // We need a variable to hold the remainder across cycles.
                // Let's add a reg for remainder.
                // Note: This requires adding registers to the module.
            end else begin
                div_active <= 1'b0;
            end
        end else if (state == IDLE && start) begin
            // Start division trigger
            // Done in IDLE state logic
        end
    end
end

// Revision: To save space/complexity, let's do division in a separate always block with explicit state
// Actually, let's inline the division logic properly.

reg [63:0] div_rem;
reg [31:0] div_quot;
reg [5:0] div_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt <= 6'd0;
        div_active <= 1'b0;
    end else begin
        if (state == IDLE && start) begin
            div_active <= 1'b1;
            div_cnt <= 6'd0;
            // Initialize
            // Numerator: s << 16
            div_rem <= {16'd0, s[31:16], 16'd0}; // s is Q16.16. s << 16 is Q16.32. 
                                                  // We want Q16.16 result. 
                                                  // s / r = (s * 65536) / r.
            // Actually s is 32 bits. s * 65536 is 48 bits. 
            // Let's use 64-bit rem: {s, 16'd0} / r. Result in upper bits?
            div_rem <= {s, 16'd0}; // s is Q16.16. shift left 16 = Q16.32. 
            div_quot <= 32'd0;
        end else if (div_active && div_cnt < 6'd32) begin
            // Binary long division
            // Shift div_rem left by 1
            // Compare div_rem[63:32] (top part) with r
            div_rem <= div_rem << 1;
            
            if (div_rem[63:32] >= r[31:0]) begin // Compare upper 32 bits of rem with r
                div_rem[63:32] <= div_rem[63:32] - r[31:0];
                div_quot <= {div_quot[30:0], 1'b1};
            end else begin
                div_quot <= {div_quot[30:0], 1'b0};
            end
            
            div_cnt <= div_cnt + 6'd1;
        end else if (div_cnt == 6'd32) begin
            div_active <= 1'b0;
            s_over_r <= div_quot;
        end
    end
end

endmodule