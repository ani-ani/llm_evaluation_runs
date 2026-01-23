module elder_gui (
    input clk,
    input rst_n,
    input start,
    // Configuration inputs (Q16.16 fixed-point for W, H, F, N)
    input [31:0] W_in,       // Viewport width in Q16.16
    input [31:0] H_in,       // Viewport height in Q16.16
    input [31:0] F_in,       // First line to show in Q16.16
    input [31:0] N_in,       // Number of text lines in Q16.16
    // Text input: 16 lines max, 16 chars max per line
    input [15:0] char_data,  // Current character input (ASCII)
    input char_valid,        // Character valid
    output reg char_read,    // Read next character
    // Output: 200 chars max per line, 200 lines max (scaled to 16x16)
    output reg [15:0] out_char,
    output reg out_valid,
    output reg done
);

    // Parameters for fixed sizes
    parameter MAX_W = 16;
    parameter MAX_H = 16;
    parameter MAX_LINES = 16;
    parameter MAX_CHARS = 16;
    
    // State definitions
    parameter IDLE = 0;
    parameter PARSE_CONFIG = 1;
    parameter READ_TEXT = 2;
    parameter LINE_BREAK = 3;
    parameter CALC_THUMB = 4;
    parameter OUTPUT_FRAME = 5;
    parameter DONE_STATE = 6;
    
    reg [3:0] state;
    
    // Registers for configuration
    reg [7:0] W_val, H_val, F_val, N_val;
    
    // Text storage: 16 lines of 16 chars each
    reg [7:0] text_lines [0:15][0:15];
    reg [3:0] line_idx;
    reg [3:0] char_idx;
    reg [3:0] lines_count;
    
    // Adjusted lines storage
    reg [7:0] adj_lines [0:31][0:15]; // 32 possible adjusted lines, 16 chars max
    reg [4:0] adj_count;
    reg [4:0] current_adj_line;
    
    // Intermediate buffers
    reg [7:0] temp_line [0:15];
    reg [3:0] temp_idx;
    reg [7:0] current_word [0:15];
    reg [3:0] word_idx;
    
    // Thumb calculation registers
    reg [31:0] numerator;
    reg [31:0] denominator;
    reg [7:0] thumb_pos;
    
    // Output generation registers
    reg [4:0] out_row;
    reg [4:0] out_col;
    reg [4:0] view_start_line;
    reg [7:0] output_char;
    
    // Temporary computation registers
    reg [31:0] temp_mult;
    reg [31:0] temp_sub;
    
    integer i, j;
    
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
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    out_valid <= 0;
                    if (start) begin
                        state <= PARSE_CONFIG;
                        line_idx <= 0;
                        char_idx <= 0;
                        lines_count <= 0;
                    end
                end
                
                PARSE_CONFIG: begin
                    // Extract integer values from Q16.16 inputs
                    W_val <= W_in[23:16];
                    H_val <= H_in[23:16];
                    F_val <= F_in[23:16];
                    N_val <= N_in[23:16];
                    state <= READ_TEXT;
                    char_idx <= 0;
                end
                
                READ_TEXT: begin
                    if (char_valid && lines_count < N_val && lines_count < MAX_LINES) begin
                        if (char_data[7:0] == 10 || char_data[7:0] == 13) begin // Newline
                            if (char_idx > 0) begin
                                lines_count <= lines_count + 1;
                                line_idx <= line_idx + 1;
                                char_idx <= 0;
                            end
                        end else if (char_idx < MAX_CHARS) begin
                            text_lines[line_idx][char_idx] <= char_data[7:0];
                            char_idx <= char_idx + 1;
                        end
                        char_read <= 1;
                    end else if (char_idx > 0 && lines_count < N_val && lines_count < MAX_LINES) begin
                        // Store last line if no newline at end
                        lines_count <= lines_count + 1;
                        state <= LINE_BREAK;
                        char_read <= 0;
                        current_adj_line <= 0;
                        line_idx <= 0;
                        char_idx <= 0;
                        temp_idx <= 0;
                        word_idx <= 0;
                    end else begin
                        state <= LINE_BREAK;
                        char_read <= 0;
                        current_adj_line <= 0;
                        line_idx <= 0;
                        char_idx <= 0;
                        temp_idx <= 0;
                        word_idx <= 0;
                    end
                end
                
                LINE_BREAK: begin
                    if (line_idx < lines_count) begin
                        // Process one word from current input line
                        if (char_idx < MAX_CHARS && text_lines[line_idx][char_idx] != 0) begin
                            if (text_lines[line_idx][char_idx] != 32) begin // Not space
                                current_word[word_idx] <= text_lines[line_idx][char_idx];
                                word_idx <= word_idx + 1;
                                char_idx <= char_idx + 1;
                            end else begin // Space: end of word
                                // Check if word fits
                                if (temp_idx + word_idx <= W_val && temp_idx > 0) begin
                                    // Add space and word
                                    for (i = 0; i < word_idx; i = i + 1) begin
                                        temp_line[temp_idx + i] <= current_word[i];
                                    end
                                    temp_idx <= temp_idx + word_idx + 1;
                                    temp_line[temp_idx] <= 32;
                                end else if (temp_idx + word_idx <= W_val && temp_idx == 0) begin
                                    // Add word at start
                                    for (i = 0; i < word_idx; i = i + 1) begin
                                        temp_line[temp_idx + i] <= current_word[i];
                                    end
                                    temp_idx <= temp_idx + word_idx;
                                end else begin
                                    // Word doesn't fit or line is full
                                    if (temp_idx > 0) begin
                                        // Save current line
                                        for (j = 0; j < temp_idx; j = j + 1) begin
                                            adj_lines[current_adj_line][j] <= temp_line[j];
                                        end
                                        adj_count <= adj_count + 1;
                                        current_adj_line <= current_adj_line + 1;
                                        // Start new line with this word
                                        if (word_idx <= W_val) begin
                                            for (i = 0; i < word_idx; i = i + 1) begin
                                                temp_line[i] <= current_word[i];
                                            end
                                            temp_idx <= word_idx;
                                        end else begin
                                            // Word too long - truncate
                                            for (i = 0; i < W_val; i = i + 1) begin
                                                temp_line[i] <= current_word[i];
                                            end
                                            temp_idx <= W_val;
                                        end
                                    end else begin
                                        // Word too long for empty line
                                        if (word_idx <= W_val) begin
                                            for (i = 0; i < word_idx; i = i + 1) begin
                                                temp_line[i] <= current_word[i];
                                            end
                                            temp_idx <= word_idx;
                                        end else begin
                                            for (i = 0; i < W_val; i = i + 1) begin
                                                temp_line[i] <= current_word[i];
                                            end
                                            temp_idx <= W_val;
                                        end
                                    end
                                end
                                word_idx <= 0;
                                char_idx <= char_idx + 1;
                            end
                        end else begin
                            // End of line or line complete
                            if (word_idx > 0) begin
                                // Process last word
                                if (temp_idx + word_idx <= W_val && temp_idx > 0) begin
                                    for (i = 0; i < word_idx; i = i + 1) begin
                                        temp_line[temp_idx + i] <= current_word[i];
                                    end
                                    temp_idx <= temp_idx + word_idx;
                                end else if (temp_idx + word_idx <= W_val && temp_idx == 0) begin
                                    for (i = 0; i < word_idx; i = i + 1) begin
                                        temp_line[i] <= current_word[i];
                                    end
                                    temp_idx <= word_idx;
                                end else if (temp_idx > 0) begin
                                    // Save current line
                                    for (j = 0; j < temp_idx; j = j + 1) begin
                                        adj_lines[current_adj_line][j] <= temp_line[j];
                                    end
                                    adj_count <= adj_count + 1;
                                    current_adj_line <= current_adj_line + 1;
                                    // Start new line with last word
                                    if (word_idx <= W_val) begin
                                        for (i = 0; i < word_idx; i = i + 1) begin
                                            temp_line[i] <= current_word[i];
                                        end
                                        temp_idx <= word_idx;
                                    end else begin
                                        for (i = 0; i < W_val; i = i + 1) begin
                                            temp_line[i] <= current_word[i];
                                        end
                                        temp_idx <= W_val;
                                    end
                                end
                            end
                            // Save final line
                            if (temp_idx > 0) begin
                                for (j = 0; j < temp_idx; j = j + 1) begin
                                    adj_lines[current_adj_line][j] <= temp_line[j];
                                end
                                adj_count <= adj_count + 1;
                                current_adj_line <= current_adj_line + 1;
                            end
                            // Reset for next input line
                            line_idx <= line_idx + 1;
                            char_idx <= 0;
                            temp_idx <= 0;
                            word_idx <= 0;
                            // Check if all lines processed
                            if (line_idx + 1 >= lines_count) begin
                                state <= CALC_THUMB;
                            end
                        end
                    end else begin
                        state <= CALC_THUMB;
                    end
                end
                
                CALC_THUMB: begin
                    // Thumb position calculation: T = (H-3) * F / (L - H)
                    // Using integer arithmetic (values are small)
                    // Sub step: H-3
                    if (H_val > 3) begin
                        temp_sub <= H_val - 3;
                    end else begin
                        temp_sub <= 0;
                    end
                    // Sub step: L-H (adj_count is L)
                    if (adj_count > H_val) begin
                        denominator <= adj_count - H_val;
                    end else begin
                        denominator <= 1; // Avoid div by zero
                    end
                    // Mult step: (H-3) * F
                    numerator <= (H_val > 3 ? (H_val - 3) : 0) * F_val;
                    // Division: this will be combinational in next cycle or state
                    // For small integer values, we can compute here
                    if (denominator > 0) begin
                        thumb_pos <= numerator / denominator;
                    end else begin
                        thumb_pos <= 0;
                    end
                    state <= OUTPUT_FRAME;
                    out_row <= 0;
                    out_col <= 0;
                    view_start_line <= F_val;
                    out_valid <= 0;
                end
                
                OUTPUT_FRAME: begin
                    // Generate frame character by character
                    if (out_row < H_val && out_row < MAX_H) begin
                        // Calculate which character to output
                        if (out_col == 0) begin
                            // Left border
                            out_char <= "|";
                            out_valid <= 1;
                            out_col <= out_col + 1;
                        end else if (out_col <= W_val && out_col < MAX_W) begin
                            // Content area
                            if (out_row < adj_count) begin
                                // Line from adjusted text
                                if (out_col <= W_val) begin
                                    if (out_col <= 16) begin
                                        // Output text line content
                                        if (adj_lines[view_start_line + out_row][out_col - 1] != 0 && (out_col - 1) < 16) begin
                                            out_char <= adj_lines[view_start_line + out_row][out_col - 1];
                                        end else begin
                                            out_char <= " "; // Padding
                                        end
                                        out_col <= out_col + 1;
                                    end else begin
                                        out_col <= out_col + 1;
                                        out_char <= " ";
                                    end
                                end else begin
                                    // Fill padding
                                    out_char <= " ";
                                    out_col <= out_col + 1;
                                end
                            end else begin
                                // Empty line
                                if (out_col <= W_val) begin
                                    out_char <= " ";
                                    out_col <= out_col + 1;
                                end else begin
                                    out_col <= out_col + 1;
                                end
                            end
                        end else if (out_col == W_val + 1) begin
                            // Right border
                            out_char <= "|";
                            out_valid <= 1;
                            out_col <= out_col + 1;
                        end else if (out_col == W_val + 2) begin
                            // Thumb indicator
                            // Determine if this line has thumb or up/down
                            if (out_row == 0) begin
                                out_char <= "^"; // Up
                            end else if (out_row == H_val - 1) begin
                                out_char <= "v"; // Down
                            end else if (out_row >= 1 && out_row < H_val - 1) begin
                                // Content/Thumb area
                                if (out_row - 1 == thumb_pos && thumb_pos < H_val - 2) begin
                                    out_char <= "X"; // Thumb
                                end else begin
                                    out_char <= " "; // Rail
                                end
                            end else begin
                                out_char <= " ";
                            end
                            out_valid <= 1;
                            out_col <= out_col + 1;
                        end else if (out_col == W_val + 3) begin
                            // Final border
                            out_char <= "|";
                            out_valid <= 1;
                            out_col <= 0;
                            out_row <= out_row + 1;
                            // Check if done with all rows
                            if (out_row + 1 >= H_val) begin
                                state <= DONE_STATE;
                            end
                        end else begin
                            out_col <= out_col + 1;
                            out_valid <= 0;
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

// Helper module for character input stream
module text_stream (
    input clk,
    input rst_n,
    input [7:0] char_in,
    input char_valid_in,
    output reg [15:0] char_out,
    output reg char_valid_out,
    input char_read
);
    // Simple pass-through with buffering
    always @(posedge clk) begin
        if (char_valid_in) begin
            char_out <= {8'h00, char_in};
            char_valid_out <= 1;
        end else if (char_read) begin
            char_valid_out <= 0;
        end
    end
endmodule