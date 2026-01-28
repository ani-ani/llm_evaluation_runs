module coin_ways (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [7:0][31:0] a,
    input wire [7:0][15:0] b,
    input wire [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_CYCLES = 32'd1000;
    
    // State registers
    reg [2:0] state, next_state;
    reg [31:0] cycle_count;
    
    // DP registers for hierarchical computation
    reg [31:0] dp[0:15];  // Current DP array (for one denomination level)
    reg [31:0] dp_next[0:15];  // Next DP array
    reg [31:0] dp_temp[0:15];  // Temporary for hierarchical computation
    
    // Index registers
    reg [3:0] i, j, k;  // Loop counters
    reg [3:0] num_coins;  // Number of coins for current type
    reg [31:0] denom;  // Denomination value (scaled)
    reg [31:0] denom_next;  // Next denomination
    reg [31:0] ratio;  // Current ratio a_k
    
    // Computation registers
    reg [31:0] ways;  // Accumulate ways
    reg [31:0] temp_add, temp_sub;
    
    // Helper signals for computation steps
    reg [1:0] comp_step;  // Computation sub-state
    reg [31:0] target_amount;
    
    integer idx;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;
            // Initialize all DP arrays
            for (idx = 0; idx < 16; idx = idx + 1) begin
                dp[idx] <= 32'd0;
                dp_next[idx] <= 32'd0;
                dp_temp[idx] <= 32'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            comp_step <= 2'd0;
            target_amount <= 32'd0;
            ways <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    cycle_count <= 32'd0;
                    done <= 1'b0;
                    result <= 32'd0;
                    ways <= 32'd0;
                    comp_step <= 2'd0;
                    if (start) begin
                        // Initialize DP for first denomination
                        for (idx = 0; idx < 16; idx = idx + 1) begin
                            dp[idx] <= 32'd0;
                            dp_next[idx] <= 32'd0;
                            dp_temp[idx] <= 32'd0;
                        end
                        dp[0] <= 32'd1;  // Base case: 0 amount has 1 way
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        target_amount <= m;
                    end
                end
                
                INIT: begin
                    // Initialize for first coin type
                    // Compute initial denomination (scaled to avoid overflow)
                    // For type 0: denom = 1 (scaled)
                    // For type k: denom = product of a[0]...a[k-1]
                    denom <= 32'd1;
                    i <= 4'd0;
                    j <= 4'd0;
                    num_coins <= b[0][3:0];  // Number of coins for type 0
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 32'd1;
                    
                    case (comp_step)
                        2'd0: begin
                            // Start processing coin type k
                            // dp represents ways using denominations up to k-1
                            // dp_temp will be updated with coins of type k
                            // Reset dp_temp to dp (ways without current coins)
                            if (j < 16) begin
                                dp_temp[j] <= dp[j];
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                comp_step <= 2'd1;
                            end
                        end
                        
                        2'd1: begin
                            // Add coins of current type using hierarchical DP
                            // For hierarchical system: each coin is a multiple of previous
                            // Use unbounded knapsack for current type
                            // dp_temp[t] += dp_temp[t - denom]
                            
                            if (i < num_coins && j < 16) begin
                                // For each coin, update dp_temp
                                // Since denominations are hierarchical, we can optimize
                                // For coin count c, we add dp[t - c*denom]
                                // Simplified: process one coin at a time
                                
                                if (j >= denom && (j - denom) < 16) begin
                                    temp_add = dp_temp[j] + dp_temp[j - denom];
                                    if (temp_add >= MOD) begin
                                        dp_temp[j] <= temp_add - MOD;
                                    end else begin
                                        dp_temp[j] <= temp_add;
                                    end
                                    j <= j + 4'd1;
                                end else begin
                                    j <= j + 4'd1;
                                end
                            end else begin
                                j <= 4'd0;
                                i <= 4'd0;
                                comp_step <= 2'd2;
                            end
                            
                            if (j >= denom && (j - denom) < 16) begin
                                // Update counter only if we processed this index
                                if (i < num_coins) begin
                                    i <= i + 4'd1;
                                end
                            end
                        end
                        
                        2'd2: begin
                            // Move dp_temp to dp for next type
                            // Also compute next denomination
                            if (j < 16) begin
                                dp[j] <= dp_temp[j];
                                j <= j + 4'd1;
                            end else begin
                                j <= 4'd0;
                                // Move to next coin type
                                if (i < n - 1) begin
                                    i <= i + 4'd1;
                                    // Compute next denomination: denom * a[i]
                                    // Handle large denominations with scaling
                                    // For hierarchical system, we track scaled values
                                    // If denom * a[i] > target, we can cap it
                                    denom_next = denom * a[i][31:0];
                                    if (denom_next > target_amount) begin
                                        // No more coins will contribute to exact amount
                                        denom <= denom_next;
                                        num_coins <= b[i + 1][3:0];
                                        comp_step <= 2'd0;
                                    end else begin
                                        denom <= denom_next;
                                        num_coins <= b[i + 1][3:0];
                                        comp_step <= 2'd0;
                                    end
                                end else begin
                                    // All types processed
                                    comp_step <= 2'd3;
                                end
                            end
                        end
                        
                        2'd3: begin
                            // Extract result for target amount m
                            if (m < 16) begin
                                ways <= dp[m];
                            end else begin
                                ways <= 32'd0;  // Amount too large for our array
                            end
                            // Finalize result
                            if (m < 16) begin
                                result <= dp[m];
                            end else begin
                                result <= 32'd0;
                            end
                        end
                    endcase
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= ways;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                if (n > 0 && m < 16) begin
                    next_state = COMPUTE;
                end else if (n == 0 || m >= 16) begin
                    next_state = FINISH;  // Invalid or unsupported input
                end
            end
            COMPUTE: begin
                if (comp_step == 2'd3) begin
                    next_state = FINISH;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;  // Timeout protection
                end
            end
            FINISH: begin
                if (!start) begin  // Wait for start to go low
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule