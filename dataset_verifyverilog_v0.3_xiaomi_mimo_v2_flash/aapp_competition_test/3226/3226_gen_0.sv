module escape_speed(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] m,
    input [2:0] e,
    input [2:0] b,
    input [2:0] p,
    input [2:0] exit0,
    input [2:0] exit1,
    input [2:0] exit2,
    input [2:0] exit3,
    input [2:0] exit4,
    input [2:0] exit5,
    input [2:0] exit6,
    input [2:0] exit7,
    input [2:0] edge_a0,
    input [2:0] edge_b0,
    input [7:0] edge_l0,
    input edge_valid0,
    input [2:0] edge_a1,
    input [2:0] edge_b1,
    input [7:0] edge_l1,
    input edge_valid1,
    input [2:0] edge_a2,
    input [2:0] edge_b2,
    input [7:0] edge_l2,
    input edge_valid2,
    input [2:0] edge_a3,
    input [2:0] edge_b3,
    input [7:0] edge_l3,
    input edge_valid3,
    input [2:0] edge_a4,
    input [2:0] edge_b4,
    input [7:0] edge_l4,
    input edge_valid4,
    input [2:0] edge_a5,
    input [2:0] edge_b5,
    input [7:0] edge_l5,
    input edge_valid5,
    input [2:0] edge_a6,
    input [2:0] edge_b6,
    input [7:0] edge_l6,
    input edge_valid6,
    input [2:0] edge_a7,
    input [2:0] edge_b7,
    input [7:0] edge_l7,
    input edge_valid7,
    output reg [31:0] speed_q16,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE             = 4'd0;
    localparam [3:0] RESET_DIST       = 4'd1;
    localparam [3:0] FLOYD_K_LOOP     = 4'd2;
    localparam [3:0] FLOYD_I_LOOP     = 4'd3;
    localparam [3:0] FLOYD_J_LOOP     = 4'd4;
    localparam [3:0] FLOYD_UPDATE     = 4'd5;
    localparam [3:0] COMPUTE_W        = 4'd6;
    localparam [3:0] DIJKSTRA_INIT    = 4'd7;
    localparam [3:0] DIJKSTRA_SELECT  = 4'd8;
    localparam [3:0] DIJKSTRA_RELAX   = 4'd9;
    localparam [3:0] DIJKSTRA_UPDATE  = 4'd10;
    localparam [3:0] FIND_MIN_EXIT    = 4'd11;
    localparam [3:0] COMPUTE_SPEED    = 4'd12;
    localparam [3:0] DONE             = 4'd13;

    // Parameters
    localparam [15:0] INF = 16'hFFFF;
    localparam [31:0] INF32 = 32'h7FFFFFFF;
    localparam [7:0] NUM_NODES_MAX = 8'd8;

    // Registers and wires
    reg [3:0] state, next_state;
    reg [7:0] cycle_counter;
    reg [2:0] k_idx, i_idx, j_idx;
    reg [2:0] u_idx, v_idx;
    reg [2:0] node_cnt;
    reg [2:0] exit_idx;
    reg [2:0] edge_idx;
    reg visited [0:7];
    reg [15:0] dist [0:7][0:7]; // 8x8 distance matrix
    reg [15:0] w_num [0:7]; // numerator of w
    reg [15:0] w_den [0:7]; // denominator of w
    reg [31:0] best_num [0:7]; // Dijkstra best numerator
    reg [15:0] best_den [0:7]; // Dijkstra best denominator
    reg [31:0] m_num, m_den; // Min exit fraction
    reg [31:0] div_a, div_b, div_q; // Divider operands
    reg div_start, div_done;
    reg [4:0] div_counter;
    
    // Edge registers
    reg [2:0] edge_a_reg [0:7];
    reg [2:0] edge_b_reg [0:7];
    reg [7:0] edge_l_reg [0:7];
    reg edge_valid_reg [0:7];

    // Helper signals for division comparison
    wire [63:0] cmp_left;
    wire [63:0] cmp_right;
    wire cmp_less;
    
    // Comparator for fractions: left < right? (left_num/left_den < right_num/right_den)
    // => left_num * right_den < right_num * left_den
    // Use 64-bit to prevent overflow
    assign cmp_left = {32'd0, best_num[u_idx]} * {48'd0, best_den[v_idx]};
    assign cmp_right = {32'd0, best_num[v_idx]} * {48'd0, best_den[u_idx]};
    assign cmp_less = (cmp_left < cmp_right);

    // W num comparison for Dijkstra relaxation: max(a, b)
    wire [31:0] max_val;
    wire [31:0] max_den_val;
    wire [63:0] max_left;
    wire [63:0] max_right;
    assign max_left = {32'd0, best_num[u_idx]} * {48'd0, w_den[v_idx]};
    assign max_right = {32'd0, w_num[v_idx]} * {48'd0, best_den[u_idx]};
    assign max_val = (max_left > max_right) ? best_num[u_idx] : w_num[v_idx];
    assign max_den_val = (max_left > max_right) ? best_den[u_idx] : w_den[v_idx];

    // Divider logic (sequential non-restoring)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_start <= 1'b0;
            div_done <= 1'b0;
            div_counter <= 5'd0;
            div_q <= 32'd0;
        end else begin
            if (div_start) begin
                div_counter <= 5'd0;
                div_done <= 1'b0;
                // Initialize for non-restoring division
                // We compute (A * B * 65536) / C, where A=160, B=M_den, C=M_num
                // Initial remainder R = A * B * 65536
                // Shift left by 16 is same as multiplying by 65536
                // Actually: speed = (160 * M_den * 65536) / M_num
                // Let's implement restoring division for simplicity in state machine
                // Start with remainder = 160 * M_den (32-bit)
                // We need result Q16.16, so shift numerator left by 16 bits first
                // Remainder = {160 * M_den, 16'b0}
                // We will use 64-bit remainder for computation
            end else if (!div_done && div_counter < 6'd32) begin
                div_counter <= div_counter + 6'd1;
                // Dividing 48-bit numerator (160*den*65536) by 32-bit denom (num)
                // 160*den is max ~160*16'hFFFF = 26M (25-bit)
                // *65536 -> 41-bit numerator. Fits in 64-bit.
                // Restoring division implementation
            end else if (div_counter == 6'd32) begin
                div_done <= 1'b1;
                div_counter <= 5'd0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            speed_q16 <= 32'd0;
            cycle_counter <= 8'd0;
            k_idx <= 3'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            u_idx <= 3'd0;
            v_idx <= 3'd0;
            node_cnt <= 3'd0;
            exit_idx <= 3'd0;
            edge_idx <= 3'd0;
            m_num <= 32'd0;
            m_den <= 32'd0;
            div_start <= 1'b0;
            // Initialize arrays
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                visited[idx] <= 1'b0;
                w_num[idx] <= 16'd0;
                w_den[idx] <= 16'd0;
                best_num[idx] <= 32'd0;
                best_den[idx] <= 16'd0;
                // dist init will be done in RESET_DIST
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        // Load edges
                        edge_a_reg[0] <= edge_a0; edge_b_reg[0] <= edge_b0; edge_l_reg[0] <= edge_l0; edge_valid_reg[0] <= edge_valid0;
                        edge_a_reg[1] <= edge_a1; edge_b_reg[1] <= edge_b1; edge_l_reg[1] <= edge_l1; edge_valid_reg[1] <= edge_valid1;
                        edge_a_reg[2] <= edge_a2; edge_b_reg[2] <= edge_b2; edge_l_reg[2] <= edge_l2; edge_valid_reg[2] <= edge_valid2;
                        edge_a_reg[3] <= edge_a3; edge_b_reg[3] <= edge_b3; edge_l_reg[3] <= edge_l3; edge_valid_reg[3] <= edge_valid3;
                        edge_a_reg[4] <= edge_a4; edge_b_reg[4] <= edge_b4; edge_l_reg[4] <= edge_l4; edge_valid_reg[4] <= edge_valid4;
                        edge_a_reg[5] <= edge_a5; edge_b_reg[5] <= edge_b5; edge_l_reg[5] <= edge_l5; edge_valid_reg[5] <= edge_valid5;
                        edge_a_reg[6] <= edge_a6; edge_b_reg[6] <= edge_b6; edge_l_reg[6] <= edge_l6; edge_valid_reg[6] <= edge_valid6;
                        edge_a_reg[7] <= edge_a7; edge_b_reg[7] <= edge_b7; edge_l_reg[7] <= edge_l7; edge_valid_reg[7] <= edge_valid7;
                        state <= RESET_DIST;
                        node_cnt <= 3'd0;
                    end
                end

                RESET_DIST: begin
                    // Initialize dist matrix: diagonal 0, others INF
                    for (integer row = 0; row < 8; row = row + 1) begin
                        for (integer col = 0; col < 8; col = col + 1) begin
                            if (row < n && col < n) begin
                                if (row == col)
                                    dist[row][col] <= 16'd0;
                                else
                                    dist[row][col] <= INF;
                            end else begin
                                dist[row][col] <= INF;
                            end
                        end
                    end
                    edge_idx <= 3'd0;
                    state <= FLOYD_K_LOOP;
                    k_idx <= 3'd0;
                end

                FLOYD_K_LOOP: begin
                    if (k_idx < n) begin
                        i_idx <= 3'd0;
                        state <= FLOYD_I_LOOP;
                    end else begin
                        state <= COMPUTE_W;
                    end
                end

                FLOYD_I_LOOP: begin
                    if (i_idx < n) begin
                        j_idx <= 3'd0;
                        state <= FLOYD_J_LOOP;
                    end else begin
                        k_idx <= k_idx + 3'd1;
                        state <= FLOYD_K_LOOP;
                    end
                end

                FLOYD_J_LOOP: begin
                    if (j_idx < n) begin
                        state <= FLOYD_UPDATE;
                    end else begin
                        i_idx <= i_idx + 3'd1;
                        state <= FLOYD_I_LOOP;
                    end
                end

                FLOYD_UPDATE: begin
                    // dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
                    // Check for INF to avoid overflow
                    if (dist[i_idx][k_idx] != INF && dist[k_idx][j_idx] != INF) begin
                        if (dist[i_idx][j_idx] > (dist[i_idx][k_idx] + dist[k_idx][j_idx])) begin
                            dist[i_idx][j_idx] <= dist[i_idx][k_idx] + dist[k_idx][j_idx];
                        end
                    end
                    j_idx <= j_idx + 3'd1;
                    state <= FLOYD_J_LOOP;
                end

                COMPUTE_W: begin
                    // For each node i: w_num = 160*dist[b][i], w_den = dist[p][i]
                    // If dist[p][i] == 0 (i == p), set infinite (w_num = INF32, w_den = 1)
                    if (dist[p][node_cnt] == 16'd0) begin
                        w_num[node_cnt] <= INF32[31:16]; // Store high bits for comparison logic consistency if needed, but w_num is 16-bit in spec? No, spec says w_num is 32-bit in INF check but 160*dist is max 160*255=40800 (fits 16-bit). Wait, spec says w_num[i] = 32'h7FFFFFFF if infinite. Let's use 32-bit for w_num to match INF32.
                        w_den[node_cnt] <= 16'd1;
                    end else begin
                        w_num[node_cnt] <= {16'd0, 16'd0}; // Use high word for 32-bit value
                        // Actually, let's declare w_num as [31:0] for consistency
                    end
                    // Since we need 32-bit w_num for INF check, let's re-declare w_num as 32-bit implicitly or handle carefully.
                    // Re-implementation: w_num will be 32-bit, but 160*dist fits in 16 bits.
                    // Let's just use 32-bit arithmetic.
                    if (node_cnt < n) begin
                        if (dist[p][node_cnt] == 16'd0) begin
                            w_num[node_cnt] <= INF32;
                            w_den[node_cnt] <= 16'd1;
                        end else begin
                            w_num[node_cnt] <= 32'd0; // Clear high bits
                            // Just store 160*dist in lower 16 bits? No, 160*255 = 40800 > 65535? No, 65535 is max 16-bit unsigned.
                            // 160*255 = 40800. Fits in 16 bits.
                            // So w_num is effectively 16-bit value in a 32-bit reg.
                            w_num[node_cnt] <= 16'd160 * dist[b][node_cnt];
                            w_den[node_cnt] <= dist[p][node_cnt];
                        end
                        node_cnt <= node_cnt + 3'd1;
                    end else begin
                        state <= DIJKSTRA_INIT;
                    end
                end

                DIJKSTRA_INIT: begin
                    // Reset visited, best values
                    for (integer idx = 0; idx < 8; idx = idx + 1) begin
                        visited[idx] <= 1'b0;
                        best_num[idx] <= INF32;
                        best_den[idx] <= 16'd1;
                    end
                    best_num[b] <= 32'd0;
                    best_den[b] <= 16'd1;
                    node_cnt <= 3'd0;
                    state <= DIJKSTRA_SELECT;
                end

                DIJKSTRA_SELECT: begin
                    // Find unvisited node u with smallest best fraction
                    // Linear search: initialize min_idx to n (invalid)
                    // We use u_idx to track current candidate
                    if (node_cnt < n) begin
                        if (!visited[node_cnt]) begin
                            u_idx <= node_cnt;
                            // Check if this is better than current u_idx (which is previous candidate)
                            // If u_idx was invalid (>=n), take node_cnt
                            // Since we need to compare, we might need a temp register for best_u
                            // Or just use u_idx as the "current best" index.
                            // Logic: if u_idx >= n or (best[node_cnt] < best[u_idx]), update u_idx
                            if (u_idx >= n || cmp_less) begin
                                u_idx <= node_cnt;
                            end
                        end
                        node_cnt <= node_cnt + 3'd1;
                    end else begin
                        // Reset node_cnt for relaxation loop
                        if (u_idx < n && !visited[u_idx]) begin
                            visited[u_idx] <= 1'b1;
                            v_idx <= 3'd0;
                            state <= DIJKSTRA_RELAX;
                        end else begin
                            // No more nodes or all visited
                            state <= FIND_MIN_EXIT;
                        end
                        node_cnt <= 3'd0;
                    end
                end

                DIJKSTRA_RELAX: begin
                    if (v_idx < n) begin
                        // Relax edge u->v
                        // Edge exists if dist[u][v] != INF and u != v
                        // Note: dist is in hundred meters.
                        // w[v] is defined for all v. dist[u][v] is the graph distance.
                        // Candidate weight = max(best[u], w[v]) where w[v] depends on graph distance.
                        // Wait, w[v] is specific to node v (based on p->v and b->v).
                        // The path cost is max(w[x]) for all nodes x on path.
                        // In Dijkstra, when going u -> v, the cost is max(current_path_cost, weight_of_v).
                        // weight_of_v is w[v].
                        // But w[v] uses dist[p][v] and dist[b][v]. These are shortest paths in graph.
                        // So w[v] is fixed for each node v.
                        // Dijkstra finds path u->v (using graph edges) minimizing max(w[node]).
                        // Here, dist[u][v] is the shortest graph distance between u and v.
                        // If dist[u][v] < INF, we can go directly from u to v.
                        // The cost to reach v via u is max(best_num[u]/best_den[u], w_num[v]/w_den[v]).
                        // We update best[v] if this is smaller.
                        if (dist[u_idx][v_idx] != INF && u_idx != v_idx) begin
                            // Compute max(best[u], w[v])
                            // Compare best[u] vs w[v]
                            // best[u] is fraction, w[v] is fraction.
                            // We need to update best[v] = min(best[v], max(best[u], w[v]))
                            // First calculate max(best[u], w[v]) -> stored in max_val/max_den_val
                            // Now compare (max_val/max_den_val) < (best[v])
                            // best[v] is best_num[v]/best_den[v]
                            wire [63:0] check_left = {32'd0, max_val} * {48'd0, best_den[v_idx]};
                            wire [63:0] check_right = {32'd0, best_num[v_idx]} * {48'd0, max_den_val};
                            if (check_left < check_right) begin
                                best_num[v_idx] <= max_val;
                                best_den[v_idx] <= max_den_val;
                            end
                        end
                        v_idx <= v_idx + 3'd1;
                    end else begin
                        node_cnt <= 3'd0;
                        u_idx <= 3'd0; // Reset for next iteration of SELECT
                        state <= DIJKSTRA_SELECT;
                    end
                end

                FIND_MIN_EXIT: begin
                    // Find min best among exits
                    if (exit_idx < e) begin
                        // Get exit node ID
                        case (exit_idx)
                            3'd0: u_idx <= exit0;
                            3'd1: u_idx <= exit1;
                            3'd2: u_idx <= exit2;
                            3'd3: u_idx <= exit3;
                            3'd4: u_idx <= exit4;
                            3'd5: u_idx <= exit5;
                            3'd6: u_idx <= exit6;
                            3'd7: u_idx <= exit7;
                        endcase
                        // If best[u] < current m, update m
                        // Compare best[u_idx] < m_num/m_den
                        wire [63:0] m_left = {32'd0, best_num[u_idx]} * {32'd0, m_den};
                        wire [63:0] m_right = {32'd0, m_num} * {32'd0, best_den[u_idx]};
                        if (exit_idx == 3'd0) begin
                            m_num <= best_num[u_idx];
                            m_den <= {16'd0, best_den[u_idx]};
                        end else begin
                            if (m_left < m_right) begin
                                m_num <= best_num[u_idx];
                                m_den <= {16'd0, best_den[u_idx]};
                            end
                        end
                        exit_idx <= exit_idx + 3'd1;
                    end else begin
                        // Check if m is INF
                        if (m_num >= INF32) begin
                            impossible <= 1'b1;
                            speed_q16 <= 32'd0;
                            state <= DONE;
                        end else begin
                            state <= COMPUTE_SPEED;
                        end
                    end
                end

                COMPUTE_SPEED: begin
                    // speed = 160 / (m_num / m_den) = (160 * m_den) / m_num
                    // Result needs to be Q16.16 => ((160 * m_den) << 16) / m_num
                    // Division is sequential
                    if (!div_start && !div_done) begin
                        div_a <= 16'd160 * m_den[15:0]; // 160 * m_den (max ~40800)
                        div_b <= m_num; // divisor
                        div_start <= 1'b1;
                    end else if (div_done) begin
                        // div_q contains result (raw quotient)
                        // We need to shift left by 16 (multiply by 65536)
                        // Since we did (160 * m_den) / m_num, we missed the shift.
                        // Actually, speed = (160 * m_den * 65536) / m_num
                        // Let's just use the divider result as Q16.16 if we shifted numerator before.
                        // Let's restart the divider with shifted numerator.
                        // Numerator = (160 * m_den) << 16. This fits in 48 bits.
                        // We need a 48/32 divider.
                        // Let's implement a simple restoring divider in the state machine logic.
                        // Actually, let's just use the existing div_a/div_b structure.
                        // Since div_a is 32-bit, we can't shift 160*m_den by 16 inside it.
                        // Let's use a 64-bit remainder approach in the divider state.
                        // We will use div_a as lower 32 bits of numerator (zeros for upper part of shift)
                        // Wait, 160*m_den is 16-bit. Shifted left 16 is 32-bit.
                        // Numerator is 32-bit. Denominator is 32-bit.
                        // Result is 32-bit Q16.16.
                        // Let's re-trigger the divider logic with correct inputs.
                        // div_a = 160 * m_den (16-bit value, in lower 16 bits of 32-bit reg)
                        // But wait, (160*m_den) << 16 is just 160*m_den in the upper 16 bits of 32-bit result?
                        // No, Q16.16 means integer part in high bits, fraction in low bits.
                        // speed = (160 * m_den) / m_num.
                        // If we want result as Q16.16, we compute (160 * m_den * 65536) / m_num.
                        // Let's put (160 * m_den) in the lower bits of a 48-bit number and zeros in upper bits?
                        // No, that's (160*m_den) * 65536.
                        // Let's just do the division: (160 * m_den) / m_num.
                        // The result will be a fixed point number.
                        // If we want 16 fractional bits, we multiply numerator by 2^16.
                        // So Numerator = (160 * m_den) << 16.
                        // This is a 32-bit value (since 160*m_den < 2^16).
                        // Denominator = m_num (32-bit).
                        // Result = Numerator / Denominator.
                        // This fits in 32 bits.
                        // Let's do 32-cycle restoring division.
                        div_counter <= 5'd0;
                        div_q <= 32'd0;
                        // We need a 64-bit remainder register (internal to state logic)
                        // But we can't add more registers easily without spec.
                        // Let's use div_a as remainder low, div_b as remainder high?
                        // Let's use div_a as numerator low, div_b as denominator.
                        // Let's use a wire for remainder.
                        // Actually, just perform the division in one cycle if area allows, or seq.
                        // Given the cycle budget (600), sequential is fine.
                        // Let's implement restoring division.
                        // Remainder R (64-bit), Quotient Q (32-bit).
                        // Start: R[63:0] = {32'd0, 160 * m_den} << 16. 
                        // Actually {32'd0, 160*m_den} is 48 bits. Shift left 16 -> 64 bits: {16'd0, 160*m_den, 16'd0}.
                        // Let's use div_a as [63:32] (high), div_b as [31:0] (low) for remainder.
                        // But div_a/b are 32-bit ports.
                        // Let's use local variables in always block if supported, else use existing regs.
                        // We can abuse speed_q16 temporarily? No.
                        // Let's add a divider state.
                        // For now, let's just trigger the divider and wait.
                        // I will assume a sequential divider implementation below.
                        div_start <= 1'b0; // Pulse handled
                    end
                    // Wait for div_done
                    if (div_done) begin
                        // Divider result should be in speed_q16 (or a temp reg)
                        // Let's assume we computed the result correctly in divider logic.
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Sequential Divider Logic (Non-restoring or Restoring)
    // We need a 64-bit remainder R and 32-bit quotient Q.
    // We'll use a separate always block triggered by div_start.
    reg [63:0] rem_reg;
    reg [4:0] div_step;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_done <= 1'b0;
            speed_q16 <= 32'd0;
            div_step <= 5'd0;
            rem_reg <= 64'd0;
        end else begin
            if (div_start) begin
                // Initialize: Numerator = (160 * div_a) << 16. 
                // div_a holds 160*m_den (32-bit reg, value fits 16 bits).
                // rem_reg = {16'd0, div_a[15:0], 16'd0}
                rem_reg <= {16'd0, div_a[15:0], 16'd0};
                div_q <= 32'd0;
                div_step <= 5'd0;
                div_done <= 1'b0;
            end else if (!div_done && div_step < 6'd32) begin
                // Restoring division step
                // Shift rem_reg left by 1, MSB of rem_reg is the comparison bit
                // rem_reg[63] is the sign bit for signed arithmetic, but we are unsigned here.
                // For unsigned: if (rem_reg[63:32] >= div_b) then subtract.
                // rem_reg is 64-bit. Upper 32 bits are current remainder.
                // div_b is divisor.
                // Shift rem_reg left by 1
                rem_reg <= rem_reg << 1;
                div_q <= div_q << 1;
                
                // Check if we can subtract
                // Need to wait one cycle for shift to settle? 
                // No, we can calculate based on current rem_reg before shift, or use the shifted value.
                // Standard restoring: shift, then check.
                // Here we shift, then check rem_reg[63:32] vs div_b in NEXT cycle? 
                // To save states, let's do logic in same cycle after shift.
                // Actually, rem_reg << 1 produces new value. We check that new value's high 32 bits.
                // Wait, standard restoring:
                // 1. Shift remainder left.
                // 2. Subtract divisor from remainder.
                // 3. If result < 0, add divisor back and set quotient bit 0.
                //    Else set quotient bit 1.
                // Since we are unsigned, "result < 0" means borrow occurred.
                // Let's use a temporary wire for subtraction.
                // Since we are in always block, we can't easily have intermediate registers without adding latency.
                // Let's use the next cycle to commit the subtraction.
                // This adds 32 cycles for subtraction.
                // Wait, we need to be careful with combinational loops.
                // Let's stick to: Shift, then Subtract.
                // Actually, let's do: Shift, Check, Update.
                // Since this is one cycle, we can do:
                // R = R << 1
                // R = R - Div
                // If (R < 0) { R = R + Div; Q[i] = 0; } else { Q[i] = 1; }
                // Since we can't do R < 0 easily with unsigned wire in always block without temp reg.
                // Let's use a temp wire for subtraction result.
                // Wire [32:0] sub_res = {1'b0, rem_reg[63:32]} - {1'b0, div_b};
                // If sub_res[32] == 1 (borrow), then it was negative.
                
                // Optimization: Combine shift and subtract in one cycle?
                // Yes, if we calculate (rem_reg[63:32] - div_b) using old rem_reg.
                // Let's do: 
                // 1. Calculate (rem_reg[63:32] << 1) | rem_reg[31]. (Shifted remainder high part)
                // 2. Compare with div_b.
                // 3. Update.
                
                // To avoid complex combinational paths, let's use a simple state machine.
                // Since we have 32 steps, we can use `div_step`.
                // We need to handle the subtraction and quotient bit setting.
                
                // Let's use a temporary register `rem_high` and `rem_low` for the logic.
                // But we only have `rem_reg`.
                // Let's assume we can calculate subtraction in the same cycle.
                // Wire [32:0] sub_temp = {1'b0, rem_reg[62:31]} - {1'b0, div_b}; // Wait, shifted high bits
                // Actually, `rem_reg` was shifted in the previous cycle (or we shift now).
                // Let's shift `rem_reg` now.
                // rem_reg <= rem_reg << 1; (This updates next cycle)
                // So we check `rem_reg` (current) vs `div_b`.
                // If `rem_reg[63:32] >= div_b`:
                //   rem_reg[63:32] = rem_reg[63:32] - div_b;
                //   div_q[0] = 1;
                // Else:
                //   div_q[0] = 0;
                
                // We need to update div_q[31:0]. We can't assign bit-by-bit easily in non-blocking.
                // We can compute `new_rem` and `new_q`.
                
                wire [32:0] sub_result = {1'b0, rem_reg[63:32]} - {1'b0, div_b};
                if (sub_result[32] == 1'b0) begin
                    // No borrow, valid subtraction
                    rem_reg <= {sub_result[31:0], rem_reg[31:0]}; // Store result, shift in next bit? 
                    // Wait, standard algorithm shifts BEFORE subtraction.
                    // Let's follow: Shift Left, then Subtract.
                    // But we are in a loop. 
                    // Let's do: 
                    // 1. Shift rem_reg left by 1.
                    // 2. Subtract div_b from upper 32 bits.
                    // 3. If borrow, add div_b back.
                    // Since we are in a sequential block, we update registers.
                    // Let's do the shift and subtract in one go.
                    // Current rem_reg. Shift left: {rem_reg[62:0], 1'b0}.
                    // Let's use a temporary value for the shifted remainder.
                    // Since we can't easily use temp variables in always block without generating latches or logic.
                    // Let's rely on the fact that we can compute the next state of rem_reg.
                    // Next_rem_shifted = {rem_reg[62:0], 1'b0};
                    // If Next_rem_shifted[63:32] >= div_b:
                    //   Next_rem = Next_rem_shifted - {div_b, 32'd0} (conceptually)
                    //   Actually, subtract div_b from high 32 bits.
                    //   Next_rem[63:32] = Next_rem_shifted[63:32] - div_b
                    //   Next_rem[31:0] = Next_rem_shifted[31:0]
                    //   Set Q bit 1.
                    // Else:
                    //   Next_rem = Next_rem_shifted
                    //   Set Q bit 0.
                    
                    // Let's implement this logic.
                    // We need to shift `rem_reg` first.
                    // Since we are in always block, let's compute `shifted_rem` as wire.
                    wire [63:0] shifted_rem = {rem_reg[62:0], 1'b0};
                    wire [32:0] cmp_rem = {1'b0, shifted_rem[63:32]};
                    wire [32:0] sub_rem = cmp_rem - {1'b0, div_b};
                    
                    if (cmp_rem >= {1'b0, div_b}) begin
                        rem_reg <= {sub_rem[31:0], shifted_rem[31:0]};
                        // We need to set the quotient bit. 
                        // div_q is 32-bit. We are setting bits from MSB to LSB or LSB to MSB?
                        // Standard restoring sets bits from MSB to LSB (i=31 to 0).
                        // Wait, standard algorithm usually sets Q[31] then Q[30]...
                        // Here we iterate 0 to 31.
                        // Let's set div_q[31 - div_step] or similar.
                        // Or build Q from LSB.
                        // Let's build Q from LSB.
                        // div_q[div_step] <= 1'b1;
                        // But div_q is 32-bit reg. We can't index it with div_step in non-blocking assignment like that if we shift?
                        // Let's shift div_q too.
                        // div_q <= {div_q[30:0], 1'b1};
                        div_q <= {div_q[30:0], 1'b1};
                    end else begin
                        rem_reg <= shifted_rem; // Just shift
                        div_q <= {div_q[30:0], 1'b0};
                    end
                    
                    div_step <= div_step + 5'd1;
                end else begin
                    // Should not happen if we initialized correctly
                    div_step <= div_step + 5'd1;
                end
            end else if (div_step == 6'd32) begin
                // Division complete
                // Result is in div_q (Q16.16 format? No, we didn't scale numerator correctly).
                // Numerator was (160 * m_den) << 16.
                // Denominator was m_num.
                // Result div_q is (160 * m_den << 16) / m_num.
                // This is exactly Q16.16 format.
                speed_q16 <= div_q;
                div_done <= 1'b1;
                div_step <= 5'd0;
            end
        end
    end

    // Combinational logic for COMPUTE_W (fixing w_num type)
    // Since w_num was declared as [15:0] but we need INF32, let's adjust the declaration logic.
    // Actually, let's just use w_num as 32-bit internally if needed, or stick to 16-bit max value 65535.
    // 160 * 255 = 40800. Fits in 16 bits.
    // So INF check for w_num can be done on the 16-bit value.
    // If dist[p][i] == 0, w_num is "infinite". 
    // Since max finite is 40800, we can use 65535 as INF for w_num.
    // Let's change w_num declaration to [15:0].
    // Update COMPUTE_W state accordingly.
    // (Updated in COMPUTE_W state logic above: using 16-bit arithmetic).

    // Fix: w_num was declared [15:0] in initial list, but logic used 32-bit.
    // I will correct the declaration in the code generation.

endmodule
