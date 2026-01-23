module cheapest_price (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] mag_data [3:0],
    input wire [1:0]  mag_len  [3:0],
    output reg [3:0]  result_digits [11:0],
    output reg [3:0]  result_len,
    output reg        result_valid
);

localparam MAX_MAGNETS = 4;
localparam MAX_DIGITS_PER_MAG = 3;
localparam MAX_TOTAL_DIGITS = MAX_MAGNETS * MAX_DIGITS_PER_MAG;
localparam DIGIT_WIDTH = 4;

localparam S_IDLE = 0;
localparam S_LOAD = 1;
localparam S_COMB_START = 2;
localparam S_COMB_SELECT = 3;
localparam S_SORT = 4;
localparam S_CONCAT = 5;
localparam S_COMPARE = 6;
localparam S_UPDATE = 7;
localparam S_NEXT_COMB = 8;
localparam S_DONE = 9;

reg [3:0] state;

reg [11:0] orig_data [3:0];
reg [1:0]  orig_len  [3:0];

reg [11:0] flip_data [3:0];
reg [1:0]  flip_len  [3:0];
reg        flip_valid [3:0];

reg [3:0] comb;

reg [11:0] sel_data [3:0];
reg [1:0]  sel_len  [3:0];

reg [11:0] sorted_data [3:0];
reg [1:0]  sorted_len  [3:0];

reg [3:0] cand_digits [11:0];
reg [3:0] cand_len;

reg [3:0] best_digits [11:0];
reg [3:0] best_len;
reg       best_valid;

function automatic is_flippable_digit(input [3:0] d);
begin
    is_flippable_digit = (d == 4'd0 || d == 4'd1 || d == 4'd6 || d == 4'd8 || d == 4'd9);
end
endfunction

function automatic [3:0] flip_digit(input [3:0] d);
begin
    case (d)
        4'd0: flip_digit = 4'd0;
        4'd1: flip_digit = 4'd1;
        4'd6: flip_digit = 4'd9;
        4'd8: flip_digit = 4'd8;
        4'd9: flip_digit = 4'd6;
        default: flip_digit = 4'd15;
    endcase
end
endfunction

task automatic compute_flip(input [11:0] data_in, input [1:0] len_in,
                            output [11:0] data_out, output [1:0] len_out, output valid);
    integer i;
    reg [3:0] d;
begin
    valid = 1;
    len_out = len_in;
    for (i = 0; i < MAX_DIGITS_PER_MAG; i = i + 1) begin
        if (i < len_in) begin
            d = data_in[ (i*DIGIT_WIDTH) +: DIGIT_WIDTH ];
            if (!is_flippable_digit(d)) begin
                valid = 0;
                data_out = 12'd0;
                len_out = 2'd0;
                return;
            end
            data_out[ ((len_in-1-i)*DIGIT_WIDTH) +: DIGIT_WIDTH ] = flip_digit(d);
        end else begin
            data_out[ (i*DIGIT_WIDTH) +: DIGIT_WIDTH ] = 4'd0;
        end
    end
end
endtask

function automatic [3:0] get_digit(input [11:0] data, input [1:0] len, input integer idx);
begin
    if (idx < len)
        get_digit = data[ (idx*DIGIT_WIDTH) +: DIGIT_WIDTH ];
    else
        get_digit = 4'd0;
end
endfunction

function automatic compare_strings(input [11:0] dataA, input [1:0] lenA,
                                   input [11:0] dataB, input [1:0] lenB);
    integer i;
    reg [3:0] concatA [5:0];
    reg [3:0] concatB [5:0];
    integer totalA, totalB;
begin
    totalA = lenA + lenB;
    totalB = lenB + lenA;
    for (i = 0; i < 6; i = i + 1) begin
        if (i < lenA) begin
            concatA[i] = get_digit(dataA, lenA, i);
        end else if (i < totalA) begin
            concatA[i] = get_digit(dataB, lenB, i - lenA);
        end else begin
            concatA[i] = 4'd0;
        end
    end
    for (i = 0; i < 6; i = i + 1) begin
        if (i < lenB) begin
            concatB[i] = get_digit(dataB, lenB, i);
        end else if (i < totalB) begin
            concatB[i] = get_digit(dataA, lenA, i - lenB);
        end else begin
            concatB[i] = 4'd0;
        end
    end
    for (i = 0; i < 6; i = i + 1) begin
        if (concatA[i] < concatB[i]) begin
            compare_strings = 1;
            return;
        end else if (concatA[i] > concatB[i]) begin
            compare_strings = 0;
            return;
        end
    end
    compare_strings = 1;
end
endfunction

task automatic swap_strings(inout [11:0] data1, inout [1:0] len1,
                            inout [11:0] data2, inout [1:0] len2);
    reg [11:0] tmp_data;
    reg [1:0] tmp_len;
begin
    tmp_data = data1; tmp_len = len1;
    data1 = data2; len1 = len2;
    data2 = tmp_data; len2 = tmp_len;
end
endtask

task automatic concatenate_sorted;
    integer i, pos;
begin
    pos = 0;
    for (i = 0; i < MAX_MAGNETS; i = i + 1) begin
        if (sorted_len[i] > 0) begin
            for (integer j = 0; j < sorted_len[i]; j = j + 1) begin
                cand_digits[pos] = get_digit(sorted_data[i], sorted_len[i], j);
                pos = pos + 1;
            end
        end
    end
    cand_len = pos;
end
endtask

function automatic candidate_better;
    integer i;
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
    for (i = 0; i < cand_len; i = i + 1) begin
        if (cand_digits[i] < best_digits[i]) begin
            candidate_better = 1;
            return;
        end else if (cand_digits[i] > best_digits[i]) begin
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
        result_valid <= 0;
        best_valid <= 0;
        comb <= 4'd0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_LOAD;
                    result_valid <= 0;
                    best_valid <= 0;
                    comb <= 4'd0;
                end
            end
            S_LOAD: begin
                for (integer i = 0; i < MAX_MAGNETS; i = i + 1) begin
                    orig_data[i] <= mag_data[i];
                    orig_len[i]  <= mag_len[i];
                    compute_flip(mag_data[i], mag_len[i], flip_data[i], flip_len[i], flip_valid[i]);
                end
                state <= S_COMB_START;
            end
            S_COMB_START: begin
                comb <= 4'd0;
                state <= S_COMB_SELECT;
            end
            S_COMB_SELECT: begin
                for (integer i = 0; i < MAX_MAGNETS; i = i + 1) begin
                    if (comb[i] && flip_valid[i]) begin
                        sel_data[i] <= flip_data[i];
                        sel_len[i]  <= flip_len[i];
                    end else begin
                        sel_data[i] <= orig_data[i];
                        sel_len[i]  <= orig_len[i];
                    end
                end
                state <= S_SORT;
            end
            S_SORT: begin
                if (compare_strings(sel_data[0], sel_len[0], sel_data[1], sel_len[1])) begin
                end else begin
                    swap_strings(sel_data[0], sel_len[0], sel_data[1], sel_len[1]);
                end
                if (compare_strings(sel_data[1], sel_len[1], sel_data[2], sel_len[2])) begin
                end else begin
                    swap_strings(sel_data[1], sel_len[1], sel_data[2], sel_len[2]);
                end
                if (compare_strings(sel_data[2], sel_len[2], sel_data[3], sel_len[3])) begin
                end else begin
                    swap_strings(sel_data[2], sel_len[2], sel_data[3], sel_len[3]);
                end
                if (compare_strings(sel_data[0], sel_len[0], sel_data[1], sel_len[1])) begin
                end else begin
                    swap_strings(sel_data[0], sel_len[0], sel_data[1], sel_len[1]);
                end
                if (compare_strings(sel_data[1], sel_len[1], sel_data[2], sel_len[2])) begin
                end else begin
                    swap_strings(sel_data[1], sel_len[1], sel_data[2], sel_len[2]);
                end
                for (integer i = 0; i < MAX_MAGNETS; i = i + 1) begin
                    sorted_data[i] <= sel_data[i];
                    sorted_len[i]  <= sel_len[i];
                end
                state <= S_CONCAT;
            end
            S_CONCAT: begin
                concatenate_sorted;
                state <= S_COMPARE;
            end
            S_COMPARE: begin
                if (candidate_better) begin
                    state <= S_UPDATE;
                end else begin
                    state <= S_NEXT_COMB;
                end
            end
            S_UPDATE: begin
                for (integer i = 0; i < MAX_TOTAL_DIGITS; i = i + 1) begin
                    best_digits[i] <= cand_digits[i];
                end
                best_len <= cand_len;
                best_valid <= 1;
                state <= S_NEXT_COMB;
            end
            S_NEXT_COMB: begin
                if (comb == 4'b1111) begin
                    state <= S_DONE;
                end else begin
                    comb <= comb + 1;
                    state <= S_COMB_SELECT;
                end
            end
            S_DONE: begin
                for (integer i = 0; i < MAX_TOTAL_DIGITS; i = i + 1) begin
                    result_digits[i] <= best_digits[i];
                end
                result_len <= best_len;
                result_valid <= 1;
                state <= S_IDLE;
            end
            default: state <= S_IDLE;
        endcase
    end
end

endmodule