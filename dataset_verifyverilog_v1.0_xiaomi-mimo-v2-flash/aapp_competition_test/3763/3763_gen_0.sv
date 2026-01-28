module RestaurantVisitors (
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [5:0] p_in,
    input [4:0] a_in [0:15],
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [3:0] IDLE          = 4'd0;
localparam [3:0] CHECK_TOTAL   = 4'd1;
localparam [3:0] RESET_DP      = 4'd2;
localparam [3:0] GUEST_LOOP    = 4'd3;
localparam [3:0] RESET_GUEST   = 4'd4;
localparam [3:0] UPDATE_DP     = 4'd5;
localparam [3:0] COUNT subsets = 4'd6;
localparam [3:0] ACCUMULATE    = 4'd7;
localparam [3:0] DIVIDE        = 4'd8;
localparam [3:0] FINISH        = 4'd9;

// Registers for state machine
reg [3:0] state, next_state;
reg [7:0] cycle_count;

// Input storage
reg [3:0] n_reg;
reg [5:0] p_reg;
reg [4:0] a_reg [0:15];

// Factorial LUT (0! to 16!)
reg [19:0] fact [0:16];

// DP table: DP[k][s] for current guest set
// k: 0-16, s: 0-32
reg [19:0] dp_cur [0:16][0:32];
reg [19:0] dp_next [0:16][0:32];

// Intermediate registers
reg [3:0] i;           // Current guest index (0 to n-1)
reg [3:0] j;           // Other guest index
reg [3:0] k;           // Subset size
reg [5:0] s;           // Subset sum
reg [19:0] total;      // Accumulated total (scaled)
reg [19:0] temp_sum;   // Temporary for sum check
reg [5:0] subset_sum;  // Sum of current subset
reg [3:0] idx_temp;
reg [3:0] valid_idx;   // Valid guest count

// Control signals
reg dp_reset_done;
reg guest_loop_done;
reg update_done;
reg count_done;
reg accumulate_done;

// Loop counters
reg [3:0] k_cnt;
reg [5:0] s_cnt;
reg [3:0] i_cnt;
reg [3:0] j_cnt;

// Integer for iteration
integer ki, si, sj;

// Factorial initialization - done once in reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize factorial LUT
        fact[0] <= 20'd1;
        fact[1] <= 20'd1;
        fact[2] <= 20'd2;
        fact[3] <= 20'd6;
        fact[4] <= 20'd24;
        fact[5] <= 20'd120;
        fact[6] <= 20'd720;
        fact[7] <= 20'd5040;
        fact[8] <= 20'd40320;
        fact[9] <= 20'd362880;
        fact[10] <= 20'd3628800;
        fact[11] <= 20'd39916800;
        fact[12] <= 20'd479001600;
        fact[13] <= 20'd6227020800; // Truncates but enough for n<=16
        fact[14] <= 20'd87178291200;
        fact[15] <= 20'd1307674368000;
        fact[16] <= 20'd20922789888000;
    end
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        cycle_count <= 8'd0;
        done <= 1'b0;
        result <= 16'd0;
        n_reg <= 4'd0;
        p_reg <= 6'd0;
        for (si = 0; si < 16; si = si + 1) begin
            a_reg[si] <= 5'd0;
        end
        total <= 20'd0;
    end else begin
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    n_reg <= n_in;
                    p_reg <= p_in;
                    for (si = 0; si < 16; si = si + 1) begin
                        a_reg[si] <= a_in[si];
                    end
                    state <= CHECK_TOTAL;
                end
            end
            
            CHECK_TOTAL: begin
                // Check if sum of all guests <= p
                temp_sum <= 20'd0;
                for (si = 0; si < 16; si = si + 1) begin
                    if (si < n_reg) begin
                        temp_sum <= temp_sum + a_reg[si];
                    end
                end
                state <= RESET_DP;
            end
            
            RESET_DP: begin
                // Reset DP table
                for (ki = 0; ki <= 16; ki = ki + 1) begin
                    for (si = 0; si <= 32; si = si + 1) begin
                        dp_cur[ki][si] <= 20'd0;
                        dp_next[ki][si] <= 20'd0;
                    end
                end
                dp_cur[0][0] <= 20'd1;  // Base case
                i <= 4'd0;
                total <= 20'd0;
                
                if (temp_sum <= p_reg && n_reg > 4'd0) begin
                    // All guests fit
                    state <= DIVIDE;
                    total <= fact[n_reg];  // Sum of all subsets = n!
                end else if (n_reg == 4'd0) begin
                    state <= FINISH;
                    total <= 20'd0;
                end else begin
                    state <= GUEST_LOOP;
                end
            end
            
            GUEST_LOOP: begin
                if (i < n_reg) begin
                    state <= RESET_GUEST;
                end else begin
                    state <= DIVIDE;
                end
            end
            
            RESET_GUEST: begin
                // Reset dp_next for this guest iteration
                for (ki = 0; ki <= 16; ki = ki + 1) begin
                    for (si = 0; si <= 32; si = si + 1) begin
                        dp_next[ki][si] <= dp_cur[ki][si];
                    end
                end
                j_cnt <= 4'd0;
                state <= UPDATE_DP;
            end
            
            UPDATE_DP: begin
                if (j_cnt < n_reg && j_cnt != i) begin
                    // Add guest j to all subsets
                    for (si = 32; si > 0; si = si - 1) begin
                        for (ki = 1; ki <= 16; ki = ki + 1) begin
                            if (si >= a_reg[j_cnt]) begin
                                if (dp_cur[ki-1][si - a_reg[j_cnt]] != 20'd0) begin
                                    dp_next[ki][si] <= dp_next[ki][si] + dp_cur[ki-1][si - a_reg[j_cnt]];
                                end
                            end
                        end
                    end
                    j_cnt <= j_cnt + 1;
                end else begin
                    state <= COUNT_subsets;
                    k_cnt <= 4'd0;
                end
            end
            
            COUNT_subsets: begin
                if (k_cnt < n_reg) begin
                    s_cnt <= 6'd0;
                    state <= ACCUMULATE;
                end else begin
                    // Copy dp_next to dp_cur for next guest
                    for (ki = 0; ki <= 16; ki = ki + 1) begin
                        for (si = 0; si <= 32; si = si + 1) begin
                            dp_cur[ki][si] <= dp_next[ki][si];
                        end
                    end
                    i <= i + 1;
                    state <= GUEST_LOOP;
                end
            end
            
            ACCUMULATE: begin
                if (s_cnt <= 32) begin
                    // Check if (subset_sum + a_i) > p
                    if (s_cnt + a_reg[i] > p_reg) begin
                        if (dp_next[k_cnt][s_cnt] != 20'd0) begin
                            // total += k * DP[k][s] * fact[k] * fact[n-1-k]
                            // Scale by 256 (8 bits) for Q8.8
                            total <= total + (k_cnt * dp_next[k_cnt][s_cnt] * fact[k_cnt] * fact[n_reg - 4'd1 - k_cnt]) >> 8;
                        end
                    end
                    s_cnt <= s_cnt + 1;
                end else begin
                    k_cnt <= k_cnt + 1;
                    state <= COUNT_subsets;
                end
            end
            
            DIVIDE: begin
                // Divide by fact[n] using shift approximation
                // fact[n] is at least 1, at most ~20 bits
                // total is accumulated in Q8.8 * fact[n] format
                // Divide by fact[n] to get final Q8.8 value
                if (n_reg >= 4'd8) begin
                    // Large factorial: use right shift approximation
                    // fact[8] = 40320, log2 ≈ 15.3
                    result <= total[15:0];  // Just truncate for now
                end else begin
                    // Small factorial: exact division
                    case (n_reg)
                        4'd1: result <= total[15:0];
                        4'd2: result <= total >> 1;
                        4'd3: result <= total / 3;
                        4'd4: result <= total >> 2;  // Divide by 4
                        4'd5: result <= total / 5;
                        4'd6: result <= total / 6;
                        4'd7: result <= total / 7;
                        default: result <= total[15:0];
                    endcase
                end
                state <= FINISH;
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