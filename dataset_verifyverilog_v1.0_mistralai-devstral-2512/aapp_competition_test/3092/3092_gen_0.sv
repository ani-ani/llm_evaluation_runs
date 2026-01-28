module shortest_path_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_nodes,
    input wire [4:0] num_edges,
    input wire [31:0] edge_in_0,
    input wire [31:0] edge_in_1,
    input wire [31:0] edge_in_2,
    input wire [31:0] edge_in_3,
    input wire [31:0] edge_in_4,
    input wire [31:0] edge_in_5,
    input wire [31:0] edge_in_6,
    input wire [31:0] edge_in_7,
    input wire [31:0] edge_in_8,
    input wire [31:0] edge_in_9,
    input wire [31:0] edge_in_10,
    input wire [31:0] edge_in_11,
    input wire [31:0] edge_in_12,
    input wire [31:0] edge_in_13,
    input wire [31:0] edge_in_14,
    input wire [31:0] edge_in_15,
    input wire [31:0] edge_in_16,
    input wire [31:0] edge_in_17,
    input wire [31:0] edge_in_18,
    input wire [31:0] edge_in_19,
    input wire [31:0] edge_in_20,
    input wire [31:0] edge_in_21,
    input wire [31:0] edge_in_22,
    input wire [31:0] edge_in_23,
    input wire [31:0] edge_in_24,
    input wire [31:0] edge_in_25,
    input wire [31:0] edge_in_26,
    input wire [31:0] edge_in_27,
    input wire [31:0] edge_in_28,
    input wire [31:0] edge_in_29,
    input wire [31:0] edge_in_30,
    input wire [31:0] edge_in_31,
    output reg [31:0] result,
    output reg result_valid,
    output reg edge_done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [4:0] MAX_EDGES = 5'd32;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FLOYD = 4'd1;
    localparam [3:0] COUNT = 4'd2;
    localparam [3:0] REV_COUNT = 4'd3;
    localparam [3:0] EDGE_PROCESS = 4'd4;
    localparam [3:0] DONE = 4'd5;

    reg [3:0] state;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd10000;

    // Edge storage
    reg [4:0] edge_src [0:31];
    reg [4:0] edge_dst [0:31];
    reg [5:0] edge_len [0:31];

    // Dist matrix (16x16, 24-bit)
    reg [23:0] dist [0:15][0:15];

    // Count and rev_count matrices (16x16, 32-bit)
    reg [31:0] cnt [0:15][0:15];
    reg [31:0] rev_cnt [0:15][0:15];

    // Current edge processing
    reg [4:0] current_edge;
    reg [3:0] current_node;
    reg [3:0] i_reg, j_reg, k_reg;
    reg [3:0] s_reg, t_reg;

    // Temporary registers
    reg [31:0] temp_result;
    reg [31:0] temp_sum;

    // Initialize edges
    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 32; idx = idx + 1) begin
                edge_src[idx] <= 5'd0;
                edge_dst[idx] <= 5'd0;
                edge_len[idx] <= 6'd0;
            end
        end else if (start) begin
            edge_src[0] <= edge_in_0[10:6];
            edge_dst[0] <= edge_in_0[15:11];
            edge_len[0] <= edge_in_0[5:0];
            edge_src[1] <= edge_in_1[10:6];
            edge_dst[1] <= edge_in_1[15:11];
            edge_len[1] <= edge_in_1[5:0];
            edge_src[2] <= edge_in_2[10:6];
            edge_dst[2] <= edge_in_2[15:11];
            edge_len[2] <= edge_in_2[5:0];
            edge_src[3] <= edge_in_3[10:6];
            edge_dst[3] <= edge_in_3[15:11];
            edge_len[3] <= edge_in_3[5:0];
            edge_src[4] <= edge_in_4[10:6];
            edge_dst[4] <= edge_in_4[15:11];
            edge_len[4] <= edge_in_4[5:0];
            edge_src[5] <= edge_in_5[10:6];
            edge_dst[5] <= edge_in_5[15:11];
            edge_len[5] <= edge_in_5[5:0];
            edge_src[6] <= edge_in_6[10:6];
            edge_dst[6] <= edge_in_6[15:11];
            edge_len[6] <= edge_in_6[5:0];
            edge_src[7] <= edge_in_7[10:6];
            edge_dst[7] <= edge_in_7[15:11];
            edge_len[7] <= edge_in_7[5:0];
            edge_src[8] <= edge_in_8[10:6];
            edge_dst[8] <= edge_in_8[15:11];
            edge_len[8] <= edge_in_8[5:0];
            edge_src[9] <= edge_in_9[10:6];
            edge_dst[9] <= edge_in_9[15:11];
            edge_len[9] <= edge_in_9[5:0];
            edge_src[10] <= edge_in_10[10:6];
            edge_dst[10] <= edge_in_10[15:11];
            edge_len[10] <= edge_in_10[5:0];
            edge_src[11] <= edge_in_11[10:6];
            edge_dst[11] <= edge_in_11[15:11];
            edge_len[11] <= edge_in_11[5:0];
            edge_src[12] <= edge_in_12[10:6];
            edge_dst[12] <= edge_in_12[15:11];
            edge_len[12] <= edge_in_12[5:0];
            edge_src[13] <= edge_in_13[10:6];
            edge_dst[13] <= edge_in_13[15:11];
            edge_len[13] <= edge_in_13[5:0];
            edge_src[14] <= edge_in_14[10:6];
            edge_dst[14] <= edge_in_14[15:11];
            edge_len[14] <= edge_in_14[5:0];
            edge_src[15] <= edge_in_15[10:6];
            edge_dst[15] <= edge_in_15[15:11];
            edge_len[15] <= edge_in_15[5:0];
            edge_src[16] <= edge_in_16[10:6];
            edge_dst[16] <= edge_in_16[15:11];
            edge_len[16] <= edge_in_16[5:0];
            edge_src[17] <= edge_in_17[10:6];
            edge_dst[17] <= edge_in_17[15:11];
            edge_len[17] <= edge_in_17[5:0];
            edge_src[18] <= edge_in_18[10:6];
            edge_dst[18] <= edge_in_18[15:11];
            edge_len[18] <= edge_in_18[5:0];
            edge_src[19] <= edge_in_19[10:6];
            edge_dst[19] <= edge_in_19[15:11];
            edge_len[19] <= edge_in_19[5:0];
            edge_src[20] <= edge_in_20[10:6];
            edge_dst[20] <= edge_in_20[15:11];
            edge_len[20] <= edge_in_20[5:0];
            edge_src[21] <= edge_in_21[10:6];
            edge_dst[21] <= edge_in_21[15:11];
            edge_len[21] <= edge_in_21[5:0];
            edge_src[22] <= edge_in_22[10:6];
            edge_dst[22] <= edge_in_22[15:11];
            edge_len[22] <= edge_in_22[5:0];
            edge_src[23] <= edge_in_23[10:6];
            edge_dst[23] <= edge_in_23[15:11];
            edge_len[23] <= edge_in_23[5:0];
            edge_src[24] <= edge_in_24[10:6];
            edge_dst[24] <= edge_in_24[15:11];
            edge_len[24] <= edge_in_24[5:0];
            edge_src[25] <= edge_in_25[10:6];
            edge_dst[25] <= edge_in_25[15:11];
            edge_len[25] <= edge_in_25[5:0];
            edge_src[26] <= edge_in_26[10:6];
            edge_dst[26] <= edge_in_26[15:11];
            edge_len[26] <= edge_in_26[5:0];
            edge_src[27] <= edge_in_27[10:6];
            edge_dst[27] <= edge_in_27[15:11];
            edge_len[27] <= edge_in_27[5:0];
            edge_src[28] <= edge_in_28[10:6];
            edge_dst[28] <= edge_in_28[15:11];
            edge_len[28] <= edge_in_28[5:0];
            edge_src[29] <= edge_in_29[10:6];
            edge_dst[29] <= edge_in_29[15:11];
            edge_len[29] <= edge_in_29[5:0];
            edge_src[30] <= edge_in_30[10:6];
            edge_dst[30] <= edge_in_30[15:11];
            edge_len[30] <= edge_in_30[5:0];
            edge_src[31] <= edge_in_31[10:6];
            edge_dst[31] <= edge_in_31[15:11];
            edge_len[31] <= edge_in_31[5:0];
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 32'd0;
            result <= 32'd0;
            result_valid <= 1'b0;
            edge_done <= 1'b0;
            current_edge <= 5'd0;
            current_node <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            s_reg <= 4'd0;
            t_reg <= 4'd0;
            temp_result <= 32'd0;
            temp_sum <= 32'd0;

            // Initialize dist matrix
            for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                for (j_reg = 0; j_reg < 16; j_reg = j_reg + 1) begin
                    if (i_reg == j_reg) begin
                        dist[i_reg][j_reg] <= 24'd0;
                    end else begin
                        dist[i_reg][j_reg] <= 24'd1000000; // Large value
                    end
                end
            end

            // Initialize cnt and rev_cnt matrices
            for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                for (j_reg = 0; j_reg < 16; j_reg = j_reg + 1) begin
                    cnt[i_reg][j_reg] <= 32'd0;
                    rev_cnt[i_reg][j_reg] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    edge_done <= 1'b0;
                    if (start) begin
                        state <= FLOYD;
                        cycle_count <= 32'd0;
                        k_reg <= 4'd0;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                    end
                end

                FLOYD: begin
                    cycle_count <= cycle_count + 32'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Floyd-Warshall algorithm
                        if (k_reg < num_nodes) begin
                            if (i_reg < num_nodes) begin
                                if (j_reg < num_nodes) begin
                                    // dist[i][j] = min(dist[i][j], dist[i][k] + dist[k][j])
                                    if (dist[i_reg][k_reg] + dist[k_reg][j_reg] < dist[i_reg][j_reg]) begin
                                        dist[i_reg][j_reg] <= dist[i_reg][k_reg] + dist[k_reg][j_reg];
                                    end
                                    j_reg <= j_reg + 4'd1;
                                end else begin
                                    j_reg <= 4'd0;
                                    i_reg <= i_reg + 4'd1;
                                end
                            end else begin
                                i_reg <= 4'd0;
                                k_reg <= k_reg + 4'd1;
                            end
                        end else begin
                            state <= COUNT;
                            s_reg <= 4'd0;
                            current_node <= 4'd0;
                        end
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 32'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Initialize cnt for current source
                        if (current_node == 4'd0) begin
                            for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                                cnt[s_reg][i_reg] <= 32'd0;
                            end
                            cnt[s_reg][s_reg] <= 32'd1;
                        end

                        // Relax edges for cnt
                        if (current_node < num_nodes) begin
                            for (i_reg = 0; i_reg < num_edges; i_reg = i_reg + 1) begin
                                if (edge_src[i_reg] == current_node && 
                                    dist[s_reg][edge_src[i_reg]] + edge_len[i_reg] == dist[s_reg][edge_dst[i_reg]]) begin
                                    cnt[s_reg][edge_dst[i_reg]] <= (cnt[s_reg][edge_dst[i_reg]] + cnt[s_reg][edge_src[i_reg]]) % MOD;
                                end
                            end
                            current_node <= current_node + 4'd1;
                        end else begin
                            current_node <= 4'd0;
                            s_reg <= s_reg + 4'd1;
                            if (s_reg >= num_nodes) begin
                                state <= REV_COUNT;
                                s_reg <= 4'd0;
                            end
                        end
                    end
                end

                REV_COUNT: begin
                    cycle_count <= cycle_count + 32'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Initialize rev_cnt for current source
                        if (current_node == 4'd0) begin
                            for (i_reg = 0; i_reg < 16; i_reg = i_reg + 1) begin
                                rev_cnt[s_reg][i_reg] <= 32'd0;
                            end
                            rev_cnt[s_reg][s_reg] <= 32'd1;
                        end

                        // Relax edges for rev_cnt (reversed graph)
                        if (current_node < num_nodes) begin
                            for (i_reg = 0; i_reg < num_edges; i_reg = i_reg + 1) begin
                                if (edge_dst[i_reg] == current_node && 
                                    dist[s_reg][edge_dst[i_reg]] + edge_len[i_reg] == dist[s_reg][edge_src[i_reg]]) begin
                                    rev_cnt[s_reg][edge_src[i_reg]] <= (rev_cnt[s_reg][edge_src[i_reg]] + rev_cnt[s_reg][edge_dst[i_reg]]) % MOD;
                                end
                            end
                            current_node <= current_node + 4'd1;
                        end else begin
                            current_node <= 4'd0;
                            s_reg <= s_reg + 4'd1;
                            if (s_reg >= num_nodes) begin
                                state <= EDGE_PROCESS;
                                current_edge <= 5'd0;
                                s_reg <= 4'd0;
                                t_reg <= 4'd0;
                            end
                        end
                    end
                end

                EDGE_PROCESS: begin
                    cycle_count <= cycle_count + 32'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        result_valid <= 1'b0;
                        if (current_edge < num_edges) begin
                            if (s_reg < num_nodes && t_reg < num_nodes) begin
                                // Check if edge lies on shortest path
                                if (dist[s_reg][edge_src[current_edge]] + edge_len[current_edge] + dist[edge_dst[current_edge]][t_reg] == dist[s_reg][t_reg]) begin
                                    temp_sum <= (temp_sum + (cnt[s_reg][edge_src[current_edge]] * rev_cnt[s_reg][edge_dst[current_edge]]) % MOD) % MOD;
                                end
                                t_reg <= t_reg + 4'd1;
                            end else begin
                                t_reg <= 4'd0;
                                s_reg <= s_reg + 4'd1;
                                if (s_reg >= num_nodes) begin
                                    result <= temp_sum;
                                    result_valid <= 1'b1;
                                    temp_sum <= 32'd0;
                                    s_reg <= 4'd0;
                                    current_edge <= current_edge + 5'd1;
                                    if (current_edge >= num_edges) begin
                                        edge_done <= 1'b1;
                                        state <= DONE;
                                    end
                                end
                            end
                        end else begin
                            edge_done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule