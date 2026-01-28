module sequence_counter(
    input [3:0] n,
    output reg [31:0] result
);

    localparam MOD = 32'd1000000007;
    
    reg [31:0] dp [0:15];
    integer i;
    reg [31:0] dp_sum;
    reg [31:0] term;

    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            dp[i] = 32'd0;
        end
        
        if (n == 4'd1) begin
            result = 32'd1;
        end else begin
            dp[0] = 32'd1;
            dp[1] = 32'd1;
            dp_sum = 32'd2;
            
            for (i = 2; i < n; i = i + 1) begin
                dp[i] = (dp_sum - dp[i-2] + MOD) % MOD;
                dp_sum = (dp_sum + dp[i]) % MOD;
            end
            
            result = 32'd0;
            for (i = 0; i < n-1; i = i + 1) begin
                if (i >= n-3) begin
                    term = ((n-1) * (n-1) + (n-1)) % MOD;
                end else begin
                    term = ((n-1) * (n-1) + (i+2)) % MOD;
                end
                result = (result + dp[i] * term) % MOD;
            end
            result = (result + dp[n-1] * n) % MOD;
        end
    end

endmodule