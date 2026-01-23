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

// Internal memory
reg [7:0] word_memory [0:MAX_WORDS-1][0:MAX_WORD_LEN-1];
reg [3:0] word_len [0:MAX_WORDS-1];
reg [$clog2(MAX_WORDS):0] num_words;
reg [7:0] adjusted_lines [0:15][0:W-1];
reg [3:0] line_count;

// State machine
localparam [2:0] IDLE  = 3'd0;
localparam [2:0] READ  = 3'd1;
localparam [2:0] BUILD = 3'd2;
localparam [2:0] CALC  = 3'd3;
localparam [2:0] RENDER = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

reg [2:0] state, next_state;

// Building registers
reg [$clog2(MAX_WORDS):0] build_word_idx;
reg [3:0] build_line_idx;
reg [3:0] build_col;

// Rendering registers
reg [3:0] render_line;
reg [3:0] render_col;
reg [7:0] thumb_pos;

integer i, j;

// Word memory writing
always @(posedge clk) begin
    if (word_write) begin
        word_memory[word_addr][char_idx] <= word_char;
    end
end

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        char_valid <= 1'b0;
        num_words <= 0;
        line_count <= 0;
        
        for (i=0; i<MAX_WORDS; i=i+1) begin
            word_len[i] <= 4'd0;
        end
        
        for (i=0; i<16; i=i+1) begin
            for (j=0; j<W; j=j+1) begin
                adjusted_lines[i][j] <= 8'd0;
            end
        end
        
        build_word_idx <= 0;
        build_line_idx <= 0;
        build_col <= 0;
        render_line <= 0;
        render_col <= 0;
        thumb_pos <= 8'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                char_valid <= 1'b0;
                if (start) begin
                    num_words <= 0;
                    next_state <= READ;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            READ: begin
                // Update word_len arrays
                for (i=0; i<MAX_WORDS; i=i+1) begin
                    for (j=0; j<MAX_WORD_LEN; j=j+1) begin
                        if (word_memory[i][j] != 8'h00) begin
                            word_len[i] <= word_len[i] + 4'd1;
                        end
                    end
                end
                
                // Count valid words
                for (i=0; i<MAX_WORDS; i=i+1) begin
                    if (word_memory[i][0] != 8'h00) begin
                        num_words <= num_words + 1'b1;
                    end
                end
                
                next_state <= BUILD;
                build_word_idx <= 0;
                build_line_idx <= 0;
                build_col <= 0;
            end
            
            BUILD: begin
                if (build_word_idx < num_words) begin
                    if (build_col == 4'd0) begin
                        if (word_len[build_word_idx] <= W) begin
                            for (j=0; j<word_len[build_word_idx]; j=j+1) begin
                                adjusted_lines[build_line_idx][j] <= word_memory[build_word_idx][j];
                            end
                            build_col <= word_len[build_word_idx];
                        end else begin
                            for (j=0; j<W; j=j+1) begin
                                adjusted_lines[build_line_idx][j] <= word_memory[build_word_idx][j];
                            end
                            build_col <= W;
                        end
                        build_word_idx <= build_word_idx + 1;
                    end else begin
                        if ((build_col + 1 + word_len[build_word_idx]) <= W) begin
                            adjusted_lines[build_line_idx][build_col] <= 8'h20;
                            for (j=0; j<word_len[build_word_idx]; j=j+1) begin
                                adjusted_lines[build_line_idx][build_col + 1 + j] <= word_memory[build_word_idx][j];
                            end
                            build_col <= build_col + 1 + word_len[build_word_idx];
                            build_word_idx <= build_word_idx + 1;
                        end else begin
                            build_line_idx <= build_line_idx + 1;
                            build_col <= 0;
                        end
                    end
                end else begin
                    line_count <= build_line_idx + (build_col > 0 ? 4'd1 : 4'd0);
                    next_state <= CALC;
                end
            end
            
            CALC: begin
                if (line_count > H) begin
                    thumb_pos <= ((H - 3'd3) * F) / (line_count - H);
                end else begin
                    thumb_pos <= 8'd0;
                end
                next_state <= RENDER;
                render_line <= 4'd0;
                render_col <= 4'd0;
            end
            
            RENDER: begin
                char_valid <= 1'b1;
                
                if (render_col < (W + 4'd4)) begin
                    if (render_line == 4'd0 || render_line == (H + 4'd1)) begin
                        if (render_col == 4'd0 || render_col == (W + 4'd3)) begin
                            char_out <= "+";
                        end else begin
                            char_out <= "-";
                        end
                    end else begin
                        if (render_col == 4'd0) begin
                            char_out <= "|";
                        end else if (render_col == (W + 4'd1)) begin
                            char_out <= 8'h20;
                        end else if (render_col == (W + 4'd2)) begin
                            if (render_line == 4'd1) begin
                                char_out <= "^";
                            end else if (render_line == H) begin
                                char_out <= "v";
                            end else if ((render_line - 4'd1) == (thumb_pos + 4'd1)) begin
                                char_out <= "X";
                            end else begin
                                char_out <= 8'h20;
                            end
                        end else if (render_col == (W + 4'd3)) begin
                            char_out <= "|";
                        end else begin
                            if (render_line <= line_count) begin
                                char_out <= adjusted_lines[render_line][render_col - 4'd1];
                                if (char_out == 8'h00) char_out <= 8'h20;
                            end else begin
                                char_out <= 8'h20;
                            end
                        end
                    end
                    
                    render_col <= render_col + 1;
                end else begin
                    char_valid <= 1'b0;
                    render_col <= 0;
                    render_line <= render_line + 1;
                    
                    if (render_line == (H + 4'd1)) begin
                        next_state <= DONE_STATE;
                    end
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                if (!start) begin
                    next_state <= IDLE;
                end
            end
            
            default: next_state <= IDLE;
        endcase
    end
end

endmodule