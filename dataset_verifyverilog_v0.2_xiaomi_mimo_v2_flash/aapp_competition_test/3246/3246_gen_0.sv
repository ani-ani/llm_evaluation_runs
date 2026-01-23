module text_decipher(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [7:0] dict_word [0:7][0:7],
    input [3:0] dict_size,
    input [3:0] input_length,
    output reg [7:0] result [0:31],
    output reg [1:0] status,
    output reg done
);

    // State definitions
    localparam IDLE = 5'd0;
    localparam LOAD_DICT = 5'd1;
    localparam LOAD_STRING = 5'd2;
    localparam DP_INIT = 5'd3;
    localparam DP_LOOP_I = 5'd4;
    localparam SCAN_LEN = 5'd5;
    localparam PREP_SORT = 5'd6;
    localparam SORT_LOOP = 5'd7;
    localparam LOAD_SUBSTRING = 5'd8;
    localparam SORT_SUB_LOOP = 5'd9;
    localparam COMPARE_SORTED = 5'd10;
    localparam UPDATE_DP = 5'd11;
    localparam CHECK_UNIQUE = 5'd12;
    localparam BUILD_FIND_START = 5'd13;
    localparam BUILD_RECONSTRUCT = 5'd14;
    localparam CHECK_MATCH_RECON = 5'd15;
    localparam PREP_SORT_RECON = 5'd16;
    localparam SORT_LOOP_RECON = 5'd17;
    localparam LOAD_SUBSTRING_RECON = 5'd18;
    localparam SORT_SUB_LOOP_RECON = 5'd19;
    localparam COMPARE_SORTED_RECON = 5'd20;
    localparam BUILD_RECONSTRUCT_LOOP = 5'd21;
    localparam APPEND_WORD = 5'd22;
    localparam ADD_SPACE = 5'd23;
    localparam DONE = 5'd24;

    reg [4:0] state;

    // Internal Memory
    reg [7:0] input_str [0:15];
    reg [7:0] internal_dict [0:7][0:7];
    reg [3:0] str_idx;
    reg [3:0] dict_idx;
    reg [3:0] dict_len_idx;
    
    // DP
    reg [31:0] dp [0:16];
    reg [3:0] dp_i;
    reg [3:0] dp_w;
    reg [3:0] word_len;
    reg match_found;
    
    // Sorting
    reg [7:0] sort_buf [0:6];
    reg [7:0] sub_buf [0:6];
    reg [3:0] sort_len;
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp_char;
    
    // Reconstruction
    reg [3:0] curr_pos;
    reg [3:0] temp_w_idx;
    reg [3:0] char_copy_idx;
    reg path_found;
    reg [3:0] res_idx;

    // 1-Process FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            status <= 0;
            str_idx <= 0;
            dict_idx <= 0;
            res_idx <= 0;
            dp_i <= 1;
            dp_w <= 0;
            curr_pos <= 0;
            for (int i = 0; i < 32; i++) result[i] <= 8'hFF;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    status <= 0;
                    str_idx <= 0;
                    dict_idx <= 0;
                    if (start) state <= LOAD_DICT;
                end

                LOAD_DICT: begin
                    if (dict_idx < dict_size) begin
                        internal_dict[dict_idx] <= dict_word[dict_idx];
                        dict_idx <= dict_idx + 1;
                    end else begin
                        state <= LOAD_STRING;
                    end
                end

                LOAD_STRING: begin
                    if (str_idx < input_length) begin
                        input_str[str_idx] <= char_in;
                        str_idx <= str_idx + 1;
                    end else begin
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    dp[0] <= 1;
                    for (int k = 1; k <= 16; k++) dp[k] <= 0;
                    dp_i <= 1;
                    dp_w <= 0;
                    dict_len_idx <= 0;
                    state <= DP_LOOP_I;
                end

                DP_LOOP_I: begin
                    if (dp_i > input_length) begin
                        state <= CHECK_UNIQUE;
                    end else if (dp_w < dict_size) begin
                        state <= SCAN_LEN;
                        dict_len_idx <= 0;
                        word_len <= 0;
                    end else begin
                        // Done with this i, move to next
                        dp_i <= dp_i + 1;
                        dp_w <= 0;
                        // Stay in DP_LOOP_I to check condition next cycle
                    end
                end

                SCAN_LEN: begin
                    if (internal_dict[dp_w][dict_len_idx] != 8'hFF) begin
                        dict_len_idx <= dict_len_idx + 1;
                        word_len <= dict_len_idx + 1;
                    end else begin
                        if (dp_i >= word_len && word_len > 0) begin
                            if (internal_dict[dp_w][0] == input_str[dp_i - word_len] && 
                                internal_dict[dp_w][word_len - 1] == input_str[dp_i - 1]) begin
                                sort_len <= (word_len >= 2) ? word_len - 2 : 0;
                                sort_i <= 0;
                                sort_j <= 0;
                                if (word_len <= 2) state <= LOAD_SUBSTRING; // Skip sort, directly to load/compare logic (optimized path)
                                else state <= PREP_SORT;
                            end else begin
                                state <= UPDATE_DP; // No match
                                match_found <= 0;
                            end
                        end else begin
                            state <= UPDATE_DP; // Too long
                            match_found <= 0;
                        end
                    end
                end

                PREP_SORT: begin
                    if (sort_i < sort_len) begin
                        sort_buf[sort_i] <= internal_dict[dp_w][sort_i + 1];
                        sort_i <= sort_i + 1;
                    end else begin
                        sort_i <= 0;
                        sort_j <= 0;
                        if (sort_len > 1) state <= SORT_LOOP;
                        else state <= LOAD_SUBSTRING;
                    end
                end

                SORT_LOOP: begin
                    if (sort_j < sort_len - 1 - sort_i) begin
                        if (sort_buf[sort_j] > sort_buf[sort_j + 1]) begin
                            temp_char <= sort_buf[sort_j];
                            sort_buf[sort_j] <= sort_buf[sort_j + 1];
                            sort_buf[sort_j + 1] <= temp_char;
                        end
                        sort_j <= sort_j + 1;
                    end else begin
                        sort_j <= 0;
                        sort_i <= sort_i + 1;
                        if (sort_i >= sort_len - 1) state <= LOAD_SUBSTRING;
                    end
                end

                LOAD_SUBSTRING: begin
                    if (sort_i < sort_len) begin
                        sub_buf[sort_i] <= input_str[dp_i - word_len + 1 + sort_i];
                        sort_i <= sort_i + 1;
                    end else begin
                        sort_i <= 0;
                        sort_j <= 0;
                        if (sort_len > 1) state <= SORT_SUB_LOOP;
                        else state <= COMPARE_SORTED;
                    end
                end

                SORT_SUB_LOOP: begin
                    if (sort_j < sort_len - 1 - sort_i) begin
                        if (sub_buf[sort_j] > sub_buf[sort_j + 1]) begin
                            temp_char <= sub_buf[sort_j];
                            sub_buf[sort_j] <= sub_buf[sort_j + 1];
                            sub_buf[sort_j + 1] <= temp_char;
                        end
                        sort_j <= sort_j + 1;
                    end else begin
                        sort_j <= 0;
                        sort_i <= sort_i + 1;
                        if (sort_i >= sort_len - 1) state <= COMPARE_SORTED;
                    end
                end

                COMPARE_SORTED: begin
                    if (sort_i < sort_len) begin
                        if (sort_buf[sort_i] != sub_buf[sort_i]) begin
                            match_found <= 0;
                            state <= UPDATE_DP;
                        end else begin
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        match_found <= 1;
                        state <= UPDATE_DP;
                    end
                end

                UPDATE_DP: begin
                    if (match_found) begin
                        dp[dp_i] <= dp[dp_i] + dp[dp_i - word_len];
                    end
                    dp_w <= dp_w + 1;
                    state <= DP_LOOP_I;
                end

                CHECK_UNIQUE: begin
                    if (dp[input_length] == 0) status <= 2;
                    else if (dp[input_length] > 1) status <= 3;
                    else status <= 1;
                    
                    if (dp[input_length] != 1) state <= DONE;
                    else begin
                        curr_pos <= 0;
                        res_idx <= 0;
                        temp_w_idx <= 0;
                        state <= BUILD_FIND_START;
                    end
                end

                BUILD_FIND_START: begin
                    if (curr_pos == input_length) begin
                        if (res_idx < 32) result[res_idx] <= 8'h00;
                        state <= DONE;
                        done <= 1;
                    end else begin
                        temp_w_idx <= 0;
                        state <= BUILD_RECONSTRUCT;
                    end
                end

                BUILD_RECONSTRUCT: begin
                    dict_len_idx <= 0;
                    if (temp_w_idx < dict_size) state <= CHECK_MATCH_RECON;
                    else state <= DONE; // Failsafe
                end

                CHECK_MATCH_RECON: begin
                    if (internal_dict[temp_w_idx][dict_len_idx] != 8'hFF) begin
                        dict_len_idx <= dict_len_idx + 1;
                        word_len <= dict_len_idx + 1;
                    end else begin
                        if (curr_pos + word_len <= input_length && word_len > 0) begin
                            if (internal_dict[temp_w_idx][0] == input_str[curr_pos] && 
                                internal_dict[temp_w_idx][word_len - 1] == input_str[curr_pos + word_len - 1]) begin
                                sort_len <= (word_len >= 2) ? word_len - 2 : 0;
                                sort_i <= 0;
                                sort_j <= 0;
                                if (word_len <= 2) state <= COMPARE_SORTED_RECON;
                                else state <= PREP_SORT_RECON;
                            end else begin
                                state <= BUILD_RECONSTRUCT_LOOP;
                                path_found <= 0;
                            end
                        end else begin
                            state <= BUILD_RECONSTRUCT_LOOP;
                            path_found <= 0;
                        end
                    end
                end

                PREP_SORT_RECON: begin
                    if (sort_i < sort_len) begin
                        sort_buf[sort_i] <= internal_dict[temp_w_idx][sort_i + 1];
                        sort_i <= sort_i + 1;
                    end else begin
                        sort_i <= 0;
                        sort_j <= 0;
                        if (sort_len > 1) state <= SORT_LOOP_RECON;
                        else state <= LOAD_SUBSTRING_RECON;
                    end
                end

                SORT_LOOP_RECON: begin
                    if (sort_j < sort_len - 1 - sort_i) begin
                        if (sort_buf[sort_j] > sort_buf[sort_j + 1]) begin
                            temp_char <= sort_buf[sort_j];
                            sort_buf[sort_j] <= sort_buf[sort_j + 1];
                            sort_buf[sort_j + 1] <= temp_char;
                        end
                        sort_j <= sort_j + 1;
                    end else begin
                        sort_j <= 0;
                        sort_i <= sort_i + 1;
                        if (sort_i >= sort_len - 1) state <= LOAD_SUBSTRING_RECON;
                    end
                end

                LOAD_SUBSTRING_RECON: begin
                    if (sort_i < sort_len) begin
                        sub_buf[sort_i] <= input_str[curr_pos + 1 + sort_i];
                        sort_i <= sort_i + 1;
                    end else begin
                        sort_i <= 0;
                        sort_j <= 0;
                        if (sort_len > 1) state <= SORT_SUB_LOOP_RECON;
                        else state <= COMPARE_SORTED_RECON;
                    end
                end

                SORT_SUB_LOOP_RECON: begin
                    if (sort_j < sort_len - 1 - sort_i) begin
                        if (sub_buf[sort_j] > sub_buf[sort_j + 1]) begin
                            temp_char <= sub_buf[sort_j];
                            sub_buf[sort_j] <= sub_buf[sort_j + 1];
                            sub_buf[sort_j + 1] <= temp_char;
                        end
                        sort_j <= sort_j + 1;
                    end else begin
                        sort_j <= 0;
                        sort_i <= sort_i + 1;
                        if (sort_i >= sort_len - 1) state <= COMPARE_SORTED_RECON;
                    end
                end

                COMPARE_SORTED_RECON: begin
                    if (sort_i < sort_len) begin
                        if (sort_buf[sort_i] != sub_buf[sort_i]) begin
                            path_found <= 0;
                            state <= BUILD_RECONSTRUCT_LOOP;
                        end else begin
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        path_found <= 1;
                        state <= BUILD_RECONSTRUCT_LOOP;
                    end
                end

                BUILD_RECONSTRUCT_LOOP: begin
                    if (path_found) begin
                        char_copy_idx <= 0;
                        state <= APPEND_WORD;
                    end else begin
                        if (temp_w_idx < dict_size - 1) begin
                            temp_w_idx <= temp_w_idx + 1;
                            state <= BUILD_RECONSTRUCT;
                        end else begin
                            state <= DONE; // Should not happen
                        end
                    end
                end

                APPEND_WORD: begin
                    if (char_copy_idx < word_len) begin
                        result[res_idx] <= input_str[curr_pos + char_copy_idx];
                        res_idx <= res_idx + 1;
                        char_copy_idx <= char_copy_idx + 1;
                    end else begin
                        curr_pos <= curr_pos + word_len;
                        state <= ADD_SPACE;
                    end
                end

                ADD_SPACE: begin
                    if (curr_pos < input_length) begin
                        result[res_idx] <= 8'h20;
                        res_idx <= res_idx + 1;
                    end
                    state <= BUILD_FIND_START;
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end
endmodule