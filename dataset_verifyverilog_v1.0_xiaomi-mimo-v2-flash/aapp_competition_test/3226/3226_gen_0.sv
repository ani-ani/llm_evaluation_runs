module police_escape (
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] exit_count,
    input [3:0] bro_start,
    input [3:0] police_start,
    input [3:0] edge_src [0:15],
    input [3:0] edge_dst [0:15],
    input [7:0] edge_len [0:15],
    input [3:0] exit_list [0:7],
    output reg [15:0] result_speed,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_FW    = 3'd1;
    localparam [2:0] FW_LOOP    = 3'd2;
    localparam [2:0] CHECK_EXIT = 3'd3;
    localparam [2:0] UPDATE_BIN = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers for control
    reg [2:0] state, next_state;
    reg [3:0] k_idx, i_idx, j_idx; // Loop indices for Floyd-Warshall
    reg [3:0] exit_idx;            // Loop index for exit check
    reg [3:0] edge_idx;            // Loop index for edge loading
    reg [2:0] iter_count;          // Binary search iteration counter
    
    // Distance matrix (8x8, 16-bit per entry)
    reg [15:0] dist [0:7][0:7];
    
    // Binary search registers (Q8.8 fixed point)
    reg [15:0] speed_high;
    reg [15:0] speed_low;
    reg [15:0] speed_mid;
    
    // Temporary values for comparison
    reg [31:0] val_bro;
    reg [31:0] val_pol;
    reg [31:0] dist_bro_scaled; // distB * 160
    reg [31:0] dist_pol_scaled; // distP * S
    
    // Intermediate calculation registers
    reg [15:0] temp_dist_sum;
    reg [15:0] new_dist;
    reg [15:0] old_dist;
    
    // Flags
    reg escape_possible;
    
    // Constants
    localparam [15:0] INF = 16'hFFFF;
    localparam [7:0] POLICE_SPEED_FIXED = 8'hA0; // 160.0 in Q8.8 (160 << 8 = 40960, high byte is 160)
    localparam [15:0] POLICE_SPEED_16 = 16'd160; // For multiplication
    
    // Loop control
    integer r, c;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            result_speed <= 16'd0;
            
            // Initialize distance matrix
            for (r = 0; r < 8; r = r + 1) begin
                for (c = 0; c < 8; c = c + 1) begin
                    dist[r][c] <= (r == c) ? 16'd0 : INF;
                end
            end
            
            // Initialize binary search bounds
            speed_high <= 16'hFFFF; // Max Q8.8
            speed_low <= 16'd0;
            speed_mid <= 16'd0;
            
            // Initialize counters
            k_idx <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            exit_idx <= 4'd0;
            edge_idx <= 4'd0;
            iter_count <= 3'd0;
            
            escape_possible <= 1'b0;
            temp_dist_sum <= 16'd0;
            new_dist <= 16'd0;
            old_dist <= 16'd0;
            
            dist_bro_scaled <= 32'd0;
            dist_pol_scaled <= 32'd0;
            val_bro <= 32'd0;
            val_pol <= 32'd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    
                    if (start) begin
                        state <= INIT_FW;
                        // Reset distance matrix
                        for (r = 0; r < 8; r = r + 1) begin
                            for (c = 0; c < 8; c = c + 1) begin
                                dist[r][c] <= (r == c) ? 16'd0 : INF;
                            end
                        end
                        edge_idx <= 4'd0;
                        k_idx <= 4'd0;
                        i_idx <= 4'd0;
                        j_idx <= 4'd0;
                        exit_idx <= 4'd0;
                        iter_count <= 3'd0;
                        speed_high <= 16'hFFFF;
                        speed_low <= 16'd0;
                    end
                end

                INIT_FW: begin
                    // Load edges into distance matrix
                    if (edge_idx < 16 && edge_idx < node_count * 2) begin
                        // Check if edge is valid (src and dst < node_count)
                        if (edge_src[edge_idx] < node_count && edge_dst[edge_idx] < node_count) begin
                            dist[edge_src[edge_idx]][edge_dst[edge_idx]] <= {8'd0, edge_len[edge_idx]};
                            // Undirected graph assumption based on typical city graphs
                            dist[edge_dst[edge_idx]][edge_src[edge_idx]] <= {8'd0, edge_len[edge_idx]};
                        end
                        edge_idx <= edge_idx + 4'd1;
                    end else begin
                        // Check if police or bro start is at an exit (impossible)
                        state <= FW_LOOP;
                        k_idx <= 4'd0;
                        i_idx <= 4'd0;
                        j_idx <= 4'd0;
                    end
                end

                FW_LOOP: begin
                    // Floyd-Warshall: dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
                    // Optimization: Only compute if dist[i][k] and dist[k][j] are not INF
                    if (k_idx < node_count) begin
                        if (i_idx < node_count) begin
                            if (j_idx < node_count) begin
                                // Check for valid sum (avoid overflow)
                                if (dist[i_idx][k_idx] != INF && dist[k_idx][j_idx] != INF) begin
                                    temp_dist_sum = dist[i_idx][k_idx] + dist[k_idx][j_idx];
                                    if (temp_dist_sum < dist[i_idx][j_idx]) begin
                                        dist[i_idx][j_idx] <= temp_dist_sum;
                                    end
                                end
                                j_idx <= j_idx + 4'd1;
                            end else begin
                                j_idx <= 4'd0;
                                i_idx <= i_idx + 4'd1;
                            end
                        end else begin
                            i_idx <= 4'd0;
                            k_idx <= k_idx + 4'd1;
                        end
                    end else begin
                        // Floyd-Warshall Complete
                        // Check if initial condition is impossible (Police at exit)
                        state <= CHECK_EXIT;
                        exit_idx <= 4'd0;
                        escape_possible <= 1'b0;
                    end
                end

                CHECK_EXIT: begin
                    // Check feasibility for current speed_mid (calculated in UPDATE_BIN, but we use speed_mid)
                    // Actually, we need to calculate speed_mid before CHECK_EXIT or store it.
                    // Let's calculate speed_mid in UPDATE_BIN and transition to CHECK_EXIT.
                    // Wait, the loop is: UPDATE_BIN -> CHECK_EXIT -> UPDATE_BIN ...
                    // To start: Binary Search Init. But we are in IDLE -> INIT_FW -> FW_LOOP -> ...
                    // We need a state to init binary search params.
                    // Let's insert a BINARY_INIT state or combine with FW_LOOP finish.
                    // Re-reading logic: We need to loop Binary Search.
                    // Let's modify flow: FW_LOOP -> BINARY_INIT -> CHECK_EXIT -> UPDATE_BIN -> (Loop to CHECK_EXIT or FINISH)
                end
            endcase
        end
    end

    // Second always block for non-blocking state logic fix
    // Combining logic for binary search to avoid extra states
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            // Additional logic to handle transition from FW_LOOP completion and Binary Search
            if (state == FW_LOOP && k_idx >= node_count) begin
                // Initialize Binary Search
                if (dist[police_start][bro_start] == 16'd0 && police_start != bro_start) begin
                    // Police and Bro at same node (but different IDs?) unlikely unless mapped
                    // Check specifically if police starts at an exit
                end
                // Check if police starts at any exit
                // This requires a quick check. Let's assume inputs are valid per spec.
                // We check if distP[exit] is 0.
                
                // Initialize Binary Search Bounds
                speed_low <= 16'd0;
                speed_high <= 16'hFFFF; // Max possible
                iter_count <= 3'd0;
                state <= UPDATE_BIN; // Start Binary Search Loop
            end
            
            if (state == UPDATE_BIN) begin
                if (iter_count < 3'd10) begin
                    speed_mid <= (speed_low + speed_high) >> 1;
                    exit_idx <= 4'd0;
                    state <= CHECK_EXIT;
                    escape_possible <= 1'b0; // Reset for new check
                end else begin
                    // Binary Search Complete
                    if (escape_possible) begin
                        result_speed <= speed_low; // Lowest valid speed
                        impossible <= 1'b0;
                    end else begin
                        result_speed <= 16'd0;
                        impossible <= 1'b1;
                    end
                    state <= FINISH;
                end
            end
            
            if (state == CHECK_EXIT) begin
                if (exit_idx < exit_count) begin
                    // Check condition: distB[e] * 160 < distP[e] * S
                    // Calculate distB[e] * 160 (scaled to Q8.8)
                    // distB[e] is 16-bit integer. 160 is 16-bit integer.
                    // Product is 32-bit integer.
                    // We need to compare: (distB * 160) * 256 < distP * S * 256
                    // Actually, S is Q8.8. distP is integer.
                    // distP * S yields Q8.8 (32-bit).
                    // distB * 160 is integer. To compare with Q8.8, scale distB * 160 by 256 (shift left 8).
                    
                    // Optimization: If distP[e] is INF or 0, skip or handle
                    
                    if (dist[police_start][exit_list[exit_idx]] != INF && dist[bro_start][exit_list[exit_idx]] != INF) begin
                        // Check if Police is already at exit (dist 0) -> Impossible for this speed
                        if (dist[police_start][exit_list[exit_idx]] == 16'd0) begin
                            // Police is at exit, brothers cannot escape unless they are also there (dist 0)
                            if (dist[bro_start][exit_list[exit_idx]] == 16'd0) begin
                                // Both at exit, consider possible (tie)
                            end else begin
                                // Police there, bro not -> Impossible for this speed
                                // We don't set global impossible yet, just fail this check
                            end
                        end else begin
                            // Calculate Values
                            // distB * 160 * 256 (shift left 8) -> 32-bit
                            dist_bro_scaled <= {dist[bro_start][exit_list[exit_idx]] * POLICE_SPEED_16, 8'd0};
                            
                            // distP * S
                            // S is 16-bit (speed_mid).
                            // distP is 16-bit.
                            // Result is 32-bit Q8.8.
                            // Multiplication: 16 * 16 = 32 bits.
                            // Since S is Q8.8, the result is effectively integer * fractional.
                            // To avoid 64-bit multiplication, we can do 16x32 or 32x16.
                            // distP (16-bit) * speed_mid (16-bit Q8.8) -> 32-bit result.
                            // The product is (distP << 8) * (speed_mid >> 8) + lower parts? 
                            // Simpler: 32-bit intermediate.
                            // val_pol = distP * speed_mid.
                            // Since speed_mid is Q8.8, this is effectively integer arithmetic.
                            // Example: distP=10, speed=2.0 (512). 10*512 = 5120. 
                            // Result is Q8.8 (5120 = 20.0 in Q8.8).
                            // Comparison: (distB * 160) < (distP * S) ?
                            // Actually, the formula is distB * 160 < distP * S.
                            // This is comparing integers vs Q8.8. 
                            // We need to scale the integer side up by 256.
                            // So: (distB * 160 * 256) < (distP * S * 256) ? No.
                            // Condition: distB * 160 < distP * S.
                            // distP * S is Q8.8. distB * 160 is integer.
                            // If S=1.5 (384), distP=10. distP*S = 15.36 (3932).
                            // distB * 160 = integer X.
                            // We need X < 15.36. Max X = 15.
                            // So integer comparison: distB * 160 * 256 < distP * S * 256.
                            // distP * S * 256 = distP * (S << 8).
                            // S << 8 is integer version of S (e.g., 2.0 -> 512 -> 512<<8 = 131072? No).
                            // Let's use 32-bit arithmetic carefully.
                            // Left side: distB * 160. 
                            // Right side: distP * S. S is Q8.8.
                            // Convert right side to pure integer by multiplying by 256 (shifting left 8).
                            // Right Side: distP * S * 256 = distP * (S * 256).
                            // S is 16-bit. S * 256 = 24-bit? No, S is fixed point.
                            // Let's stick to 64-bit intermediate if needed or careful scaling.
                            
                            // Let's perform: (distP * speed_mid) << 8 vs (distB * 160) << 8
                            // Wait, the condition is strict: distB * 160 < distP * S
                            // Let A = distB * 160 (Integer)
                            // Let B = distP * S (Q8.8)
                            // We want A < B.
                            // Multiply both by 256: A*256 < B*256
                            // B*256 = distP * (S * 256) = distP * (S << 8).
                            // S is 16-bit. S << 8 is 24-bit if we don't truncate? No, S << 8 fits in 24-bit? Max S=255.99 -> 0xFF00. Shift 8 -> 0xFF0000 (24-bit).
                            // distP max ~2000.
                            // 24-bit * 16-bit = 40-bit. Too big.
                            // 
                            // Alternative: Use 64-bit temporarily or divide.
                            // Since distP and distB are small (< 4096), we can do:
                            // Check: distB * 160 * 256 < distP * S * 256
                            // Let's do: (distB * 160) << 8 < (distP * S) << 8
                            // (distP * S) << 8 = distP * (S << 8)
                            // S << 8 is just S with fraction removed? No, S is value.
                            // If S=1.5 (384). S<<8 = 98304.
                            // distP=10. 10 * 98304 = 983040.
                            // distB*160*256 = distB * 40960.
                            // 
                            // Let's use 32-bit accumulation carefully.
                            // We can't fit everything in 32-bit easily without loss.
                            // But distP < 4096, distB < 4096.
                            // distB * 160 * 256 = distB * 40960. Max 4096 * 40960 = 167M (28 bits). Fits in 32-bit.
                            // distP * S * 256 = distP * (S << 8). 
                            // S max 255.99 -> 0xFF00. Shift 8 -> 0xFF0000 (16,711,680).
                            // distP * 16M -> 4096 * 16M = 65B (36 bits). 
                            // 36 bits > 32 bits. Overflow risk.
                            // 
                            // Optimization: Divide both sides by 256 (shift right 8).
                            // Condition: (distB * 160) < (distP * S)
                            // Left: distB * 160 (Integer).
                            // Right: distP * S (Q8.8).
                            // Shift Right 8: (distB * 160) >> 8 < (distP * S) >> 8
                            // (distB * 160) >> 8 = distB * 0.625. Not good for integer logic.
                            // 
                            // Let's use 64-bit intermediate for the right side.
                            // Right side: distP * (S << 8).
                            // distP is 16-bit. (S << 8) is 24-bit.
                            // Product is 40-bit. Fits in 64-bit.
                            // Left side: distB * 40960 (28-bit). Fits in 64-bit.
                            // We will use 64-bit registers for comparison.
                            
                            // We'll use a helper block or explicit logic.
                            // Since this is a large calculation, let's do it in stages if needed, but Verilog handles 64-bit params.
                            
                            // Actually, we can just use logic:
                            // if (distB * 160 * 256 < distP * S * 256)
                            // This comparison can be done if we keep precision high enough.
                            // Let's define:
                            // val_left = distB * 40960; // 32-bit result
                            // val_right = distP * S;     // 32-bit Q8.8 result
                            // We want val_left < val_right.
                            // val_right is Q8.8. val_left is integer.
                            // Example: val_left=1000. val_right=1000.5 (256128). 1000 < 1000.5 is true.
                            // If val_right is 1000.0 (256000). 1000 < 1000 is false.
                            // If val_right is 999.9 (255974). 1000 < 999.9 is false.
                            // So we are checking if integer A is strictly less than fixed point B.
                            // This is equivalent to A*256 < B*256.
                            // B*256 = distP * S * 256 = distP * (S << 8).
                            // 
                            // Let's stick to 64-bit for safety.
                            // Left: distB * 160 * 256 = distB * 40960. Max ~167M (28 bits).
                            // Right: distP * (S << 8). Max 4096 * (256 << 8) = 4096 * 65536 = 268M (28 bits).
                            // Actually, S max is 255.99. S << 8 is 0xFF00 << 8? No.
                            // S is 16-bit Q8.8. Value 255.99 = 0xFFFF.
                            // S << 8 (arithmetically) = 0xFFFF00. 24 bits.
                            // 4096 * 0xFFFF00 = 2^12 * (2^24 - 2^8) = 2^36 - 2^20.
                            // 68 Billion. 36 bits. 
                            // Okay, we definitely need > 32 bits.
                            // 64-bit registers are fine in synthesis.
                            
                            // Calculation:
                            // val_bro <= dist[bro_start][exit_list[exit_idx]] * 32'd40960;
                            // val_pol <= dist[police_start][exit_list[exit_idx]] * (speed_mid << 8);
                            
                            // However, dist is 16-bit. 16*32 = 48 bits. Fits in 64-bit.
                            // speed_mid is 16-bit. 16*16 = 32 bits. 
                            // distP * (speed_mid << 8) -> 16 * 24 = 40 bits.
                            // 
                            // Let's break it down:
                            // Left (Bro): distB * 160 * 256 = distB * 40960.
                            // Right (Pol): distP * S * 256 = distP * (S * 256).
                            // S * 256 is just S shifted left 8. 
                            // 
                            // We'll use two 64-bit registers for comparison.
                            // We need to declare them as reg [63:0].
                            // 
                            // Wait, we can't declare new regs inside the always block in standard Verilog 2001 without defining them outside.
                            // I will use the existing val_bro and val_pol if they are wide enough, or declare them as 64-bit.
                            // I declared val_bro and val_pol as 32-bit in the initial draft. I need to change that to 64-bit.
                            // Let's assume I can use [63:0] for calculation.
                            
                            // Since I can't change the reg width mid-design, I will rely on the fact that for small graphs, distances might be small.
                            // But to be safe, let's simulate the calculation.
                            // Max dist ~ 255 * 7 = 1785.
                            // Max speed S = 255.99.
                            // distP * S = 1785 * 255.99 ~ 457,000. (19 bits)
                            // distB * 160 = 1785 * 160 = 285,600. (19 bits)
                            // These fit in 32 bits easily.
                            // Wait, earlier I calculated 268M. That was wrong.
                            // distP * S is Q8.8.
                            // If S=255.99 (0xFFFF). distP=1785 (0x06F9).
                            // 0x06F9 * 0xFFFF = 0x06F8 F907. (32-bit result).
                            // distB * 160 = 1785 * 160 = 285600 (0x00045BA0).
                            // 0x06F8F907 is much larger than 0x00045BA0.
                            // So 32-bit is sufficient! My previous bit-width calculation was incorrect because I multiplied by 256 unnecessarily or incorrectly.
                            // 
                            // Correct Logic:
                            // Check: distB * 160 < distP * S
                            // Left: distB * 160 (Integer). Max ~ 1785 * 160 = 285,600.
                            // Right: distP * S (Q8.8). Max ~ 1785 * 255.99 = 457,000.
                            // Both fit in 32-bit signed integers.
                            // 
                            // Wait, distB * 160 < distP * S.
                            // If distB=10, distP=10, S=1.0. 10*160 = 1600. 10*1.0 = 10. 1600 < 10 is False.
                            // If S=200. 10*200 = 2000. 1600 < 2000 is True.
                            // 
                            // So we just need:
                            // val_bro = distB * 160
                            // val_pol = distP * S (Q8.8 multiplication)
                            // 
                            // distP is 16-bit int. S is 16-bit Q8.8.
                            // distP * S produces 32-bit Q8.8 result.
                            // The integer part of the result is in bits [31:8].
                            // The fractional part is bits [7:0].
                            // 
                            // We are comparing integer value (distB*160) with fixed point value (distP*S).
                            // Since distB*160 is integer, we compare it with the integer part of distP*S, checking if it's strictly less.
                            // Actually, 1600.5 < 1601 is true. 1600 < 1600.5 is true.
                            // So we should compare: distB * 160 * 256 < distP * S * 256.
                            // distP * S * 256 = distP * (S << 8).
                            // S << 8 is integer shift. Max S = 0xFFFF. S << 8 = 0xFF0000 (16,711,680).
                            // 1785 * 16,711,680 = 29 Billion. (35 bits).
                            // This exceeds 32-bit.
                            // 
                            // Alternative: Compare (distB * 160) with (distP * S) integer part + fractional check?
                            // We need strict inequality.
                            // distB * 160 < distP * S
                            // distB * 160 * 256 < distP * S * 256
                            // distB * 40960 < distP * (S << 8)
                            // 
                            // Let's try to reduce the range.
                            // distB and distP are small.
                            // Maybe we can do: (distB * 160) << 8 < (distP * S) << 8
                            // (distP * S) << 8 = distP * (S << 8).
                            // 
                            // Let's assume we use 64-bit registers for the multiplication.
                            // I will declare `val_bro` and `val_pol` as `reg [63:0]`.
                            // Wait, I declared them as `reg [31:0]` in the template.
                            // I should update that. 
                            // Since I am writing the code now, I can declare them as 64-bit.
                            // Let's use 64-bit for comparison.

                            // Multiplication Logic:
                            // val_bro = distB * 40960; (distB * 160 * 256)
                            // val_pol = distP * (speed_mid << 8);
                            
                            // Let's implement this with 64-bit intermediate values.
                            // I will use {32'd0, dist[bro_start][exit_list[exit_idx]]} * 32'd40960 logic or similar.
                            // Actually, since dist is 16-bit, dist * 32'd40960 fits in 48 bits.
                            // distP * (speed_mid << 8) -> 16 * (16 << 8) = 16 * 24 = 40 bits.
                            // 64-bit is safe.
                            
                            // However, I need to ensure the code is synthesizable.
                            // Verilog multiplication: A * B. Width is size(A) + size(B).
                            // I'll define temporary 64-bit signals in the sequential block.
                            // But wait, I can't easily define new variables in the always block if they weren't declared.
                            // I declared `val_bro` and `val_pol` as 32-bit. I will change them to 64-bit in the declaration section above.
                            // 
                            // Correction: I will use `val_bro` and `val_pol` as 64-bit for calculation.
                            // But to save logic, maybe we can check without full 64-bit if we are careful.
                            // However, given the potential range (up to 35 bits), 64-bit is safest.
                            
                            // Let's perform the calculation:
                            // val_bro <= dist[bro_start][exit_list[exit_idx]] * 24'd40960;
                            // val_pol <= dist[police_start][exit_list[exit_idx]] * ((speed_mid << 8));
                            
                            // Since speed_mid is 16-bit, speed_mid << 8 is 24-bit.
                            // dist[...] is 16-bit.
                            // 
                            // Let's do it step by step in combinational logic or use the clock.
                            // We are in CHECK_EXIT state. We can compute one edge per cycle or all.
                            // Let's compute the multiplication in one cycle using 64-bit width.
                            
                            // Check condition:
                            if (dist[police_start][exit_list[exit_idx]] == 0) begin
                                // Police at exit, skip or fail.
                                // If distB > 0, fail. If distB == 0, tie (consider fail for strict escape).
                            end else begin
                                // Calculate Left Side: distB * 160 * 256
                                // We can keep left side as distB * 160 and right as distP * S.
                                // But to compare strictly, we need scaling.
                                // Let's use 64-bit for scaling.
                                // Left: distB * 40960
                                // Right: distP * (speed_mid << 8)
                                
                                // Using 64-bit temporary values.
                                // We need to calculate these.
                                // I'll use the existing `temp_dist_sum` register for intermediate or just compute in combinational logic.
                                // 
                                // Wait, `val_bro` and `val_pol` are sequential. I can update them.
                                // Let's update them in this state.
                                
                                // Multiplication 1: distB * 40960
                                val_bro <= {48'd0, dist[bro_start][exit_list[exit_idx]]} * 32'd40960;
                                
                                // Multiplication 2: distP * (speed_mid << 8)
                                val_pol <= {48'd0, dist[police_start][exit_list[exit_idx]]} * (speed_mid << 8);
                            end
                            
                            exit_idx <= exit_idx + 4'd1;
                        end
                    end else begin
                        // No path to exit
                        exit_idx <= exit_idx + 4'd1;
                    end
                end else begin
                    // Done checking all exits
                    if (escape_possible) begin
                        // If possible at this speed, we want LOWER speed (binary search min)
                        // Standard binary search: if possible, try lower. High = Mid.
                        // If not possible, try higher. Low = Mid + 1.
                        // Here: We want minimal S where escape is possible.
                        // So if `escape_possible` is true, we set `speed_high = speed_mid`.
                        // If false, `speed_low = speed_mid + 1`.
                        // Wait, the loop direction needs to be correct.
                        // We initialized Low=0, High=Max.
                        // If condition holds (escape possible), we might be able to go lower.
                        // So High = Mid.
                        // If condition fails, we need higher speed. Low = Mid + 1.
                        state <= UPDATE_BIN;
                    end else begin
                        // Not possible at this speed, need higher
                        state <= UPDATE_BIN;
                    end
                end
            end
            
            if (state == UPDATE_BIN) begin
                // We need to check the result of the previous CHECK_EXIT.
                // We need a register to hold if the last check passed.
                // Let's use `escape_possible` to store the result of the check.
                // But `escape_possible` is set inside CHECK_EXIT loop.
                // How do we know the result of the full check?
                // We need a flag `current_check_passed`.
                // Let's add a flag `check_passed`.
                
                // Actually, `escape_possible` is reset to 0 at start of CHECK_EXIT.
                // It is set to 1 if any exit works.
                // So at end of CHECK_EXIT, `escape_possible` is the result.
                
                if (escape_possible) begin
                    // Found a solution, try lower speed
                    speed_high <= speed_mid;
                end else begin
                    // No solution, need higher speed
                    speed_low <= speed_mid + 16'd1;
                end
                
                iter_count <= iter_count + 3'd1;
            end
        end
    end

    // Combinational logic for multiplication and comparison
    // We need to perform the comparison inside CHECK_EXIT.
    // Since `val_bro` and `val_pol` are registered, we need to compute them.
    // We can compute them combinationally based on current state.
    
    wire [63:0] bro_calc;
    wire [63:0] pol_calc;
    wire [23:0] speed_shifted;
    
    assign speed_shifted = speed_mid << 8;
    assign bro_calc = {48'd0, dist[bro_start][exit_list[exit_idx]]} * 32'd40960;
    assign pol_calc = {48'd0, dist[police_start][exit_list[exit_idx]]} * speed_shifted;
    
    // We need to capture the result of the check.
    // Since we iterate exits, we need to aggregate the result.
    // Let's add a wire for the comparison.
    wire check_condition_met;
    // Condition: bro_calc < pol_calc
    assign check_condition_met = (bro_calc < pol_calc);
    
    // We need to handle the sequential update of `escape_possible` and `val_bro`, `val_pol`.
    // But actually, we don't need to store `val_bro` and `val_pol` if we compare immediately.
    // We just need to know if the condition holds for the current exit.
    
    // Revisiting the sequential block for CHECK_EXIT:
    // We can do:
    // if (check_condition_met) escape_possible <= 1'b1;
    
    // However, I need to ensure `dist` and `exit_list` are valid for the combinational logic.
    // They are updated sequentially, so the values are stable at the clock edge.
    
    // Let's refine the CHECK_EXIT state in the sequential block to use the combinational wire.
    
    // Wait, there's a slight issue. `exit_idx` changes. The combinational logic depends on `exit_idx`.
    // This is fine for logic gates, but we need to be careful about latches.
    // Since `exit_idx` is a reg, the combinational outputs will update based on it.
    
    // Let's update the CHECK_EXIT section in the sequential block:
    // Instead of assigning to `val_bro`/`val_pol`, we just check `check_condition_met`.
    
    // But wait, `check_condition_met` is a single bit. If multiple exits are valid, we just need one.
    // So if `check_condition_met` is high, set `escape_possible` to 1.
    
    // Let's adjust the code inside the sequential block for CHECK_EXIT.
    // I will replace the multiplication logic with the combinational check.
    
    // Also, need to handle the case where dist is INF.
    // If dist is INF, the multiplication will be huge (0xFFFF * ...).
    // We should gate the check.
    
    // Updated logic for CHECK_EXIT (inside the always block):
    /*
    if (exit_idx < exit_count) begin
        if (dist[police_start][exit_list[exit_idx]] != INF && dist[bro_start][exit_list[exit_idx]] != INF) begin
             // Check if police is at exit (dist 0)
             if (dist[police_start][exit_list[exit_idx]] == 0) begin
                 // Police there. If bro is also there (dist 0), it's a tie. We need strict escape.
                 // So if police is there, we fail this exit unless we allow tie (assume fail).
                 // If bro is not there, fail.
             end else begin
                 // Perform calculation and check
                 // We need to use the combinational wire `check_condition_met`
                 // However, `check_condition_met` depends on `dist` and `speed_mid`.
                 // Since we are in the clocked block, we can evaluate the condition.
                 // But we can't directly use the `assign` wire inside the always block if we want to be purely procedural.
                 // We can replicate the logic or use the wire if it updates correctly.
                 // `check_condition_met` is a continuous assignment. It is valid immediately.
                 // 
                 // One issue: `check_condition_met` uses `exit_idx`. As `exit_idx` updates, the wire updates.
                 // So inside the always block, we can just check `check_condition_met`.
                 
                 // However, Verilog simulators might have different evaluation order.
                 // Safer to replicate the logic or use a temporary variable.
                 // Let's replicate the logic in the always block to be safe and avoid multiple drivers.
                 
                 // Logic:
                 // if ({48'd0, distB} * 40960 < {48'd0, distP} * (speed_mid << 8))
                 
                 // We can do this calculation in the always block.
                 // We need 64-bit intermediate values.
                 // We can calculate them in combinational logic outside, or inside.
                 // Let's define intermediate signals for the calculation.
             end
        end
    end
    */
    
    // Redefining the sequential block for CHECK_EXIT to be robust.
    // I will use a combinational block to generate the comparison result.
    
    // Combinational check logic
    reg check_valid;
    reg [63:0] left_val;
    reg [63:0] right_val;
    
    always @(*) begin
        check_valid = 1'b0;
        left_val = 64'd0;
        right_val = 64'd0;
        
        if (state == CHECK_EXIT && exit_idx < exit_count) begin
            if (dist[police_start][exit_list[exit_idx]] != INF && dist[bro_start][exit_list[exit_idx]] != INF) begin
                if (dist[police_start][exit_list[exit_idx]] == 0) begin
                    // Police at exit. Brothers must not be there or they tie.
                    // We consider this impossible for escape unless brothers are strictly faster (impossible if at same node).
                    // So check_valid stays 0.
                end else begin
                    left_val = {48'd0, dist[bro_start][exit_list[exit_idx]]} * 32'd40960;
                    right_val = {48'd0, dist[police_start][exit_list[exit_idx]]} * (speed_mid << 8);
                    check_valid = (left_val < right_val);
                end
            end
        end
    end

    // Corrected Sequential Block logic for CHECK_EXIT
    // (Assuming the above always @(*) block provides check_valid)
    // We need to integrate this into the main FSM.
    
    // I will rewrite the specific part of the sequential block for CHECK_EXIT.
    // Since I can't easily edit the previous block in this text format without rewriting the whole thing,
    // I will rely on the fact that I can use the combinational `check_valid` signal.
    
    // Actually, let's just put the logic directly in the sequential block for simplicity and to avoid multiple drivers if possible.
    // But checking combinational logic inside sequential block is fine.
    // 
    // Let's modify the `CHECK_EXIT` case item in the sequential block.
    
    // Since I am generating the final code, I will write the complete always block below
    // incorporating these corrections.

endmodule

// Helper module for 64-bit multiplication (if needed) or just use built-in.
// Verilog handles 64-bit multiplication fine in synthesis.

// Re-writing the core FSM logic with refined details.

module police_escape (
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] exit_count,
    input [3:0] bro_start,
    input [3:0] police_start,
    input [3:0] edge_src [0:15],
    input [3:0] edge_dst [0:15],
    input [7:0] edge_len [0:15],
    input [3:0] exit_list [0:7],
    output reg [15:0] result_speed,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_FW    = 3'd1;
    localparam [2:0] FW_LOOP    = 3'd2;
    localparam [2:0] CHECK_EXIT = 3'd3;
    localparam [2:0] UPDATE_BIN = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] k_idx, i_idx, j_idx;
    reg [3:0] exit_idx;
    reg [3:0] edge_idx;
    reg [2:0] iter_count;
    
    // Distance matrix
    reg [15:0] dist [0:7][0:7];
    
    // Binary search
    reg [15:0] speed_high;
    reg [15:0] speed_low;
    reg [15:0] speed_mid;
    
    // Flags
    reg escape_possible;
    
    // Combinational wires for calculation
    wire [63:0] bro_val;
    wire [63:0] pol_val;
    wire check_passed;
    
    // Constants
    localparam [15:0] INF = 16'hFFFF;
    localparam [31:0] MUL_CONST = 32'd40960; // 160 * 256
    
    // Calculation logic
    assign bro_val = {48'd0, dist[bro_start][exit_list[exit_idx]]} * MUL_CONST;
    assign pol_val = {48'd0, dist[police_start][exit_list[exit_idx]]} * (speed_mid << 8);
    assign check_passed = (bro_val < pol_val);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            result_speed <= 16'd0;
            
            // Initialize distance matrix
            for (int r = 0; r < 8; r++) begin
                for (int c = 0; c < 8; c++) begin
                    dist[r][c] <= (r == c) ? 16'd0 : INF;
                end
            end
            
            speed_high <= 16'hFFFF;
            speed_low <= 16'd0;
            speed_mid <= 16'd0;
            
            k_idx <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            exit_idx <= 4'd0;
            edge_idx <= 4'd0;
            iter_count <= 3'd0;
            escape_possible <= 1'b0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_FW;
                        edge_idx <= 4'd0;
                        // Reset matrix here or rely on INIT_FW?
                        // Resetting here to be clean
                        for (int r = 0; r < 8; r++) begin
                            for (int c = 0; c < 8; c++) begin
                                dist[r][c] <= (r == c) ? 16'd0 : INF;
                            end
                        end
                    end
                end

                INIT_FW: begin
                    // Load edges
                    if (edge_idx < 16) begin
                        // Check bounds
                        if (edge_idx < (node_count * 2) && edge_src[edge_idx] < node_count && edge_dst[edge_idx] < node_count) begin
                             dist[edge_src[edge_idx]][edge_dst[edge_idx]] <= {8'd0, edge_len[edge_idx]};
                             dist[edge_dst[edge_idx]][edge_src[edge_idx]] <= {8'd0, edge_len[edge_idx]};
                        end
                        edge_idx <= edge_idx + 4'd1;
                    end else begin
                        state <= FW_LOOP;
                        k_idx <= 4'd0;
                        i_idx <= 4'd0;
                        j_idx <= 4'd0;
                    end
                end

                FW_LOOP: begin
                    if (k_idx < node_count) begin
                        if (i_idx < node_count) begin
                            if (j_idx < node_count) begin
                                // Floyd-Warshall update
                                if (dist[i_idx][k_idx] != INF && dist[k_idx][j_idx] != INF) begin
                                    if (dist[i_idx][k_idx] + dist[k_idx][j_idx] < dist[i_idx][j_idx]) begin
                                        dist[i_idx][j_idx] <= dist[i_idx][k_idx] + dist[k_idx][j_idx];
                                    end
                                end
                                j_idx <= j_idx + 4'd1;
                            end else begin
                                j_idx <= 4'd0;
                                i_idx <= i_idx + 4'd1;
                            end
                        end else begin
                            i_idx <= 4'd0;
                            k_idx <= k_idx + 4'd1;
                        end
                    end else begin
                        // FW Done. Check if impossible immediately (Police at exit)
                        // We can do a quick check or just proceed to binary search.
                        // Binary Search Init
                        speed_low <= 16'd0;
                        speed_high <= 16'hFFFF;
                        iter_count <= 3'd0;
                        state <= UPDATE_BIN;
                    end
                end

                UPDATE_BIN: begin
                    if (iter_count < 3'd10) begin
                        speed_mid <= (speed_low + speed_high) >> 1;
                        escape_possible <= 1'b0; // Reset flag for new check
                        exit_idx <= 4'd0;
                        state <= CHECK_EXIT;
                    end else begin
                        // Finished binary search
                        if (escape_possible) begin
                            result_speed <= speed_low;
                            impossible <= 1'b0;
                        end else begin
                            result_speed <= 16'd0;
                            impossible <= 1'b1;
                        end
                        state <= FINISH;
                    end
                end

                CHECK_EXIT: begin
                    if (exit_idx < exit_count) begin
                        // Check combinational condition
                        // Note: dist and exit_list are valid. speed_mid is valid.
                        // Need to handle INF and 0 cases.
                        if (dist[police_start][exit_list[exit_idx]] != INF && dist[bro_start][exit_list[exit_idx]] != INF) begin
                            if (dist[police_start][exit_list[exit_idx]] != 16'd0) begin
                                if (check_passed) begin
                                    escape_possible <= 1'b1;
                                end
                            end
                            // If police is at exit (dist 0), we cannot escape (unless bro is also there, but then dist 0, check fails as 0 < 0 is false)
                        end
                        exit_idx <= exit_idx + 4'd1;
                    end else begin
                        // Done checking all exits
                        state <= UPDATE_BIN;
                        // Update binary search bounds
                        // Note: `escape_possible` is now the result for speed_mid
                        if (escape_possible) begin
                            speed_high <= speed_mid;
                        end else begin
                            speed_low <= speed_mid + 16'd1;
                        end
                        iter_count <= iter_count + 3'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule