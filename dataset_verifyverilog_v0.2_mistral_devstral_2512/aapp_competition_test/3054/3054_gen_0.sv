module haiku_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,  // ASCII character input
    input wire char_valid,      // High if char_in is valid
    output reg [2:0] state_out, // 0: IDLE, 1: PARSE, 2: CHECK, 3: VALID, 4: INVALID
    output reg [7:0] display_char // Character to display (for debugging/simulation)
);

// FSM States
localparam IDLE = 3'd0;
localparam PARSE = 3'd1;
localparam CHECK = 3'd2;
localparam VALID = 3'd3;
localparam INVALID = 3'd4;

// Constants for syllable targets
localparam TARGET_L1 = 5;
localparam TARGET_L2 = 7;
localparam TARGET_L3 = 5;
localparam MAX_WORDS = 16; // Max words in a line (scaled down)

// Internal Registers
reg [7:0] text_buffer [0:199]; // 200 character buffer
reg [7:0] word_syllables [0:15]; // Syllables per word
reg [7:0] word_lengths [0:15];   // Length of each word (for reconstruction)
reg [7:0] char_idx;
reg [7:0] word_idx;
reg [7:0] word_char_idx;
reg [2:0] current_syllable_count;
reg [2:0] line_1_total;
reg [2:0] line_2_total;
reg [2:0] line_3_total;

// Helper registers for syllable logic
reg in_vowel_group;
reg prev_was_vowel;
reg prev_was_q;
reg prev_was_y_consonant;
reg [7:0] last_alpha_char;
reg [7:0] next_to_last_alpha_char;
reg is_parsing_word;

// Solver registers
reg [3:0] solver_idx;
reg [2:0] solver_accum;
reg [1:0] solver_phase;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_out <= IDLE;
        char_idx <= 8'd0;
        word_idx <= 8'd0;
        in_vowel_group <= 1'b0;
        prev_was_vowel <= 1'b0;
        is_parsing_word <= 1'b0;
        current_syllable_count <= 3'd0;
        for (i = 0; i < 200; i = i + 1) text_buffer[i] <= 8'd0;
        for (i = 0; i < 16; i = i + 1) begin
            word_syllables[i] <= 8'd0;
            word_lengths[i] <= 8'd0;
        end
    end else begin
        case (state_out)
            IDLE: begin
                if (start) begin
                    state_out <= PARSE;
                    char_idx <= 8'd0;
                    word_idx <= 8'd0;
                    word_char_idx <= 8'd0;
                    is_parsing_word <= 1'b0;
                    current_syllable_count <= 3'd0;
                    in_vowel_group <= 1'b0;
                    prev_was_vowel <= 1'b0;
                    prev_was_q <= 1'b0;
                    prev_was_y_consonant <= 1'b0;
                    last_alpha_char <= 8'd0;
                    next_to_last_alpha_char <= 8'd0;
                end
            end

            PARSE: begin
                if (char_valid) begin
                    text_buffer[char_idx] <= char_in;
                    
                    // Check if alphabetic
                    if ((char_in >= 8'h41 && char_in <= 8'h5A) || (char_in >= 8'h61 && char_in <= 8'h7A)) begin
                        // Is Alpha
                        if (!is_parsing_word) begin
                            is_parsing_word <= 1'b1;
                            word_char_idx <= 8'd0;
                            current_syllable_count <= 3'd0;
                            in_vowel_group <= 1'b0;
                            prev_was_vowel <= 1'b0;
                            prev_was_q <= 1'b0;
                            prev_was_y_consonant <= 1'b0;
                            last_alpha_char <= 8'd0;
                            next_to_last_alpha_char <= 8'd0;
                        end
                        
                        // Logic for syllable counting
                        // Convert to lowercase for logic
                        reg [7:0] lower_char;
                        lower_char = (char_in >= 8'h41 && char_in <= 8'h5A) ? (char_in + 8'h20) : char_in;
                        
                        // Check Vowel/Consonant
                        reg is_vowel;
                        is_vowel = 1'b0;
                        if (lower_char == 8'h61 || lower_char == 8'h65 || lower_char == 8'h69 || 
                            lower_char == 8'h6f || lower_char == 8'h75) is_vowel = 1'b1;
                        // 'y' check
                        if (lower_char == 8'h79) begin
                            is_vowel = 1'b1;
                        end

                        // "QU" is single consonant
                        if (prev_was_q && lower_char == 8'h75) begin
                            // 'u' after 'q', treat as consonant block, no syllable increment
                            // Reset vowel group
                            in_vowel_group <= 1'b0;
                            is_vowel = 1'b0; // Treat as consonant for boundary logic
                        end
                        
                        if (is_vowel) begin
                            if (!in_vowel_group) begin
                                current_syllable_count <= current_syllable_count + 1;
                                in_vowel_group <= 1'b1;
                            end
                        end else begin
                            in_vowel_group <= 1'b0;
                        end
                        
                        // Update history
                        prev_was_q <= (lower_char == 8'h71);
                        next_to_last_alpha_char <= last_alpha_char;
                        last_alpha_char <= lower_char;
                        prev_was_vowel <= is_vowel;
                        prev_was_y_consonant <= 1'b0; // Reset for next check
                        
                        word_char_idx <= word_char_idx + 1;
                        
                    end else begin
                        // Not Alpha (Space, Punctuation, etc)
                        if (is_parsing_word) begin
                            // End of a word
                            // Apply Exception Rules based on accumulated history
                            
                            reg [2:0] final_syllables;
                            final_syllables = current_syllable_count;
                            
                            // Rule: Silent E
                            if (last_alpha_char == 8'h65 && final_syllables > 1) begin
                                final_syllables = final_syllables - 1;
                            end
                            
                            if (final_syllables < 1) final_syllables = 1;
                            
                            // Store
                            word_syllables[word_idx] <= {5'd0, final_syllables};
                            word_lengths[word_idx] <= word_char_idx;
                            word_idx <= word_idx + 1;
                            
                            is_parsing_word <= 1'b0;
                        end
                    end
                    
                    // Check for End of Input (Newline or Max Length)
                    if (char_in == 8'h0a || char_idx == 8'd199) begin
                        state_out <= CHECK;
                    end else begin
                        char_idx <= char_idx + 1;
                    end
                end
            end

            CHECK: begin
                state_out <= 3'd5; // Special state for Solver
                solver_idx <= 0;
                solver_accum <= 0;
                solver_phase <= 0;
            end

            3'd5: begin // SOLVER state
                if (solver_idx < word_idx) begin
                    reg [2:0] target;
                    if (solver_phase == 0) target = TARGET_L1;
                    else if (solver_phase == 1) target = TARGET_L2;
                    else target = TARGET_L3;
                    
                    if (solver_accum + word_syllables[solver_idx] <= target) begin
                        solver_accum <= solver_accum + word_syllables[solver_idx];
                        solver_idx <= solver_idx + 1;
                        
                        if (solver_accum == target) begin
                            if (solver_phase < 2) begin
                                solver_phase <= solver_phase + 1;
                                solver_accum <= 0;
                            end
                        end
                    end else begin
                        state_out <= INVALID;
                    end
                end else begin
                    if (solver_phase == 2 && solver_accum == TARGET_L3) state_out <= VALID;
                    else state_out <= INVALID;
                end
            end
            
            VALID: state_out <= VALID;
            INVALID: state_out <= INVALID;
        endcase
    end
end

endmodule