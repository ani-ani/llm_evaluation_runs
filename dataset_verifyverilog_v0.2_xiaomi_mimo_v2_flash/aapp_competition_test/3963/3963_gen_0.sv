module coin_ways_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] a_1, a_2, a_3,
    input [3:0] b_0, b_1, b_2, b_3,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    parameter MOD = 32'd1000000007;
    
    // State Encoding
    localparam IDLE = 4'b0001;
    localparam MOD_CHECK = 4'b0010;
    localparam UPDATE_DP = 4'b0100;
    localparam NEXT_COIN = 4'b1000;
    localparam FINAL_CHECK = 4'b1001;
    localparam DONE = 4'b1010;

    reg [3:0] state, next_state;
    
    // Registers
    reg [2:0] n_reg;
    reg [31:0] a_reg [3:0];
    reg [3:0] b_reg [4:0];
    reg [31:0] current_m;
    reg [31:0] ways [0:63];
    reg [5:0] idx;            // Coin type counter (0 to n-2)
    reg [5:0] j;              // DP loop counter
    
    // Combinational State Transition
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = MOD_CHECK;
            
            MOD_CHECK: begin
                if (n_reg <= 1) next_state = FINAL_CHECK;
                else if (current_m % a_reg[idx+1] != 0) next_state = DONE;
                else next_state = UPDATE_DP;
            end
            
            UPDATE_DP: begin
                // Loop for 64 cycles (j from 63 down to 0)
                if (j > 0) next_state = UPDATE_DP;
                else next_state = NEXT_COIN;
            end
            
            NEXT_COIN: begin
                // Increment idx and update current_m
                if (idx + 1 >= n_reg - 1) next_state = FINAL_CHECK;
                else next_state = MOD_CHECK;
            end
            
            FINAL_CHECK: next_state = DONE;
            
            DONE: if (start) next_state = MOD_CHECK; else next_state = DONE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: if (start) begin
                    n_reg <= n;
                    a_reg[1] <= a_1; a_reg[2] <= a_2; a_reg[3] <= a_3;
                    b_reg[0] <= b_0; b_reg[1] <= b_1; b_reg[2] <= b_2; b_reg[3] <= b_3;
                    current_m <= m;
                    ways[0] <= 1;
                    for (integer i = 1; i < 64; i++) ways[i] <= 0;
                    idx <= 0;
                    done <= 0;
                end
                
                MOD_CHECK: begin
                    if (next_state == UPDATE_DP) j <= 63;
                end
                
                UPDATE_DP: begin
                    if (j >= 0 && j < 64) begin
                        reg [31:0] temp_sum;
                        integer k;
                        temp_sum = 0;
                        // Unrolled loop for synthesis
                        if (b_reg[idx] >= 1 && j >= 1) temp_sum = (temp_sum + ways[j-1]) % MOD;
                        if (b_reg[idx] >= 2 && j >= 2) temp_sum = (temp_sum + ways[j-2]) % MOD;
                        if (b_reg[idx] >= 3 && j >= 3) temp_sum = (temp_sum + ways[j-3]) % MOD;
                        if (b_reg[idx] >= 4 && j >= 4) temp_sum = (temp_sum + ways[j-4]) % MOD;
                        if (b_reg[idx] >= 5 && j >= 5) temp_sum = (temp_sum + ways[j-5]) % MOD;
                        if (b_reg[idx] >= 6 && j >= 6) temp_sum = (temp_sum + ways[j-6]) % MOD;
                        if (b_reg[idx] >= 7 && j >= 7) temp_sum = (temp_sum + ways[j-7]) % MOD;
                        if (b_reg[idx] >= 8 && j >= 8) temp_sum = (temp_sum + ways[j-8]) % MOD;
                        
                        ways[j] <= (ways[j] + temp_sum) % MOD;
                        
                        if (j > 0) j <= j - 1;
                    end
                end
                
                NEXT_COIN: begin
                    current_m <= current_m / a_reg[idx+1];
                    idx <= idx + 1;
                end
                
                FINAL_CHECK: begin
                    if (current_m < 64) result <= ways[current_m];
                    else result <= 0;
                    done <= 1;
                end
                
                DONE: begin
                    if (start) done <= 0;
                end
            endcase
        end
    end

endmodule
