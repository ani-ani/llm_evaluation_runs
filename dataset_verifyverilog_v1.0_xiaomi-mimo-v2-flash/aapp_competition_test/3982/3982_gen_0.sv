module MorseCounter (
    input clk,
    input rst_n,
    input start,
    input new_bit,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] ONE = 32'd1;
    
    // Registers
    reg [1:0] state, next_state;
    reg [3:0] window_reg;          // Stores last 4 bits
    reg [31:0] dp [0:3];           // DP array: dp[i] = count ending i bits before current
    reg [31:0] result_reg;         // Cumulative sum
    reg start_prev;                // Edge detection for start
    
    // Combinational signals
    wire [3:0] new_window;
    wire is_invalid;
    wire [31:0] new_dp0;
    wire [31:0] sum_dp;
    wire [31:0] sum_dp_mod;
    
    // Compute new window: shift left and insert new_bit at LSB
    assign new_window = {window_reg[2:0], new_bit};
    
    // Check for invalid patterns: 0011, 0101, 1110, 1111
    assign is_invalid = (new_window == 4'b0011) || 
                        (new_window == 4'b0101) || 
                        (new_window == 4'b1110) || 
                        (new_window == 4'b1111);
    
    // Sum of previous dp values (dp[3] + dp[2] + dp[1] + dp[0])
    // This represents all valid sequences that can be extended
    assign sum_dp = dp[3] + dp[2] + dp[1] + dp[0];
    
    // Modulo operation for sum_dp (two subtractions for safety)
    assign sum_dp_mod = (sum_dp < MOD) ? sum_dp : 
                        (sum_dp - MOD < MOD) ? (sum_dp - MOD) : (sum_dp - 2*MOD);
    
    // Calculate new dp[0]: if window is valid, sum_dp + 1 (for single character), else 0
    assign new_dp0 = is_invalid ? 32'd0 : 
                     (sum_dp_mod + ONE >= MOD) ? (sum_dp_mod + ONE - MOD) : (sum_dp_mod + ONE);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = (start && !start_prev) ? COMPUTE : IDLE;
            COMPUTE:    next_state = FINISH;
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            window_reg <= 4'd0;
            dp[0] <= 32'd0;
            dp[1] <= 32'd0;
            dp[2] <= 32'd0;
            dp[3] <= 32'd0;
            result_reg <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            start_prev <= 1'b0;
        end else begin
            start_prev <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !start_prev) begin
                        // Update window register
                        window_reg <= new_window;
                        
                        // Update DP array (shift and update dp[0])
                        dp[3] <= dp[2];
                        dp[2] <= dp[1];
                        dp[1] <= dp[0];
                        dp[0] <= new_dp0;
                        
                        // Update result (add new_dp0 to result_reg)
                        result_reg <= (result_reg + new_dp0 >= MOD) ? 
                                     (result_reg + new_dp0 - MOD) : 
                                     (result_reg + new_dp0);
                    end
                end
                
                COMPUTE: begin
                    // Output the updated result
                    result <= result_reg;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    start_prev <= 1'b0;
                end
            endcase
        end
    end

endmodule