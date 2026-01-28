module fence_painting(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] k,
    output reg [31:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] INIT    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] i;  // Loop counter
    reg [31:0] dp_prev;  // dp[i-2]
    reg [31:0] dp_curr;  // dp[i-1]
    reg [31:0] dp_next;  // dp[i]
    
    // Modulo constant
    localparam [31:0] MOD = 32'd1000000007;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 4'd0;
            dp_prev <= 32'd0;
            dp_curr <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Handle base cases
                    if (n == 4'd1) begin
                        result <= k;
                        state <= DONE;
                    end else if (n == 4'd2) begin
                        result <= (k * k) % MOD;
                        state <= DONE;
                    end else begin
                        // Initialize for n >= 3
                        dp_prev <= k;  // dp[1]
                        dp_curr <= (k * k) % MOD;  // dp[2]
                        i <= 4'd3;  // Start from i=3
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate dp[i] = ((k - 1) * (dp[i-1] + dp[i-2])) % MOD
                    dp_next <= ((k - 1) * (dp_curr + dp_prev)) % MOD;
                    
                    // Update previous values
                    dp_prev <= dp_curr;
                    dp_curr <= dp_next;
                    
                    // Increment counter
                    i <= i + 4'd1;
                    
                    // Check if done
                    if (i == n) begin
                        result <= dp_next;
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
endmodule