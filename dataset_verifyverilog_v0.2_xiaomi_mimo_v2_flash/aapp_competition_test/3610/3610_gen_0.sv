module vertex_cover_solver (
    input clk,
    input rst_n,
    input start,
    input [9:0] team_stockholm,
    input [9:0] team_london,
    input team_valid,
    input team_done,
    output reg [4:0] result_count,
    output reg [9:0] result_ids [0:15],
    output reg result_valid,
    output reg done
);

    localparam MAX_EMP = 16;
    localparam FRIEND_ID = 10'd1009;

    localparam IDLE = 0;
    localparam INPUT = 1;
    localparam COMP_INIT = 2;
    localparam COMP_FIND_MAX = 3;
    localparam COMP_ADD = 4;
    localparam COMP_REMOVE = 5;
    localparam COMP_CHECK = 6;
    localparam OUT_SORT = 7;
    localparam OUT_SEND = 8;
    localparam FINISH = 9;

    reg [3:0] state, next_state;

    reg [9:0] s_ids [0:15];
    reg [9:0] l_ids [0:15];
    reg [3:0] s_cnt, l_cnt;
    reg edges [0:15][0:15];
    
    reg [4:0] max_v_idx;
    reg [4:0] max_deg;
    reg [4:0] cur_deg;
    reg [4:0] iter_v;
    reg [4:0] iter_r, iter_c;
    reg [15:0] cov_s, cov_l;
    reg [4:0] cov_s_cnt, cov_l_cnt;
    
    reg [4:0] sort_i, sort_j;
    reg [9:0] swap_temp;
    reg [9:0] temp_results [0:15];
    reg [4:0] temp_res_cnt;
    
    reg friend_in_s;
    reg friend_in_l;
    reg friend_selected;

    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INPUT;
            INPUT: if (team_done) next_state = COMP_INIT;
            COMP_INIT: next_state = COMP_FIND_MAX;
            COMP_FIND_MAX: if (iter_v >= 32) next_state = (max_deg == 0) ? OUT_SORT : COMP_ADD;
            COMP_ADD: next_state = COMP_REMOVE;
            COMP_REMOVE: if (iter_r >= 16 && iter_c >= 16) next_state = COMP_CHECK;
            COMP_CHECK: next_state = COMP_FIND_MAX;
            OUT_SORT: if (sort_i > temp_res_cnt) next_state = OUT_SEND;
            OUT_SEND: if (sort_i > temp_res_cnt) next_state = FINISH;
            FINISH: next_state = FINISH;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_valid <= 0; done <= 0; result_count <= 0;
            s_cnt <= 0; l_cnt <= 0;
            cov_s <= 0; cov_l <= 0; cov_s_cnt <= 0; cov_l_cnt <= 0;
            friend_selected <= 0; friend_in_s <= 0; friend_in_l <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) edges[i][j] <= 0;
                result_ids[i] <= 0;
                temp_results[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 0; done <= 0;
                end
                INPUT: begin
                    if (team_valid) begin
                        reg [3:0] s_idx, l_idx;
                        reg s_found, l_found;
                        s_found = 0; l_found = 0;
                        for (int k = 0; k < 16; k++) begin
                            if (s_ids[k] == team_stockholm) begin s_idx = k; s_found = 1; end
                            if (l_ids[k] == team_london) begin l_idx = k; l_found = 1; end
                        end
                        if (!s_found && s_cnt < 16 && team_stockholm != 0) begin
                            s_idx = s_cnt;
                            s_ids[s_cnt] <= team_stockholm;
                            s_cnt <= s_cnt + 1;
                            if (team_stockholm == FRIEND_ID) begin friend_in_s <= 1; end
                        end
                        if (!l_found && l_cnt < 16 && team_london != 0) begin
                            l_idx = l_cnt;
                            l_ids[l_cnt] <= team_london;
                            l_cnt <= l_cnt + 1;
                            if (team_london == FRIEND_ID) begin friend_in_l <= 1; end
                        end
                        if (team_stockholm != 0 && team_london != 0) begin
                            edges[s_idx][l_idx] <= 1;
                        end
                    end
                end
                COMP_INIT: begin
                    iter_v <= 0;
                    max_deg <= 0;
                    max_v_idx <= 0;
                end
                COMP_FIND_MAX: begin
                    if (iter_v < 32) begin
                        reg in_cover = 0;
                        if (iter_v < 16) in_cover = cov_s[iter_v];
                        else in_cover = cov_l[iter_v - 16];
                        if (!in_cover) begin
                            reg is_friend = 0;
                            if (friend_in_s && iter_v < 16 && s_ids[iter_v] == FRIEND_ID) is_friend = 1;
                            if (friend_in_l && iter_v >= 16 && l_ids[iter_v - 16] == FRIEND_ID) is_friend = 1;
                            reg max_is_friend = 0;
                            if (friend_in_s && max_v_idx < 16 && s_ids[max_v_idx] == FRIEND_ID) max_is_friend = 1;
                            if (friend_in_l && max_v_idx >= 16 && l_ids[max_v_idx - 16] == FRIEND_ID) max_is_friend = 1;
                            if (cur_deg > max_deg) begin
                                max_deg <= cur_deg;
                                max_v_idx <= iter_v;
                            end else if (cur_deg == max_deg && cur_deg != 0) begin
                                if (is_friend && !max_is_friend) begin
                                    max_deg <= cur_deg;
                                    max_v_idx <= iter_v;
                                end
                            end
                        end
                        iter_v <= iter_v + 1;
                    end
                end
                COMP_ADD: begin
                    if (max_v_idx < 16) begin
                        cov_s[max_v_idx] <= 1;
                        cov_s_cnt <= cov_s_cnt + 1;
                    end else begin
                        cov_l[max_v_idx - 16] <= 1;
                        cov_l_cnt <= cov_l_cnt + 1;
                    end
                    iter_r <= 0;
                    iter_c <= 0;
                end
                COMP_REMOVE: begin
                    if (iter_r < 16 && iter_c < 16) begin
                        if (max_v_idx < 16) begin
                            if (iter_r == max_v_idx) edges[iter_r][iter_c] <= 0;
                        end else begin
                            if (iter_c == (max_v_idx - 16)) edges[iter_r][iter_c] <= 0;
                        end
                        if (iter_c == 15) begin
                            iter_c <= 0;
                            iter_r <= iter_r + 1;
                        end else begin
                            iter_c <= iter_c + 1;
                        end
                    end
                end
                COMP_CHECK: begin
                    iter_v <= 0;
                    max_deg <= 0;
                    max_v_idx <= 0;
                end
                OUT_SORT: begin
                    if (sort_i == 0) begin
                        temp_res_cnt <= 0;
                        for (int k = 0; k < 16; k++) begin
                            if (cov_s[k]) begin
                                temp_results[temp_res_cnt] <= s_ids[k];
                                temp_res_cnt <= temp_res_cnt + 1;
                            end
                        end
                        for (int k = 0; k < 16; k++) begin
                            if (cov_l[k]) begin
                                temp_results[temp_res_cnt] <= l_ids[k];
                                temp_res_cnt <= temp_res_cnt + 1;
                            end
                        end
                        sort_i <= 1;
                        sort_j <= 0;
                    end else begin
                        if (sort_j < temp_res_cnt - 1) begin
                            if (temp_results[sort_j] > temp_results[sort_j + 1]) begin
                                swap_temp <= temp_results[sort_j];
                                temp_results[sort_j] <= temp_results[sort_j + 1];
                                temp_results[sort_j + 1] <= swap_temp;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_i <= sort_i + 1;
                            sort_j <= 0;
                        end
                    end
                end
                OUT_SEND: begin
                    result_count <= temp_res_cnt;
                    for (int k = 0; k < 16; k++) begin
                        result_ids[k] <= temp_results[k];
                    end
                    result_valid <= 1;
                    done <= 1;
                    sort_i <= sort_i + 1;
                end
                FINISH: begin
                    done <= 1;
                end
            endcase
        end
    end

    always @(*) begin
        cur_deg = 0;
        if (state == COMP_FIND_MAX && iter_v < 32) begin
            if (iter_v < 16) begin
                for (int c = 0; c < 16; c++) begin
                    if (edges[iter_v][c]) cur_deg = cur_deg + 1;
                end
            end else begin
                for (int r = 0; r < 16; r++) begin
                    if (edges[r][iter_v - 16]) cur_deg = cur_deg + 1;
                end
            end
        end
    end

endmodule