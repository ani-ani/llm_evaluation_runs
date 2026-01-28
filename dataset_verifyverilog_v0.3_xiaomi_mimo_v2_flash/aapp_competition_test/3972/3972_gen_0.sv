module sequence_counter (
    input [3:0] n,  // n from 1 to 16
    output reg [31:0] result
);

    localparam [31:0] MOD = 32'd1000000007;
    
    reg [31:0] dp [0:15];  // dp[0] to dp[15]
    integer i;
    reg [31:0] dp_sum;
    reg [31:0] term;
    
    always @(*) begin
        // Initialize dp array
        for (i = 0; i < 16; i = i + 1) begin
            dp[i] = 32'd0;
        end
        
        if (n == 4'd1) begin
            result = 32'd1;
        end else begin
            // Initialize base cases
            dp[0] = 32'd1;
            dp[1] = 32'd1;
            dp_sum = 32'd2;
            
            // Compute dp[2] to dp[n-1]
            for (i = 2; i < n; i = i + 1) begin
                // dp[i] = (dp_sum - dp[i-2] + MOD) % MOD
                // Handle potential underflow
                if (dp_sum >= dp[i-2]) begin
                    dp[i] = (dp_sum - dp[i-2]) % MOD;
                end else begin
                    dp[i] = (dp_sum - dp[i-2] + MOD) % MOD;
                end
                dp_sum = (dp_sum + dp[i]) % MOD;
            end
            
            // Compute the final answer
            result = 32'd0;
            for (i = 0; i < (n - 1); i = i + 1) begin
                if (i >= (n - 3)) begin
                    term = ((n - 1) * (n - 1) + (n - 1)) % MOD;
                end else begin
                    term = ((n - 1) * (n - 1) + (i + 2)) % MOD;
                end
                result = (result + (dp[i] * term) % MOD) % MOD;
            end
            result = (result + (dp[n-1] * n) % MOD) % MOD;
        end
    end

endmodule