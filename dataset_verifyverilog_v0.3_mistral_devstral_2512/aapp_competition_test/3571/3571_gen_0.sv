module text_viewport #(
    parameter W = 8,              // Viewport width (3-200, scaled)
    parameter H = 6,              // Viewport height (3-200, scaled)
    parameter MAX_WORDS = 8,      // Maximum number of words
    parameter MAX_WORD_LEN = 8    // Maximum characters per word
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] F,           // First line index (0-31)
    
    // Word memory interface (testbench writes words via these signals)
    input wire [$clog2(MAX_WORDS)-1:0] word_addr,  // Word index (0 to MAX_WORDS-1)
    input wire [2:0] char_idx,                     // Character index within word (0 to MAX_WORD_LEN-1)
    input wire [7:0] word_char,                    // ASCII character to store
    input wire word_write,                         // Write enable
    
    // Output interface
    output reg [7:0] char_out,      // Output character
    output reg char_valid,          // Valid when outputting
    output reg done                 // Done signal
);

// Internal memory for words
reg [7:0] word_memory [0:MAX_WORDS-1][0:MAX_WORD_LEN-1];
reg [3:0] word_len [0:MAX_WORDS-1];  // Actual length of each word
reg [$clog2(MAX_WORDS):0] num_words; // Number of valid words

// Adjusted lines buffer
reg [7:0] adjusted_lines [0:15][0:W-1];  // Up to 16 lines
reg [3:0] line_count;                    // Total number of adjusted lines

// State machine
localparam [2:0] IDLE = 3'd0;
localparam [2:0] READ = 3'd1;
localparam [2:0] BUILD = 3'd2;
localparam [2:0] CALC = 3'd3;
localparam [2:0] RENDER = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;
reg [2:0] state;  // 0=IDLE, 1=READ, 2=BUILD, 3=CALC, 4=RENDER, 5=DONE

// Building state registers
reg [$clog2(MAX_WORDS):0] build_word_idx;  // Current word being processed
reg [3:0] build_line_idx;                  // Current line being built
reg [3:0] build_col;                       // Current column in line

// Rendering state
reg [3:0] render_line;  // Line being rendered (0 to H+1)
reg [3:0] render_col;   // Column in render line (0 to W+3)
reg [7:0] thumb_pos;    // Calculated thumb position (0 to H-3)

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
        num_words <= 0;
        line_count <= 0;
        build_word_idx <= 0;
        build_line_idx <= 0;
        build_col <= 0;
        render_line <= 0;
        render_col <= 0;
        thumb_pos <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Count valid words (non-zero length)
                    num_words <= 0;
                    for (int i = 0; i < MAX_WORDS; i = i + 1) begin
                        if (word_memory[i][0] != 8'h00) num_words <= num_words + 1;
                    end
                    state <= READ;
                end
            end
            
            READ: begin
                // Compute word lengths
                for (int i = 0; i < MAX_WORDS; i = i + 1) begin
                    word_len[i] <= 0;
                    for (int j = 0; j < MAX_WORD_LEN; j = j + 1) begin
                        if (word_memory[i][j] != 8'h00) word_len[i] <= word_len[i] + 1;
                    end
                end
                state <= BUILD;
                build_word_idx <= 0;
                build_line_idx <= 0;
                build_col <= 0;
            end
            
            BUILD: begin
                if (build_word_idx < num_words) begin
                    // Try to fit current word
                    if (build_col == 0) begin  // First word on line
                        if (word_len[build_word_idx] <= W) begin
                            // Fit entire word
                            for (int i = 0; i < word_len[build_word_idx]; i = i + 1) begin
                                adjusted_lines[build_line_idx][build_col + i] <= word_memory[build_word_idx][i];
                            end
                            build_col <= build_col + word_len[build_word_idx];
                        end else begin
                            // Truncate
                            for (int i = 0; i < W; i = i + 1) begin
                                adjusted_lines[build_line_idx][i] <= word_memory[build_word_idx][i];
                            end
                            build_col <= W;
                        end
                        build_word_idx <= build_word_idx + 1;
                    end else begin  // Not first word
                        if (build_col + 1 + word_len[build_word_idx] <= W) begin
                            // Fit with space
                            adjusted_lines[build_line_idx][build_col] <= 8'h20;  // space
                            for (int i = 0; i < word_len[build_word_idx]; i = i + 1) begin
                                adjusted_lines[build_line_idx][build_col + 1 + i] <= word_memory[build_word_idx][i];
                            end
                            build_col <= build_col + 1 + word_len[build_word_idx];
                            build_word_idx <= build_word_idx + 1;
                        end else begin
                            // Start new line
                            build_line_idx <= build_line_idx + 1;
                            build_col <= 0;
                        end
                    end
                end else begin
                    // All words processed
                    line_count <= build_line_idx + (build_col > 0 ? 1 : 0);
                    state <= CALC;
                end
            end
            
            CALC: begin
                if (line_count > H) begin
                    // T = floor((H-3) * F / (line_count - H))
                    thumb_pos <= ((H - 3) * F) / (line_count - H);
                end else begin
                    thumb_pos <= 0;
                end
                state <= RENDER;
                render_line <= 0;
                render_col <= 0;
            end
            
            RENDER: begin
                if (render_col < W + 4) begin
                    // Determine character based on position
                    if (render_line == 0 || render_line == H + 1) begin
                        // Top/bottom border
                        if (render_col == 0 || render_col == W + 3)
                            char_out <= 8'h2B;  // '+'
                        else
                            char_out <= 8'h2D;  // '-'
                    end else begin
                        // Content lines
                        if (render_col == 0)
                            char_out <= 8'h7C;  // '|'
                        else if (render_col == W + 1)
                            char_out <= 8'h20;  // ' '
                        else if (render_col == W + 2) begin
                            // Scrollbar
                            if (render_line == 1)
                                char_out <= 8'h5E;  // '^'
                            else if (render_line == H)
                                char_out <= 8'h76;  // 'v'
                            else if (render_line - 1 == thumb_pos + 1)
                                char_out <= 8'h58;  // 'X'
                            else
                                char_out <= 8'h20;  // ' '
                        end else if (render_col == W + 3)
                            char_out <= 8'h7C;  // '|'
                        else begin
                            // Text area (columns 1 to W)
                            if (render_line - 1 + F < line_count) begin
                                char_out <= adjusted_lines[render_line - 1 + F][render_col - 1];
                                // If character is zero (unused), show space
                                if (char_out == 8'h00) char_out <= 8'h20;
                            end else begin
                                char_out <= 8'h20;
                            end
                        end
                    end
                    char_valid <= 1'b1;
                    render_col <= render_col + 1;
                end else begin
                    // End of line
                    char_valid <= 1'b0;
                    render_col <= 0;
                    render_line <= render_line + 1;
                    if (render_line == H + 1) begin
                        state <= DONE_STATE;  // DONE
                    end
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;  // Reset when start goes low
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule