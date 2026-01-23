module cheapest_price (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] mag_data [3:0],
    input wire [1:0] mag_len [3:0],
    output reg [3:0] result_digits [11:0],
    output reg [3:0] result_len,
    output reg result_valid
);

localparam MAX_MAGNETS = 4;
localparam MAX_DIGITS_PER_MAG = 3;
localparam MAX_TOTAL_DIGITS = 12;
localparam DIGIT_WIDTH = 4;

localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_LOAD = 4'd1;
localparam [3:0] S_COMB_START = 4'd2;
localparam [3:0] S_COMB_SELECT = 4'd3;
localparam [3:0] S_SORT = 4'd4;
localparam [3:0] S_CONCAT = 4'd5;
localparam [3:0] S_COMPARE = 4'd6;
localparam [3:0] S_UPDATE = 4'd7;
localparam [3:0] S_NEXT_COMB = 4'd8;
localparam [3:0] S_DONE = 4'd9;

reg [3:0] state;

reg [11:0] orig_data [3:0];
reg [1:0] orig_len [3:0];

reg [11:0] flip_data [3:0];
reg [1:0] flip_len [3:0];
reg flip_valid [3:0];

reg [3:0] comb;

reg [11:0] sel_data [3:0];
reg [1:0] sel_len [3:0];

reg [11:0] sorted_data [3:0];
reg [1:0] sorted_len [3:0];

reg [3:0] cand_digits [11:0];
reg [3:0] cand_len;

reg [3:0] best_digits [11:0];
reg [3:0] best_len;
reg best_valid;

reg [3:0] i_temp;
reg [3:0] j_temp;
reg [3:0] pos_temp;
reg cmp_result;
reg better_result;

function automatic is_flippable_digit(input [3:0] d);
    is_flippable_digit = (d == 4'd0 || d == 4'd1 || d == 4'd6 || d == 4'd8 || d == 4'd9);
endfunction

function automatic [3:0] flip_digit(input [3:0] d);
    case (d)
        4'd0: flip_digit = 4'd0;
        4'd1: flip_digit = 4'd1;
        4'd6: flip_digit = 4'd9;
        4'd8: flip_digit = 4'd8;
        4'd9: flip_digit = 4'd6;
        default: flip_digit = 4'd15;
    endcase
endfunction

function automatic [3:0] get_digit(input [11:0] data, input [1:0] len, input [3:0] idx);
    if (idx < len)
        get_digit = data[idx*DIGIT_WIDTH +: DIGIT_WIDTH];
    else
        get_digit = 4'd0;
endfunction

function automatic compare_strings(input [11:0] dataA, input [1:0] lenA, input [11:0] dataB, input [1:0] lenB);
    reg [3:0] concatA [5:0];
    reg [3:0] concatB [5:0];
    integer k;
    begin
        for (k = 0; k < 6; k = k + 1) begin
            if (k < lenA)
                concatA[k] = get_digit(dataA, lenA, k);
            else if (k < lenA + lenB)
                concatA[k] = get_digit(dataB, lenB, k - lenA);
            else
                concatA[k] = 4'd0;
        end
        for (k = 0; k < 6; k = k + 1) begin
            if (k < lenB)
                concatB[k] = get_digit(dataB, lenB, k);
            else if (k < lenB + lenA)
                concatB[k] = get_digit(dataA, lenA, k - lenB);
            else
                concatB[k] = 4'd0;
        end
        for (k = 0; k < 6; k = k + 1) begin
            if (concatA[k] < concatB[k]) begin
                compare_strings = 1;
                return;
            end else if (concatA[k] > concatB[k]) begin
                compare_strings = 0;
                return;
            end
        end
        compare_strings = 1;
    end
endfunction

function automatic candidate_better;
    integer k;
    begin
        if (!best_valid) begin
            candidate_better = 1;
            return;
        end
        if (cand_len < best_len) begin
            candidate_better = 1;
            return;
        end else if (cand_len > best_len) begin
            candidate_better = 0;
            return;
        end
        for (k = 0; k < cand_len; k = k + 1) begin
            if (cand_digits[k] < best_digits[k]) begin
                candidate_better = 1;
                return;
            end else if (cand_digits[k] > best_digits[k]) begin
                candidate_better = 0;
                return;
            end
        end
        candidate_better = 0;
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        result_valid <= 1'b0;
        best_valid <= 1'b0;
        comb <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_LOAD;
                    result_valid <= 1'b0;
                    best_valid <= 1'b0;
                    comb <= 4'd0;
                end
            end
            S_LOAD: begin
                for (i_temp = 0; i_temp < MAX_MAGNETS; i_temp = i_temp + 1) begin
                    orig_data[i_temp] <= mag_data[i_temp];
                    orig_len[i_temp] <= mag_len[i_temp];
                    flip_valid[i_temp] <= 1'b1;
                    flip_len[i_temp] <= mag_len[i_temp];
                    for (j_temp = 0; j_temp < MAX_DIGITS_PER_MAG; j_temp = j_temp + 1) begin
                        if (j_temp < mag_len[i_temp]) begin
                            if (!is_flippable_digit(mag_data[i_temp][j_temp*DIGIT_WIDTH +: DIGIT_WIDTH])) begin
                                flip_valid[i_temp] <= 1'b0;
                            end
                            flip_data[i_temp][(mag_len[i_temp]-1-j_temp)*DIGIT_WIDTH +: DIGIT_WIDTH] <= flip_digit(mag_data[i_temp][j_temp*DIGIT_WIDTH +: DIGIT_WIDTH]);
                        end
                    end
                end
                state <= S_COMB_START;
            end
            S_COMB_START: begin
                comb <= 4'd0;
                state <= S_COMB_SELECT;
            end
            S_COMB_SELECT: begin
                for (i_temp = 0; i_temp < MAX_MAGNETS; i_temp = i_temp + 1) begin
                    if (comb[i_temp] && flip_valid[i_temp]) begin
                        sel_data[i_temp] <= flip_data[i_temp];
                        sel_len[i_temp] <= flip_len[i_temp];
                    end else begin
                        sel_data[i_temp] <= orig_data[i_temp];
                        sel_len[i_temp] <= orig_len[i_temp];
                    end
                end
                state <= S_SORT;
            end
            S_SORT: begin
                if (!compare_strings(sel_data[0], sel_len[0], sel_data[1], sel_len[1])) begin
                    sel_data[0] <= sel_data[1];
                    sel_len[0] <= sel_len[1];
                    sel_data[1] <= sel_data[0];
                    sel_len[1] <= sel_len[0];
                end
                state <= S_SORT_2;
            end
            S_SORT_2: begin
                if (!compare_strings(sel_data[1], sel_len[1], sel_data[2], sel_len[2])) begin
                    sel_data[1] <= sel_data[2];
                    sel_len[1] <= sel_len[2];
                    sel_data[2] <= sel_data[1];
                    sel_len[2] <= sel_len[1];
                end
                state <= S_SORT_3;
            end
            S_SORT_3: begin
                if (!compare_strings(sel_data[2], sel_len[2], sel_data[3], sel_len[3])) begin
                    sel_data[2] <= sel_data[3];
                    sel_len[2] <= sel_len[3];
                    sel_data[3] <= sel_data[2];
                    sel_len[3] <= sel_len[2];
                end
                state <= S_SORT_4;
            end
            S_SORT_4: begin
                if (!compare_strings(sel_data[0], sel_len[0], sel_data[1], sel_len[1])) begin
                    sel_data[0] <= sel_data[1];
                    sel_len[0] <= sel_len[1];
                    sel_data[1] <= sel_data[0];
                    sel_len[1] <= sel_len[0];
                end
                state <= S_SORT_5;
            end
            S_SORT_5: begin
                if (!compare_strings(sel_data[1], sel_len[1], sel_data[2], sel_len[2])) begin
                    sel_data[1] <= sel_data[2];
                    sel_len[1] <= sel_len[2];
                    sel_data[2] <= sel_data[1];
                    sel_len[2] <= sel_len[1];
                end
                for (i_temp = 0; i_temp < MAX_MAGNETS; i_temp = i_temp + 1) begin
                    sorted_data[i_temp] <= sel_data[i_temp];
                    sorted_len[i_temp] <= sel_len[i_temp];
                end
                state <= S_CONCAT;
            end
            S_CONCAT: begin
                pos_temp = 0;
                for (i_temp = 0; i_temp < MAX_MAGNETS; i_temp = i_temp + 1) begin
                    for (j_temp = 0; j_temp < MAX_DIGITS_PER_MAG; j_temp = j_temp + 1) begin
                        if (j_temp < sorted_len[i_temp]) begin
                            cand_digits[pos_temp] <= get_digit(sorted_data[i_temp], sorted_len[i_temp], j_temp);
                            pos_temp = pos_temp + 1;
                        end
                    end
                end
                cand_len <= pos_temp;
                state <= S_COMPARE;
            end
            S_COMPARE: begin
                better_result = candidate_better;
                if (better_result)
                    state <= S_UPDATE;
                else
                    state <= S_NEXT_COMB;
            end
            S_UPDATE: begin
                for (i_temp = 0; i_temp < MAX_TOTAL_DIGITS; i_temp = i_temp + 1) begin
                    best_digits[i_temp] <= cand_digits[i_temp];
                end
                best_len <= cand_len;
                best_valid <= 1'b1;
                state <= S_NEXT_COMB;
            end
            S_NEXT_COMB: begin
                if (comb == 4'b1111) begin
                    state <= S_DONE;
                end else begin
                    comb <= comb + 4'd1;
                    state <= S_COMB_SELECT;
                end
            end
            S_DONE: begin
                for (i_temp = 0; i_temp < MAX_TOTAL_DIGITS; i_temp = i_temp + 1) begin
                    result_digits[i_temp] <= best_digits[i_temp];
                end
                result_len <= best_len;
                result_valid <= 1'b1;
                state <= S_IDLE;
            end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule