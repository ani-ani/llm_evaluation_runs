module optimal_hearings(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] s_in,
    input wire [15:0] a_in,
    input wire [15:0] b_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Memory for hearings
    reg [15:0] s_mem [0:15];
    reg [15:0] a_mem [0:15];
    reg [15:0] b_mem [0:15];

    // DP array
    reg [31:0] dp [0:16];

    // Counters for computation
    reg [3:0] i_reg;
    reg [15:0] t_reg;
    reg [31:0] sum_exp;
    reg [15:0] end_time;
    reg [3:0] next_idx;
    reg [3:0] load_count;

    // Fixed-point constants
    localparam [31:0] ONE = 32'd65536;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            load_count <= 4'd0;
            i_reg <= 4'd0;
            t_reg <= 16'd0;
            sum_exp <= 32'd0;
            end_time <= 16'd0;
            next_idx <= 4'd0;

            // Initialize memories
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                s_mem[j] <= 16'd0;
                a_mem[j] <= 16'd0;
                b_mem[j] <= 16'd0;
                dp[j] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                        load_count <= 4'd0;
                    end
                end

                LOAD: begin
                    if (load_count < n) begin
                        s_mem[load_count] <= s_in;
                        a_mem[load_count] <= a_in;
                        b_mem[load_count] <= b_in;
                        load_count <= load_count + 4'd1;
                    end else begin
                        state <= COMPUTE;
                        i_reg <= n - 4'd1;
                        sum_exp <= 32'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        // Compute dp[i]
                        if (t_reg == 16'd0) begin
                            // Initialize for new i
                            sum_exp <= 32'd0;
                            t_reg <= a_mem[i_reg];
                        end else begin
                            // Calculate end_time
                            end_time <= s_mem[i_reg] + t_reg;

                            // Find next_idx (linear scan)
                            next_idx <= 4'd0;
                            integer k;
                            for (k = 0; k < n; k = k + 1) begin
                                if (s_mem[k] >= end_time) begin
                                    next_idx <= k;
                                    break;
                                end
                            end

                            // Accumulate sum
                            sum_exp <= sum_exp + dp[next_idx];

                            // Increment t
                            if (t_reg == b_mem[i_reg]) begin
                                // Calculate dp[i]
                                if (b_mem[i_reg] - a_mem[i_reg] + 16'd1 != 16'd0) begin
                                    dp[i_reg] <= ONE + (sum_exp / (b_mem[i_reg] - a_mem[i_reg] + 16'd1));
                                end else begin
                                    dp[i_reg] <= ONE;
                                end

                                // Move to next i
                                if (i_reg == 4'd0) begin
                                    state <= FINISH;
                                end else begin
                                    i_reg <= i_reg - 4'd1;
                                    t_reg <= 16'd0;
                                end
                            end else begin
                                t_reg <= t_reg + 16'd1;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= dp[0];
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule