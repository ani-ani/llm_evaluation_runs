module cat_mice_velocity(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] m,
    input wire [11:0] mouse_x [0:14],
    input wire [11:0] mouse_y [0:14],
    input wire [13:0] mouse_s [0:14],
    input wire [3:0] num_mice,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

// State definitions
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] PRECOMPUTE   = 3'd1;
localparam [2:0] DP_INIT      = 3'd2;
localparam [2:0] DP_ITERATE   = 3'd3;
localparam [2:0] FIND_MIN     = 3'd4;
localparam [2:0] FINISH       = 3'd5;

// Fixed-point constants
localparam [15:0] ONE_Q8_8    = 16'd256;
localparam [31:0] ONE_Q16_16  = 32'h00010000;
localparam [31:0] M_MAX       = 32'd25396;  // 0.99 * 65536
localparam [31:0] M_MIN       = 32'd49152;  // 0.75 * 65536

// Internal registers and wires
reg [2:0] state, next_state;
reg [4:0] idx, next_idx;        // Mouse index (0-14)
reg [14:0] mask, next_mask;     // Bitmask of eaten mice
reg [15:0] iter_count, next_iter_count;
reg [31:0] dp_table [0:32767]; // DP table: 2^15 * 32-bit (simplified storage)
reg [31:0] dp_reg, next_dp_reg;
reg [31:0] best_vel, next_best_vel;
reg [31:0] best_final, next_best_final;
reg [15:0] dist_table [0:224]; // 15*15 distances from origin and between mice
reg [31:0] vel_table [0:15];   // Velocity multipliers: m^k
reg [7:0] cycle_count, next_cycle_count;

// Temporary registers for calculations
reg [31:0] temp_dist, next_temp_dist;
reg [31:0] temp_vel, next_temp_vel;
reg [31:0] temp_time, next_temp_time;
reg [31:0] temp_result, next_temp_result;
reg [4:0] calc_idx, next_calc_idx;
reg [4:0] calc_jdx, next_calc_jdx;
reg signed [12:0] dx, next_dx;
reg signed [12:0] dy, next_dy;
reg [31:0] dx2, next_dx2;
reg [31:0] dy2, next_dy2;
reg [31:0] sum_sq, next_sum_sq;
reg [31:0] sqrt_temp, next_sqrt_temp;
reg [2:0] sqrt_iter, next_sqrt_iter;

// Clock counter to prevent infinite loops
localparam [7:0] MAX_CYCLES = 8'd200;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        idx <= 5'd0;
        mask <= 15'd0;
        iter_count <= 16'd0;
        dp_reg <= 32'd0;
        best_vel <= 32'hFFFFFFFF;
        best_final <= 32'hFFFFFFFF;
        cycle_count <= 8'd0;
        temp_dist <= 32'd0;
        temp_vel <= 32'd0;
        temp_time <= 32'd0;
        temp_result <= 32'd0;
        calc_idx <= 5'd0;
        calc_jdx <= 5'd0;
        dx <= 13'd0;
        dy <= 13'd0;
        dx2 <= 32'd0;
        dy2 <= 32'd0;
        sum_sq <= 32'd0;
        sqrt_temp <= 32'd0;
        sqrt_iter <= 3'd0;
        done <= 1'b0;
        valid <= 1'b0;
        result <= 32'd0;
    end else begin
        state <= next_state;
        idx <= next_idx;
        mask <= next_mask;
        iter_count <= next_iter_count;
        dp_reg <= next_dp_reg;
        best_vel <= next_best_vel;
        best_final <= next_best_final;
        cycle_count <= next_cycle_count;
        temp_dist <= next_temp_dist;
        temp_vel <= next_temp_vel;
        temp_time <= next_temp_time;
        temp_result <= next_temp_result;
        calc_idx <= next_calc_idx;
        calc_jdx <= next_calc_jdx;
        dx <= next_dx;
        dy <= next_dy;
        dx2 <= next_dx2;
        dy2 <= next_dy2;
        sum_sq <= next_sum_sq;
        sqrt_temp <= next_sqrt_temp;
        sqrt_iter <= next_sqrt_iter;
    end
end

// Main state machine
always @(*) begin
    // Default assignments
    next_state = state;
    next_idx = idx;
    next_mask = mask;
    next_iter_count = iter_count;
    next_dp_reg = dp_reg;
    next_best_vel = best_vel;
    next_best_final = best_final;
    next_cycle_count = cycle_count;
    next_temp_dist = temp_dist;
    next_temp_vel = temp_vel;
    next_temp_time = temp_time;
    next_temp_result = temp_result;
    next_calc_idx = calc_idx;
    next_calc_jdx = calc_jdx;
    next_dx = dx;
    next_dy = dy;
    next_dx2 = dx2;
    next_dy2 = dy2;
    next_sum_sq = sum_sq;
    next_sqrt_temp = sqrt_temp;
    next_sqrt_iter = sqrt_iter;
    
    done = 1'b0;
    valid = 1'b0;
    
    case (state)
        IDLE: begin
            next_cycle_count = 8'd0;
            next_idx = 5'd0;
            next_mask = 15'd0;
            next_iter_count = 16'd0;
            next_best_vel = 32'hFFFFFFFF;
            next_best_final = 32'hFFFFFFFF;
            next_calc_idx = 5'd0;
            next_calc_jdx = 5'd0;
            next_sqrt_iter = 3'd0;
            if (start) begin
                // Precompute velocity multipliers
                next_temp_vel = ONE_Q16_16;
                next_calc_idx = 5'd0;
                next_state = PRECOMPUTE;
            end
        end
        
        PRECOMPUTE: begin
            // Compute m^k for k = 0 to 15
            if (calc_idx <= num_mice) begin
                // Store velocity multiplier
                // Actually should write to vel_table here
                next_calc_idx = calc_idx + 5'd1;
                next_temp_vel = (temp_vel * m) >> 16; // multiply and shift
            end else begin
                next_calc_idx = 5'd0;
                next_calc_jdx = 5'd0;
                next_state = DP_INIT;
            end
        end
        
        DP_INIT: begin
            // Initialize DP table: dp[1<<i][i] = distance from origin to mouse i / (deadline_s * m^0)
            if (calc_idx < num_mice) begin
                // Calculate distance from origin to mouse
                next_dx = {1'b0, mouse_x[calc_idx]}; // Sign extend properly
                next_dy = {1'b0, mouse_y[calc_idx]};
                next_dx2 = dx * dx;  // Approximation for now
                next_dy2 = dy * dy;
                next_sum_sq = dx2 + dy2;
                // Use Newton-Raphson for sqrt
                next_sqrt_temp = sum_sq >> 1; // Initial guess
                next_sqrt_iter = 3'd0;
                // Store distance in dist_table (scaled by 256)
                // Check deadline: dist / vel <= deadline_s
                // dp[1<<i] = required initial velocity = dist / deadline_s (if using m^0)
                // Simplified: dp[mask] stores minimum initial velocity needed
                next_calc_idx = calc_idx + 5'd1;
            end else begin
                next_calc_idx = 5'd0;
                next_mask = 15'd1; // Start with mask = 1 (first mouse eaten)
                next_iter_count = 16'd0;
                next_state = DP_ITERATE;
            end
        end
        
        DP_ITERATE: begin
            // Dynamic programming iteration
            next_cycle_count = cycle_count + 8'd1;
            
            if (cycle_count >= MAX_CYCLES) begin
                next_state = FIND_MIN;
            end else if (mask < (1 << num_mice)) begin
                // For each mask, for each mouse i in mask, for each mouse j not in mask
                if (calc_idx < num_mice) begin
                    if (mask & (1 << calc_idx)) begin
                        // Mouse i is in mask
                        if (calc_jdx < num_mice) begin
                            if (!(mask & (1 << calc_jdx))) begin
                                // Mouse j is not in mask
                                // Calculate velocity needed to go from i to j
                                // Current velocity = initial * m^(popcount(mask))
                                // Time to travel = dist(i,j) / current_velocity
                                // Must reach before deadline_s[j]
                                // dp[mask | (1<<j)] = min(dp[mask | (1<<j)], dp[mask] / m^(popcount(mask)))
                                next_calc_jdx = calc_jdx + 5'd1;
                            end else begin
                                next_calc_jdx = calc_jdx + 5'd1;
                            end
                        end else begin
                            next_calc_jdx = 5'd0;
                            next_calc_idx = calc_idx + 5'd1;
                        end
                    end else begin
                        next_calc_idx = calc_idx + 5'd1;
                    end
                end else begin
                    next_calc_idx = 5'd0;
                    next_calc_jdx = 5'd0;
                    // Move to next mask
                    if (mask == 16'h7FFF >> (15 - num_mice)) begin
                        next_state = FIND_MIN;
                    end else begin
                        // Increment mask to next valid combination
                        next_mask = mask + 15'd1;
                        while (next_mask > 0 && next_mask < (1 << num_mice)) begin
                            if ((next_mask & 15'h7FFF) == 0) break;
                            next_mask = next_mask + 15'd1;
                        end
                    end
                end
            end else begin
                next_state = FIND_MIN;
            end
        end
        
        FIND_MIN: begin
            // Find minimum dp value in final states (all mice eaten)
            // Final state is mask = (1 << num_mice) - 1
            next_best_final = best_vel;
            next_state = FINISH;
        end
        
        FINISH: begin
            done = 1'b1;
            valid = 1'b1;
            result = best_final;
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

// Square root approximation (Newton-Raphson - 5 iterations)
always @(*) begin
    next_sqrt_temp = sqrt_temp;
    next_sqrt_iter = sqrt_iter;
    
    if (state == PRECOMPUTE || state == DP_INIT) begin
        if (sqrt_iter < 3'd5) begin
            // Newton iteration: x_{n+1} = 0.5 * (x_n + S/x_n)
            // For Q8.8: multiply by ONE_Q8_8 then shift
            next_sqrt_temp = (sqrt_temp + (sum_sq / sqrt_temp)) >> 1;
            next_sqrt_iter = sqrt_iter + 3'd1;
        end
    end
end

// Memory write logic (simplified - in practice would use proper BRAM inference)
always @(posedge clk) begin
    if (!rst_n) begin
        // Clear tables
        // Note: In real implementation, use initialization block or reset logic
    end else begin
        // Write to dist_table or vel_table based on state
        if (state == PRECOMPUTE && calc_idx <= num_mice) begin
            // vel_table[calc_idx] <= temp_vel;
        end
        if (state == DP_INIT && calc_idx < num_mice) begin
            // dist_table[calc_idx] <= sqrt_temp << 8; // Scale to Q8.8
            // dp_table[1 << calc_idx] <= (sqrt_temp << 8) / mouse_s[calc_idx];
        end
    end
end

endmodule