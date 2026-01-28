module paint_fence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] k,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    // State and internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, next_i;  // Loop counter (3 to n)
    reg [31:0] dp_prev, next_dp_prev;  // dp[i-2]
    reg [31:0] dp_curr, next_dp_curr;  // dp[i-1]
    reg [31:0] result_reg, next_result_reg;
    reg done_reg, next_done_reg;

    // Combinational logic for next state and next values
    always @(*) begin
        next_state = state;
        next_i = i;
        next_dp_prev = dp_prev;
        next_dp_curr = dp_curr;
        next_result_reg = result_reg;
        next_done_reg = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                if (n == 4'd1) begin
                    // result = k mod MOD
                    next_result_reg = k % MOD;
                    next_state = DONE;
                end else if (n == 4'd2) begin
                    // result = k * k mod MOD
                    next_result_reg = (k * k) % MOD;
                    next_state = DONE;
                end else begin
                    // n >= 3
                    // Initialize dp_prev = k (for i=1)
                    // Initialize dp_curr = k*k (for i=2)
                    next_dp_prev = k % MOD;
                    next_dp_curr = (k * k) % MOD;
                    next_i = 3'd3;  // Start loop at i=3
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                // dp[i] = ((k - 1) * (dp[i-1] + dp[i-2])) mod MOD
                // Use 64-bit intermediate for multiplication to avoid overflow
                // before modulo
                wire [63:0] temp_sum;
                wire [63:0] temp_mult;
                reg [31:0] temp_result;

                // Calculate (dp[i-1] + dp[i-2]) mod MOD
                // Note: Even though max sum is ~2*MOD, we still do mod for correctness
                temp_sum = dp_curr + dp_prev;
                if (temp_sum >= MOD) begin
                    temp_sum = temp_sum - MOD;
                end

                // Calculate (k-1) * sum mod MOD
                // k is 8-bit, so k-1 fits in 8 bits. Max value 254
                // Max product: 254 * (MOD-1) ≈ 2.54e11 < 2^32 * 2^8 = 2^40
                // So 64-bit is plenty safe.
                temp_mult = (k - 8'd1) * temp_sum;
                temp_result = temp_mult % MOD;

                // Update dp values
                next_dp_prev = dp_curr;
                next_dp_curr = temp_result;

                // Check if loop is done
                if (i >= n) begin
                    next_result_reg = temp_result;
                    next_state = DONE;
                end else begin
                    next_i = i + 4'd1;
                    next_state = COMPUTE;
                end
            end

            DONE: begin
                // Done stays high for one cycle
                next_done_reg = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic (synchronous update)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            dp_prev <= 32'd0;
            dp_curr <= 32'd0;
            result_reg <= 32'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            i <= next_i;
            dp_prev <= next_dp_prev;
            dp_curr <= next_dp_curr;
            result_reg <= next_result_reg;
            done_reg <= next_done_reg;
        end
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            if (state == DONE) begin
                result <= result_reg;
            end
            done <= done_reg;
        end
    end

endmodule