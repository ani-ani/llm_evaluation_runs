module SequenceCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MOD_MASK = 32'd4294967295;

    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state;
    reg [9:0] n;
    reg [9:0] i;
    reg [31:0] dp_prev1;
    reg [31:0] dp_prev2;
    reg [31:0] window_sum;
    reg [31:0] temp_sum;
    reg [31:0] temp_mult;
    reg [9:0] window_start;
    reg [9:0] window_end;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd10000;

    // Modulo addition
    function [31:0] mod_add;
        input [31:0] a, b;
        begin
            mod_add = (a + b) % MOD;
        end
    endfunction

    // Modulo multiplication
    function [31:0] mod_mult;
        input [31:0] a, b;
        begin
            mod_mult = (a * b) % MOD;
        end
    endfunction

    // Modulo subtraction
    function [31:0] mod_sub;
        input [31:0] a, b;
        begin
            mod_sub = (a - b + MOD) % MOD;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n <= 10'd0;
            i <= 10'd0;
            dp_prev1 <= 32'd0;
            dp_prev2 <= 32'd0;
            window_sum <= 32'd0;
            temp_sum <= 32'd0;
            temp_mult <= 32'd0;
            window_start <= 10'd0;
            window_end <= 10'd0;
            cycle_count <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        n <= n_in;
                        state <= COMPUTE;
                        i <= n - 11'd1;
                        dp_prev1 <= n;
                        dp_prev2 <= mod_mult(n, n);
                        window_sum <= 32'd0;
                        window_start <= 10'd0;
                        window_end <= 10'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;

                    // Base cases
                    if (i == n - 11'd1) begin
                        dp_prev1 <= n;
                        dp_prev2 <= mod_mult(n, n);
                        window_sum <= 32'd0;
                        window_start <= 10'd0;
                        window_end <= 10'd0;
                    end else if (i == n - 11'd2) begin
                        // dp[i] = n^2 + (n-1)^2 + ...
                        temp_mult <= mod_mult(n, n);
                        temp_sum <= mod_add(temp_mult, mod_mult(n - 11'd1, n - 11'd1));
                        dp_prev1 <= temp_sum;
                        window_sum <= mod_add(window_sum, dp_prev1);
                        window_start <= i + 11'd3;
                        window_end <= n - 11'd1;
                    end else begin
                        // Update window sum
                        if (window_start <= window_end) begin
                            // Add new element to window
                            if (window_end + 11'd1 <= n - 11'd1) begin
                                window_sum <= mod_add(window_sum, dp_prev1);
                                window_end <= window_end + 11'd1;
                            end
                            // Remove old element from window
                            if (window_start <= window_end) begin
                                // Need to track dp values for window
                                // For simplicity, we'll use a different approach
                                // Since we can't store all dp values, we'll compute on the fly
                                // This is a simplified version
                                temp_sum <= mod_add(dp_prev1, dp_prev2);
                                temp_sum <= mod_add(temp_sum, window_sum);
                                temp_mult <= mod_mult(n - i - 11'd1, n - i - 11'd1);
                                temp_sum <= mod_add(temp_sum, temp_mult);
                                dp_prev2 <= dp_prev1;
                                dp_prev1 <= temp_sum;
                                window_start <= window_start + 11'd1;
                            end
                        end
                    end

                    // Move to next iteration
                    if (i == 10'd0) begin
                        state <= FINISH;
                        result <= dp_prev1;
                    end else begin
                        i <= i - 11'd1;
                    end

                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 32'd0;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule