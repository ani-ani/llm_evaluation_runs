module MaximalFactoring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] string_in [0:15],
    input wire [4:0] length_in,
    output reg [4:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] LOAD           = 3'd1;
    localparam [2:0] INIT           = 3'd2;
    localparam [2:0] MAIN_LOOP      = 3'd3;
    localparam [2:0] COMPUTE_SPLIT  = 3'd4;
    localparam [2:0] CHECK_REPETITION=3'd5;
    localparam [2:0] UPDATE_DP      = 3'd6;
    localparam [2:0] DONE_STATE     = 3'd7;

    reg [2:0] state, next_state;
    reg [7:0] str [0:15]; // Internal string storage
    reg [4:0] n;          // Length register
    reg [4:0] L_reg;       // Current substring length
    reg [3:0] i_reg;       // Start index
    reg [3:0] k_reg;       // Split index
    reg [3:0] d_reg;       // Divisor
    reg [3:0] r_reg;       // Repetition counter
    reg [3:0] p_reg;       // Period repetition counter
    reg [3:0] counter;     // General relative pos counter
    
    reg [4:0] min_val;    // Computed minimal value
    reg [4:0] temp_sum;   // Temporary sum register
    reg [4:0] current_dp; // Current dp value
    reg [7:0] dp_index;   // Index for dp memory
    
    reg [4:0] dp[0:255];  // DP memory 16x16 -> 256 entries
    reg period_match;     // Flag for periodic match
    
    integer idx; // For-loop integer

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize ALL registers
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            L_reg <= 5'd0;
            i_reg <= 4'd0;
            k_reg <= 4'd0;
            d_reg <= 4'd0;
            r_reg <= 4'd0;
            p_reg <= 4'd0;
            counter <= 4'd0;
            min_val <= 5'd0;
            temp_sum <= 5'd0;
            current_dp <= 5'd0;
            dp_index <= 8'd0;
            period_match <= 1'b0;
            // Initialize dp memory
            for (idx = 0; idx < 256; idx = idx + 1) begin
                dp[idx] <= 5'd0;
            end
            // Initialize str memory
            for (idx = 0; idx < 16; idx = idx + 1) begin
                str[idx] <= 8'd0;
            end
            n <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load string_in into str
                    for (idx = 0; idx < 16; idx = idx + 1) begin
                        str[idx] <= string_in[idx];
                    end
                    n <= length_in;
                    next_state <= INIT;
                end
                
                INIT: begin
                    dp_index <= {4'd0, 4'd0};  // dp[0][0]
                    dp[dp_index] <= 5'd1;      // Initialize dp[i][i] = 1
                    
                    i_reg <= i_reg + 4'd1;
                    if (i_reg < 4'd15) begin
                        dp_index <= {i_reg + 4'd1, i_reg + 4'd1};
                        next_state <= INIT;
                    end else begin
                        i_reg <= 4'd0;
                        L_reg <= 5'd2;
                        next_state <= MAIN_LOOP;
                    end
                end
                
                MAIN_LOOP: begin
                    if (L_reg > n) begin
                        // All substrings processed
                        next_state <= DONE_STATE;
                    end else begin
                        if (i_reg > (n - L_reg[4:0])) begin
                            // Move to next L
                            L_reg <= L_reg + 5'd1;
                            i_reg <= 4'd0;
                            next_state <= MAIN_LOOP;
                        end else begin
                            // Compute current j = i + L - 1
                            min_val <= 5'd31; // Safe max value (16 * 2 approx)
                            
                            // Start split computations
                            k_reg <= i_reg;
                            next_state <= COMPUTE_SPLIT;
                        end
                    end
                end
                
                COMPUTE_SPLIT: begin
                    if (k_reg < (i_reg + L_reg[4:0] - 4'd1)) begin
                        dp_index <= {i_reg, k_reg};
                        // Get dp[i][k] (read in next state)
                        next_state <= COMPUTE_SPLIT_READ1;
                    end else begin
                        // Switch to check repetition
                        d_reg <= 4'd1;
                        next_state <= CHECK_REPETITION;
                    end
                end
                
                // Additional states for memory read latency
                COMPUTE_SPLIT_READ1: begin
                    current_dp <= dp[dp_index];
                    dp_index <= {k_reg + 4'd1, i_reg + L_reg[4:0] - 4'd1};
                    next_state <= COMPUTE_SPLIT_READ2;
                end
                
                COMPUTE_SPLIT_READ2: begin
                    temp_sum <= current_dp + dp[dp_index];
                    next_state <= COMPUTE_SPLIT_UPDATE;
                end
                
                COMPUTE_SPLIT_UPDATE: begin
                    if (temp_sum < min_val) begin
                        min_val <= temp_sum;
                    end
                    k_reg <= k_reg + 4'd1;
                    next_state <= COMPUTE_SPLIT;
                end
                
                CHECK_REPETITION: begin
                    if (d_reg > (L_reg[4:0] >> 1)) begin
                        // All divisors checked, update dp
                        dp_index <= {i_reg, i_reg + L_reg[4:0] -4'd1};
                        next_state <= UPDATE_DP;
                    end else begin
                        if (L_reg % d_reg == 0) begin
                            // Check repetitions
                            p_reg <= 4'd1;
                            period_match <= 1'b1;
                            r_reg <= 4'd0;
                            next_state <= CHECK_PERIODIC;
                        end else begin
                            d_reg <= d_reg + 4'd1;
                            next_state <= CHECK_REPETITION;
                        end
                    end
                end
                
                CHECK_PERIODIC: begin
                    if (r_reg < d_reg) begin
                        if (!period_match) begin
                            p_reg <= 4'd0; // Skip rest
                            r_reg <= d_reg; // Exit loop
                            next_state <= CHECK_PERIODIC_P;
                        end else begin
                            counter <= r_reg + p_reg * d_reg;
                            if (str[i_reg + r_reg] != str[i_reg + r_reg + p_reg * d_reg]) begin
                                period_match <= 1'b0;
                            end
                            p_reg <= p_reg + 4'd1;
                            next_state <= CHECK_PERIODIC_LEN;
                        end
                    end else begin
                        next_state <= CHECK_PERIODIC_P;
                    end
                end
                
                CHECK_PERIODIC_LEN: begin
                    if (p_reg >= (L_reg / d_reg)) begin
                        r_reg <= r_reg + 4'd1;
                        next_state <= CHECK_PERIODIC;
                    end else begin
                        next_state <= CHECK_PERIODIC;
                    end
                end
                
                CHECK_PERIODIC_P: begin
                    if (period_match) begin
                        dp_index <= {i_reg, i_reg + d_reg - 4'd1};
                        next_state <= CHECK_REPETITION_READ;
                    end else begin
                        d_reg <= d_reg + 4'd1;
                        next_state <= CHECK_REPETITION;
                    end
                end
                
                CHECK_REPETITION_READ: begin
                    temp_sum <= dp[dp_index];
                    if (temp_sum < min_val) begin
                        min_val <= temp_sum;
                    end
                    d_reg <= d_reg + 4'd1;
                    next_state <= CHECK_REPETITION;
                end
                
                UPDATE_DP: begin
                    dp[dp_index] <= min_val;
                    i_reg <= i_reg + 4'd1;
                    next_state <= MAIN_LOOP;
                end
                
                DONE_STATE: begin
                    dp_index <= {4'd0, n[3:0] - 4'd1};
                    next_state <= DONE_STATE_READ;
                end
                
                DONE_STATE_READ: begin
                    result <= dp[dp_index];
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // State transition (combinational)
    always @* begin
        case (state)
            IDLE: if (start) next_state = LOAD; else next_state = IDLE;
            // Other transitions handled in sequential block
            default: next_state = state;
        endcase
    end

endmodule