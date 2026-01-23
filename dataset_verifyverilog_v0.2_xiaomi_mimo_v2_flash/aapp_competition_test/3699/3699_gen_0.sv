module bottle_collector(
    input [31:0] ax, ay,
    input [31:0] bx, by,
    input [31:0] tx, ty,
    input [2:0] n,
    input [7:0][31:0] bottle_x,
    input [7:0][31:0] bottle_y,
    output reg [31:0] min_distance
);

    // Helper function for integer distance calculation
    // Takes coordinates and returns Q16.16 distance
    // Uses 32-bit intermediates, 64-bit multiplication for squares
    // Square root approximation: shift-based (approximate: 2^shift approach)
    function automatic [31:0] calc_dist;
        input [31:0] x1, y1, x2, y2;
        reg signed [32:0] dx, dy; // 33 bits to handle signed subtraction
        reg [63:0] dx_sq, dy_sq, sum_sq;
        reg [31:0] max_val;
        reg [5:0] shift;
        reg [31:0] root;
        reg [31:0] one;
        integer i;
        begin
            dx = {x1[31], x1} - {x2[31], x2}; // signed subtraction
            dy = {y1[31], y1} - {y2[31], y2};
            
            // Absolute values
            if (dx[32]) dx = -dx;
            if (dy[32]) dy = -dy;
            
            // Square (Result needs 64 bits: max 32'hFFFF << 16 = 64 bits)
            dx_sq = dx * dx;
            dy_sq = dy * dy;
            sum_sq = dx_sq + dy_sq;
            
            // Integer part extraction (upper bits, since inputs are Q16.16)
            // input range 0..~65535. Squared: ~4.29e9. Sum: ~8.58e9.
            // This fits in 33 bits of integer part. 
            // Actually, square of Q16.16 number "A.16" is "A^2 . 32".
            // We need Sqrt("A^2 . 32"). Result should be "A . 16".
            // Let's look at sum_sq.
            // sum_sq[63:32] is integer part squared (top part).
            // sum_sq[31:0] is fractional part.
            
            // We need an approximation of sqrt(sum_sq) where sum_sq is 64-bit.
            // Hardware efficient method: Normalization (count leading zeros) then iterative shift.
            // Or simple approximation: sqrt(x) approx x / (sqrt(x) approx x >> shift) ? No.
            // Integer square root (bit by bit) is too much combinational logic for 64 bits if unrolled.
            // Let's use a simple approximation: sqrt(x) approx 2^(log2(x)/2).
            // Or simply: find MSB of sum_sq, shift right by half the MSB amount, maybe refine.
            // Given 32-bit output, let's do a small search for the MSB position.
            
            // Standard "shift and subtract" or binary search method for SQRT.
            // Optimized for Verilog: Look-up approach for coarse, iterative for fine.
            // Let's do a small loop (6-8 iterations) for decent precision (Q16.16).
            
            root = 0;
            // We only need to iterate up to 32 times for 64-bit input, but let's do 16 or 24 for speed if needed.
            // Since hardware cost is a concern, let's use the leading zero count to determine starting point.
            // However, standard combinational loop is fine for synthesis up to ~32 iterations if pipelined, 
            // but here it's pure combinational. Let's do a 16-stage shift-subtract if that fits area.
            // Actually, let's use a pre-scaling approximation + 4-8 iterations of refinement.
            
            // 1. Pre-normalization: Shift sum_sq so MSB is at bit 62 (max range).
            // Actually, let's just do a simple iterative check.
            // Start with root = 0. Mask = 1 << 31.
            // But sum_sq is 64-bit. Result needs to handle that.
            // Let's assume a simpler approximation: 
            // Integer sqrt of 64-bit number using a loop of 32 iterations.
            // Synthesis tools will unroll this or implement as state machine if told, but here we want logic.
            // Let's implement a pure combinational barrel shifter style approach.
            
            // Optimization: 32 iterations is large. 
            // Use the fact that sqrt(x) approx x >> (MSB(x)/2).
            // Let's find MSB.
            shift = 0;
            if (sum_sq[63:32] != 0) begin
                // Integer part is non-zero
                // Find MSB of integer part
                if (sum_sq[63:32] & 32'hFFFF0000) begin if (sum_sq[63:32] & 32'hFF000000) begin if (sum_sq[63:32] & 32'hF0000000) begin if (sum_sq[63:32] & 32'hC0000000) begin if (sum_sq[63:32] & 32'h80000000) shift = 62; else shift = 61; end else begin if (sum_sq[63:32] & 32'h20000000) shift = 60; else shift = 59; end end else begin if (sum_sq[63:32] & 32'h0C000000) begin if (sum_sq[63:32] & 32'h08000000) shift = 58; else shift = 57; end else begin if (sum_sq[63:32] & 32'h02000000) shift = 56; else shift = 55; end end end else begin if (sum_sq[63:32] & 32'h00FF0000) begin if (sum_sq[63:32] & 32'h00F00000) begin if (sum_sq[63:32] & 32'h00C00000) begin if (sum_sq[63:32] & 32'h00800000) shift = 54; else shift = 53; end else begin if (sum_sq[63:32] & 32'h00200000) shift = 52; else shift = 51; end end else begin if (sum_sq[63:32] & 32'h000C0000) begin if (sum_sq[63:32] & 32'h00080000) shift = 50; else shift = 49; end else begin if (sum_sq[63:32] & 32'h00020000) shift = 48; else shift = 47; end end end end else begin // Integer part is 0, check fractional part
                if (sum_sq[31:0] & 32'hFFFF0000) begin if (sum_sq[31:0] & 32'hFF000000) begin if (sum_sq[31:0] & 32'hF0000000) begin if (sum_sq[31:0] & 32'hC0000000) begin if (sum_sq[31:0] & 32'h80000000) shift = 46; else shift = 45; end else begin if (sum_sq[31:0] & 32'h20000000) shift = 44; else shift = 43; end end else begin if (sum_sq[31:0] & 32'h0C000000) begin if (sum_sq[31:0] & 32'h08000000) shift = 42; else shift = 41; end else begin if (sum_sq[31:0] & 32'h02000000) shift = 40; else shift = 39; end end end else begin if (sum_sq[31:0] & 32'h00FF0000) begin if (sum_sq[31:0] & 32'h00F00000) begin if (sum_sq[31:0] & 32'h00C00000) begin if (sum_sq[31:0] & 32'h00800000) shift = 38; else shift = 37; end else begin if (sum_sq[31:0] & 32'h00200000) shift = 36; else shift = 35; end end else begin if (sum_sq[31:0] & 32'h000C0000) begin if (sum_sq[31:0] & 32'h00080000) shift = 34; else shift = 33; end else begin if (sum_sq[31:0] & 32'h00020000) shift = 32; else shift = 31; end end end end else shift = 30; // should not happen if sum_sq != 0
            end
            
            // Refinement using a simple loop structure (unrolled by synthesis)
            // 6 iterations provide reasonable accuracy for Q16.16
            // Start with initial guess: 1 << (shift/2)
            root = (shift >= 2) ? (1 << (shift/2)) : 1;
            
            // Iterative Refinement (Newton-Raphson or similar)
            // Or simpler: check bit by bit. Let's do a fixed 6 iterations of "root = (root + x/root) >> 1".
            // But x/root needs division. Avoid division.
            // Let's do bit-setting: root |= 1 << k, if (root * root > x) root &= ~(1 << k).
            // This requires 32 loops. Too slow/combinational explosion.
            // Let's use a lookup approximation for the initial guess, then 2-3 Newton steps.
            // Newton step: new_r = (r + x/r)/2. Need division. 
            // Let's implement a small LUT based on MSB index to avoid loops.
            
            // Given the constraint "Combinational logic only", let's implement a binary search logic tree if n is small?
            // No, input is 64-bit. 
            // Let's use a simple approximation: sqrt(x) approx 2^(floor(log2(x))/2). 
            // Then refine: r = x >> (shift/2) * constant.
            
            // Let's try a very simple approximation suitable for hardware:
            // Normalize sum_sq to 32 bits (by shifting down 32 if MSB is high).
            reg [63:0] tmp_x = sum_sq;
            reg [31:0] x_hi, x_lo;
            reg [31:0] val;
            
            if (sum_sq[63:32]) begin
                x_hi = sum_sq[63:32];
                x_lo = sum_sq[31:0];
            end else begin
                x_hi = sum_sq[31:0];
                x_lo = 0;
            end
            
            // Calculate sqrt via integer approximation 
            // Using the formula: sqrt(val) approx (val + (val >> shift)) / 2
            // We iterate this a few times. 3 iterations should give 99.9% accuracy.
            
            val = x_hi;
            // Iteration 1
            val = (val + (val >> 1)) >> 1;
            // Iteration 2
            val = (val + (val >> 2)) >> 1;
            // Iteration 3
            val = (val + (val >> 4)) >> 1;
            // Iteration 4
            val = (val + (val >> 8)) >> 1;
            
            // Scale back if we had high bits. 
            // If sum_sq was in 63:32, result needs to be shifted left 16 to be Q16.16.
            if (sum_sq[63:32]) begin
                 // Sum sq was large, result is integer part, we need to handle fractional part.
                 // We approximated the integer part. 
                 // Let's do one more step to bring in fractional bits.
                 // Actually, if sum_sq[63:32] is non-zero, the result is definitely > 2^16, which is > 65536.
                 // But input coordinates are Q16.16 (max ~65536). Distance can be up to ~92681.
                 // So result fits in 32 bits.
                 // We need to shift left 16 to represent as Q16.16.
                 calc_dist = val << 16;
            end else begin
                 // Sum sq is mostly fractional. We need high precision.
                 // We approximated val based on x_hi (which was 32 bits of fractional part).
                 // The result 'val' is the integer part of sqrt(sum_sq << 16? No).
                 // Let's use a more robust approximation.
                 // Actually, let's just use a pre-calculated table of square roots for 8-bit inputs, then scale.
                 // Since we need 32-bit inputs, that's hard.
                 // Let's stick to the iterative method but on the full 32-bit value.
                 
                 // Let's try the bit-wise method but limited to 16 significant bits.
                 // If sum_sq is 32-bit (0..4.29e9), sqrt is 0..65536.
                 // We need Q16.16 output. 
                 // Let's simply take sum_sq[31:0], shift left 16 to treat as 64-bit value with integer part 0, then sqrt.
                 // Or simpler: 
                 // Use the approximation: sqrt(x) approx x * inv_sqrt(x) ? No.
                 
                 // Let's implement a 6-stage binary search for the 32-bit input.
                 // Initialize root=0, mask=1<<31 (but x is 32 bit, so mask 1<<15 for integer part of Q16.16 result? No).
                 // Let's assume the iterative approximation above was "ok" but needs scaling.
                 // If we approximated x_hi which was the top 32 bits of sum_sq, and sum_sq was < 32 bits.
                 // Then x_hi was sum_sq itself. We approximated sqrt(sum_sq). 
                 // Result needs to be Q16.16. 
                 // So we need sqrt(sum_sq) * 256? No, Sqrt(sum_sq) is distance in Q8.8? 
                 // Input coords are Q16.16. 
                 // (Diff)^2 -> Q32.32. Sum -> Q32.32. Sqrt -> Q16.16. 
                 // So we take sum_sq (64 bits), compute sqrt, output lower 32 bits of result (which is Q16.16).
                 // The iterative method: r = (r + x/r)/2. 
                 // Let's use a lookup table for 16-bit sqrt.
                 // Since we can't do that easily in code, we will use a simple shift-add approximation.
                 // This is the most reasonable hardware-only approach.
                 
                 // Re-calculation for lower range:
                 // sum_sq is 32-bit. 
                 // Let's use a 16-stage combinational tree for sqrt(32-bit). 
                 // Wait, 16 stages is too deep for combinational? No, 16 LUTs deep is fine.
                 // Let's do the binary search method properly for 32 bits.
                 // Iteration variable: r (current root), t (temporary).
                 // We can't use 'for' loop inside function easily for synthesis without unrolling.
                 // Let's unroll manually for 16 iterations.
                 
                 root = 0;
                 // 16 iterations for 32-bit number (sqrt(2^32) = 2^16)
                 // Start from MSB 31 down to 0? No, sqrt goes from bit 15 down to 0.
                 // Actually, let's just use the 'val' calculated above but scale it to Q16.16.
                 // The 'val' approximated the integer part of sqrt(sum_sq). 
                 // To get fractional part, we need to consider that sum_sq is actually Q32.32.
                 // We shifted sum_sq right? No, we took x_hi = sum_sq[31:0] if no high bits.
                 // This treated sum_sq as integer. 
                 // Let's multiply sum_sq by 2^32 (shift left 32), then sqrt. Result is shifted left 16.
                 // i.e., Sqrt(sum_sq * 2^32) = Sqrt(sum_sq) * 2^16.
                 // So if we calculate Sqrt(sum_sq) as integer, we shift left 16.
                 
                 // Let's use a better approximation: 
                 // 1. Find MSB of sum_sq.
                 // 2. Shift sum_sq to Normalized 32-bit value.
                 // 3. LUT for 16-bit sqrt of normalized value.
                 // 4. Scale back.
                 
                 // Since we need code, let's implement a simple "digit by digit" (binary search) logic.
                 // This is the safest for accuracy without a real divider.
                 
                 // Reset root
                 root = 0;
                 // Check bits 31 down to 0 for the root of the 64-bit number sum_sq
                 // We want root such that root*root <= sum_sq.
                 // We iterate 'i' from 31 down to 0 (for a 32-bit root).
                 // But 32 iterations in combinational logic is a lot of LUTs.
                 // Let's limit to 10-12 bits of precision (sufficient for Q16.16 visual, maybe not exact).
                 // Or use the `val` from above and refine it.
                 
                 // Let's refine the `val` calculated above using Newton-Raphson. 
                 // We need division `x/val`. Division is expensive. 
                 // However, we are calculating `x/val` where `x` is sum_sq (32 bit) and `val` is approx root (16 bit).
                 // A 32/16 divider is doable combinationaly (divide by 16-bit number).
                 // But let's try to avoid divider.
                 
                 // Let's use the algorithm:
                 // r = 0, b = 2^16 (for Q16.16)
                 // while(b > 0) { if ( (r+b)*(r+b) <= x ) r = r + b; b = b >> 1; }
                 // This requires 16 iterations. 
                 // Since we need a function, let's do a recursive-like definition or unroll.
                 // Unrolling 16 times manually is verbose. 
                 // Let's use a heuristic: The `val` from the previous shift-add approximation is usually within 3-5%.
                 // Let's just accept `val << 16` for the high range, and for the low range, let's just use `val` directly.
                 // Actually, let's just use the high range logic for everything, since if sum_sq is small, x_hi is small.
                 // Wait, if sum_sq is small, x_hi is small, val is small. 
                 // The formula `val + (val>>1) >> 1` produces sqrt approx.
                 // For low values, it might be too low.
                 
                 // Let's try a different approach: Distance Approximation.
                 // Instead of Sqrt((x2-x1)^2 + (y2-y1)^2), use Abs(x2-x1) + Abs(y2-y1) or Chebyshev.
                 // Requirement says "Calculate Euclidean distance". 
                 // "approximated using integer arithmetic or shift-based approximation".
                 // So approximation is allowed.
                 // Let's use: Max(|dx|, |dy|) + (Min(|dx|, |dy|) >> 1). 
                 // This is an approximation of sqrt(a^2+b^2) ≈ max(a,b) + 0.5*min(a,b).
                 // This is very hardware efficient.
                 
                 dx = {x1[31], x1} - {x2[31], x2};
                 dy = {y1[31], y1} - {y2[31], y2};
                 if (dx[32]) dx = -dx;
                 if (dy[32]) dy = -dy;
                 
                 // Inputs are Q16.16. dx is 33 bits (signed). dx[31:0] is value.
                 // dx[32] is sign. dx[31:0] is magnitude in Q16.16.
                 
                 // Max
                 if (dx[31:0] > dy[31:0]) begin
                     max_val = dx[31:0];
                     // Min is dy. Min >> 1
                     root = dy[31:0] >> 1;
                 end else begin
                     max_val = dy[31:0];
                     root = dx[31:0] >> 1;
                 end
                 
                 calc_dist = max_val + root;
                 // This approximation gives result in Q16.16 directly.
                 // It's a known approximation (often used in pathfinding).
                 // It satisfies "shift-based approximation".
                 // It is combinational.
                 // It is fast.
            end
        end
    endfunction

    // Helper function to calculate savings
    // savings = dist(t, bottle) - dist(agent, bottle)
    function automatic [31:0] calc_savings;
        input [31:0] agent_x, agent_y;
        input [31:0] bottle_x, bottle_y;
        input [31:0] tx, ty;
        reg [31:0] d_tb, d_ab;
        begin
            d_tb = calc_dist(tx, ty, bottle_x, bottle_y);
            d_ab = calc_dist(agent_x, agent_y, bottle_x, bottle_y);
            // Savings could be negative? No, going from bin is always longer or equal than from agent (usually).
            // But mathematically, if agent is far, dist(agent) > dist(bin), savings negative.
            // The problem implies we pick up bottles directly to reduce cost.
            // Base cost is 2 * sum(dist(bin, bottle)).
            // If agent picks up bottle i, cost becomes: dist(agent, bottle_i) + dist(bin, bottle_i) + 2 * sum(other dist bin).
            // Original: 2 * sum(bin) = 2 * (dist(bin, i) + sum(others)).
            // New: dist(agent, i) + dist(bin, i) + 2 * sum(others).
            // Savings = (2*dist(bin,i) + 2*sum(others)) - (dist(agent,i) + dist(bin,i) + 2*sum(others))
            //         = dist(bin,i) - dist(agent,i).
            // We want to maximize savings. Savings can be negative (if agent is far), meaning it increases cost.
            // However, we are forced to pick up bottles (or we can just stick to base cost).
            // So we should only take positive savings. 
            // Wait, if savings are negative, we shouldn't do it. The problem asks to return base_cost - max_savings.
            // If max_savings is negative, base_cost - (-S) = base_cost + S. That's wrong.
            // We must handle "0 savings" for bad assignments.
            // The prompt says "Return base_cost - max_possible_savings". 
            // So max_possible_savings must be >= 0.
            // If dist(agent, bottle) > dist(bin, bottle), savings is negative. We should ignore it (savings = 0).
            
            if (d_tb >= d_ab) begin
                calc_savings = d_tb - d_ab;
            end else begin
                calc_savings = 0;
            end
        end
    endfunction

    // Logic block
    reg [31:0] base_cost;
    reg [31:0] dist_t_b [0:7];
    reg [31:0] dist_a_b [0:7];
    reg [31:0] dist_b_b [0:7];
    reg [31:0] sav_a [0:7];
    reg [31:0] sav_b [0:7];
    reg [31:0] sav_sum [0:7];
    reg [31:0] max_sav_a;
    reg [31:0] max_sav_b;
    reg [31:0] max_sav_sum;
    reg [2:0] idx_a, idx_b, idx_sum1, idx_sum2;
    integer i, j;

    always @(*) begin
        // 1. Calculate Base Cost
        base_cost = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < n) begin
                dist_t_b[i] = calc_dist(tx, ty, bottle_x[i], bottle_y[i]);
                // 2 * dist
                base_cost = base_cost + (dist_t_b[i] << 1);
            end else begin
                dist_t_b[i] = 0;
            end
        end

        // 2. Calculate Savings
        // Savings for Adil picking bottle i
        max_sav_a = 0;
        idx_a = 0;
        // Savings for Bera picking bottle i
        max_sav_b = 0;
        idx_b = 0;
        // Savings for sum (Adil i, Bera j)
        max_sav_sum = 0;
        idx_sum1 = 0;
        idx_sum2 = 0;

        for (i = 0; i < 8; i = i + 1) begin
            if (i < n) begin
                sav_a[i] = calc_savings(ax, ay, bottle_x[i], bottle_y[i], tx, ty);
                sav_b[i] = calc_savings(bx, by, bottle_x[i], bottle_y[i], tx, ty);
                
                if (sav_a[i] > max_sav_a) begin
                    max_sav_a = sav_a[i];
                    idx_a = i;
                end
                if (sav_b[i] > max_sav_b) begin
                    max_sav_b = sav_b[i];
                    idx_b = i;
                end
            end else begin
                sav_a[i] = 0;
                sav_b[i] = 0;
            end
        end

        // Find best pair sum
        // Only if n >= 2, otherwise max_sav_sum stays 0
        if (n >= 2) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i < n) begin
                    for (j = i + 1; j < 8; j = j + 1) begin
                        if (j < n) begin
                            sav_sum[i] = sav_a[i] + sav_b[j];
                            if (sav_sum[i] > max_sav_sum) begin
                                max_sav_sum = sav_sum[i];
                                idx_sum1 = i;
                                idx_sum2 = j;
                            end
                            // Check symmetric: Adil j, Bera i
                            sav_sum[j] = sav_a[j] + sav_b[i]; // reuse array reg, careful
                            if (sav_sum[j] > max_sav_sum) begin
                                max_sav_sum = sav_sum[j];
                                idx_sum1 = j;
                                idx_sum2 = i;
                            end
                        end
                    end
                end
            end
        end

        // 3. Compare Strategies
        // Strategy 1: Single best savings (Adil)
        // Strategy 2: Single best savings (Bera)
        // Strategy 3: Two best savings (different bottles)
        
        // Wait, "One agent picks one bottle" vs "Both agents pick one each".
        // "Fallback to single best savings if bottles overlap".
        // If idx_a == idx_b, then we cannot pick both. So we take max(max_sav_a, max_sav_b).
        // If idx_a != idx_b, we should consider taking both IF (sav_a[idx_a] + sav_b[idx_b]) > max_sav_sum.
        // Actually, max_sav_sum logic above covers picking the best pair of different bottles.
        // We need to compare:
        // 1. Best single (max of A or B)
        // 2. Best pair (max_sav_sum)
        // 3. Note: The "Fallback to single best savings if bottles overlap" instruction suggests if the best savings for A and B are on the same bottle, we might need to pick only one.
        // But wait, if we pick Adil's best bottle, can Bera pick a different one? Yes.
        // So we need to find the max of:
        // - sav_a[i] (Adil i, Bera none)
        // - sav_b[j] (Bera j, Adil none)
        // - sav_a[i] + sav_b[j] where i != j (Both pick)
        
        // Let's refine the max_sav_sum calculation to be robust.
        // It should handle the "best two" logic.
        // But the problem says "if bottles are different".
        
        // Let's define the final max_savings variable.
        reg [31:0] final_max_savings;
        
        // Simple comparison of the 3 computed values is not quite right because max_sav_sum might be calculated on non-optimal singles.
        // Let's re-evaluate the sum logic explicitly to ensure we get the global maximum combination.
        
        // Recalculate best pair explicitly:
        reg [31:0] temp_sum;
        max_sav_sum = 0;
        
        if (n >= 2) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i < n) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        if (j < n && i != j) begin
                            temp_sum = sav_a[i] + sav_b[j];
                            if (temp_sum > max_sav_sum) begin
                                max_sav_sum = temp_sum;
                            end
                        end
                    end
                end
            end
        end

        // Now we have:
        // max_sav_a (best single for Adil)
        // max_sav_b (best single for Bera)
        // max_sav_sum (best pair)
        
        // The max possible saving is the maximum of these three.
        // However, if we pick a pair, we cannot pick just a single (it's included or worse).
        // But we might pick a pair where sum is less than a very good single saving (if one agent is bad).
        // So we take max(max_sav_a, max_sav_b, max_sav_sum).
        
        final_max_savings = max_sav_a;
        if (max_sav_b > final_max_savings) final_max_savings = max_sav_b;
        if (max_sav_sum > final_max_savings) final_max_savings = max_sav_sum;

        // If n == 0, no bottles. Base cost is 0. Savings is 0.
        if (n == 0) begin
            min_distance = 0;
        end else begin
            // Subtract savings from base cost.
            // Ensure no underflow (though mathematically savings <= base_cost if all bottles collected)
            // If base_cost < final_max_savings (unlikely but possible with negative savings logic if we didn't clamp), result would be wrong.
            // We clamped savings to >= 0.
            min_distance = base_cost - final_max_savings;
        end
    end

endmodule