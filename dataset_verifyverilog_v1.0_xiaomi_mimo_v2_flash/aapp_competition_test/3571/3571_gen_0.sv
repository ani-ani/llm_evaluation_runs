module text_viewport #(
    parameter W = 8,
    parameter H = 6,
    parameter MAX_WORDS = 8,
    parameter MAX_WORD_LEN = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] F,
    input wire [$clog2(MAX_WORDS)-1:0] word_addr,
    input wire [2:0] char_idx,
    input wire [7:0] word_char,
    input wire word_write,
    output reg [7:0] char_out,
    output reg char_valid,
    output reg done
);

    // Memory declarations
    reg [7:0] word_memory [0:MAX_WORDS-1][0:MAX_WORD_LEN-1];
    reg [3:0] word_len [0:MAX_WORDS-1];
    reg [$clog2(MAX_WORDS):0] num_words;
    reg [7:0] adjusted_lines [0:15][0:W-1];
    reg [3:0] line_count;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ = 3'd1;
    localparam [2:0] BUILD = 3'd2;
    localparam [2:0] CALC = 3'd3;
    localparam [2:0] RENDER = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Building state registers
    reg [$clog2(MAX_WORDS):0] build_word_idx;
    reg [3:0] build_line_idx;
    reg [3:0] build_col;
    reg [3:0] calc_idx;
    reg [2:0] calc_char_idx;
    reg [3:0] render_line;
    reg [3:0] render_col;
    reg [7:0] thumb_pos;

    // Word write handling
    always @(posedge clk) begin
        if (word_write) begin
            word_memory[word_addr][char_idx] <= word_char;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            char_valid <= 1'b0;
            num_words <= 8'd0;
            line_count <= 4'd0;
            char_out <= 8'd0;
            build_word_idx <= 8'd0;
            build_line_idx <= 4'd0;
            build_col <= 4'd0;
            calc_idx <= 4'd0;
            calc_char_idx <= 3'd0;
            render_line <= 4'd0;
            render_col <= 4'd0;
            thumb_pos <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= READ;
                    end
                end

                READ: begin
                    if (calc_idx < MAX_WORDS) begin
                        // Count non-zero characters for this word
                        if (calc_char_idx == 0) begin
                            word_len[calc_idx] <= 4'd0;
                        end
                        if (word_memory[calc_idx][calc_char_idx] != 8'h00 && calc_char_idx < MAX_WORD_LEN) begin
                            word_len[calc_idx] <= word_len[calc_idx] + 4'd1;
                        end
                        if (calc_char_idx < MAX_WORD_LEN - 1) begin
                            calc_char_idx <= calc_char_idx + 3'd1;
                        end else begin
                            calc_char_idx <= 3'd0;
                            calc_idx <= calc_idx + 8'd1;
                        end
                    end else begin
                        // Count valid words
                        if (calc_idx < MAX_WORDS + 8'd1) begin
                            if (calc_idx == 0) begin
                                num_words <= 8'd0;
                                calc_idx <= calc_idx + 8'd1;
                            end else if (calc_idx <= MAX_WORDS) begin
                                if (word_len[calc_idx - 8'd1] != 4'd0) begin
                                    num_words <= num_words + 8'd1;
                                end
                                calc_idx <= calc_idx + 8'd1;
                            end else begin
                                calc_idx <= 8'd0;
                                calc_char_idx <= 3'd0;
                                build_word_idx <= 8'd0;
                                build_line_idx <= 4'd0;
                                build_col <= 4'd0;
                                state <= BUILD;
                            end
                        end
                    end
                end

                BUILD: begin
                    if (build_word_idx < num_words) begin
                        // Determine if word fits
                        if (build_col == 4'd0) begin
                            if (word_len[build_word_idx] <= W) begin
                                // Fit entire word
                                if (calc_char_idx < word_len[build_word_idx]) begin
                                    adjusted_lines[build_line_idx][build_col + calc_char_idx] <= word_memory[build_word_idx][calc_char_idx];
                                    calc_char_idx <= calc_char_idx + 3'd1;
                                end else begin
                                    calc_char_idx <= 3'd0;
                                    build_col <= build_col + word_len[build_word_idx];
                                    build_word_idx <= build_word_idx + 8'd1;
                                end
                            end else begin
                                // Truncate
                                if (calc_char_idx < W) begin
                                    adjusted_lines[build_line_idx][calc_char_idx] <= word_memory[build_word_idx][calc_char_idx];
                                    calc_char_idx <= calc_char_idx + 3'd1;
                                end else begin
                                    calc_char_idx <= 3'd0;
                                    build_col <= W;
                                    build_word_idx <= build_word_idx + 8'd1;
                                end
                            end
                        end else begin
                            // Not first word
                            if (build_col + 1 + word_len[build_word_idx] <= W) begin
                                if (calc_char_idx == 0) begin
                                    adjusted_lines[build_line_idx][build_col] <= 8'h20;
                                    calc_char_idx <= calc_char_idx + 3'd1;
                                end else if (calc_char_idx <= word_len[build_word_idx]) begin
                                    if (calc_char_idx == word_len[build_word_idx]) begin
                                        calc_char_idx <= 3'd0;
                                        build_col <= build_col + 1 + word_len[build_word_idx];
                                        build_word_idx <= build_word_idx + 8'd1;
                                    end else begin
                                        adjusted_lines[build_line_idx][build_col + calc_char_idx] <= word_memory[build_word_idx][calc_char_idx - 3'd1];
                                        calc_char_idx <= calc_char_idx + 3'd1;
                                    end
                                end
                            end else begin
                                // Start new line
                                build_line_idx <= build_line_idx + 4'd1;
                                build_col <= 4'd0;
                                calc_char_idx <= 3'd0;
                            end
                        end
                    end else begin
                        line_count <= build_line_idx + (build_col > 4'd0 ? 4'd1 : 4'd0);
                        state <= CALC;
                        calc_idx <= 4'd0;
                    end
                end

                CALC: begin
                    if (line_count > H) begin
                        thumb_pos <= ((H - 4'd3) * F) / (line_count - H);
                    end else begin
                        thumb_pos <= 8'd0;
                    end
                    render_line <= 4'd0;
                    render_col <= 4'd0;
                    state <= RENDER;
                end

                RENDER: begin
                    if (render_col < W + 4) begin
                        // Determine character
                        if (render_line == 4'd0 || render_line == H + 4'd1) begin
                            if (render_col == 4'd0 || render_col == W + 3)
                                char_out <= "+";
                            else
                                char_out <= "-";
                        end else begin
                            if (render_col == 4'd0)
                                char_out <= "|";
                            else if (render_col == W + 1)
                                char_out <= " ";
                            else if (render_col == W + 2) begin
                                if (render_line == 4'd1)
                                    char_out <= "^";
                                else if (render_line == H)
                                    char_out <= "v";
                                else if (render_line - 4'd1 == thumb_pos + 4'd1)
                                    char_out <= "X";
                                else
                                    char_out <= " ";
                            end else if (render_col == W + 3)
                                char_out <= "|";
                            else begin
                                if (render_line - 4'd1 + F < line_count) begin
                                    char_out <= adjusted_lines[render_line - 4'd1 + F][render_col - 4'd1];
                                    if (char_out == 8'h00) char_out <= " ";
                                end else begin
                                    char_out <= " ";
                                end
                            end
                        end
                        char_valid <= 1'b1;
                        render_col <= render_col + 4'd1;
                    end else begin
                        char_valid <= 1'b0;
                        render_col <= 4'd0;
                        render_line <= render_line + 4'd1;
                        if (render_line == H + 4'd1) begin
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule