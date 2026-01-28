module max_sum_module(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    reg [2:0] state;
    reg [7:0] i;
    reg [15:0] dp [0:100];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    dp[0] <= 16'd0;
                    dp[1] <= 16'd1;
                    i <= 8'd2;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute indices using integer division
                    reg [7:0] i2 = i >> 1;
                    reg [7:0] i3 = i / 3;
                    reg [7:0] i4 = i >> 2;
                    reg [7:0] i5 = i / 5;

                    // Compute sum
                    reg [15:0] sum = dp[i2] + dp[i3] + dp[i4] + dp[i5];

                    // Compute max(i, sum)
                    if (i > sum) begin
                        dp[i] <= i;
                    end else begin
                        dp[i] <= sum;
                    end

                    // Increment i
                    i <= i + 8'd1;

                    // Check if done
                    if (i == 8'd101 || cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    result <= dp[n_in];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule