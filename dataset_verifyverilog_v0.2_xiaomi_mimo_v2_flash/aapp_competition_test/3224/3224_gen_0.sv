module circumsphere_center (
    input signed [7:0] p1_x, p1_y, p1_z,
    input signed [7:0] p2_x, p2_y, p2_z,
    input signed [7:0] p3_x, p3_y, p3_z,
    input signed [7:0] p4_x, p4_y, p4_z,
    output [31:0] center_x,
    output [31:0] center_y,
    output [31:0] center_z
);

    // --- Internal Wires for Point Differences (Q16.16) ---
    // Inputs are 8-bit signed. Shift left 16 to convert to Q16.16.
    // Range: +/- 128 -> +/- 8,388,608 (fits in Q16.16 signed range of +/- 32,768)
    wire signed [31:0] p1x, p1y, p1z;
    wire signed [31:0] p2x, p2y, p2z;
    wire signed [31:0] p3x, p3y, p3z;
    wire signed [31:0] p4x, p4y, p4z;

    assign p1x = {p1_x, 16'b0};
    assign p1y = {p1_y, 16'b0};
    assign p1z = {p1_z, 16'b0};
    assign p2x = {p2_x, 16'b0};
    assign p2y = {p2_y, 16'b0};
    assign p2z = {p2_z, 16'b0};
    assign p3x = {p3_x, 16'b0};
    assign p3y = {p3_y, 16'b0};
    assign p3z = {p3_z, 16'b0};
    assign p4x = {p4_x, 16'b0};
    assign p4y = {p4_y, 16'b0};
    assign p4z = {p4_z, 16'b0};

    // --- Forming the Linear System (Ax = b) ---
    // Equation: 2(xj - xi)x + 2(yj - yi)y + 2(zj - zi)z = (xj^2 - xi^2) + (yj^2 - yi^2) + (zj^2 - zi^2)
    // Let A be the matrix of coefficients 2(Delta). Let b be the vector of RHS constants.
    // We solve for Center (C) using Matrix Inversion: C = A^-1 * B
    // Cramer's rule involves Det(A) and Det(A_i).

    // --- Matrix A Coefficients (Q16.16) ---
    // Factor of 2 is handled by shifting. 
    // Since the determinant scales by 2^3, and all sub-determinants scale by 2^2, 
    // the common factor of 2 cancels out (Leibniz formula property: factor in columns scales det by that factor).
    // So we can just use (Delta) without the 2x factor to save precision.
    // Wait, let's stick to the formula logic. 
    // 2(Delta) is the coefficient. 
    // Determinant of A (with 2 factors) = 8 * Det(Delta).
    // Numerators (with 2 factors) = 4 * Det(Delta with col replaced).
    // Result = (4/8) * Ratio = 0.5 * Ratio. 
    // Actually, let's just compute the Matrix M where M_ij = (P_j - P_i)
    // And the vector V where V_k = |P_j|^2 - |P_i|^2.
    // The system is 2M * C = V.
    // Let M be the matrix of deltas.
    // C = (M^-1) * (0.5 * V).
    // We will compute M and V.

    // Deltas (P2-P1, P3-P1, P4-P1)
    wire signed [31:0] dx1, dy1, dz1; // P2 - P1
    wire signed [31:0] dx2, dy2, dz2; // P3 - P1
    wire signed [31:0] dx3, dy3, dz3; // P4 - P1

    assign dx1 = p2x - p1x;
    assign dy1 = p2y - p1y;
    assign dz1 = p2z - p1z;
    assign dx2 = p3x - p1x;
    assign dy2 = p3y - p1y;
    assign dz2 = p3z - p1z;
    assign dx3 = p4x - p1x;
    assign dy3 = p4y - p1y;
    assign dz3 = p4z - p1z;

    // RHS constants (Sum of Squares differences)
    // Note: Inputs are Q16.16. Square is Q32.32. Difference is Q32.32.
    // We need to keep enough bits. 64-bit intermediates are required.
    // Let's define the RHS calculation carefully.
    // RHS_k = (xj^2 + yj^2 + zj^2) - (xi^2 + yi^2 + zi^2)
    // Result C is in Q16.16. 
    // The equation is: (P_j - P_i) . C = 0.5 * (|P_j|^2 - |P_i|^2)
    // Let RHS = 0.5 * (|P_j|^2 - |P_i|^2).
    // To keep fixed point consistency, we will compute |P|^2 first.
    // |P|^2 involves product of Q16.16 * Q16.16 -> Q32.32.
    // Let's compute S = (x^2 + y^2 + z^2). 
    // S1, S2, S3, S4.
    // S are Q32.32.

    wire signed [63:0] s1_x2, s1_y2, s1_z2;
    wire signed [63:0] s2_x2, s2_y2, s2_z2;
    wire signed [63:0] s3_x2, s3_y2, s3_z2;
    wire signed [63:0] s4_x2, s4_y2, s4_z2;

    assign s1_x2 = p1x * p1x;
    assign s1_y2 = p1y * p1y;
    assign s1_z2 = p1z * p1z;
    assign s2_x2 = p2x * p2x;
    assign s2_y2 = p2y * p2y;
    assign s2_z2 = p2z * p2z;
    assign s3_x2 = p3x * p3x;
    assign s3_y2 = p3y * p3y;
    assign s3_z2 = p3z * p3z;
    assign s4_x2 = p4x * p4x;
    assign s4_y2 = p4y * p4y;
    assign s4_z2 = p4z * p4z;

    wire signed [63:0] S1, S2, S3, S4;
    assign S1 = s1_x2 + s1_y2 + s1_z2;
    assign S2 = s2_x2 + s2_y2 + s2_z2;
    assign S3 = s3_x2 + s3_y2 + s3_z2;
    assign S4 = s4_x2 + s4_y2 + s4_z2;

    // RHS Vectors (System: M * C = V)
    // Note: We multiply by 0.5 (shift right 1) to account for the 2 factor in the equation.
    // Inputs S are Q32.32. Result V should ideally be Q32.32, but we have a division by 2.
    // Since the matrix M is Q16.16, and we want C in Q16.16, the units roughly work out if we normalize correctly.
    // Let's trace the units: 
    // M: Q16.16
    // C: Q16.16
    // M*C: Q32.32.
    // V: (S_diff) / 2. S_diff is Q32.32. /2 keeps Q32.32.
    // System: M * C = V.
    // We need C in Q16.16. 
    // However, standard fixed point matrix solve for (U*V) = (W*X) is tricky.
    // Let's use the geometric solution to ensure integer arithmetic where possible, 
    // or stick to determinant method with bit-growth management.

    // Let's define V vectors (64-bit):
    wire signed [63:0] v1, v2, v3;
    // v1: 0.5 * (S2 - S1)
    assign v1 = (S2 - S1) >>> 1;
    // v2: 0.5 * (S3 - S1)
    assign v2 = (S3 - S1) >>> 1;
    // v3: 0.5 * (S4 - S1)
    assign v3 = (S4 - S1) >>> 1;

    // --- Matrix Operations ---
    // We need to solve: 
    // [ dx1 dy1 dz1 ] [x]
    // [ dx2 dy2 dz2 ] [y] = [v1, v2, v3]^T
    // [ dx3 dy3 dz3 ] [z]
    // 
    // Cramer's Rule:
    // DetA = Determinant of M.
    // Dx = Determinant of M with Col 1 replaced by V.
    // Dy = Determinant of M with Col 2 replaced by V.
    // Dz = Determinant of M with Col 3 replaced by V.
    // x = Dx / DetA
    // y = Dy / DetA
    // z = Dz / DetA

    // Matrix M is Q16.16 (since deltas are diffs of Q16.16).
    // Vector V is roughly Q32.32 (since S is Q32.32).
    // This means Dx (where Col 1 is V) will be huge compared to DetA.
    // Specifically: 
    // DetA (scalar): 3 terms, each 3 products of Q16.16. Max value ~ (2^16)^3 * 3 = 2^48 * 3.
    // Dx (vector in Col 1): 
    //   Det = v1 * (dy2*dz3 - dy3*dz2) - v2 * (dy1*dz3 - dy3*dz1) + v3 * (dy1*dz2 - dy2*dz1)
    //   v1 is Q32.32. 
    //   dy2, dz3, etc are Q16.16. Their product is Q32.32.
    //   So term v1 * (dy2*dz3) is Q32.32 * Q32.32 = Q64.64.
    //   Dx will be Q64.64.
    //   Result x = Dx / DetA. 
    //   Dx is Q64.64. DetA is effectively Q48.0 (or Q16.16 * 3 terms, but let's assume magnitude).
    //   Actually, let's look at the linear equation units again.
    //   M (16.16) * C (16.16) = V (32.32).
    //   So V is roughly twice the magnitude of M*C.
    //   Let's normalize inputs so that V is scaled correctly for division.
    //   If we want C in 16.16, we can treat V as having a larger fractional part.
    //   Actually, to avoid complex scaling, let's use the determinant method and then scale the result.

    // Let's compute all sub-determinants needed for Cramer's rule using 64-bit accumulators.
    // Note: The values here can be very large. We might need more than 64 bits, 
    // but let's optimize for 64-bit for now and try to keep precision.
    // The range of inputs is small (1 byte). This helps.
    // Max D: 255. Q16.16: 255 << 16 = 1.6e6.
    // Product of 3: (1.6e6)^3 = 4e18. (This is ~2^62). Fits in 64-bit signed? 
    // 2^63-1 = 9e18. Yes, barely fits.
    // But wait, V is from S. S = x^2 + y^2 + z^2.
    // S = (1.6e6)^2 = 2.5e12 (Q32.32). 
    // v = S/2 ~ 1.25e12.
    // Dx term: v * (product of two deltas) -> 1.25e12 * (1.6e6)^2 = 1.25e12 * 2.5e12 = 3.1e24. 
    // 2^64 is 1.8e19. So 64 bits is NOT enough.
    // We must use 128-bit intermediates or truncate/scale aggressively.
    // Given the prompt "Use 64-bit intermediate values to prevent overflow", 
    // I suspect the inputs might be smaller than 8-bit full range, or the solver expects simpler logic.
    // However, to be safe and correct for full range, I will use SystemVerilog logic types for 128-bit math internally if needed, 
    // but the prompt asks for 64-bit. 
    // Let's re-read carefully: "Use 64-bit intermediate values". 
    // This implies the design should be robust for 64-bit accumulators. 
    // If inputs are 8-bit, the max magnitude is 255.
    // Let's check the determinant of A (Deltas).
    // Deltas are diff of 8-bit numbers -> range -255 to 255.
    // Q16.16 representation: magnitude ~ 6.7e6.
    // Product of 3: 3 * (6.7e6)^3 = 9e20. -> 2^69. 
    // So 64-bit is definitely insufficient for the raw determinants if we stick to Q16.16 for M.
    // HOWEVER, the problem states "Scale factors: multiply by 65536".
    // Maybe we should scale down BEFORE multiplication to keep bits low?
    // "All intermediate calculations use Q16.16 fixed-point arithmetic."
    // This is contradictory for determinants of 3x3 matrices of Q16.16.
    // 
    // Let's try a different approach. The problem asks for Cramer's rule or Matrix Inversion.
    // Maybe we should interpret the "64-bit" hint as: use 64-bit `reg` for intermediate calculations, 
    // which implies we cannot handle the full 8-bit range without overflow, or we must carefully truncate.
    // OR, perhaps the points are expected to be small enough that 64-bit works.
    // 
    // Alternative: The Geometric solution (Lehmer / Bellavitis) is often used.
    // Center = (|P2|^2 (P3-P1) x (P4-P1) + ... ) / (2 * |(P2-P1) x (P3-P1)|^2)
    // This involves cross products and dot products. 
    // This might be safer in fixed point because we can scale divisions.
    // 
    // Let's try to fit Cramer's rule into 64-bit math by scaling inputs. 
    // If we treat the input points as Q8.0 integers (not Q16.16) for the determinant calculations, 
    // and handle the Q16.16 scaling in the final result.
    // Wait, "All intermediate calculations use Q16.16 fixed-point arithmetic."
    // 
    // Okay, let's assume the "Use 64-bit intermediate values" means the accumulator for the determinant 
    // is 64-bit. If the problem requires full range 8-bit inputs, it's mathematically impossible to fit 
    // in 64-bit without floating point or larger integers.
    // However, usually in these embedded/fpga tasks, the "scale factor" hint is key.
    // 
    // Let's look at the equation structure again.
    // 2(xj-xi)x + ... = ...
    // If we divide the whole system by 2, we get:
    // (xj-xi)x + ... = (xj^2 - xi^2 + ...)/2
    // Let's work with the Deltas (diffs) as integers (8-bit) first, then scale.
    // D1 = P2 - P1 (integer -128 to 128).
    // RHS = (|P2|^2 - |P1|^2)/2.
    // Note: |P|^2 is int * int. Sum of squares. 
    // If P is 8-bit, |P|^2 is 16-bit. 
    // RHS fits in 32-bit easily.
    // Determinant of Matrix of Deltas (3x3) is integer. 
    // Value <= 128^3 * 3 = 6.2e6. Fits in 32-bit.
    // 
    // So the trick is: 
    // 1. Compute Deltas as integers (8-bit, extend to 32-bit for math).
    // 2. Compute RHS as 32-bit integers.
    // 3. Solve Ax=b where A is integer, b is integer.
    // 4. Result (x, y, z) will be rational numbers.
    // 5. To get Q16.16, we multiply numerator by 65536 and divide by denominator.
    // 
    // BUT the prompt says: "All intermediate calculations use Q16.16 fixed-point arithmetic."
    // This might mean the variables holding the points (dx, etc) are conceptually Q16.16, 
    // but for the math, we can treat them as scaled integers. 
    // 
    // Let's follow the "Safe" path: 
    // Since 64-bit isn't enough for full Q16.16 * 3 matrix, we must be clever.
    // Is it possible the inputs are NOT 8-bit full range? 
    // "Input integers are converted to Q16.16 by shifting left 16 bits"
    // 
    // Let's try the Geometric solution with 64-bit intermediates.
    // Center formula:
    // Let u = P2-P1, v = P3-P1, w = P4-P1.
    // Let A = cross(u, v)
    // Let B = cross(w, u)
    // Let D = cross(v, w)
    // Let C = cross(w, v)
    // 
    // Center = P1 + 
    // ( (|u|^2 * D + |v|^2 * B + |w|^2 * A ) ) / (2 * (A . w))
    // This is for tetrahedron? No.
    // Standard formula for circumsphere center of 4 points:
    // O = ( |P2-P1|^2 * ( (P3-P1) x (P4-P1) ) + ... ) / ( 2 * ( (P2-P1) x (P3-P1) ) . (P4-P1) )
    // Actually, a more robust formula:
    // Solve M * C = N where M is matrix of dot products and N is vector of 0.5*(|Pj|^2 - |Pi|^2).
    // 
    // Let's use Cramer's rule on the system derived from:
    // (P2-P1).C = (|P2|^2 - |P1|^2)/2
    // (P3-P1).C = (|P3|^2 - |P1|^2)/2
    // (P4-P1).C = (|P4|^2 - |P1|^2)/2
    // 
    // Let A be the matrix with rows (P2-P1), (P3-P1), (P4-P1).
    // Let b be the vector of RHS.
    // 
    // If we treat P as Q8.0 integers for A and b, we get integer determinants.
    // Determinant of A: Det_A (Integer).
    // Determinant of A with Col 1 replaced by b: Det_X.
    // x = Det_X / Det_A.
    // 
    // To get Q16.16 output: result = (Det_X << 16) / Det_A.
    // This works for integer math! 
    // The "Q16.16 intermediate" requirement might be satisfied by the fact that the Result 
    // is conceptually Q16.16, and we use 64-bit math to prevent overflow during the shift-and-divide.
    // 
    // Let's assume the inputs are 8-bit signed integers (the raw values). 
    // We will NOT shift them to Q16.16 before computing A and b.
    // We will compute A and b using full integer width (extend to 32-bit to be safe).
    // 
    // Wait, "Inputs are converted to Q16.16 by shifting left 16 bits". 
    // This might be a hint on how to interpret the raw input bits, or just a description of how fixed point works.
    // If I shift inputs to Q16.16, I overflow 64-bit math.
    // If I treat inputs as integers, I can fit in 64-bit math.
    // 
    // Let's check if integer math is valid.
    // Equation: (P2-P1).C = (|P2|^2 - |P1|^2)/2.
    // If P is integer, (P2-P1) is integer.
    // RHS is integer/2. 
    // If we multiply the equation by 2, we get integer coefficients on both sides.
    // 2(P2-P1).C = |P2|^2 - |P1|^2.
    // This is cleaner!
    // Let's use this.
    // Matrix M' with rows 2(Pj-Pi).
    // Vector B' with components (|Pj|^2 - |Pi|^2).
    // Solve M' * C = B'.
    // C = M'^-1 * B'.
    // 
    // M' entries: range -256 to 256.
    // B' entries: (255^2*2) = 130k. Range approx -130k to 130k.
    // Determinant of M' = 8 * Det(A) where A is matrix of Deltas.
    // Det(M') max ~ 8 * (256)^3 * 3 ~ 4e8. Fits in 64-bit easily.
    // Determinant of M' with replaced column (Num) ~ (130k) * (256^2) * 3 ~ 2.5e10. Fits in 64-bit.
    // 
    // Result C = Num / Det(M').
    // To get Q16.16: C_fp = (Num << 16) / Det(M').
    // Num is ~2.5e10. << 16 is ~1.6e15. 
    // Det is ~4e8. 
    // Result ~4000. This is small, expected for 8-bit inputs.
    // 1.6e15 / 4e8 fits in 64-bit integer division.
    // 
    // So, the strategy:
    // 1. Read 8-bit inputs.
    // 2. Compute Deltas (diffs).
    // 3. Compute B' components (diffs of squared magnitudes).
    // 4. Compute Determinant of Matrix M' (Rows: 2*dx, 2*dy, 2*dz).
    //    Actually, the factor of 2 can be ignored for both M' and B'? 
    //    No, B' is derived from the equation, M' is derived from LHS.
    //    Let's stick to: (Pj-Pi).C = (|Pj|^2 - |Pi|^2)/2. 
    //    Multiply by 2: 2(Pj-Pi).C = |Pj|^2 - |Pi|^2.
    //    So M' = 2*Delta.
    //    B' = |Pj|^2 - |Pi|^2.
    //    
    // 5. Compute Det_A (M') = 8 * Det(Delta). We can compute it directly with 2*dx etc.
    //    Actually, factoring out 2: 
    //    If M' = 2*Delta, then Det(M') = 8 * Det(Delta).
    //    If we compute x = Det(M'_x) / Det(M'), where M'_x is M' with col 1 replaced by B'.
    //    Det(M'_x) = B'1 * (2*dy2*2*dz3 - 2*dy3*2*dz2) - ...
    //    Det(M'_x) = 4 * ( B'1 * (dy2*dz3 - dy3*dz2) - ... )
    //    So x = [4 * Det(Delta_x)] / [8 * Det(Delta)] = 0.5 * (Det(Delta_x) / Det(Delta)).
    //    Wait, the equation is M' * C = B'.
    //    So C = M'^-1 * B'.
    //    If M' = 2*Delta, C = (2*Delta)^-1 * B' = 0.5 * Delta^-1 * B'.
    //    This doesn't match the previous scaling.
    //    
    //    Let's go back to the original linear system:
    //    (Pj - Pi).C = (|Pj|^2 - |Pi|^2)/2. 
    //    Let M = Delta (matrix of Pj-Pi).
    //    Let V = (|Pj|^2 - |Pi|^2)/2.
    //    M * C = V.
    //    To keep integer math, we can scale M and V. 
    //    But V is naturally odd/even. 
    //    Let's stick to the integerization strategy.
    //    Multiply equation by 2: 2M * C = 2V = (|Pj|^2 - |Pi|^2).
    //    Let M_int = 2 * Delta.
    //    Let V_int = (|Pj|^2 - |Pi|^2).
    //    M_int * C = V_int.
    //    C = V_int / M_int (in matrix sense).
    //    
    //    We need C in Q16.16.
    //    Since M_int and V_int are integers, C is rational.
    //    C_fp = (V_int << 16) / M_int (where / is matrix inverse).
    //    
    //    Let's use Cramer's rule:
    //    Let A = M_int.
    //    Let D = Det(A).
    //    Let D_x = Det(A with col 1 replaced by V_int).
    //    Let D_y = Det(A with col 2 replaced by V_int).
    //    Let D_z = Det(A with col 3 replaced by V_int).
    //    
    //    Result X = (D_x << 16) / D.
    //    Result Y = (D_y << 16) / D.
    //    Result Z = (D_z << 16) / D.
    //    
    //    This fits the "64-bit intermediate" constraint (D_x and D are 64-bit max).
    //    This satisfies "All intermediate calculations use Q16.16" loosely by treating the result generation as the fixed point step.
    //    The prompt says "Input integers are converted to Q16.16 by shifting left 16 bits".
    //    This might imply we should shift inputs first. But we saw that overflows.
    //    However, if we do the math in 64-bit, let's re-check the overflow.
    //    If we shift inputs: p1x = p1 << 16. Max ~ 1.6e6.
    //    Delta: ~ 1.6e6.
    //    2*Delta: ~ 3.2e6.
    //    Det(2*Delta): 3 * (3.2e6)^3 = 1e20. 2^66.
    //    So 64-bit is NOT enough for Q16.16 inputs.
    //    
    //    Therefore, we MUST treat inputs as 8-bit integers for the determinant math.
    //    The "convert to Q16.16" instruction is likely about the conceptual model, or how we interpret the output.
    //    "Scale factors: multiply by 65536 (2^16) for fixed-point conversion."
    //    This applies to the output. (D_x << 16) / D is exactly this.
    //    
    //    So the plan is:
    //    1. Compute Deltas as 16-bit integers (extending 8-bit sign).
    //    2. Compute V_int = (|P|^2 diff) as 32-bit integers.
    //    3. Compute M_int = 2 * Delta. (Use 16-bit or 32-bit).
    //    4. Compute Determinants using 64-bit accumulators.
    //       - Det_A (of M_int).
       //       - Det_X, Det_Y, Det_Z.
    //    5. Perform Division: (Det_X << 16) / Det_A, etc.
    //       - Division of 64-bit numbers. 
    //       - Det_X is ~ 2.5e10. Det_A ~ 4e8.
    //       - Det_X << 16 = 1.6e15. Div result ~ 4000. 
    //       - 4000 fits in 16-bit, but output is 32-bit.
    //       - The division must be done carefully to avoid precision loss.
    //       - Since we need Q16.16, we can do: ((Det_X * 65536) / Det_A). 
    //       - Det_X is 64-bit. Det_X * 65536 will overflow 64-bit (2.5e10 * 6.5e4 = 1.6e15 -> still fits? 2^64 is 1.8e19. YES.)
    //       - Wait, 1.6e15 < 1.8e19. So `Det_X << 16` fits in 64-bit.
    //       - We need to do `(Det_X << 16) / Det_A`.
    //       - We need a 64-bit divider.
    //       - Verilog has `/` operator for synthesis. 
    //       - However, Verilog integer division truncates towards zero.
    //       - We want proper fixed point rounding. 
    //       - We can compute `((Det_X << 16) + (Det_A >> 1)) / Det_A` for rounding.
    //       - Or simply truncate if precision allows.
    
    //    
    //    IMPORTANT: Sign extension. 
    //    Inputs are signed 8-bit. Deltas are signed. V_int is signed.
    //    
    //    Let's write the code.

    // --- Step 1: Integer Deltas and Squares ---
    // Extend 8-bit to 16-bit (or 32-bit) for safety.
    wire signed [15:0] p1_x_ext, p1_y_ext, p1_z_ext;
    wire signed [15:0] p2_x_ext, p2_y_ext, p2_z_ext;
    wire signed [15:0] p3_x_ext, p3_y_ext, p3_z_ext;
    wire signed [15:0] p4_x_ext, p4_y_ext, p4_z_ext;

    assign p1_x_ext = {{8{p1_x[7]}}, p1_x};
    assign p1_y_ext = {{8{p1_y[7]}}, p1_y};
    assign p1_z_ext = {{8{p1_z[7]}}, p1_z};
    assign p2_x_ext = {{8{p2_x[7]}}, p2_x};
    assign p2_y_ext = {{8{p2_y[7]}}, p2_y};
    assign p2_z_ext = {{8{p2_z[7]}}, p2_z};
    assign p3_x_ext = {{8{p3_x[7]}}, p3_x};
    assign p3_y_ext = {{8{p3_y[7]}}, p3_y};
    assign p3_z_ext = {{8{p3_z[7]}}, p3_z};
    assign p4_x_ext = {{8{p4_x[7]}}, p4_x};
    assign p4_y_ext = {{8{p4_y[7]}}, p4_y};
    assign p4_z_ext = {{8{p4_z[7]}}, p4_z};

    // Deltas (Pj - Pi)
    wire signed [15:0] dx1_int, dy1_int, dz1_int; // P2 - P1
    wire signed [15:0] dx2_int, dy2_int, dz2_int; // P3 - P1
    wire signed [15:0] dx3_int, dy3_int, dz3_int; // P4 - P1

    assign dx1_int = p2_x_ext - p1_x_ext;
    assign dy1_int = p2_y_ext - p1_y_ext;
    assign dz1_int = p2_z_ext - p1_z_ext;
    assign dx2_int = p3_x_ext - p1_x_ext;
    assign dy2_int = p3_y_ext - p1_y_ext;
    assign dz2_int = p3_z_ext - p1_z_ext;
    assign dx3_int = p4_x_ext - p1_x_ext;
    assign dy3_int = p4_y_ext - p1_y_ext;
    assign dz3_int = p4_z_ext - p1_z_ext;

    // M_int = 2 * Delta
    // Range: +/- 256 * 2 = +/- 512. Fits in 16-bit signed easily.
    wire signed [15:0] m11, m12, m13;
    wire signed [15:0] m21, m22, m23;
    wire signed [15:0] m31, m32, m33;

    assign m11 = dx1_int <<< 1;
    assign m12 = dy1_int <<< 1;
    assign m13 = dz1_int <<< 1;
    assign m21 = dx2_int <<< 1;
    assign m22 = dy2_int <<< 1;
    assign m23 = dz2_int <<< 1;
    assign m31 = dx3_int <<< 1;
    assign m32 = dy3_int <<< 1;
    assign m33 = dz3_int <<< 1;

    // |P|^2 
    // 16-bit * 16-bit = 32-bit.
    wire signed [31:0] s1_x2_int, s1_y2_int, s1_z2_int;
    wire signed [31:0] s2_x2_int, s2_y2_int, s2_z2_int;
    wire signed [31:0] s3_x2_int, s3_y2_int, s3_z2_int;
    wire signed [31:0] s4_x2_int, s4_y2_int, s4_z2_int;

    assign s1_x2_int = p1_x_ext * p1_x_ext;
    assign s1_y2_int = p1_y_ext * p1_y_ext;
    assign s1_z2_int = p1_z_ext * p1_z_ext;
    assign s2_x2_int = p2_x_ext * p2_x_ext;
    assign s2_y2_int = p2_y_ext * p2_y_ext;
    assign s2_z2_int = p2_z_ext * p2_z_ext;
    assign s3_x2_int = p3_x_ext * p3_x_ext;
    assign s3_y2_int = p3_y_ext * p3_y_ext;
    assign s3_z2_int = p3_z_ext * p3_z_ext;
    assign s4_x2_int = p4_x_ext * p4_x_ext;
    assign s4_y2_int = p4_y_ext * p4_y_ext;
    assign s4_z2_int = p4_z_ext * p4_z_ext;

    wire signed [31:0] S1_int, S2_int, S3_int, S4_int;
    assign S1_int = s1_x2_int + s1_y2_int + s1_z2_int;
    assign S2_int = s2_x2_int + s2_y2_int + s2_z2_int;
    assign S3_int = s3_x2_int + s3_y2_int + s3_z2_int;
    assign S4_int = s4_x2_int + s4_y2_int + s4_z2_int;

    // V_int (RHS of M*C = V)
    // V = |Pj|^2 - |Pi|^2.
    // Range: 32-bit. Max diff ~ (128^2*3)*2 = ~98,000. Fits in 32-bit.
    wire signed [31:0] v1_int, v2_int, v3_int;
    assign v1_int = S2_int - S1_int;
    assign v2_int = S3_int - S1_int;
    assign v3_int = S4_int - S1_int;

    // --- Step 2: Determinants ---
    // We need 64-bit accumulators for products.
    // Let's use Verilog's `wire signed [63:0]` for all intermediate products.

    // Matrix A (M_int):
    // [ m11 m12 m13 ]
    // [ m21 m22 m23 ]
    // [ m31 m32 m33 ]
    
    // Det_A = m11*(m22*m33 - m23*m32) - m12*(m21*m33 - m23*m31) + m13*(m21*m32 - m22*m31)
    wire signed [63:0] a1, a2, a3, a4, a5, a6;
    assign a1 = m22 * m33;
    assign a2 = m23 * m32;
    assign a3 = m21 * m33;
    assign a4 = m23 * m31;
    assign a5 = m21 * m32;
    assign a6 = m22 * m31;

    wire signed [63:0] sub1, sub2, sub3;
    assign sub1 = a1 - a2;
    assign sub2 = a3 - a4;
    assign sub3 = a5 - a6;

    wire signed [63:0] term1, term2, term3;
    assign term1 = m11 * sub1;
    assign term2 = m12 * sub2;
    assign term3 = m13 * sub3;

    wire signed [63:0] det_A;
    assign det_A = term1 - term2 + term3;

    // Det_X (replace Col 1 with V)
    // [ v1 m12 m13 ]
    // [ v2 m22 m23 ]
    // [ v3 m32 m33 ]
    // Det = v1*(m22*m33 - m23*m32) - m12*(v2*m33 - m23*v3) + m13*(v2*m32 - m22*v3)
    wire signed [63:0] b1, b2, b3, b4, b5, b6;
    // b1 = m22*m33 (reuse a1)
    // b2 = m23*m32 (reuse a2)
    assign b3 = v2 * m33;
    assign b4 = m23 * v3;
    assign b5 = v2 * m32;
    assign b6 = m22 * v3;

    wire signed [63:0] x_sub1, x_sub2, x_sub3;
    assign x_sub1 = a1 - a2; // m22*m33 - m23*m32
    assign x_sub2 = b3 - b4; // v2*m33 - m23*v3
    assign x_sub3 = b5 - b6; // v2*m32 - m22*v3

    wire signed [63:0] x_term1, x_term2, x_term3;
    assign x_term1 = v1 * x_sub1;
    assign x_term2 = m12 * x_sub2;
    assign x_term3 = m13 * x_sub3;

    wire signed [63:0] det_X;
    assign det_X = x_term1 - x_term2 + x_term3;

    // Det_Y (replace Col 2 with V)
    // [ m11 v1 m13 ]
    // [ m21 v2 m23 ]
    // [ m31 v3 m33 ]
    // Det = m11*(v2*m33 - m23*v3) - v1*(m21*m33 - m23*m31) + m13*(m21*v3 - v2*m31)
    wire signed [63:0] y_b1, y_b2, y_b3, y_b4, y_b5, y_b6;
    assign y_b1 = v2 * m33;
    assign y_b2 = m23 * v3;
    assign y_b3 = m21 * m33; // a3
    assign y_b4 = m23 * m31; // a4
    assign y_b5 = m21 * v3;
    assign y_b6 = v2 * m31;

    wire signed [63:0] y_sub1, y_sub2, y_sub3;
    assign y_sub1 = y_b1 - y_b2;
    assign y_sub2 = y_b3 - y_b4;
    assign y_sub3 = y_b5 - y_b6;

    wire signed [63:0] y_term1, y_term2, y_term3;
    assign y_term1 = m11 * y_sub1;
    assign y_term2 = v1 * y_sub2;
    assign y_term3 = m13 * y_sub3;

    wire signed [63:0] det_Y;
    assign det_Y = y_term1 - y_term2 + y_term3;

    // Det_Z (replace Col 3 with V)
    // [ m11 m12 v1 ]
    // [ m21 m22 v2 ]
    // [ m31 m32 v3 ]
    // Det = m11*(m22*v3 - v2*m32) - m12*(m21*v3 - v2*m31) + v1*(m21*m32 - m22*m31)
    wire signed [63:0] z_b1, z_b2, z_b3, z_b4, z_b5, z_b6;
    assign z_b1 = m22 * v3;
    assign z_b2 = v2 * m32;
    assign z_b3 = m21 * v3;
    assign z_b4 = v2 * m31;
    assign z_b5 = m21 * m32; // a5
    assign z_b6 = m22 * m31; // a6

    wire signed [63:0] z_sub1, z_sub2, z_sub3;
    assign z_sub1 = z_b1 - z_b2;
    assign z_sub2 = z_b3 - z_b4;
    assign z_sub3 = z_b5 - z_b6;

    wire signed [63:0] z_term1, z_term2, z_term3;
    assign z_term1 = m11 * z_sub1;
    assign z_term2 = m12 * z_sub2;
    assign z_term3 = v1 * z_sub3;

    wire signed [63:0] det_Z;
    assign det_Z = z_term1 - z_term2 + z_term3;

    // --- Step 3: Division & Scaling ---
    // We need to compute: 
    // Result = (Det << 16) / Det_A
    // We need to handle division by zero? (Points are coplanar). 
    // Assuming valid inputs (non-coplanar).
    
    // We must perform signed division. 
    // In Verilog, / operator is signed if operands are signed.
    // But we need to shift the numerator before division.
    // Numerator = Det << 16.
    // However, Det is 64-bit. Shifting left 16 bits might overflow 64-bit if Det is large.
    // Check Max Det_X: 
    // V_int max ~ 130k. Deltas ~ 256. 
    // Term: V * (Delta^2). 130k * (256^2) = 130k * 65k = 8.4e9.
    // Sum of 3 terms: ~2.5e10.
    // Det_X ~ 2.5e10. 
    // Det_X << 16 = 2.5e10 * 65536 = 1.6e15.
    // 2^64 = 1.84e19. 
    // So 1.6e15 < 1.84e19. It fits in 64-bit signed.
    // 
    // Det_A max: Delta^3 = 256^3 = 1.6e7. * 3 = 4.8e7. 
    // 
    // Division 1.6e15 / 4.8e7 = 3.3e7. 
    // 3.3e7 is the result. Range is fine.
    
    // Rounding: 
    // To get nearest integer, ((N * 65536) + (D/2)) / D
    // Or just truncate. Truncate is fine for now.
    
    wire signed [63:0] num_x, num_y, num_z;
    assign num_x = det_X <<< 16;
    assign num_y = det_Y <<< 16;
    assign num_z = det_Z <<< 16;

    // Signed division.
    // Note: Verilog division can be expensive but is synthesizable.
    // Ensure we handle negative numbers correctly.
    // If det_A is negative, the result should handle sign.
    
    // Edge case: det_A = 0. (Points coplanar). 
    // To prevent X, we can add a small offset to denominator or just let it saturate/divide by zero.
    // Most synthesis tools handle divide by zero gracefully (undefined or saturation). 
    // Let's add a tiny check to avoid division by zero to make it robust, 
    // though the prompt doesn't explicitly ask for it. 
    // `det_A == 0` is rare. Let's proceed without extra logic to keep it combinational and simple.
    
    wire signed [63:0] res_x_raw, res_y_raw, res_z_raw;
    assign res_x_raw = num_x / det_A;
    assign res_y_raw = num_y / det_A;
    assign res_z_raw = num_z / det_A;

    // The result is a Q16.16 integer representation.
    // It fits in 32-bit signed (Range +/- 2^15 = 32768).
    // Result magnitude was ~3.3e7, which is > 32768. 
    // Wait. 3.3e7 is about 33 million. 2^31 is 2 billion. 
    // 33 million fits in 32-bit integer.
    // 33 million is 0x01FA F080.
    // So the result fits in 32-bit signed integer.
    // However, it represents Q16.16. 
    // 33 million in Q16.16 means 33,000,000 / 65536 = ~503.
    // Does it make sense for a circumsphere center to be 500 units away from origin if inputs are +/- 128?
    // Yes, if the points are arranged such that the center is far away (flat triangle).
    // 
    // So we truncate the 64-bit result to 32-bit.
    // But we need to be careful with overflow. 
    // If the result is > 2^31, it overflows 32-bit signed.
    // The problem says "Output center coordinates are in Q16.16 format".
    // Q16.16 range is +/- 32768.
    // This implies the output MUST be within this range, or we should saturate.
    // If the inputs are 8-bit, the circumsphere center can definitely exceed +/- 32768 in Q16.16 representation.
    // Wait, Q16.16 represents values +/- 32768.0.
    // If the center is at 500.0, the value is 500 * 65536 = 32,768,000.
    // This fits in 32-bit signed integer (0x01 F4 00 00).
    // So the `center_x` output is a 32-bit integer representing the fixed point value.
    // So we just need to take the lower 32 bits of the result? 
    // No, we need the full result. If it exceeds 32-bit, we might have overflowed.
    // 
    // Let's re-evaluate the magnitude calculation.
    // Max Det_X = 2.5e10.
    // Num = 2.5e10 * 65536 = 1.6e15.
    // Det_A = 4.8e7.
    // Result = 1.6e15 / 4.8e7 = 3.3e7.
    // 3.3e7 fits in 32-bit signed integer (max 2.1e9).
    // So the raw integer result fits in 32-bit.
    // 
    // So we can safely take the lower 32 bits of the 64-bit division result.
    // Or cast it to 32-bit.
    // 
    // One more check: What if det_A is negative? 
    // Num is signed. Det_A is signed. Verilog `/` does signed division.
    // Result is correct.
    
    // Final output assignment.
    // We must ensure no overflow/crash.
    // 
    // To be safe against 0 denominator, we can add a tiny logic:
    // If det_A is 0, output 0 (or X). Let's output 0 to avoid X propagation.
    
    wire signed [63:0] safe_det_A;
    // If det_A is 0, set to 1 to avoid div by zero. Result will be garbage but defined.
    // Or better, let's just check if det_A is 0 and force output to 0.
    wire det_A_is_zero;
    assign det_A_is_zero = (det_A == 0);

    wire signed [63:0] adj_det_A;
    assign adj_det_A = (det_A_is_zero) ? 64'sd1 : det_A;

    // Recompute division with safe denominator
    wire signed [63:0] res_x_safe, res_y_safe, res_z_safe;
    assign res_x_safe = (det_A_is_zero) ? 0 : (num_x / adj_det_A);
    assign res_y_safe = (det_A_is_zero) ? 0 : (num_y / adj_det_A);
    assign res_z_safe = (det_A_is_zero) ? 0 : (num_z / adj_det_A);

    // Assign to output ports (32-bit)
    // Since the result fits in 32-bit, we can just cast.
    assign center_x = res_x_safe[31:0];
    assign center_y = res_y_safe[31:0];
    assign center_z = res_z_safe[31:0];

endmodule
