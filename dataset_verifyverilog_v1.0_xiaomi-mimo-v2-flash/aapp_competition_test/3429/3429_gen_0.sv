module ComputeMinDamage (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [47:0] xs,        // Q32.16, scaled by 2^10
    input wire signed [47:0] ys,        // Q32.16, scaled by 2^10
    input wire signed [47:0] ss,        // Q32.16, scaled by 2^16
    input wire signed [47:0] ri,        // Q32.16, scaled by 2^10
    input wire signed [47:0] rf,        // Q32.16, scaled by 2^10
    input wire signed [47:0] xa,        // Q32.16, scaled by 2^10
    input wire signed [47:0] ya,        // Q32.16, scaled by 2^10
    input wire signed [47:0] sa,        // Q32.16, scaled by 2^16
    output reg signed [47:0] result,    // Q32.16 damage
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_DIST  = 3'd1;
    localparam [2:0] INIT_SEARCH= 3'd2;
    localparam [2:0] ITERATE    = 3'd3;
    localparam [2:0] UPDATE_BEST= 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Fixed parameters (Q32.16 format)
    localparam signed [47:0] ONE  = 48'h00010000;  // 1.0 in Q32.16
    localparam signed [47:0] ZERO = 48'd0;
    localparam signed [47:0] TWO  = 48'h00020000;  // 2.0 in Q32.16
    
    // Search parameters
    localparam [7:0] MAX_ITER = 8'd64;
    localparam [7:0] CYCLE_LIMIT = 8'd100;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] iter_count;
    reg [7:0] cycle_count;
    
    // Intermediate calculations (Q32.16, scaled appropriately)
    reg signed [47:0] D_squared;      // Squared distance (scaled by 2^20)
    reg signed [47:0] D;              // Actual distance (scaled by 2^10)
    reg signed [47:0] t_low, t_high;  // Search bounds (scaled by 2^16)
    reg signed [47:0] t_mid;
    reg signed [47:0] r_t;
    reg signed [47:0] move_dist;
    reg signed [47:0] reach_time;
    reg signed [47:0] damage_candidate;
    reg signed [47:0] min_damage;
    reg signed [47:0] best_t;
    reg signed [47:0] temp_val;
    reg signed [47:0] temp_val2;
    reg signed [47:0] temp_val3;
    reg signed [95:0] long_temp;      // 64-bit intermediate for multiplication
    reg [1:0] calc_step;              // Sub-step for multi-cycle calculations
    
    // Square root intermediate
    reg signed [47:0] sqrt_val;
    reg signed [47:0] sqrt_next;
    reg [7:0] sqrt_bit;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 48'd0;
            done <= 1'b0;
            iter_count <= 8'd0;
            cycle_count <= 8'd0;
            D_squared <= 48'd0;
            D <= 48'd0;
            t_low <= 48'd0;
            t_high <= 48'd0;
            t_mid <= 48'd0;
            r_t <= 48'd0;
            move_dist <= 48'd0;
            reach_time <= 48'd0;
            damage_candidate <= 48'd0;
            min_damage <= 48'h7FFFFFFF;  // Initialize to large value
            best_t <= 48'd0;
            temp_val <= 48'd0;
            temp_val2 <= 48'd0;
            temp_val3 <= 48'd0;
            long_temp <= 96'd0;
            calc_step <= 2'd0;
            sqrt_val <= 48'd0;
            sqrt_next <= 48'd0;
            sqrt_bit <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    min_damage <= 48'h7FFFFFFF;
                    best_t <= 48'd0;
                    calc_step <= 2'd0;
                    if (start) begin
                        state <= CALC_DIST;
                        // Initialize bounds for binary search
                        // t_low = 0, t_high = 1000.0 (scaled by 2^16)
                        t_low <= 48'd0;
                        t_high <= 48'd65536000;  // 1000.0 * 65536
                    end else begin
                        state <= IDLE;
                    end
                end

                CALC_DIST: begin
                    // Compute D^2 = (xs-xa)^2 + (ys-ya)^2
                    // Each diff is scaled by 2^10, so D^2 scaled by 2^20
                    // To fit Q32.16, we'll compute D directly with sqrt
                    case (calc_step)
                        2'd0: begin
                            // Compute delta_x
                            long_temp <= (xs - xa);
                            calc_step <= 2'd1;
                        end
                        2'd1: begin
                            // Square delta_x (multiply by itself)
                            temp_val <= long_temp[47:0];  // delta_x
                            long_temp <= long_temp[47:0] * long_temp[47:0];
                            calc_step <= 2'd2;
                        end
                        2'd2: begin
                            // Store x^2 (scaled by 2^20)
                            D_squared <= long_temp[63:16];  // Convert to Q32.16
                            // Compute delta_y
                            long_temp <= (ys - ya);
                            calc_step <= 2'd3;
                        end
                        2'd3: begin
                            // Square delta_y and add to D_squared
                            temp_val2 <= long_temp[47:0];  // delta_y
                            long_temp <= long_temp[47:0] * long_temp[47:0];
                            calc_step <= 2'd0;  // Reset for next
                            state <= INIT_SEARCH;
                        end
                    endcase
                end

                INIT_SEARCH: begin
                    // Add y^2 to D_squared
                    D_squared <= D_squared + long_temp[63:16];
                    // Compute D = sqrt(D_squared) / 2^10 (to scale back to Q32.16)
                    // Start sqrt calculation
                    sqrt_val <= 48'd0;
                    sqrt_next <= 48'd0;
                    temp_val3 <= D_squared;  // Store original
                    sqrt_bit <= 8'd32;  // 16 bits of integer part (scaled by 2^10)
                    state <= ITERATE;
                    calc_step <= 2'd0;
                end

                ITERATE: begin
                    // Binary search loop (64 iterations)
                    if (iter_count < MAX_ITER && cycle_count < CYCLE_LIMIT) begin
                        case (calc_step)
                            2'd0: begin
                                // 1. Compute t_mid = (t_low + t_high) / 2
                                long_temp <= t_low + t_high;
                                calc_step <= 2'd1;
                            end
                            2'd1: begin
                                // Divide by 2 (right shift by 16, then divide, then shift back)
                                // Actually, t is already scaled by 2^16, so (low+high)/2 is:
                                // (low+high) / 2, where division is arithmetic
                                // Since all values are in Q32.16 format, we can shift right 1
                                t_mid <= long_temp[47:1];  // Divide by 2
                                calc_step <= 2'd2;
                            end
                            2'd2: begin
                                // 2. Compute r_t = ri - ss * t_mid
                                // ss is Q32.16 scaled by 2^16, t_mid is Q32.16 scaled by 2^16
                                // product is scaled by 2^32, need to adjust
                                long_temp <= ss * t_mid;
                                calc_step <= 2'd3;
                            end
                            2'd3: begin
                                // r_t = ri - (product >> 16)
                                temp_val <= long_temp[63:16];  // ss*t scaled to Q32.16
                                // Clamp r_t to rf
                                temp_val2 <= ri - temp_val;
                                if ((ri - temp_val) < rf) begin
                                    r_t <= rf;
                                end else begin
                                    r_t <= temp_val2;
                                end
                                calc_step <= 2'd0;  // Reset for next calculation
                                state <= UPDATE_BEST;
                            end
                        endcase
                        iter_count <= iter_count + 8'd1;
                        cycle_count <= cycle_count + 8'd1;
                    end else begin
                        // Finished iterations or cycle limit
                        state <= FINISH;
                        iter_count <= 8'd0;
                    end
                end

                UPDATE_BEST: begin
                    // 3. Compute move_dist = max(0, D - r_t)
                    // D and r_t are both scaled by 2^10 (distance units)
                    if (D > r_t) begin
                        move_dist <= D - r_t;
                    end else begin
                        move_dist <= 48'd0;
                    end
                    
                    // 4. Check if player can reach: move_dist <= sa * t_mid
                    // sa is Q32.16 scaled by 2^16, t_mid is Q32.16 scaled by 2^16
                    // move_dist is Q32.16 scaled by 2^10
                    // Convert move_dist to Q32.16 scaled by 2^16 (multiply by 2^6 = 64)
                    temp_val3 <= move_dist << 6;  // Scale to match sa*t
                    long_temp <= sa * t_mid;
                    
                    if (temp_val3 <= long_temp[63:16]) begin
                        // Player can reach: damage = max(0, t - D/sa)
                        // t is scaled by 2^16, D/sa needs computation
                        // D/sa = D / sa, where D is Q32.16 scaled by 2^10, sa is Q32.16 scaled by 2^16
                        // Result is dimensionless, need to convert to time scaled by 2^16
                        // D / sa = D_scaled * 2^6 / sa
                        long_temp <= (D << 6) * ONE;  // D * 2^6
                        // Need division: D_scaled / sa
                        // This is complex, approximate: if sa > 0
                        if (sa > 48'd0) begin
                            // D_scaled << 6 gives us the right scale
                            // Division: (D_scaled << 6) / sa
                            // Use approximate: D / sa ≈ (D << 16) / (sa << 10) for Q32.16
                            // Actually simpler: D is distance, sa is speed (m/s) in Q32.16*2^16
                            // D in meters, sa in m/s, time in seconds
                            // D (scaled 2^10) / sa (scaled 2^16) = (D * 2^10) / (sa * 2^16)
                            // = (D / sa) * 2^-6
                            // To get time in Q32.16 scaled by 2^16: result = (D << 16) / (sa * 2^10)
                            long_temp <= D * ONE;  // D * 2^16
                            long_temp <= long_temp / (sa >> 10);  // Divide by sa/2^10
                            // This is still problematic, let's use the condition check directly
                            // If reachable, damage = 0
                            damage_candidate <= 48'd0;
                        end else begin
                            damage_candidate <= 48'd0;
                        end
                    end else begin
                        // Cannot reach: damage = t - D/sa
                        // Approximate: damage = t - (D << 6) / sa
                        // Use simpler: damage = t - (D * 2^6) / sa
                        // Let's use: damage = t - (D / sa) * 2^6 (scaled to match t)
                        // For now, use approximation: damage = t * (move_dist / (sa*t_mid))
                        // Or simply: damage = t_mid - 48'd0 (placeholder)
                        // Better: damage = t_mid - (D / sa) * 2^6
                        // Compute D / sa
                        if (sa > 48'd0) begin
                            // D is scaled 2^10, sa is scaled 2^16
                            // D/sa has scale 2^-6 relative to Q32.16
                            // We need it scaled 2^16 for subtraction with t_mid
                            // So multiply by 2^22: D << 22 / sa
                            long_temp <= D * 48'h00400000;  // D * 2^22
                            temp_val <= long_temp[95:16] / sa;  // Division
                            // Subtract from t_mid
                            if (t_mid > temp_val) begin
                                damage_candidate <= t_mid - temp_val;
                            end else begin
                                damage_candidate <= 48'd0;
                            end
                        end else begin
                            damage_candidate <= 48'd0;
                        end
                    end
                    
                    // Update min_damage
                    if (damage_candidate < min_damage) begin
                        min_damage <= damage_candidate;
                        best_t <= t_mid;
                    end
                    
                    // Update binary search bounds
                    // Check if reachable: move_dist <= sa * t_mid
                    // We already computed this condition in temp_val3 vs long_temp[63:16]
                    // But need to re-evaluate or store the result
                    // For simplicity, re-check:
                    if (temp_val3 <= long_temp[63:16]) begin
                        // Reachable: search lower half (we can possibly reach earlier)
                        t_high <= t_mid;
                    end else begin
                        // Not reachable: must increase time, search upper half
                        t_low <= t_mid;
                    end
                    
                    state <= ITERATE;
                    calc_step <= 2'd0;
                end

                FINISH: begin
                    // Finalize D computation (it was being calculated in INIT_SEARCH)
                    // Need to complete sqrt calculation
                    if (sqrt_bit > 0) begin
                        // Iterative sqrt: next = val - (curr*curr) / (2*curr)
                        // Or simpler bit-by-bit: if (val >= (curr | 1<<bit)^2) curr |= 1<<bit
                        // Let's use a simpler approach: sqrt using shift-add
                        // For Q32.16 scaled by 2^10 input, we want output scaled 2^10
                        if (sqrt_bit <= 8'd32) begin
                            sqrt_next <= sqrt_val + (1 << (sqrt_bit - 1));
                            if (((sqrt_val + (1 << (sqrt_bit - 1))) * (sqrt_val + (1 << (sqrt_bit - 1)))) <= temp_val3) begin
                                sqrt_val <= sqrt_val + (1 << (sqrt_bit - 1));
                            end
                            sqrt_bit <= sqrt_bit - 8'd1;
                            state <= FINISH;
                        end else begin
                            // Done sqrt
                            D <= sqrt_val;  // D is now computed
                            result <= min_damage;
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end else begin
                        // D was already computed or use precomputed
                        result <= min_damage;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule