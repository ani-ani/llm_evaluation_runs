module maximal_factoring (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input [4:0] str_len,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 16;
    
    // Internal memory for string
    reg [7:0] string [0:15];
    
    // DP memory: dp[i][j] stored in flattened array
    // Index: i*16 + j, where i and j are 4-bit (0-15)
    reg [7:0] dp [0:255];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam INIT_DP = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam OUTPUT = 3'b100;
    localparam WAIT = 3'b101;
    
    reg [2:0] state;
    
    // Counters and indices
    reg [4:0] load_cnt;
    reg [3:0] init_i; // 4-bit counter for initialization
    reg [3:0] len_l;  // Current substring length L (1-16)
    reg [3:0] sub_i;  // Starting position i for current length
    reg [3:0] split_k; // Split position k
    reg [3:0] period_p; // Period p
    
    // Temporary registers for computation
    reg [7:0] current_min;
    reg [7:0] temp_val;
    reg [7:0] temp_sum;
    reg [3:0] temp_j;
    reg do_repeat_check;
    reg [3:0] rem; // remainder for period check
    reg repeat_match;
    reg [7:0] char_ref;
    reg [7:0] char_curr;
    
    // Counter for latency tracking (optional, for 5000 cycles)
    // We will use state machine to ensure sufficient cycles
    reg [12:0] cycle_cnt; // 5000 < 2^13 = 8192
    
    integer k_idx;
    integer p_idx;
    integer offset;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            load_cnt <= 0;
            init_i <= 0;
            len_l <= 2;
            sub_i <= 0;
            split_k <= 0;
            period_p <= 1;
            cycle_cnt <= 0;
            do_repeat_check <= 0;
            // Reset string (optional but good practice)
            // synthesis translate_off
            integer r;
            for (r = 0; r < 16; r = r + 1) string[r] <= 8'h00;
            // synthesis translate_on
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    load_cnt <= 0;
                    init_i <= 0;
                    len_l <= 2;
                    sub_i <= 0;
                    split_k <= 0;
                    period_p <= 1;
                    cycle_cnt <= 0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    if (valid_in) begin
                        string[load_cnt] <= char_in;
                        load_cnt <= load_cnt + 1;
                    end
                    // If load_cnt reaches 16 or valid_in stops, we wait for logic
                    // We need to fill all 16 positions. If string is shorter, rest is undefined.
                    // Requirement says: "Fill remaining positions with nulls".
                    // We assume valid_in is asserted exactly str_len times.
                    // If load_cnt < 16 after str_len inputs, we need to fill.
                    // However, standard FSM waits for count.
                    // Let's simply count 16 cycles. 
                    if (load_cnt == 15 && valid_in) begin // Last char loaded next cycle
                        // We can transition next cycle
                    end
                    if (load_cnt >= 15 && !valid_in && load_cnt < 16) begin
                        // Padding with nulls if input stopped
                        string[load_cnt] <= 8'h00;
                        load_cnt <= load_cnt + 1;
                    end
                    if (load_cnt == 16) begin
                        state <= INIT_DP;
                        load_cnt <= 0;
                    end
                end

                INIT_DP: begin
                    // dp[i][i] = 1 for i < str_len
                    // We iterate i from 0 to 15. Only effective for i < str_len.
                    // But we fill entire first band for simplicity.
                    if (init_i < 16) begin
                        if (init_i < str_len) begin
                            dp[init_i * 16 + init_i] <= 8'd1;
                        end else begin
                            dp[init_i * 16 + init_i] <= 8'd0; // Optional
                        end
                        init_i <= init_i + 1;
                    end else begin
                        state <= COMPUTE;
                        len_l <= 2;
                        sub_i <= 0;
                        // We need to ensure we respect str_len
                        if (str_len < 2) begin
                            state <= OUTPUT; // Edge case: length 0 or 1
                            if (str_len == 1) result <= 1;
                            else result <= 0;
                        end
                    end
                end

                COMPUTE: begin
                    // Main DP Loop
                    // Algorithm:
                    // for L = 2 to str_len
                    //   for i = 0 to str_len - L
                    //     dp[i][i+L-1] = L
                    //     for k = i to i+L-2 -> dp[i][i+L-1] = min(dp[i][i+L-1], dp[i][k] + dp[k+1][i+L-1])
                    //     for p = 1 to L/2 -> if (L%p==0 && repeat) dp[i][i+L-1] = min(..., dp[i][i+p-1])
                    
                    // State implementation breakdown to fit timing/area
                    // We use 'do_repeat_check' flag to switch between split and repeat logic
                    
                    if (len_l <= str_len) begin
                        if (sub_i <= str_len - len_l) begin
                            // Logic for dp[sub_i][sub_i+len_l-1]
                            
                            if (split_k < sub_i + len_l - 1) begin
                                // SPLIT CHECK phase
                                temp_j <= sub_i + len_l - 1;
                                current_min <= len_l; // Initialize with literal weight (L)
                                
                                // We need to compare dp[sub_i][split_k] + dp[split_k+1][sub_i+len_l-1]
                                // Read operands
                                temp_sum <= dp[sub_i * 16 + split_k] + dp[(split_k + 1) * 16 + (sub_i + len_l - 1)];
                                
                                // Update min logic
                                if (split_k == sub_i) begin
                                    // First iteration, just set min
                                    current_min <= dp[sub_i * 16 + split_k] + dp[(split_k + 1) * 16 + (sub_i + len_l - 1)];
                                end else begin
                                    // Compare and update
                                    if (temp_sum < current_min) begin
                                        current_min <= temp_sum;
                                    end
                                end
                                
                                split_k <= split_k + 1;
                            end else if (period_p <= (len_l >> 1)) begin
                                // PERIOD CHECK phase (only if split is done)
                                // Only start this if we are not in the middle of splits
                                if (split_k == sub_i + len_l - 1) begin
                                    // Just finished splits, check if current_min is already 1? (Optimization skip)
                                    // But we must do repeats.
                                end
                                
                                // Perform check: L % p == 0
                                rem = len_l % period_p; // Combinational logic
                                
                                if (rem == 0) begin
                                    // Check repetition
                                    // Substring s[sub_i ... sub_i+len_l-1] must repeat with period p
                                    // s[sub_i + t] == s[sub_i + t % p] for t=1..L-1
                                    // We can check this sequentially or in one go.
                                    // Given constraints, let's do it sequentially or use a helper state.
                                    // To save states, we'll do it partially here.
                                    
                                    // Check loop
                                    // We need to compare all characters.
                                    // Let's use 'offset' for the iteration of the repetition check.
                                    // But wait, we are inside a clocked block. 
                                    // We need to perform the check over multiple cycles or combinationally.
                                    // Combinational check for L<=16 is fine (256 comparisons max).
                                    
                                    repeat_match = 1;
                                    for (int t = 0; t < len_l; t = t + 1) begin
                                        if (string[sub_i + t] != string[sub_i + (t % period_p)]) begin
                                            repeat_match = 0;
                                        end
                                    end
                                    
                                    if (repeat_match) begin
                                        temp_val <= dp[sub_i * 16 + (sub_i + period_p - 1)];
                                        // Update min immediately in this cycle? 
                                        // No, we need to compare with current_min (which holds split result)
                                        if (dp[sub_i * 16 + (sub_i + period_p - 1)] < current_min) begin
                                            current_min <= dp[sub_i * 16 + (sub_i + period_p - 1)];
                                        end
                                    end
                                end
                                
                                period_p <= period_p + 1;
                            end else begin
                                // Finished all checks for this (i, L)
                                // Write back result
                                dp[sub_i * 16 + (sub_i + len_l - 1)] <= current_min;
                                
                                // Reset counters for next i
                                sub_i <= sub_i + 1;
                                split_k <= sub_i + 1; // Reset for next i (actually sub_i+1)
                                period_p <= 1;
                            end
                        end else begin
                            // Finished all i for current L
                            len_l <= len_l + 1;
                            sub_i <= 0;
                            split_k <= 0;
                            period_p <= 1;
                        end
                    end else begin
                        // Finished all L
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Check for str_len == 0 case
                    if (str_len == 0) result <= 0;
                    else result <= dp[0 * 16 + (str_len - 1)];
                    done <= 1;
                    state <= WAIT;
                end

                WAIT: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
