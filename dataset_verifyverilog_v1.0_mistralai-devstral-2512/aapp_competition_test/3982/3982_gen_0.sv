module morse_counter(
    input clk,
    input rst_n,
    input start,
    input new_bit,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] INVALID_0011 = 4'd3;
    localparam [3:0] INVALID_0101 = 4'd5;
    localparam [3:0] INVALID_1110 = 4'd14;
    localparam [3:0] INVALID_1111 = 4'd15;

    // Registers
    reg [3:0] window_reg;
    reg [31:0] dp [0:3];
    reg [31:0] total;
    reg [31:0] new_value;
    reg invalid_flag;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_reg <= 4'd0;
            dp[0] <= 32'd0;
            dp[1] <= 32'd0;
            dp[2] <= 32'd0;
            dp[3] <= 32'd0;
            total <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            new_value <= 32'd0;
            invalid_flag <= 1'b0;
        end else begin
            // Shift window register
            if (start) begin
                window_reg[3:1] <= window_reg[2:0];
                window_reg[0] <= new_bit;
            end

            // Check for invalid patterns
            if (start) begin
                invalid_flag <= (window_reg == INVALID_0011) ||
                               (window_reg == INVALID_0101) ||
                               (window_reg == INVALID_1110) ||
                               (window_reg == INVALID_1111);
            end

            // Calculate new_value
            if (start) begin
                if (invalid_flag) begin
                    new_value <= 32'd0;
                end else begin
                    new_value <= (dp[0] + dp[1] + dp[2] + dp[3] + 32'd1) % MOD;
                end
            end

            // Update DP array
            if (start) begin
                dp[3] <= dp[2];
                dp[2] <= dp[1];
                dp[1] <= dp[0];
                dp[0] <= new_value;
            end

            // Update total and result
            if (start) begin
                total <= (total + new_value) % MOD;
                result <= total;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule