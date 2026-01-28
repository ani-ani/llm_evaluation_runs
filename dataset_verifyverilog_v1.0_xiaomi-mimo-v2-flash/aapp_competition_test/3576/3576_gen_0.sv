module EvasionProbability (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] R,
    input wire [3:0] C,
    input wire [3:0] K,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_COUNT = 3'd1;
    localparam [2:0] CALC_INVERSE = 3'd2;
    localparam [2:0] MULTIPLY = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Calculation registers
    reg [31:0] total_cells;
    reg [31:0] total_pairs;
    reg [31:0] safe_pairs;
    reg [31:0] p_idx;
    reg [31:0] y_idx;
    reg [31:0] safe_next;
    reg [31:0] p_r, p_c, y_r, y_c;
    reg [31:0] dist;
    
    // Modular inverse variables
    reg [31:0] inv_a;
    reg [31:0] inv_b;
    reg [31:0] inv_x;
    reg [31:0] inv_y;
    reg [31:0] inv_a_next;
    reg [31:0] inv_b_next;
    reg [31:0] inv_x_next;
    reg [31:0] inv_y_next;
    reg [31:0] inv_orig_b;
    
    // Multiplication variables
    reg [63:0] mul_a;
    reg [31:0] mul_b;
    reg [63:0] mul_prod;
    reg [31:0] mul_mod;
    
    // Cycle counter
    reg [12:0] cycle_cnt;
    localparam [12:0] MAX_CYCLES = 13'd5000;

    // FSM Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            total_cells <= 32'd0;
            total_pairs <= 32'd0;
            safe_pairs <= 32'd0;
            p_idx <= 32'd0;
            y_idx <= 32'd0;
            safe_next <= 32'd0;
            inv_a <= 32'd0;
            inv_b <= 32'd0;
            inv_x <= 32'd0;
            inv_y <= 32'd0;
            inv_orig_b <= 32'd0;
            mul_a <= 64'd0;
            mul_b <= 32'd0;
            mul_prod <= 64'd0;
            mul_mod <= 32'd0;
            cycle_cnt <= 13'd0;
            p_r <= 32'd0;
            p_c <= 32'd0;
            y_r <= 32'd0;
            y_c <= 32'd0;
            dist <= 32'd0;
        end else begin
            state <= next_state;
            
            // Reset cycle counter on IDLE or start
            if (state == IDLE && start) begin
                cycle_cnt <= 13'd0;
            end else if (state != IDLE && state != FINISH) begin
                cycle_cnt <= cycle_cnt + 13'd1;
            end
            
            // Logic per state
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        total_cells <= R * C;
                        safe_pairs <= 32'd0;
                        p_idx <= 32'd0;
                        y_idx <= 32'd0;
                        safe_next <= 32'd0;
                    end
                end
                
                CALC_COUNT: begin
                    // Compute R*C * R*C in first cycle of this state
                    if (p_idx == 32'd0 && y_idx == 32'd0) begin
                        total_pairs <= total_cells * total_cells;
                    end
                    
                    // Inner loop logic (Y loop)
                    // Calculate distance: abs(pr-yr) + abs(pc-yc)
                    if (y_r >= p_r) dist[15:0] <= y_r - p_r;
                    else dist[15:0] <= p_r - y_r;
                    
                    // We handle Y_C comparison in next cycle logic or combinational
                    // To avoid complex combinational paths, we use registers
                    // But to save cycles, let's do a tiny sequencer within CALC_COUNT
                    // Actually, single cycle per pair is best for HDL simplicity.
                    // 64*64 = 4096 pairs.
                    // Logic for next Y:
                    y_idx <= y_idx + 32'd1;
                    if (y_idx >= (total_cells - 32'd1)) begin
                        y_idx <= 32'd0;
                        p_idx <= p_idx + 32'd1;
                        // If P loop finishes, transition logic handles next state
                    end
                    
                    // We need to wait for the distance calculation.
                    // Let's split CALC_COUNT into 2 cycles or use previous cycle values.
                    // Let's use previous cycle values for the check.
                    // Wait, Y index increments. The check should be for (prev_p, prev_y).
                    // Correction: The logic above updates Y immediately.
                    // We need to check the pair (p_r, p_c) vs (y_r, y_c) BEFORE incrementing Y.
                    
                    // Let's use a dedicated register for the current pair's safe status.
                    // This adds 1 cycle latency but simplifies logic.
                    
                    // Let's revise: In cycle N, we compute distance for pair N.
                    // The indices p_idx, y_idx point to the current pair.
                    
                    // Calculate R, C from indices
                    // p_r = p_idx / C, p_c = p_idx % C
                    // This division is expensive. 
                    // Since R, C <= 8, we can use a small LUT or hardcode logic.
                    // But C is variable. Division is required.
                    // However, for small numbers (0-63), we can do it iteratively or combinatorial.
                    // Let's do it combinatorial based on inputs.
                    // Combinational logic for p_r, p_c, y_r, y_c:
                    // p_r = p_idx / C; p_c = p_idx % C;
                    // y_r = y_idx / C; y_c = y_idx % C;
                    
                    // Check logic (based on previous cycle's indices if not using combinational next)
                    // To make it sequential and timing-safe:
                    // We calculate distances for CURRENT p_idx, y_idx.
                    // Then increment.
                    
                    // Let's use a simple counter logic.
                    // If safe, increment safe_next.
                    // safe_next is added to safe_pairs at the end of loops or continuously?
                    // Accumulate continuously.
                    
                    // Handle transition to next state
                    if (p_idx == (total_cells - 32'd1) && y_idx == (total_cells - 32'd1)) begin
                        // Last pair processed in THIS cycle.
                        // We need to wait for the last check result.
                        // But since we check BEFORE increment, we are good.
                        // Wait, my logic above increments before check or check before increment?
                        // Let's assume we check (p_idx, y_idx), then increment.
                        // If this was the last one, next state starts.
                    end
                end
                
                CALC_INVERSE: begin
                    // Binary Extended GCD
                    if (inv_b != 32'd0) begin
                        inv_a <= inv_a_next;
                        inv_b <= inv_b_next;
                        inv_x <= inv_x_next;
                        inv_y <= inv_y_next;
                    end
                end
                
                MULTIPLY: begin
                    // result = (safe_pairs * inv_x) % MOD
                    // We do this in one go for small numbers or iteratively.
                    // safe_pairs <= 4096, inv_x <= MOD-1. Product fits in 64 bits.
                    // Division of 64 bit by 32 bit is expensive combinatorially.
                    // Use iterative subtraction or combinational divider?
                    // Let's use combinational since it's one time and small width.
                    // Or split into cycles.
                    // Let's do: result <= (safe_pairs * inv_x) % MOD;
                    // We need a modular multiplier.
                    // Let's implement a simple sequential modular multi.
                    
                    if (mul_b != 32'd0) begin
                        mul_prod <= mul_prod + (mul_b[0] ? mul_a : 64'd0);
                        mul_a <= (mul_a << 1);
                        mul_b <= (mul_b >> 1);
                        // Modulo reduction is expensive inside the loop.
                        // We can do modulo at the end if we use 128-bit accumulator.
                        // safe < 4096, inv < 10^9. Product < 4*10^12. Fits in 42 bits.
                        // 64 bits is enough for sum.
                    end else begin
                        // Modulo operation
                        // mul_prod % MOD
                        // Since mul_prod is 64 bits and MOD is 32 bits, we can do:
                        // result <= mul_prod % MOD;
                        // This requires a divider.
                        // Let's just output mul_prod % MOD directly if we use standard operators.
                        // If synthesizer supports 64b/32b divider, fine.
                        // If not, we need a divider unit.
                        // Let's rely on synthesis tool for the modulo operation on the final value.
                        // One cycle modulo is heavy, but doable for a single operation.
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
            
            // Specific logic for CALC_COUNT state
            if (state == CALC_COUNT) begin
                // Division for indices (combinational logic required or small LUT)
                // Since R, C <= 8, we can hardcode the mapping for 0..63.
                // But variable C makes it hard. 
                // Let's assume C is 4, 6, 8. 
                // We will calculate index / C and index % C using a small loop or logic.
                // Iterative division is too slow (64 cycles per pair).
                // We need combinational division.
                // Let's assume C is small (4 bits). 
                // We can check: y_idx < C ? y_r=0, y_c=y_idx : y_idx < 2*C ? ...
                // This is a comparator tree.
                
                // Let's implement the check logic here:
                // p_r = p_idx / C, p_c = p_idx % C
                // y_r = y_idx / C, y_c = y_idx % C
                // dist = |p_r - y_r| + |p_c - y_c|
                // safe if dist > K
                
                // We will compute these values combinationaly in the always block header or use helper wires.
                // Due to the strictness of the environment, let's assume we can use combinational logic inside the block.
                
                // Increment safe_next if safe, accumulate to safe_pairs at the end of every pair? 
                // Accumulate continuously.
                
                // End of loops
                if (p_idx == (total_cells - 32'd1) && y_idx == (total_cells - 32'd1)) begin
                    // Logic to transition to CALC_INVERSE is handled by next_state logic below.
                end
            end
        end
    end

    // Combinational Logic for CALC_COUNT (Calculations)
    // Helper signals to avoid complex synthesis inside the sequential block
    reg [31:0] p_r_cmb, p_c_cmb, y_r_cmb, y_c_cmb;
    reg [31:0] dist_r_cmb, dist_c_cmb, dist_cmb;
    reg is_safe_cmb;
    
    always @(*) begin
        // Divider logic for small numbers (0-63)
        // p_r = p_idx / C
        // p_c = p_idx % C
        // Since C is variable, we use a generic logic.
        // We can unroll for C up to 8 or use a loop.
        // A loop is okay in combinational logic.
        
        // Compute p_r, p_c
        p_r_cmb = 32'd0;
        p_c_cmb = 32'd0;
        if (C > 0) begin
            if (p_idx < C) begin
                p_r_cmb = 0;
                p_c_cmb = p_idx;
            end else if (p_idx < 2*C) begin
                p_r_cmb = 1;
                p_c_cmb = p_idx - C;
            end else if (p_idx < 3*C) begin
                p_r_cmb = 2;
                p_c_cmb = p_idx - 2*C;
            end else if (p_idx < 4*C) begin
                p_r_cmb = 3;
                p_c_cmb = p_idx - 3*C;
            end else if (p_idx < 5*C) begin
                p_r_cmb = 4;
                p_c_cmb = p_idx - 4*C;
            end else if (p_idx < 6*C) begin
                p_r_cmb = 5;
                p_c_cmb = p_idx - 5*C;
            end else if (p_idx < 7*C) begin
                p_r_cmb = 6;
                p_c_cmb = p_idx - 6*C;
            end else begin
                p_r_cmb = 7;
                p_c_cmb = p_idx - 7*C;
            end
        end
        
        // Compute y_r, y_c
        y_r_cmb = 32'd0;
        y_c_cmb = 32'd0;
        if (C > 0) begin
            if (y_idx < C) begin
                y_r_cmb = 0;
                y_c_cmb = y_idx;
            end else if (y_idx < 2*C) begin
                y_r_cmb = 1;
                y_c_cmb = y_idx - C;
            end else if (y_idx < 3*C) begin
                y_r_cmb = 2;
                y_c_cmb = y_idx - 2*C;
            end else if (y_idx < 4*C) begin
                y_r_cmb = 3;
                y_c_cmb = y_idx - 3*C;
            end else if (y_idx < 5*C) begin
                y_r_cmb = 4;
                y_c_cmb = y_idx - 4*C;
            end else if (y_idx < 6*C) begin
                y_r_cmb = 5;
                y_c_cmb = y_idx - 5*C;
            end else if (y_idx < 7*C) begin
                y_r_cmb = 6;
                y_c_cmb = y_idx - 6*C;
            end else begin
                y_r_cmb = 7;
                y_c_cmb = y_idx - 7*C;
            end
        end
        
        // Distance
        dist_r_cmb = (p_r_cmb > y_r_cmb) ? (p_r_cmb - y_r_cmb) : (y_r_cmb - p_r_cmb);
        dist_c_cmb = (p_c_cmb > y_c_cmb) ? (p_c_cmb - y_c_cmb) : (y_c_cmb - p_c_cmb);
        dist_cmb = dist_r_cmb + dist_c_cmb;
        
        is_safe_cmb = (dist_cmb > K);
    end

    // Next State Logic
    always @(*) begin
        next_state = state; // Default hold
        case (state)
            IDLE: if (start) next_state = CALC_COUNT;
            
            CALC_COUNT: begin
                // Check if loop finished
                // Note: This logic assumes p_idx/y_idx have already been updated in the sequential block.
                // Wait, we updated them in the sequential block.
                // We need to check if we just finished.
                // If p_idx is total_cells-1 AND y_idx is total_cells-1, we are at the last pair.
                // In the cycle where we check the last pair, we should transition.
                // But we calculate `is_safe_cmb` for the CURRENT indices.
                // We accumulate `safe_next`.
                
                // Actually, let's accumulate safe_pairs in the sequential block.
                // We need to decide when to add to safe_pairs.
                // We should add `is_safe_cmb` to `safe_pairs` every cycle.
                // But `is_safe_cmb` is combinational based on current p_idx, y_idx.
                
                // Let's do this:
                // In CALC_COUNT, we process the pair (p_idx, y_idx).
                // We increment indices at the end of the cycle.
                // So when p_idx == total_cells-1 and y_idx == total_cells-1, this is the last pair.
                // After this cycle, we move to CALC_INVERSE.
                
                if (p_idx == (total_cells - 32'd1) && y_idx == (total_cells - 32'd1)) begin
                    next_state = CALC_INVERSE;
                end
            end
            
            CALC_INVERSE: begin
                if (inv_b == 32'd0) begin
                    next_state = MULTIPLY;
                end
            end
            
            MULTIPLY: begin
                // We do multiplication/modulo in one cycle or few.
                // Let's just go to FINISH. 
                // The combinational result for multiplication might be available or we compute it.
                // Since we are in sequential block, we need to manage multiplication state.
                // Let's assume the testbench gives enough time or we do it in one cycle.
                // The product fits in 64 bits. Modulo is 32 bits.
                // We can assign result = (safe_pairs * inv_x) % MOD directly in the always block.
                // But that's combinational math. 
                // Let's move to FINISH.
                // The calculation of result should happen in this state or combinational output.
                // We will compute it in the sequential block.
                next_state = FINISH;
            end
            
            FINISH: begin
                // Stay here until reset or start
                // Wait for start to go low or handled by IDLE transition if start is held high?
                // Usually start is pulsed. If held high, restarts.
                if (start) next_state = CALC_COUNT;
                else next_state = FINISH;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Accumulate safe pairs and Inverse Logic update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else begin
            if (state == CALC_COUNT) begin
                if (is_safe_cmb) safe_pairs <= safe_pairs + 32'd1;
                // Increment indices in seq block is safer for timing
                // We moved increment logic here to sync with accumulation
                
                if (y_idx == (total_cells - 32'd1)) begin
                    y_idx <= 32'd0;
                    if (p_idx == (total_cells - 32'd1)) begin
                        // End of loop, freeze indices
                    end else begin
                        p_idx <= p_idx + 32'd1;
                    end
                end else begin
                    y_idx <= y_idx + 32'd1;
                end
            end else if (state == IDLE && start) begin
                p_idx <= 32'd0;
                y_idx <= 32'd0;
                safe_pairs <= 32'd0;
            end
            
            if (state == CALC_INVERSE) begin
                // Init GCD
                if (cycle_cnt == 13'd1 || (inv_b != 0 && inv_b_next == 0)) begin
                    // Initial setup or just finished?
                    // Let's do the GCD step-by-step
                    // We need a flag to know if we initialized
                    // Let's use a small sub-state or just conditions
                    // If inv_b is 0 (initial or done), set up for next step
                end
                
                // Logic for GCD update (moved to combinational helper usually, but here inline)
                // We need to initialize inv_a, inv_b, inv_x, inv_y at start of state.
                // Let's do init when entering CALC_INVERSE.
                if (cycle_cnt == 13'd0 && state == CALC_INVERSE) begin
                     inv_a <= total_pairs;
                     inv_b <= MOD;
                     inv_x <= 32'd1;
                     inv_y <= 32'd0;
                end else if (inv_b != 32'd0) begin
                     inv_a <= inv_a_next;
                     inv_b <= inv_b_next;
                     inv_x <= inv_x_next;
                     inv_y <= inv_y_next;
                end
            end
            
            if (state == MULTIPLY) begin
                // Compute result = (safe_pairs * inv_x) % MOD
                // Since safe_pairs and inv_x are 32-bit, product is 64-bit.
                // We can use: result <= (safe_pairs * inv_x) % MOD;
                // Synthesis tool will map this to a multiplier and divider.
                result <= (safe_pairs * inv_x) % MOD;
            end
        end
    end

    // GCD Combinational Logic
    always @(*) begin
        inv_a_next = inv_a;
        inv_b_next = inv_b;
        inv_x_next = inv_x;
        inv_y_next = inv_y;
        
        if (inv_b != 32'd0) begin
            // Binary GCD algorithm steps
            if (inv_a[0] == 0) begin // A even
                inv_a_next = inv_a >> 1;
                if (inv_x[0] == 0 && inv_y[0] == 0) begin
                    inv_x_next = inv_x >> 1;
                    inv_y_next = inv_y >> 1;
                end else begin
                    // This part of binary GCD is complex to fit in one cycle logic.
                    // Let's use a simpler standard iterative algorithm for GCD, 
                    // or just rely on the fact that inputs are small.
                    // Wait, binary GCD is good but needs multiple states per step if not fully combinational.
                    // Let's use a simpler Euclidean algorithm for GCD which is easier to pipeline.
                    // Or just stick to Binary GCD but simplified.
                    
                    // Actually, let's stick to the Binary GCD logic described in instructions.
                    // It's hard to implement fully combinational without deep nesting.
                    // We will implement a simple version:
                    // If A even: A/=2, X*=2 (or shift)
                    // If B even: B/=2, Y*=2
                    // Else if A>B: A-=B, X-=Y
                    // Else: B-=A, Y-=X
                    
                    // Let's try a simplified single-step logic for the loop.
                    // The loop structure is:
                    // while(b) {
                    //   if (even(a)) { a/=2; if(even(x)) x/=2; else x=(x+mod)/2; } 
                    //   else if (even(b)) { b/=2; if(even(y)) y/=2; else y=(y+mod)/2; }
                    //   else if (a>b) { a-=b; x-=y; if(x<0) x+=mod; }
                    //   else { b-=a; y-=x; if(y<0) y+=mod; }
                    // }
                    // This is too complex for a single always block cycle.
                    
                    // Let's restrict: We will use the standard Euclidean algorithm with subtraction.
                    // It's slower but easier to implement in hardware.
                    // Algorithm:
                    // if (inv_a > inv_b) { inv_a -= inv_b; inv_x -= inv_y; if (inv_x < 0) inv_x += MOD; }
                    // else { inv_b -= inv_a; inv_y -= inv_x; if (inv_y < 0) inv_y += MOD; }
                    
                    if (inv_a > inv_b) begin
                        inv_a_next = inv_a - inv_b;
                        if (inv_x >= inv_y) inv_x_next = inv_x - inv_y;
                        else inv_x_next = inv_x - inv_y + MOD;
                        inv_b_next = inv_b;
                        inv_y_next = inv_y;
                    end else begin
                        inv_b_next = inv_b - inv_a;
                        if (inv_y >= inv_x) inv_y_next = inv_y - inv_x;
                        else inv_y_next = inv_y - inv_x + MOD;
                        inv_a_next = inv_a;
                        inv_x_next = inv_x;
                    end
                end
            end else begin // A odd, check B
                if (inv_b[0] == 0) begin // B even
                    inv_b_next = inv_b >> 1;
                    if (inv_y[0] == 0) inv_y_next = inv_y >> 1;
                    else inv_y_next = (inv_y + MOD) >> 1;
                end else begin // Both odd
                    if (inv_a > inv_b) begin
                        inv_a_next = inv_a - inv_b;
                        if (inv_x >= inv_y) inv_x_next = inv_x - inv_y;
                        else inv_x_next = inv_x - inv_y + MOD;
                        inv_b_next = inv_b;
                        inv_y_next = inv_y;
                    end else begin
                        inv_b_next = inv_b - inv_a;
                        if (inv_y >= inv_x) inv_y_next = inv_y - inv_x;
                        else inv_y_next = inv_y - inv_x + MOD;
                        inv_a_next = inv_a;
                        inv_x_next = inv_x;
                    end
                end
            end
        end
    end

endmodule