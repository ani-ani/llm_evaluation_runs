module AnthonyCoraGame (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    input wire [31:0] p_in,
    input wire p_valid,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [3:0] FINISH  = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] dp [0:15][0:15];  // 2D array for DP table
    reg [31:0] p_reg;
    reg [4:0] round_counter;     // 0 to 30 (N+M-2)
    reg [4:0] i_counter;         // row index
    reg [4:0] j_counter;         // column index
    reg [4:0] i_max;             // max i for current round
    reg [4:0] j_min;             // min j for current round
    reg [4:0] i_limit;           // i limit for current round
    reg [4:0] j_limit;           // j limit for current round
    reg [3:0] N_reg, M_reg;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;
    
    // Fixed-point constants
    localparam [31:0] ONE_HALF = 32'h00800000;  // 0.5 in Q16.16
    
    // Computation variables
    wire signed [63:0] term1_mult;
    wire signed [63:0] term2_mult;
    wire signed [31:0] term1;
    wire signed [31:0] term2;
    wire signed [31:0] sum;
    
    // Multipliers for fixed-point arithmetic
    assign term1_mult = p_reg * dp[i_counter][j_counter-1];
    assign term2_mult = (32'h00010000 - p_reg) * dp[i_counter-1][j_counter];
    assign term1 = term1_mult[47:16];  // Q16.16 from Q32.32
    assign term2 = term2_mult[47:16];  // Q16.16 from Q32.32
    assign sum = term1 + term2;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            round_counter <= 5'd0;
            i_counter <= 5'd0;
            j_counter <= 5'd0;
            p_reg <= 32'd0;
            N_reg <= 4'd0;
            M_reg <= 4'd0;
            cycle_count <= 16'd0;
            // Initialize DP table
            for (int r = 0; r < 16; r = r + 1) begin
                for (int c = 0; c < 16; c = c + 1) begin
                    dp[r][c] <= 32'd0;
                end
            end
        end else begin
            cycle_count <= cycle_count + 16'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        // Validate inputs
                        if (N >= 4'd1 && N <= 4'd16 && M >= 4'd1 && M <= 4'd16 && p_valid) begin
                            N_reg <= N;
                            M_reg <= M;
                            p_reg <= p_in;
                            state <= LOAD;
                        end else begin
                            error <= 1'b1;
                            done <= 1'b1;
                            // No state change - wait for next start
                        end
                    end
                end
                
                LOAD: begin
                    // Initialize base cases
                    // dp[i][0] = 0 for i > 0 (needs i wins, but only 0 losses)
                    // dp[0][j] = 0 for j > 0 (needs 0 wins, but j losses)
                    // dp[0][0] is undefined (0 games)
                    // Base case: dp[i][0] = p^i
                    // Base case: dp[0][j] = (1-p)^j
                    
                    // We'll compute base cases dynamically during first round
                    // For round 0 (i+j=1): dp[1][0] = p, dp[0][1] = 1-p
                    // Start computing from round 0
                    round_counter <= 5'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        error <= 1'b1;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        // Process current round
                        // Round k: i+j = k, where k = round_counter
                        // i ranges from max(1, k - (M-1)) to min(k, N)
                        // j ranges from max(1, k - (N-1)) to min(k, M)
                        
                        if (round_counter < (N_reg + M_reg - 1)) begin
                            // Compute range for current round
                            // i: max(1, round_counter - (M_reg - 1)) to min(round_counter, N_reg)
                            // j: round_counter - i
                            
                            if (i_counter <= N_reg && i_counter >= 5'd1) begin
                                j_counter <= round_counter - i_counter;
                                
                                if (j_counter <= M_reg && j_counter >= 5'd1) begin
                                    // Valid cell: compute dp[i][j]
                                    if (i_counter == round_counter && j_counter == 5'd0) begin
                                        // Base case: dp[i][0] = p^i
                                        if (i_counter == 5'd1) begin
                                            dp[i_counter][0] <= p_reg;
                                        end else begin
                                            // p * p^(i-1)
                                            dp[i_counter][0] <= p_reg * dp[i_counter-1][0] >> 16;
                                        end
                                    end else if (j_counter == round_counter && i_counter == 5'd0) begin
                                        // Base case: dp[0][j] = (1-p)^j
                                        if (j_counter == 5'd1) begin
                                            dp[0][j_counter] <= 32'h00010000 - p_reg;
                                        end else begin
                                            // (1-p) * (1-p)^(j-1)
                                            dp[0][j_counter] <= (32'h00010000 - p_reg) * dp[0][j_counter-1] >> 16;
                                        end
                                    end else begin
                                        // dp[i][j] = p*dp[i][j-1] + (1-p)*dp[i-1][j]
                                        dp[i_counter][j_counter] <= sum;
                                    end
                                end
                                
                                // Increment i for next iteration in this round
                                if (i_counter < round_counter && i_counter < N_reg) begin
                                    i_counter <= i_counter + 5'd1;
                                end else begin
                                    // Round complete, move to next round
                                    i_counter <= 5'd0;
                                    j_counter <= 5'd0;
                                    round_counter <= round_counter + 5'd1;
                                end
                            end else begin
                                // i_counter out of range, skip to next round
                                round_counter <= round_counter + 5'd1;
                                i_counter <= 5'd0;
                                j_counter <= 5'd0;
                            end
                        end else begin
                            // All rounds complete
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= dp[N_reg][M_reg];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end

endmodule