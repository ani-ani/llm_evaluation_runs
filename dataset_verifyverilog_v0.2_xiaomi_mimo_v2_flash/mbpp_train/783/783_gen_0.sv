module rgb_to_hsv (
    input [31:0] r,
    input [31:0] g,
    input [31:0] b,
    output [31:0] h,
    output [31:0] s,
    output [31:0] v
);

    // Internal signals for intermediate calculations
    // Widths are chosen to handle intermediate values without overflow
    // Q16.16 inputs: r, g, b

    // 1. Determine Max and Min
    wire [31:0] mx;
    wire [31:0] mn;
    wire mx_is_r;
    wire mx_is_g;
    wire mx_is_b;
    wire mn_is_r;
    wire mn_is_g;
    wire mn_is_b;

    // Max Logic
    assign mx_is_r = (r >= g) && (r >= b);
    assign mx_is_g = (g > r) && (g >= b);
    assign mx_is_b = (b > r) && (b > g); // Strict inequality for tie-breaking if needed, but >= is safer for general max
    // Tie-breaking ensures mx_is_b takes precedence if g == b > r, etc.
    // A simpler comparator chain:
    wire [31:0] r_gt_g = (r >= g) ? r : g;
    wire [31:0] r_lt_g = (r >= g) ? g : r;
    wire [31:0] mx_temp1 = (r_gt_g >= b) ? r_gt_g : b;
    assign mx = mx_temp1;

    // Min Logic
    wire [31:0] r_lt_g_min = (r <= g) ? r : g;
    wire [31:0] r_gt_g_min = (r <= g) ? g : r;
    wire [31:0] mn_temp1 = (r_lt_g_min <= b) ? r_lt_g_min : b;
    assign mn = mn_temp1;

    // Update mx_is flags based on the calculated mx value
    assign mx_is_r = (mx == r);
    assign mx_is_g = (mx == g);
    assign mx_is_b = (mx == b);

    // 2. Delta Calculation (df)
    // mx and mn are Q16.16, subtraction is direct. Result is Q16.16.
    wire signed [32:0] delta_ext = {1'b0, mx} - {1'b0, mn}; // 33 bits to capture borrow if any (should not be)
    wire [31:0] df = delta_ext[31:0];

    // 3. Value Calculation (V)
    // V = mx * 100.0
    // mx (Q16.16) * 100.0 (Q16.16) = Q32.32. Take upper 32 bits for Q16.16 result.
    wire [63:0] v_mult = {32'b0, mx} * 32'h00640000; // 100.0 = 0x640000
    assign v = v_mult[47:16]; // Shift right by 16 to get Q16.16 (discarding lower 16 and upper 16)

    // 4. Saturation Calculation (S)
    // If mx == 0, S = 0. Else S = (df / mx) * 100.
    // Division: (df * 65536) / mx to maintain Q16.16 scaling.
    // Result then needs to be scaled by 100.
    // S = ((df << 16) / mx) * 100
    // Let DivIn = (df << 16) / mx. DivIn is Q16.16 (approx).
    // We need to avoid overflow in the numerator of the division.
    // df is Q16.16 (max 1.0). df << 16 is Q32.16.
    // To perform division (A / B) with Q16.16 result, we usually do (A << 16) / B.
    // Here A is df, B is mx.
    // Our intermediate for S logic: (df / mx) * 100.
    // Let's calculate DivRes = (df * 65536) / mx.
    // This DivRes is technically (df/mx) represented in Q16.16.
    // Note: 0 <= df/mx <= 1.
    // DivRes * 100 gives the final S.
    // Division by 0 check.
    wire s_zero_condition = (mx == 32'h0);
    
    // Divider logic instantiation for S
    // Numerator for division: df << 16
    wire [63:0] s_div_num = {df, 16'b0};
    wire [31:0] s_div_quotient;
    
    // We need a divider. Since this is combinational logic and division is complex,
    // we assume standard synthesis tools can handle the / operator if inputs are properly sized,
    // but often it's better to use a dedicated block or behavioral description.
    // Given the constraints, we describe the behavior. Synthesis tools will map this to logic.
    // Optimization: df <= mx, so df/mx <= 1. Result fits in 32 bits Q16.16 (integer part 0).
    // Division by zero logic: If mx is 0, result is 0 (handled by conditional assignment).
    // We use a combinational division block. 
    // Note: Verilog division with wide signals can be slow/area heavy. 
    // To strictly follow Q16.16 math:
    // (df / mx) is approx 0 to 1.
    // (df / mx) * 100 is 0 to 100.
    // Let's compute: (df * 100 * 65536) / mx. This fits in the division range.
    // Numerator: df * 100.0. df (Q16.16) * 100 (Q16.16) = Q32.32. 
    // Let's use the 64-bit result: val = df * 100.
    // Then shift left 16 bits (effectively) for division scaling: val << 16 = df * 100 * 65536.
    // This is Q48.32. We divide by mx (Q16.16). 
    // Result is Q32.16. We take upper 32 bits for Q16.16.
    wire [63:0] s_mult_val = {32'b0, df} * 32'h00640000; // df * 100 -> Q32.32
    wire [95:0] s_div_num_full = {32'b0, s_mult_val} << 16; // Shift left 16 bits to simulate multiply by 65536 -> Q48.48 effectively but we keep top bits
    // Actually, let's stick to simpler scaling.
    // We want S = (df / mx) * 100.
    // Let's compute (df * 100 * 65536) / mx.
    // Num = df * 64'h006400000000 (df * 100 shifted left 32). Too wide.
    // Let's do: Num = df * 100. Result is Q32.32 (64 bits).
    // Then Num << 16 = df * 100 * 65536. (80 bits? No, 64 bits * 16 = 80? No, 64 bits * constant)
    // Let's do it step by step to ensure bit-width safety.
    // 1. calc_val = df * 100.  (Lower 32 bits are fractional, upper 32 integer. We only care about the value).
    wire [63:0] calc_val = {32'b0, df} * 32'h00640000;
    // 2. extended_num = calc_val << 16. This becomes Q48.32 (if we view it as 64 bits).
    wire [63:0] extended_num = calc_val[63:0] << 16; // We assume calc_val < 2^48 so shift fits.
    // Division: extended_num / mx.
    // Result will be Q16.16 (since we shifted numerator by 16 relative to standard normalization).
    wire [31:0] s_div_internal;
    
    // Combinational Divider for S
    // To avoid synthesis errors on wide division without clock, we describe behavior.
    // Check mx != 0 to avoid division by zero.
    assign s_div_internal = (mx != 32'h0) ? (extended_num / mx) : 32'h0;
    assign s = s_div_internal;

    // 5. Hue Calculation (H)
    // If df == 0, H = 0.
    // Else if mx == r: H = (60 * ((g - b) / df) + 360) % 360
    // Else if mx == g: H = (60 * ((b - r) / df) + 120) % 360
    // Else if mx == b: H = (60 * ((r - g) / df) + 240) % 360

    // Intermediate differences (Signed Q16.16)
    wire signed [32:0] diff_g_b = {g[31], g} - {b[31], b}; // 33 bits signed
    wire signed [32:0] diff_b_r = {b[31], b} - {r[31], r};
    wire signed [32:0] diff_r_g = {r[31], r} - {g[31], g};

    // We need to calculate (Diff / df) * 60. 
    // 60.0 = 32'h003C0000.
    // Formula: (Diff / df) * 60 + Offset.
    // Division: (Diff * 65536) / df. This gives Diff/df in Q16.16 format (signed).
    // Then multiply by 60.
    // Let H_base = ((Diff << 16) / df) * 60.
    // Since Diff can be negative, we must handle signed arithmetic carefully.
    // ((Diff << 16) / df) is effectively a signed Q16.16 number.
    // Let's assume Diff is in Q16.16 range (approx -1 to 1).
    // (Diff << 16) / df is approx (Diff / df) * 65536.
    // Result fits in 32 bits signed.
    
    // Division unit for H requires signed inputs.
    // We take the absolute value of Diff for the unsigned division logic, then re-apply sign.
    // But standard Verilog / handles signed if inputs are signed. 
    // However, synthesizing signed division with non-power-of-2 widths or large widths can be tricky.
    // Let's try to describe it cleanly for synthesis.

    // Signed Division helper
    // We need to compute (Diff * 65536) / df.
    // Let's cast inputs to 64-bit signed for calculation.
    wire signed [63:0] diff_ext;
    wire signed [63:0] df_ext;
    wire signed [63:0] div_result_signed;
    wire signed [63:0] h_base_mult;
    wire signed [63:0] h_base_raw;

    // Select the correct diff based on mx
    wire signed [32:0] selected_diff = ({33{mx_is_r}} & diff_g_b) |
                                       ({33{mx_is_g}} & diff_b_r) |
                                       ({33{mx_is_b}} & diff_r_g);
    
    // Sign extension for division inputs
    assign diff_ext = {{31{selected_diff[32]}}, selected_diff};
    assign df_ext = {32'b0, df};

    // Perform division: (Diff << 16) / df
    // Note: df is unsigned 32-bit. diff_ext is signed 64-bit.
    // We need to scale diff_ext by 65536 (<< 16).
    // diff_ext * 65536 is very wide (80 bits). We can truncate or limit range.
    // Assuming inputs are normalized 0-1, Diff << 16 is effectively Diff (in Q32.16) / 65536? 
    // No, Diff is Q16.16. (Diff << 16) is Q32.16. 
    // Divide by df (Q16.16). Result is Q16.0 (integer 0)???
    // Let's re-evaluate scaling:
    // We want result = (Diff / df) * 60.0 (Q16.16).
    // Let Intermediate = (Diff / df).
    // To keep precision, Intermediate = (Diff * 65536) / df. This gives Q16.16 representation of (Diff/df).
    // Then Multiply by 60.0 (Q16.16): Result = Intermediate * 60.0.
    // This becomes Q32.32. We need Q16.16. Take upper 32 bits.

    // Diff * 65536
    wire signed [63:0] diff_scaled = diff_ext <<< 16;
    
    // Division: diff_scaled / df_ext
    // Handle df == 0 case.
    wire df_is_zero = (df == 32'h0);
    wire signed [63:0] div_quotient;
    
    // If df is 0, result is 0 (handled later by H_final check or just 0).
    // Note: Verilog division by zero is undefined behavior in synthesis, usually results in error or X.
    // So we must gate it.
    // Use conditional expression to avoid division by zero.
    // Note: df_ext is 64-bit but only lower 32 valid.
    // We perform division on truncated values to save logic if possible, but let's stick to 64-bit signed division.
    // 
    // Optimization: The quotient of (Diff * 65536) / df will be a signed 32-bit number roughly.
    // We can perform division on 33-bit inputs if we assume scaling keeps it bounded.
    // Actually, if Diff/df is -1 to 1 (roughly), Diff*65536/df is approx -65536 to 65536.
    // This fits in 32 bits signed easily.
    // So we can do: (Diff << 16) / df, where Diff is 33-bit signed, df is 32-bit unsigned.
    // Result fits in 32 bits.
    
    // Let's use a 33-bit / 32-bit divider behaviorally.
    // To ensure no X propagation, we check df != 0.
    wire signed [31:0] h_term_raw; // This will hold ((Diff/df)*65536) * 60 scaled later
    
    // We need to compute ((Diff * 65536) / df) * 60.
    // Let's do ((Diff * 65536 * 60) / df).
    // Numerator = Diff * (65536 * 60) = Diff * 3932160.
    // 60.0 in Q16.16 is 0x3C0000.
    // 65536 is 2^16.
    // We want: ((Diff / df) * 60) * 65536 (for Q16.16 result).
    // I.E. ((Diff * 60 * 65536) / df) is effectively the result in Q16.16 if we interpret it correctly?
    // No, let's stick to: 
    // H_val = (Diff / df) * 60.
    // Intermediate = (Diff / df). 
    // (Diff / df) = (Diff * 65536) / df / 65536. 
    // So H_val = ((Diff * 65536) / df) * 60 / 65536.
    // This loses precision if we divide by 65536 at the end.
    // Better: H_val = ((Diff * 60 * 65536) / df) / 65536.
    // Actually, if we want H in Q16.16, we just want the result of (Diff / df) * 60.
    // Let's calculate Num = Diff * 60. Den = df.
    // Result = Num / Den. 
    // To maintain precision: (Num * 65536) / Den. 
    // Num = Diff * 60 (Diff is Q16.16, 60 is Q16.16) -> Q32.32. 
    // Den = df (Q16.16).
    // Result = (Num / Den). This is Q16.16.
    // Wait, standard scaling: (A/B) with Q16.16 output: (A << 16) / B.
    // Here A = Diff * 60. B = df.
    // Let's compute A = Diff * 60. (Diff signed, 60 constant).
    // Diff (Q16.16) * 60 (integer) -> Q16.16 * Integer -> Q16.16 (shifted left? No, integer mul).
    // 60 in Q16.16 is 0x3C0000.
    // A = Diff * 60. Result is Q32.32.
    // We need (Diff * 60) / df.
    // If we calculate (Diff * 60 * 65536) / df, we get (Diff * 60 / df) * 65536. 
    // That is Q16.0 integer if result is 0-360? No.
    // Let's simplify: We need H (Q16.16).
    // Formula: ((Diff / df) * 60).
    // Step 1: D = Diff / df. 
    // Step 2: H = D * 60.
    // Step 1 (scaled): D_scaled = (Diff * 65536) / df. This represents (Diff / df) * 65536.
    // Step 2: H_scaled = D_scaled * 60. This represents (Diff/df * 65536) * 60 = (Diff/df * 60) * 65536.
    // H_scaled is exactly what we need for Q16.16 representation of H.
    // So: H_val = ((Diff * 65536) / df) * 60.
    // Note: D_scaled is a 32-bit signed integer (approx -65536 to 65536).
    // H_val = D_scaled * 60. Max val approx 3.6e6. Fits in 32 bits? 65536 * 60 = 3.9e6. Yes fits in 32-bit signed.
    // Wait, H is 0-360. In Q16.16, 360 is 360 * 65536 = 23,592,960. Fits in 32 bits.
    // So H_val calculated above is the Q16.16 value (roughly).
    
    // Let's implement this specific calculation.
    // D_scaled = (Diff * 65536) / df.
    // H_val = D_scaled * 60.
    // Note: 60 in Q16.16 is 0x3C0000. But here we are multiplying the *scaled* result.
    // D_scaled is essentially (Diff/df) represented with a scale of 65536.
    // Multiplying by 60 (integer) gives (Diff/df * 60) * 65536. This is the Q16.16 value.
    
    // Signed Divider Logic for D_scaled
    // D_scaled = (Diff << 16) / df.
    // We handle df == 0.
    wire signed [31:0] d_scaled;
    // Since (Diff << 16) might overflow 32 bits if Diff is large, but Diff is typically small.
    // Diff is 33 bits. Diff << 16 is 49 bits. df is 32 bits.
    // Result is approx 32 bits.
    // We use 64-bit intermediate to be safe.
    wire signed [63:0] diff_op = {{31{selected_diff[32]}}, selected_diff}; // sign extended 33 -> 64
    wire signed [63:0] diff_op_scaled = diff_op <<< 16;
    wire signed [63:0] df_op = {32'b0, df};
    
    // Conditional division to prevent X
    // Note: If df is 0, we want d_scaled to be 0 (or handled by the mx==mn case, which forces H=0).
    wire signed [63:0] d_scaled_full = (df != 32'h0) ? (diff_op_scaled / df_op) : 64'sd0;
    // d_scaled_full is Q16.16 representation of (Diff/df).
    // We truncate to 32 bits (lower 32 bits of the quotient are the fractional part? No, quotient is integer math).
    // (Diff << 16) / df returns (Diff/df) * 65536. This is a large number.
    // Let's check magnitude. Diff ~ 1. df ~ 0.5. (1/0.5)*65536 = 131072.
    // If Diff is negative, it's -131072.
    // So d_scaled fits in 32 bits signed.
    wire signed [31:0] d_scaled_32 = d_scaled_full[31:0];

    // Now multiply by 60 to get H in Q16.16.
    // H_val = d_scaled_32 * 60.
    // 60 is integer.
    wire signed [63:0] h_val_signed = d_scaled_32 * 32'sd60; // Result is Q16.16 * integer = Q16.16 (scaled)
    
    // Now we have raw H values (can be negative).
    // We need to select which one based on mx.
    // Offset: +360, +120, +240.
    // 360.0 in Q16.16 = 360 * 65536 = 0x01680000.
    // 120.0 = 0x00780000.
    // 240.0 = 0x00F00000.
    
    wire signed [63:0] h_r_val = h_val_signed + 32'h01680000;
    wire signed [63:0] h_g_val = h_val_signed + 32'h00780000;
    wire signed [63:0] h_b_val = h_val_signed + 32'h00F00000;
    
    // Select the base H value based on mx_is flags.
    wire signed [63:0] h_selected_raw = ({64{mx_is_r}} & h_r_val) |
                                        ({64{mx_is_g}} & h_g_val) |
                                        ({64{mx_is_b}} & h_b_val);

    // Clamp to 0-360 range (modulo 360).
    // Since we added offsets, the result should be positive (0 to < 720).
    // We need to subtract 360 if >= 360.
    // 360.0 in Q16.16 = 360 * 65536.
    wire signed [63:0] limit_360 = 32'h01680000; // 360.0 in Q16.16
    wire signed [63:0] h_clipped;
    
    // Check if result >= 360
    wire h_ge_360 = (h_selected_raw >= limit_360);
    // If >= 360, subtract 360. If < 360, keep as is.
    // Also, if df == 0, we must force 0.
    wire signed [63:0] h_final_val;
    
    assign h_final_val = (df_is_zero) ? 64'sd0 : 
                         (h_ge_360 ? (h_selected_raw - limit_360) : h_selected_raw);
    
    // Final check for negative values (should not happen with correct logic, but safety first)
    wire signed [63:0] h_final_checked = (h_final_val < 0) ? 64'sd0 : h_final_val;
    
    // Clamp to 360 max (in case it was exactly 360 or overflow)
    wire signed [63:0] h_final_clamped = (h_final_checked >= limit_360) ? limit_360 : h_final_checked;
    
    // Assign to output h (take lower 32 bits, assuming upper 32 are 0 since max is 360.0)
    // 360.0 is 0x01680000, which fits in 32 bits.
    assign h = h_final_clamped[31:0];

endmodule