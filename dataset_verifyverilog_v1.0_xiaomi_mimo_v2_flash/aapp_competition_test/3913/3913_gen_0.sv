module field_of_wonders (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,          // Actual word length (≤8)
    input wire [63:0] pattern,   // Packed pattern (8 chars, 8-bit each)
    input wire [3:0] m,          // Number of words (≤8)
    input wire [63:0] word0,     // Packed word0 (8 chars)
    input wire [63:0] word1,
    input wire [63:0] word2,
    input wire [63:0] word3,
    input wire [63:0] word4,
    input wire [63:0] word5,
    input wire [63:0] word6,
    input wire [63:0] word7,
    output reg [4:0] result,     // Result (0-26)
    output reg done              // Computation complete
);

// State definitions
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] CHECK_WORDS  = 3'd1;
localparam [2:0] COUNT_LETTERS = 3'd2;
localparam [2:0] DONE_STATE   = 3'd3;

reg [2:0] state;
reg [2:0] word_idx;             // Current word index (0-7)
reg [4:0] letter_idx;           // Current letter (0-25)
reg [25:0] revealed_mask;       // Revealed letters bitmask
reg [7:0] valid_words;          // Valid word flags
reg [25:0] hidden_masks [0:7];  // Hidden letters per word
reg [3:0] total_valid;          // Count of valid words
reg [4:0] result_reg;           // Result accumulator
reg [3:0] cycle_count;         // Cycle counter to prevent infinite loops

// Combinational word selection
reg [63:0] current_word;
always @(*) begin
    case (word_idx)
        3'd0: current_word = word0;
        3'd1: current_word = word1;
        3'd2: current_word = word2;
        3'd3: current_word = word3;
        3'd4: current_word = word4;
        3'd5: current_word = word5;
        3'd6: current_word = word6;
        3'd7: current_word = word7;
        default: current_word = word0;
    endcase
end

// Combinational logic for word validation
reg valid_flag;
reg [25:0] hidden_mask;
reg [7:0] char_pat;
reg [7:0] char_word;
reg [4:0] bit_idx;
integer j;

always @(*) begin
    valid_flag = 1'b1;
    hidden_mask = 26'd0;
    
    if (state == CHECK_WORDS) begin
        for (j = 0; j < 8; j = j + 1) begin
            if (j < n) begin
                // Extract characters
                char_pat = pattern[8*j +: 8];
                char_word = current_word[8*j +: 8];
                
                if (char_pat != 8'h2A) begin
                    // Revealed position - must match
                    if (char_pat != char_word) valid_flag = 1'b0;
                end else begin
                    // Hidden position - must not use revealed letters
                    if (char_word >= 8'h61 && char_word <= 8'h7A) begin
                        bit_idx = char_word - 8'h61;
                        if (revealed_mask[bit_idx]) 
                            valid_flag = 1'b0;  // Uses revealed letter
                        else 
                            hidden_mask[bit_idx] = 1'b1;  // Track hidden letter
                    end else begin
                        valid_flag = 1'b0;  // Invalid character
                    end
                end
            end
        end
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        word_idx <= 3'd0;
        letter_idx <= 5'd0;
        result <= 5'd0;
        done <= 1'b0;
        revealed_mask <= 26'd0;
        valid_words <= 8'd0;
        total_valid <= 4'd0;
        result_reg <= 5'd0;
        cycle_count <= 4'd0;
        hidden_masks[0] <= 26'd0;
        hidden_masks[1] <= 26'd0;
        hidden_masks[2] <= 26'd0;
        hidden_masks[3] <= 26'd0;
        hidden_masks[4] <= 26'd0;
        hidden_masks[5] <= 26'd0;
        hidden_masks[6] <= 26'd0;
        hidden_masks[7] <= 26'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 4'd0;
                if (start) begin
                    // Build revealed letters mask
                    revealed_mask <= 26'd0;
                    if (n > 4'd0 && n <= 4'd8) begin
                        if (pattern[7:0] != 8'h2A && pattern[7:0] >= 8'h61 && pattern[7:0] <= 8'h7A)
                            revealed_mask[pattern[7:0] - 8'h61] <= 1'b1;
                        if (n > 4'd1) begin
                            if (pattern[15:8] != 8'h2A && pattern[15:8] >= 8'h61 && pattern[15:8] <= 8'h7A)
                                revealed_mask[pattern[15:8] - 8'h61] <= 1'b1;
                        end
                        if (n > 4'd2) begin
                            if (pattern[23:16] != 8'h2A && pattern[23:16] >= 8'h61 && pattern[23:16] <= 8'h7A)
                                revealed_mask[pattern[23:16] - 8'h61] <= 1'b1;
                        end
                        if (n > 4'd3) begin
                            if (pattern[31:24] != 8'h2A && pattern[31:24] >= 8'h61 && pattern[31:24] <= 8'h7A)
                                revealed_mask[pattern[31:24] - 8'h61] <= 1'b1;
                        end
                        if (n > 4'd4) begin
                            if (pattern[39:32] != 8'h2A && pattern[39:32] >= 8'h61 && pattern[39:32] <= 8'h7A)
                                revealed_mask[pattern[39:32] - 8'h61] <= 1'b1;
                        end
                        if (n > 4'd5) begin
                            if (pattern[47:40] != 8'h2A && pattern[47:40] >= 8'h61 && pattern[47:40] <= 8'h7A)
                                revealed_mask[pattern[47:40] - 8'h61] <= 1'b1;
                        end
                        if (n > 4'd6) begin
                            if (pattern[55:48] != 8'h2A && pattern[55:48] >= 8'h61 && pattern[55:48] <= 8'h7A)
                                revealed_mask[pattern[55:48] - 8'h61] <= 1'b1;
                        end
                        if (n > 4'd7) begin
                            if (pattern[63:56] != 8'h2A && pattern[63:56] >= 8'h61 && pattern[63:56] <= 8'h7A)
                                revealed_mask[pattern[63:56] - 8'h61] <= 1'b1;
                        end
                    end
                    // Reset counters
                    word_idx <= 3'd0;
                    total_valid <= 4'd0;
                    valid_words <= 8'd0;
                    result_reg <= 5'd0;
                    state <= CHECK_WORDS;
                end
            end
            
            CHECK_WORDS: begin
                if (word_idx < m && word_idx < 4'd8) begin
                    cycle_count <= cycle_count + 4'd1;
                    // Validate current word
                    if (valid_flag) begin
                        valid_words[word_idx] <= 1'b1;
                        hidden_masks[word_idx] <= hidden_mask;
                        total_valid <= total_valid + 4'd1;
                    end
                    word_idx <= word_idx + 3'd1;
                    if (cycle_count >= 4'd8) begin
                        state <= COUNT_LETTERS;
                        letter_idx <= 5'd0;
                    end
                end else begin
                    // Move to counting
                    letter_idx <= 5'd0;
                    state <= COUNT_LETTERS;
                    cycle_count <= 4'd0;
                end
            end
            
            COUNT_LETTERS: begin
                if (letter_idx < 5'd26) begin
                    cycle_count <= cycle_count + 4'd1;
                    // Skip revealed letters
                    if (!revealed_mask[letter_idx]) begin
                        reg [4:0] count;
                        count = 5'd0;
                        // Count valid words with this letter
                        if (m > 4'd0 && valid_words[0] && hidden_masks[0][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd1 && valid_words[1] && hidden_masks[1][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd2 && valid_words[2] && hidden_masks[2][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd3 && valid_words[3] && hidden_masks[3][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd4 && valid_words[4] && hidden_masks[4][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd5 && valid_words[5] && hidden_masks[5][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd6 && valid_words[6] && hidden_masks[6][letter_idx])
                            count = count + 5'd1;
                        if (m > 4'd7 && valid_words[7] && hidden_masks[7][letter_idx])
                            count = count + 5'd1;
                        if (count == total_valid)
                            result_reg <= result_reg + 5'd1;
                    end
                    letter_idx <= letter_idx + 5'd1;
                    if (cycle_count >= 4'd10) begin
                        result <= result_reg;
                        state <= DONE_STATE;
                        done <= 1'b1;
                    end
                end else begin
                    result <= result_reg;
                    state <= DONE_STATE;
                    done <= 1'b1;
                end
            end
            
            DONE_STATE: begin
                // Stay done until reset
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule