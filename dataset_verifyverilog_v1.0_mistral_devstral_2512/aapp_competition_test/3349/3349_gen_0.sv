module no_vowels_reconstructor(
    input clk,
    input rst_n,
    input start,
    input [127:0] message,
    input [4:0] msg_len,
    input [255:0] skeleton_chars,
    input [15:0] skeleton_len,
    input [15:0] vowel_count,
    input [3:0] num_words,
    output reg word_valid,
    output reg [1:0] word_index,
    output reg done
);

    localparam [3:0] MAX_WORDS = 4;
    localparam [3:0] MAX_WORD_LEN = 8;
    localparam [4:0] MAX_MSG_LEN = 16;

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] DP_INIT = 4'd1;
    localparam [3:0] DP_LOOP = 4'd2;
    localparam [3:0] DP_CHECK_WORD = 4'd3;
    localparam [3:0] DP_COMPARE_CHAR = 4'd4;
    localparam [3:0] DP_UPDATE = 4'd5;
    localparam [3:0] BACKTRACK = 4'd6;
    localparam [3:0] OUTPUT = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    reg [7:0] msg_reg [0:MAX_MSG_LEN-1];
    reg [7:0] dict_skeleton [0:MAX_WORDS-1][0:MAX_WORD_LEN-1];
    reg [3:0] dict_len [0:MAX_WORDS-1];

    reg [7:0] dp [0:MAX_MSG_LEN];
    reg reachable [0:MAX_MSG_LEN];
    reg [4:0] prev [0:MAX_MSG_LEN];
    reg [2:0] word_used [0:MAX_MSG_LEN];

    reg [4:0] i_reg;
    reg [2:0] w_reg;
    reg [3:0] j_reg;
    reg [3:0] L_reg;
    reg [7:0] new_vowels_reg;
    reg match_reg;

    reg [4:0] stack_ptr;
    reg [2:0] word_stack [0:MAX_MSG_LEN-1];
    reg [4:0] pos_reg;
    reg [2:0] output_word;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            word_valid <= 1'b0;
            word_index <= 2'd0;
            done <= 1'b0;
            
            for (k = 0; k < MAX_MSG_LEN; k = k + 1) begin
                msg_reg[k] <= 8'd0;
            end
            
            for (k = 0; k < MAX_WORDS; k = k + 1) begin
                for (j_reg = 0; j_reg < MAX_WORD_LEN; j_reg = j_reg + 1) begin
                    dict_skeleton[k][j_reg] <= 8'd0;
                end
                dict_len[k] <= 4'd0;
            end
            
            for (k = 0; k < MAX_MSG_LEN; k = k + 1) begin
                dp[k] <= 8'd0;
                reachable[k] <= 1'b0;
                prev[k] <= 5'd0;
                word_used[k] <= 3'd0;
            end
            
            i_reg <= 5'd0;
            w_reg <= 3'd0;
            j_reg <= 4'd0;
            L_reg <= 4'd0;
            new_vowels_reg <= 8'd0;
            match_reg <= 1'b1;
            
            stack_ptr <= 5'd0;
            for (k = 0; k < MAX_MSG_LEN; k = k + 1) begin
                word_stack[k] <= 3'd0;
            end
            pos_reg <= 5'd0;
            output_word <= 3'd0;
        end else begin
            cycle_count <= cycle_count + 16'd1;
            
            case (state)
                IDLE: begin
                    word_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= DP_INIT;
                    end
                end

                DP_INIT: begin
                    for (k = 0; k < MAX_MSG_LEN; k = k + 1) begin
                        msg_reg[k] <= message[(k+1)*8-1:k*8];
                    end
                    
                    for (k = 0; k < MAX_WORDS; k = k + 1) begin
                        dict_len[k] <= skeleton_len[k*4+3:k*4];
                        for (j_reg = 0; j_reg < MAX_WORD_LEN; j_reg = j_reg + 1) begin
                            dict_skeleton[k][j_reg] <= skeleton_chars[(k*64)+(j_reg*8)+7:(k*64)+(j_reg*8)];
                        end
                    end
                    
                    dp[0] <= 8'd0;
                    reachable[0] <= 1'b1;
                    for (k = 1; k < MAX_MSG_LEN; k = k + 1) begin
                        dp[k] <= 8'd0;
                        reachable[k] <= 1'b0;
                    end
                    
                    i_reg <= 5'd0;
                    state <= DP_LOOP;
                end

                DP_LOOP: begin
                    if (i_reg < msg_len) begin
                        if (reachable[i_reg]) begin
                            w_reg <= 3'd0;
                            state <= DP_CHECK_WORD;
                        end else begin
                            i_reg <= i_reg + 5'd1;
                        end
                    end else begin
                        state <= BACKTRACK;
                    end
                end

                DP_CHECK_WORD: begin
                    if (w_reg < num_words) begin
                        L_reg <= dict_len[w_reg];
                        if (i_reg + L_reg <= msg_len) begin
                            j_reg <= 4'd0;
                            match_reg <= 1'b1;
                            state <= DP_COMPARE_CHAR;
                        end else begin
                            w_reg <= w_reg + 3'd1;
                        end
                    end else begin
                        i_reg <= i_reg + 5'd1;
                        state <= DP_LOOP;
                    end
                end

                DP_COMPARE_CHAR: begin
                    if (j_reg < L_reg) begin
                        if (match_reg) begin
                            if (msg_reg[i_reg + j_reg] != dict_skeleton[w_reg][j_reg]) begin
                                match_reg <= 1'b0;
                            end
                            j_reg <= j_reg + 4'd1;
                        end else begin
                            j_reg <= L_reg;
                        end
                    end else begin
                        if (match_reg) begin
                            new_vowels_reg <= dp[i_reg] + vowel_count[w_reg*4+3:w_reg*4];
                            state <= DP_UPDATE;
                        end else begin
                            w_reg <= w_reg + 3'd1;
                            state <= DP_CHECK_WORD;
                        end
                    end
                end

                DP_UPDATE: begin
                    if (!reachable[i_reg + L_reg] || new_vowels_reg > dp[i_reg + L_reg]) begin
                        dp[i_reg + L_reg] <= new_vowels_reg;
                        reachable[i_reg + L_reg] <= 1'b1;
                        prev[i_reg + L_reg] <= i_reg;
                        word_used[i_reg + L_reg] <= w_reg;
                    end
                    w_reg <= w_reg + 3'd1;
                    state <= DP_CHECK_WORD;
                end

                BACKTRACK: begin
                    stack_ptr <= 5'd0;
                    pos_reg <= msg_len;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    if (stack_ptr == 5'd0) begin
                        if (pos_reg > 5'd0) begin
                            word_stack[stack_ptr] <= word_used[pos_reg];
                            stack_ptr <= stack_ptr + 5'd1;
                            pos_reg <= prev[pos_reg];
                        end else begin
                            stack_ptr <= stack_ptr - 5'd1;
                            output_word <= word_stack[stack_ptr];
                            word_valid <= 1'b1;
                            word_index <= output_word[1:0];
                        end
                    end else begin
                        if (stack_ptr > 5'd0) begin
                            stack_ptr <= stack_ptr - 5'd1;
                            output_word <= word_stack[stack_ptr];
                            word_valid <= 1'b1;
                            word_index <= output_word[1:0];
                        end else begin
                            word_valid <= 1'b0;
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule