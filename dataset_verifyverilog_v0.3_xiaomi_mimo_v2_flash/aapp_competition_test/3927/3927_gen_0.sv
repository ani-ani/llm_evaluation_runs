module WeightQuerySolver(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam [7:0] N = 8'd8;
    localparam [7:0] MAX_VAL = 8'd16;
    localparam [7:0] DATA_WIDTH = 8'd8;
    localparam [7:0] CLK_PERIOD = 8'd10;
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [7:0] MAX_SUM = 8'd128;

    // State declarations
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_COUNT_FREQ = 3'd1;
    localparam [2:0] S_INIT_DP = 3'd2;
    localparam [2:0] S_COMPUTE_DP = 3'd3;
    localparam [2:0] S_CHECK_RESULTS = 3'd4;
    localparam [2:0] S_DONE = 3'd5;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Control registers
    reg [7:0] cycle_count;
    reg [3:0] i, j, k, v; // Loop counters
    reg [7:0] weight;
    reg [7:0] total_sum;
    reg [7:0] freq_val;
    reg [7:0] temp_result;
    reg start_d1;

    // Memory declarations (using packed arrays for compatibility)
    // freq[0:15][7:0] - 16x8 bit array, packed as [127:0]
    reg [127:0] freq_reg;
    wire [7:0] freq [0:15];
    genvar g_freq;
    generate
        for (g_freq = 0; g_freq < 16; g_freq = g_freq + 1) begin : gen_freq
            assign freq[g_freq] = freq_reg[(g_freq*8)+7 : g_freq*8];
        end
    endgenerate

    // dp[128][8][8] - 128x8x8 bit array, packed as [8191:0]
    reg [8191:0] dp_reg;
    wire [7:0] dp [0:127][0:7];
    genvar g_dp1, g_dp2;
    generate
        for (g_dp1 = 0; g_dp1 < 128; g_dp1 = g_dp1 + 1) begin : gen_dp1
            for (g_dp2 = 0; g_dp2 < 8; g_dp2 = g_dp2 + 1) begin : gen_dp2
                assign dp[g_dp1][g_dp2] = dp_reg[(g_dp1*64 + g_dp2*8)+7 : g_dp1*64 + g_dp2*8];
            end
        end
    endgenerate

    // binom[8][8] - 8x8 bit array, packed as [63:0]
    reg [63:0] binom_reg;
    wire [7:0] binom [0:7][0:7];
    genvar g_bin1, g_bin2;
    generate
        for (g_bin1 = 0; g_bin1 < 8; g_bin1 = g_bin1 + 1) begin : gen_bin1
            for (g_bin2 = 0; g_bin2 < 8; g_bin2 = g_bin2 + 1) begin : gen_bin2
                assign binom[g_bin1][g_bin2] = binom_reg[(g_bin1*8 + g_bin2*8)+7 : g_bin1*8 + g_bin2*8];
            end
        end
    endgenerate

    // Compute next state logic
    always @(*) begin
        case (state)
            S_IDLE: next_state = (start && !start_d1) ? S_COUNT_FREQ : S_IDLE;
            S_COUNT_FREQ: next_state = (i >= N) ? S_INIT_DP : S_COUNT_FREQ;
            S_INIT_DP: next_state = (j >= 8) ? S_COMPUTE_DP : S_INIT_DP;
            S_COMPUTE_DP: next_state = (i >= N) ? S_CHECK_RESULTS : S_COMPUTE_DP;
            S_CHECK_RESULTS: next_state = (v >= MAX_VAL) ? S_DONE : S_CHECK_RESULTS;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            v <= 4'd0;
            weight <= 8'd0;
            total_sum <= 8'd0;
            freq_val <= 8'd0;
            temp_result <= 8'd0;
            start_d1 <= 1'b0;
            freq_reg <= 128'd0;
            dp_reg <= 8192'd0;
            binom_reg <= 64'd0;
        end else begin
            start_d1 <= start;
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    v <= 4'd0;
                    total_sum <= 8'd0;
                    temp_result <= 8'd0;
                    freq_reg <= 128'd0;
                    dp_reg <= 8192'd0;
                    binom_reg <= 64'd0;
                    // Precompute binomials
                    binom_reg[7:0] <= 8'd1;     // binom[0][0]
                    binom_reg[15:8] <= 8'd1;    // binom[1][0]
                    binom_reg[23:16] <= 8'd1;   // binom[1][1]
                    binom_reg[31:24] <= 8'd1;   // binom[2][0]
                    binom_reg[39:32] <= 8'd2;   // binom[2][1]
                    binom_reg[47:40] <= 8'd1;   // binom[2][2]
                    binom_reg[55:48] <= 8'd1;   // binom[3][0]
                    binom_reg[63:56] <= 8'd3;   // binom[3][1]
                    binom_reg[71:64] <= 8'd3;   // binom[3][2]
                    binom_reg[79:72] <= 8'd1;   // binom[3][3]
                    binom_reg[87:80] <= 8'd1;   // binom[4][0]
                    binom_reg[95:88] <= 8'd4;   // binom[4][1]
                    binom_reg[103:96] <= 8'd6;  // binom[4][2]
                    binom_reg[111:104] <= 8'd4; // binom[4][3]
                    binom_reg[119:112] <= 8'd1; // binom[4][4]
                    binom_reg[127:120] <= 8'd1; // binom[5][0]
                    binom_reg[135:128] <= 8'd5; // binom[5][1]
                    binom_reg[143:136] <= 8'd10; // binom[5][2]
                    binom_reg[151:144] <= 8'd10; // binom[5][3]
                    binom_reg[159:152] <= 8'd5; // binom[5][4]
                    binom_reg[167:160] <= 8'd1; // binom[5][5]
                    binom_reg[175:168] <= 8'd1; // binom[6][0]
                    binom_reg[183:176] <= 8'd6; // binom[6][1]
                    binom_reg[191:184] <= 8'd15; // binom[6][2]
                    binom_reg[199:192] <= 8'd20; // binom[6][3]
                    binom_reg[207:200] <= 8'd15; // binom[6][4]
                    binom_reg[215:208] <= 8'd6; // binom[6][5]
                    binom_reg[223:216] <= 8'd1; // binom[6][6]
                    binom_reg[231:224] <= 8'd1; // binom[7][0]
                    binom_reg[239:232] <= 8'd7; // binom[7][1]
                    binom_reg[247:240] <= 8'd21; // binom[7][2]
                    binom_reg[255:248] <= 8'd35; // binom[7][3]
                    binom_reg[263:256] <= 8'd35; // binom[7][4]
                    binom_reg[271:264] <= 8'd21; // binom[7][5]
                    binom_reg[279:272] <= 8'd7; // binom[7][6]
                    binom_reg[287:280] <= 8'd1; // binom[7][7]
                end

                S_COUNT_FREQ: begin
                    if (i < N) begin
                        // freq[arr[i]]++
                        freq_reg[(arr[i]*8)+7 : arr[i]*8] <= freq_reg[(arr[i]*8)+7 : arr[i]*8] + 8'd1;
                        i <= i + 4'd1;
                    end
                end

                S_INIT_DP: begin
                    if (j < 8) begin
                        // dp[0][j] = 1
                        dp_reg[(0*64 + j*8)+7 : 0*64 + j*8] <= 8'd1;
                        j <= j + 4'd1;
                    end
                end

                S_COMPUTE_DP: begin
                    if (i < N) begin
                        // Get weight
                        weight <= arr[i];
                        // Fill DP from high to low
                        if (k < 128) begin
                            if (k >= arr[i] && k <= 128) begin
                                // For each count from 8 down to 1
                                for (int m = 0; m < 8; m = m + 1) begin
                                    dp_reg[(k*64 + m*8)+7 : k*64 + m*8] <= dp_reg[(k*64 + m*8)+7 : k*64 + m*8] + dp_reg[((k - arr[i])*64 + (m-1)*8)+7 : ((k - arr[i])*64 + (m-1)*8)];
                                end
                            end
                            k <= k + 4'd1;
                        end else begin
                            k <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end
                end

                S_CHECK_RESULTS: begin
                    if (v < MAX_VAL) begin
                        freq_val <= freq[v];
                        // Check for i from 1 to freq_val
                        if (freq_val > 8'd0) begin
                            // Check if we can form v*i with i items and rest without
                            // Simplified: check dp[v*i][i] == binom[freq[v]][i]
                            if (dp[v*8'd8][freq_val] == binom[freq_val][freq_val] || dp[total_sum - v*8'd8][8'd8 - freq_val] == binom[freq_val][freq_val]) begin
                                if (freq_val > temp_result) begin
                                    temp_result <= freq_val;
                                end
                            end
                        end
                        v <= v + 4'd1;
                    end else begin
                        result <= temp_result;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule