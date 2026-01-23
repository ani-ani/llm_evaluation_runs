module elder_gui (
    input clk,
    input rst_n,
    input start,
    input [31:0] W_in,
    input [31:0] H_in,
    input [31:0] F_in,
    input [31:0] N_in,
    input [15:0] char_data,
    input char_valid,
    output reg char_read,
    output reg [15:0] out_char,
    output reg out_valid,
    output reg done
);

    parameter MAX_W = 16;
    parameter MAX_H = 16;
    parameter MAX_LINES = 16;
    parameter MAX_CHARS = 16;
    parameter IDLE = 0;
    parameter PARSE_CONFIG = 1;
    parameter READ_TEXT = 2;
    parameter LINE_BREAK = 3;
    parameter CALC_THUMB = 4;
    parameter OUTPUT_FRAME = 5;
    parameter DONE_STATE = 6;
    parameter OUTPUT_CHAR = 7;
    parameter FETCH_WORD = 8;
    parameter CHECK_FIT = 9;
    parameter SAVE_LINE = 10;
    parameter START_NEW_LINE = 11;
    
    reg [3:0] state;
    reg [7:0] W_val, H_val, F_val, N_val;
    reg [7:0] text_lines [0:15][0:15];
    reg [3:0] line_idx;
    reg [3:0] char_idx;
    reg [3:0] lines_count;
    reg [7:0] adj_lines [0:31][0:15];
    reg [4:0] adj_count;
    reg [4:0] current_adj_line;
    reg [7:0] temp_line [0:15];
    reg [3:0] temp_idx;
    reg [7:0] current_word [0:15];
    reg [3:0] word_idx;
    reg [31:0] thumb_numer;
    reg [31:0] thumb_denom;
    reg [7:0] thumb_pos;
    reg [4:0] out_row;
    reg [4:0] out_col;
    reg [4:0] view_start_line;
    reg [7:0] output_char_reg;
    reg [31:0] temp_mult;
    reg [31:0] temp_sub;
    reg [3:0] word_proc_idx;
    reg [3:0] copy_idx;
    reg [7:0] temp_w_word_len;
    reg [7:0] temp_w_temp_idx;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            out_valid <= 0;
            char_read <= 0;
            lines_count <= 0;
            adj_count <= 0;
            line_idx <= 0;
            char_idx <= 0;
            adj_count <= 0;
            current_adj_line <= 0;
            temp_idx <= 0;
            word_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    out_valid <= 0;
                    char_read <= 0;
                    if (start) begin
                        state <= PARSE_CONFIG;
                        line_idx <= 0;
                        char_idx <= 0;
                        lines_count <= 0;
                        adj_count <= 0;
                        current_adj_line <= 0;
                    end
                end
                
                PARSE_CONFIG: begin
                    W_val <= (W_in[23:16] > 16) ? 16 : W_in[23:16];
                    H_val <= (H_in[23:16] > 16) ? 16 : H_in[23:16];
                    F_val <= F_in[23:16];
                    N_val <= (N_in[23:16] > 16) ? 16 : N_in[23:16];
                    state <= READ_TEXT;
                    char_idx <= 0;
                    lines_count <= 0;
                    line_idx <= 0;
                end
                
                READ_TEXT: begin
                    if (char_valid && lines_count < N_val && line_idx < 16) begin
                        char_read <= 1;
                        if (char_data[7:0] == 10 || char_data[7:0] == 13) begin
                            if (char_idx > 0) begin
                                lines_count <= lines_count + 1;
                                line_idx <= line_idx + 1;
                                char_idx <= 0;
                            end
                        end else if (char_idx < 16) begin
                            text_lines[line_idx][char_idx] <= char_data[7:0];
                            char_idx <= char_idx + 1;
                        end
                    end else begin
                        char_read <= 0;
                        if (lines_count >= N_val || line_idx >= 16) begin
                            state <= LINE_BREAK;
                            line_idx <= 0;
                            char_idx <= 0;
                            temp_idx <= 0;
                            word_idx <= 0;
                        end else if (!char_valid && char_idx > 0) begin
                            lines_count <= lines_count + 1;
                            state <= LINE_BREAK;
                            line_idx <= 0;
                            char_idx <= 0;
                            temp_idx <= 0;
                            word_idx <= 0;
                        end
                    end
                end
                
                LINE_BREAK: begin
                    if (line_idx < lines_count) begin
                        if (char_idx < 16 && text_lines[line_idx][char_idx] != 0) begin
                            if (text_lines[line_idx][char_idx] != 32) begin
                                current_word[word_idx] <= text_lines[line_idx][char_idx];
                                word_idx <= word_idx + 1;
                                char_idx <= char_idx + 1;
                            end else begin
                                if (word_idx > 0) begin
                                    if (temp_idx > 0) begin
                                        if (temp_idx + word_idx + 1 <= W_val) begin
                                            for (copy_idx = 0; copy_idx < word_idx; copy_idx = copy_idx + 1) begin
                                                temp_line[temp_idx + copy_idx] <= current_word[copy_idx];
                                            end
                                            temp_line[temp_idx + word_idx] <= 32;
                                            temp_idx <= temp_idx + word_idx + 1;
                                        end else begin
                                            for (copy_idx = 0; copy_idx < temp_idx; copy_idx = copy_idx + 1) begin
                                                adj_lines[current_adj_line][copy_idx] <= temp_line[copy_idx];
                                            end
                                            adj_count <= adj_count + 1;
                                            current_adj_line <= current_adj_line + 1;
                                            if (word_idx <= W_val) begin
                                                for (copy_idx = 0; copy_idx < word_idx; copy_idx = copy_idx + 1) begin
                                                    temp_line[copy_idx] <= current_word[copy_idx];
                                                end
                                                temp_line[word_idx] <= 32;
                                                temp_idx <= word_idx + 1;
                                            end else begin
                                                for (copy_idx = 0; copy_idx < W_val; copy_idx = copy_idx + 1) begin
                                                    temp_line[copy_idx] <= current_word[copy_idx];
                                                end
                                                temp_idx <= W_val;
                                            end
                                        end
                                    end else begin
                                        if (word_idx <= W_val) begin
                                            for (copy_idx = 0; copy_idx < word_idx; copy_idx = copy_idx + 1) begin
                                                temp_line[copy_idx] <= current_word[copy_idx];
                                            end
                                            temp_line[word_idx] <= 32;
                                            temp_idx <= word_idx + 1;
                                        end else begin
                                            for (copy_idx = 0; copy_idx < W_val; copy_idx = copy_idx + 1) begin
                                                temp_line[copy_idx] <= current_word[copy_idx];
                                            end
                                            temp_idx <= W_val;
                                        end
                                    end
                                    word_idx <= 0;
                                end
                                char_idx <= char_idx + 1;
                            end
                        end else begin
                            if (word_idx > 0) begin
                                if (temp_idx > 0) begin
                                    if (temp_idx + word_idx <= W_val) begin
                                        for (copy_idx = 0; copy_idx < word_idx; copy_idx = copy_idx + 1) begin
                                            temp_line[temp_idx + copy_idx] <= current_word[copy_idx];
                                        end
                                        temp_idx <= temp_idx + word_idx;
                                    end else begin
                                        for (copy_idx = 0; copy_idx < temp_idx; copy_idx = copy_idx + 1) begin
                                            adj_lines[current_adj_line][copy_idx] <= temp_line[copy_idx];
                                        end
                                        adj_count <= adj_count + 1;
                                        current_adj_line <= current_adj_line + 1;
                                        if (word_idx <= W_val) begin
                                            for (copy_idx = 0; copy_idx < word_idx; copy_idx = copy_idx + 1) begin
                                                temp_line[copy_idx] <= current_word[copy_idx];
                                            end
                                            temp_idx <= word_idx;
                                        end else begin
                                            for (copy_idx = 0; copy_idx < W_val; copy_idx = copy_idx + 1) begin
                                                temp_line[copy_idx] <= current_word[copy_idx];
                                            end
                                            temp_idx <= W_val;
                                        end
                                    end
                                end else begin
                                    if (word_idx <= W_val) begin
                                        for (copy_idx = 0; copy_idx < word_idx; copy_idx = copy_idx + 1) begin
                                            temp_line[copy_idx] <= current_word[copy_idx];
                                        end
                                        temp_idx <= word_idx;
                                    end else begin
                                        for (copy_idx = 0; copy_idx < W_val; copy_idx = copy_idx + 1) begin
                                            temp_line[copy_idx] <= current_word[copy_idx];
                                        end
                                        temp_idx <= W_val;
                                    end
                                end
                            end
                            if (temp_idx > 0) begin
                                for (copy_idx = 0; copy_idx < temp_idx; copy_idx = copy_idx + 1) begin
                                    adj_lines[current_adj_line][copy_idx] <= temp_line[copy_idx];
                                end
                                adj_count <= adj_count + 1;
                                current_adj_line <= current_adj_line + 1;
                            end
                            line_idx <= line_idx + 1;
                            char_idx <= 0;
                            temp_idx <= 0;
                            word_idx <= 0;
                        end
                    end else begin
                        state <= CALC_THUMB;
                    end
                end
                
                CALC_THUMB: begin
                    if (adj_count > H_val) begin
                        temp_sub <= H_val - 3;
                        thumb_denom <= adj_count - H_val;
                        thumb_numer <= (H_val > 3) ? (H_val - 3) * F_val : 0;
                    end else begin
                        thumb_numer <= 0;
                        thumb_denom <= 1;
                    end
                    if (thumb_denom > 0 && thumb_numer > 0) begin
                        thumb_pos <= thumb_numer / thumb_denom;
                    end else begin
                        thumb_pos <= 0;
                    end
                    state <= OUTPUT_FRAME;
                    out_row <= 0;
                    out_col <= 0;
                    view_start_line <= F_val;
                end
                
                OUTPUT_FRAME: begin
                    if (out_row < H_val) begin
                        if (out_col == 0) begin
                            out_char <= "|";
                            out_valid <= 1;
                            out_col <= out_col + 1;
                        end else if (out_col <= W_val) begin
                            out_valid <= 1;
                            if (out_row < adj_count) begin
                                if (out_col - 1 < 16 && adj_lines[view_start_line + out_row][out_col - 1] != 0) begin
                                    out_char <= {8'h00, adj_lines[view_start_line + out_row][out_col - 1]};
                                end else begin
                                    out_char <= " ";
                                end
                            end else begin
                                out_char <= " ";
                            end
                            out_col <= out_col + 1;
                        end else if (out_col == W_val + 1) begin
                            out_char <= "|";
                            out_valid <= 1;
                            out_col <= out_col + 1;
                        end else if (out_col == W_val + 2) begin
                            out_valid <= 1;
                            if (out_row == 0) begin
                                out_char <= "^";
                            end else if (out_row == H_val - 1) begin
                                out_char <= "v";
                            end else if (out_row >= 1 && out_row < H_val - 1) begin
                                if (out_row - 1 == thumb_pos && thumb_pos < H_val - 2 && adj_count > H_val) begin
                                    out_char <= "X";
                                end else begin
                                    out_char <= " ";
                                end
                            end else begin
                                out_char <= " ";
                            end
                            out_col <= out_col + 1;
                        end else if (out_col == W_val + 3) begin
                            out_char <= "|";
                            out_valid <= 1;
                            out_col <= 0;
                            out_row <= out_row + 1;
                            if (out_row + 1 >= H_val) begin
                                state <= DONE_STATE;
                            end
                        end else begin
                            out_valid <= 0;
                            out_col <= out_col + 1;
                        end
                    end
                end
                
                DONE_STATE: begin
                    out_valid <= 0;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule