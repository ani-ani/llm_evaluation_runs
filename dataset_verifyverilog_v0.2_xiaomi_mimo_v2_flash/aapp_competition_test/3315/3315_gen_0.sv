module loda_teleport (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_strings,
    input [63:0] strings [0:7],
    output reg [3:0] result,
    output reg done
);

    localparam IDLE = 0, INPUT_PARSE = 1, COMPARE_INIT = 2, COMPARE_OUTER = 3,
               COMPARE_INNER = 4, COMPARE_CHECK = 5, COMPARE_INNER_INC = 6,
               COMPARE_OUTER_INC = 7, DP_CALC_INIT = 8, DP_LOOP = 9,
               DP_UPDATE = 10, DP_LOOP_INC = 11, DP_OUTER_INC = 12,
               RESULT = 13, DONE = 14;

    reg [3:0] state, next_state;
    reg [2:0] i_reg, j_reg;
    reg [3:0] lengths [0:7];
    reg [3:0] dp [0:7];
    reg [7:0] match_matrix [0:7];

    function automatic match_check;
        input [63:0] s_i;
        input [63:0] s_j;
        input [3:0] l_i;
        input [3:0] l_j;
        integer k;
        reg m;
        begin
            m = 1;
            if (l_i == 0 || l_i > l_j) m = 0;
            else begin
                if ((s_i & ((64'h1 << (l_i * 8)) - 1)) != (s_j & ((64'h1 << (l_i * 8)) - 1))) m = 0;
                for (k = 0; k < 8 && m; k = k + 1) begin
                    if (k < l_i) begin
                        if (s_i[8*k +: 8] != s_j[8*(l_j - l_i + k) +: 8]) m = 0;
                    end
                end
            end
            match_check = m;
        end
    endfunction

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INPUT_PARSE;
            INPUT_PARSE: if (i_reg == num_strings) next_state = COMPARE_INIT; else next_state = INPUT_PARSE;
            COMPARE_INIT: next_state = COMPARE_OUTER;
            COMPARE_OUTER: if (i_reg >= num_strings) next_state = DP_CALC_INIT; else next_state = COMPARE_INNER;
            COMPARE_INNER: if (j_reg >= num_strings) next_state = COMPARE_OUTER_INC; else if (j_reg <= i_reg) next_state = COMPARE_INNER_INC; else next_state = COMPARE_CHECK;
            COMPARE_CHECK: next_state = COMPARE_INNER_INC;
            COMPARE_INNER_INC: next_state = COMPARE_INNER;
            COMPARE_OUTER_INC: next_state = COMPARE_OUTER;
            DP_CALC_INIT: next_state = DP_LOOP;
            DP_LOOP: if (i_reg >= num_strings) next_state = RESULT; else if (j_reg >= i_reg) next_state = DP_OUTER_INC; else next_state = DP_UPDATE;
            DP_UPDATE: next_state = DP_LOOP_INC;
            DP_LOOP_INC: next_state = DP_LOOP;
            DP_OUTER_INC: next_state = DP_CALC_INIT;
            RESULT: if (i_reg >= num_strings) next_state = DONE; else next_state = RESULT;
            DONE: if (!start) next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; done <= 0; result <= 0;
        end else begin
            state <= next_state;
            case (next_state)
                IDLE: begin i_reg <= 0; j_reg <= 0; end
                INPUT_PARSE: begin
                    if (strings[i_reg][7:0] != 0) lengths[i_reg] <= 8;
                    else if (strings[i_reg][15:8] != 0) lengths[i_reg] <= 7;
                    else if (strings[i_reg][23:16] != 0) lengths[i_reg] <= 6;
                    else if (strings[i_reg][31:24] != 0) lengths[i_reg] <= 5;
                    else if (strings[i_reg][39:32] != 0) lengths[i_reg] <= 4;
                    else if (strings[i_reg][47:40] != 0) lengths[i_reg] <= 3;
                    else if (strings[i_reg][55:48] != 0) lengths[i_reg] <= 2;
                    else if (strings[i_reg][63:56] != 0) lengths[i_reg] <= 1;
                    else lengths[i_reg] <= 0;
                    i_reg <= i_reg + 1;
                end
                COMPARE_INIT: i_reg <= 0;
                COMPARE_OUTER: j_reg <= 0;
                COMPARE_CHECK: if (match_check(strings[i_reg], strings[j_reg], lengths[i_reg], lengths[j_reg])) match_matrix[j_reg][i_reg] <= 1;
                COMPARE_INNER_INC: j_reg <= j_reg + 1;
                COMPARE_OUTER_INC: i_reg <= i_reg + 1;
                DP_CALC_INIT: begin i_reg <= 0; j_reg <= 0; end
                DP_LOOP: if (j_reg == 0) dp[i_reg] <= 1;
                DP_UPDATE: if (match_matrix[i_reg][j_reg] && dp[j_reg] + 1 > dp[i_reg]) dp[i_reg] <= dp[j_reg] + 1;
                DP_LOOP_INC: j_reg <= j_reg + 1;
                DP_OUTER_INC: i_reg <= i_reg + 1;
                RESULT: begin if (dp[i_reg] > result) result <= dp[i_reg]; i_reg <= i_reg + 1; end
                DONE: done <= 1;
            endcase
        end
    end
endmodule