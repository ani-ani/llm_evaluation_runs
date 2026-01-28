module WeightQuerySolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam [2:0] N = 3'd8;
    localparam [7:0] MAX_VAL = 8'd16;
    localparam [7:0] DATA_WIDTH = 8'd8;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // States
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_COUNT_FREQ = 3'd1;
    localparam [2:0] S_INIT_DP = 3'd2;
    localparam [2:0] S_COMPUTE_DP = 3'd3;
    localparam [2:0] S_CHECK_RESULTS = 3'd4;
    localparam [2:0] S_DONE = 3'd5;

    // State and control signals
    reg [2:0] state;
    reg [7:0] cycle_count;

    // Frequency array
    reg [7:0] freq [0:15];

    // DP table: [sum][count]
    reg [7:0] dp [0:127];
    reg [7:0] dp_count [0:127];

    // Binomial coefficients
    reg [7:0] binom [0:7];

    // Loop counters
    reg [7:0] i, j, k, v;
    reg [7:0] weight, sum, count;
    reg [7:0] total_sum;
    reg [7:0] current_max;

    // Initialize binomial coefficients
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binom[0] <= 8'd1;
            binom[1] <= 8'd8;
            binom[2] <= 8'd28;
            binom[3] <= 8'd56;
            binom[4] <= 8'd70;
            binom[5] <= 8'd56;
            binom[6] <= 8'd28;
            binom[7] <= 8'd8;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize frequency array
            for (i = 0; i < 16; i = i + 1) begin
                freq[i] <= 8'd0;
            end

            // Initialize DP table
            for (i = 0; i < 128; i = i + 1) begin
                dp[i] <= 8'd0;
                dp_count[i] <= 8'd0;
            end

            // Initialize loop counters
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            v <= 8'd0;
            weight <= 8'd0;
            sum <= 8'd0;
            count <= 8'd0;
            total_sum <= 8'd0;
            current_max <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_COUNT_FREQ;
                        i <= 8'd0;
                    end
                end

                S_COUNT_FREQ: begin
                    if (i < N) begin
                        weight <= arr[i];
                        freq[weight] <= freq[weight] + 8'd1;
                        i <= i + 8'd1;
                    end else begin
                        state <= S_INIT_DP;
                        i <= 8'd0;
                    end
                end

                S_INIT_DP: begin
                    if (i < 128) begin
                        dp[i] <= 8'd0;
                        dp_count[i] <= 8'd0;
                        i <= i + 8'd1;
                    end else begin
                        dp[0] <= 8'd1;
                        dp_count[0] <= 8'd0;
                        state <= S_COMPUTE_DP;
                        i <= 8'd0;
                        j <= 8'd0;
                        k <= 8'd0;
                    end
                end

                S_COMPUTE_DP: begin
                    if (i < N) begin
                        weight <= arr[i];
                        if (j < 128) begin
                            if (k < 8) begin
                                if (j >= weight && k > 0) begin
                                    dp[j] <= dp[j] + dp[j - weight];
                                    dp_count[j] <= dp_count[j] + dp_count[j - weight];
                                end
                                k <= k + 8'd1;
                            end else begin
                                k <= 8'd0;
                                j <= j + 8'd1;
                            end
                        end else begin
                            j <= 8'd0;
                            i <= i + 8'd1;
                        end
                    end else begin
                        state <= S_CHECK_RESULTS;
                        v <= 8'd0;
                        current_max <= 8'd0;
                    end
                end

                S_CHECK_RESULTS: begin
                    if (v < 16) begin
                        if (freq[v] > 0) begin
                            if (i < 8) begin
                                if (i > 0 && i <= freq[v]) begin
                                    if (dp[v * i] == binom[i] || dp[total_sum - v * i] == binom[i]) begin
                                        if (i > current_max) begin
                                            current_max <= i;
                                        end
                                    end
                                end
                                i <= i + 8'd1;
                            end else begin
                                i <= 8'd0;
                                v <= v + 8'd1;
                            end
                        end else begin
                            v <= v + 8'd1;
                        end
                    end else begin
                        result <= current_max;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Calculate total sum
    always @(posedge clk) begin
        if (state == S_COUNT_FREQ && i == N) begin
            total_sum <= 8'd0;
            for (i = 0; i < N; i = i + 1) begin
                total_sum <= total_sum + arr[i];
            end
        end
    end

endmodule