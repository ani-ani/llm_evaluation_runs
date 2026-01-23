module assembly_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_symbols,
    input [2:0] seq_length,
    input [2:0] sequence [0:7],
    input [17:0] time_table [0:2][0:2],
    input [1:0] result_table [0:2][0:2],
    output reg [19:0] min_time,
    output reg [1:0] result_symbol,
    output reg done
);

    // States
    localparam IDLE = 0;
    localparam LOAD_SEQ = 1;
    localparam INIT_DP = 2;
    localparam DP_OUTER = 3;
    localparam DP_MIDDLE = 4;
    localparam DP_INNER = 5;
    localparam FIND_RESULT = 6;
    localparam DONE = 7;
    // Helper states for inner loop calculation
    localparam CALC_SUM = 8;
    localparam CMP_MIN = 9;

    reg [3:0] state;

    // Internal memory
    reg [2:0] seq_mem [0:7];

    // DP Table: 8x8x3
    // Internal storage uses 40 bits to handle accumulation without overflow
    reg [39:0] dp [0:7][0:7][0:2];

    // Loop counters
    reg [3:0] i, j, p; // i=length, j=start, p=split
    reg [1:0] l, m, k; // symbols

    // Temp variables for computation
    reg [39:0] current_min;
    reg [39:0] sum_val;
    reg [39:0] left_val;
    reg [39:0] right_val;
    reg [39:0] time_val;

    // Infinity value
    localparam INF = 40'h0000_00FF_FFFF_FFFF; // Large enough value

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_time <= 0;
            result_symbol <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= LOAD_SEQ;
                end

                LOAD_SEQ: begin
                    // Copy sequence to internal memory
                    seq_mem[0] <= sequence[0];
                    seq_mem[1] <= sequence[1];
                    seq_mem[2] <= sequence[2];
                    seq_mem[3] <= sequence[3];
                    seq_mem[4] <= sequence[4];
                    seq_mem[5] <= sequence[5];
                    seq_mem[6] <= sequence[6];
                    seq_mem[7] <= sequence[7];
                    state <= INIT_DP;
                    i <= 0;
                end

                INIT_DP: begin
                    // Initialize base cases
                    // Loop i from 0 to 7
                    if (i < 8) begin
                        // Reset all k
                        dp[i][i][0] <= INF;
                        dp[i][i][1] <= INF;
                        dp[i][i][2] <= INF;
                        // Set valid k if within seq_length
                        if (i < seq_length) begin
                            case (seq_mem[i])
                                3'd0: dp[i][i][0] <= 0;
                                3'd1: dp[i][i][1] <= 0;
                                3'd2: dp[i][i][2] <= 0;
                                default: ;
                            endcase
                        end
                        i <= i + 1;
                    end else begin
                        state <= DP_OUTER;
                        i <= 2; // Start with length 2
                    end
                end

                DP_OUTER: begin
                    // Loop length
                    if (i <= seq_length) begin
                        j <= 0;
                        state <= DP_MIDDLE;
                    end else begin
                        state <= FIND_RESULT;
                        j <= 0;
                    end
                end

                DP_MIDDLE: begin
                    // Loop start position
                    if (j <= seq_length - i) begin
                        k <= 0;
                        current_min <= INF;
                        p <= j;
                        l <= 0;
                        m <= 0;
                        state <= DP_INNER;
                    end else begin
                        i <= i + 1;
                        state <= DP_OUTER;
                    end
                end

                DP_INNER: begin
                    // Loop split and symbols
                    // Check if we need to process this (l,m) pair
                    if (l <= 2 && m <= 2) begin
                        if (result_table[l][m] == k) begin
                            // Valid transition, load values
                            left_val <= dp[j][p][l];
                            right_val <= dp[p+1][j+i-1][m];
                            time_val <= {22'b0, time_table[l][m]};
                            state <= CALC_SUM;
                        end else begin
                            // Skip this pair, advance
                            state <= 10; // Use temp state for advancing
                        end
                    end else begin
                        // End of l,m loop for current p
                        if (p == j + i - 2) begin
                            // End of p loop
                            dp[j][j+i-1][k] <= current_min;
                            if (k == 2) begin
                                state <= DP_MIDDLE;
                                j <= j + 1;
                            end else begin
                                k <= k + 1;
                                current_min <= INF;
                                p <= j;
                                l <= 0;
                                m <= 0;
                            end
                        end else begin
                            // Next p
                            p <= p + 1;
                            l <= 0;
                            m <= 0;
                        end
                    end
                end

                CALC_SUM: begin
                    // Compute sum = left + right + (time << 16)
                    sum_val <= left_val + right_val + (time_val << 16);
                    state <= CMP_MIN;
                end

                CMP_MIN: begin
                    if (sum_val < current_min) current_min <= sum_val;
                    // Advance l,m
                    if (m == 2) begin
                        m <= 0;
                        if (l == 2) begin
                            // Done with this p
                            if (p == j + i - 2) begin
                                dp[j][j+i-1][k] <= current_min;
                                if (k == 2) begin
                                    state <= DP_MIDDLE;
                                    j <= j + 1;
                                end else begin
                                    k <= k + 1;
                                    current_min <= INF;
                                    p <= j;
                                    l <= 0;
                                    m <= 0;
                                    state <= DP_INNER;
                                end
                            end else begin
                                p <= p + 1;
                                l <= 0;
                                m <= 0;
                                state <= DP_INNER;
                            end
                        end else begin
                            l <= l + 1;
                            m <= 0;
                            state <= DP_INNER;
                        end
                    end else begin
                        m <= m + 1;
                        state <= DP_INNER;
                    end
                end

                // Temporary state to handle l,m advance without calculation
                10: begin
                    if (m == 2) begin
                        m <= 0;
                        if (l == 2) begin
                            if (p == j + i - 2) begin
                                dp[j][j+i-1][k] <= current_min;
                                if (k == 2) begin
                                    state <= DP_MIDDLE;
                                    j <= j + 1;
                                end else begin
                                    k <= k + 1;
                                    current_min <= INF;
                                    p <= j;
                                    l <= 0;
                                    m <= 0;
                                    state <= DP_INNER;
                                end
                            end else begin
                                p <= p + 1;
                                l <= 0;
                                m <= 0;
                                state <= DP_INNER;
                            end
                        end else begin
                            l <= l + 1;
                            m <= 0;
                            state <= DP_INNER;
                        end
                    end else begin
                        m <= m + 1;
                        state <= DP_INNER;
                    end
                end

                FIND_RESULT: begin
                    // Find min among k=0,1,2 for dp[0][seq_length-1][k]
                    if (j == 0) begin
                        min_time <= dp[0][seq_length-1][0][19:0];
                        result_symbol <= 0;
                        j <= 1;
                    end else if (j == 1) begin
                        if (dp[0][seq_length-1][1][19:0] < min_time) begin
                            min_time <= dp[0][seq_length-1][1][19:0];
                            result_symbol <= 1;
                        end
                        j <= 2;
                    end else if (j == 2) begin
                        if (dp[0][seq_length-1][2][19:0] < min_time) begin
                            min_time <= dp[0][seq_length-1][2][19:0];
                            result_symbol <= 2;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

module TopWrapper (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_symbols,
    input [2:0] seq_length,
    input [2:0] sequence [0:7],
    input [17:0] time_table [0:2][0:2],
    input [1:0] result_table [0:2][0:2],
    output [19:0] min_time,
    output [1:0] result_symbol,
    output done
);

    // Instantiation wrapper if needed, or direct connection
    assembly_optimizer u_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .num_symbols(num_symbols),
        .seq_length(seq_length),
        .sequence(sequence),
        .time_table(time_table),
        .result_table(result_table),
        .min_time(min_time),
        .result_symbol(result_symbol),
        .done(done)
    );

endmodule