module substitution_cipher_decoder (
    input clk,
    input rst_n,
    input start,
    input [63:0] encrypted_text,
    input [5:0] text_length,
    output reg [63:0] plaintext,
    output reg [255:0] mapping,
    output reg valid,
    output reg done,
    output reg ambiguous
);

    // Known words (12 words, stored as packed arrays)
    localparam [7:0] KNOWN_WORDS [0:11] = '{8'h6265, 8'h6f7572, 8'h72756d, 8'h77696c6c, 8'h64656164, 8'h686f6f6b, 8'h73686970, 8'h626c6f6f64, 8'h7361626c65, 8'h6176656e6765, 8'h706172726f74, 8'h6361707461696e};
    localparam [2:0] KNOWN_WORD_LENGTHS [0:11] = '{3'd2, 3'd3, 3'd3, 3'd4, 3'd4, 3'd4, 3'd4, 3'd5, 3'd5, 3'd6, 3'd6, 3'd7};

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        PREPARE,
        GENERATE_CANDIDATES,
        VERIFY_MAPPING,
        COMPLETE
    } state_t;
    state_t state, next_state;

    // Internal registers
    reg [63:0] plaintext_reg;
    reg [255:0] mapping_reg;
    reg valid_reg;
    reg done_reg;
    reg ambiguous_reg;

    reg [5:0] cycle_count;
    reg [25:0] unique_encrypted_letters;
    reg [25:0] unique_plain_letters;
    reg [25:0] candidate_mapping [0:25];
    reg [7:0] solution_count;

    // Pattern matching results
    reg [25:0] word_match [0:11];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            unique_encrypted_letters <= 0;
            unique_plain_letters <= 0;
            solution_count <= 0;
            plaintext_reg <= 0;
            mapping_reg <= 0;
            valid_reg <= 0;
            done_reg <= 0;
            ambiguous_reg <= 0;
            for (int i = 0; i < 26; i++) begin
                candidate_mapping[i] <= 0;
            end
        end else begin
            state <= next_state;
            if (state == PREPARE) begin
                // Pre-compute unique letters in encrypted text
                unique_encrypted_letters <= 0;
                for (int i = 0; i < text_length; i++) begin
                    reg [7:0] char = encrypted_text[i*8 +: 8];
                    if (char >= 8'h61 && char <= 8'h7a) begin
                        unique_encrypted_letters[char - 8'h61] <= 1;
                    end
                end
            end else if (state == GENERATE_CANDIDATES) begin
                // Generate candidate mappings from word matches
                for (int i = 0; i < 12; i++) begin
                    word_match[i] <= 0;
                    for (int j = 0; j < text_length - KNOWN_WORD_LENGTHS[i] + 1; j++) begin
                        reg match = 1;
                        for (int k = 0; k < KNOWN_WORD_LENGTHS[i]; k++) begin
                            reg [7:0] enc_char = encrypted_text[(j + k)*8 +: 8];
                            reg [7:0] word_char = KNOWN_WORDS[i][k*8 +: 8];
                            if (enc_char != word_char) begin
                                match = 0;
                            end
                        end
                        if (match) begin
                            word_match[i][j] <= 1;
                        end
                    end
                end
            end else if (state == VERIFY_MAPPING) begin
                // Verify candidate mapping
                reg [25:0] temp_mapping = 0;
                reg [63:0] temp_plaintext = 0;
                reg valid_mapping = 1;
                reg [25:0] temp_unique_plain = 0;

                // Apply mapping to encrypted text
                for (int i = 0; i < text_length; i++) begin
                    reg [7:0] enc_char = encrypted_text[i*8 +: 8];
                    if (enc_char >= 8'h61 && enc_char <= 8'h7a) begin
                        reg [7:0] plain_char = mapping_reg[enc_char*8 +: 8];
                        temp_plaintext[i*8 +: 8] <= plain_char;
                        temp_unique_plain[plain_char - 8'h61] <= 1;
                    end else begin
                        temp_plaintext[i*8 +: 8] <= enc_char;
                    end
                end

                // Check uniqueness constraint
                reg [25:0] unique_enc = 0;
                for (int i = 0; i < 26; i++) begin
                    if (unique_encrypted_letters[i]) begin
                        unique_enc[i] <= 1;
                    end
                end

                reg [25:0] unique_plain = 0;
                for (int i = 0; i < 26; i++) begin
                    if (temp_unique_plain[i]) begin
                        unique_plain[i] <= 1;
                    end
                end

                if (unique_enc == unique_plain) begin
                    solution_count <= solution_count + 1;
                    plaintext_reg <= temp_plaintext;
                end
            end else if (state == COMPLETE) begin
                if (solution_count == 1) begin
                    valid_reg <= 1;
                    ambiguous_reg <= 0;
                end else if (solution_count > 1) begin
                    valid_reg <= 0;
                    ambiguous_reg <= 1;
                end else begin
                    valid_reg <= 0;
                    ambiguous_reg <= 0;
                end
                done_reg <= 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PREPARE;
                    cycle_count = 0;
                    unique_encrypted_letters = 0;
                    unique_plain_letters = 0;
                    solution_count = 0;
                    plaintext_reg = 0;
                    mapping_reg = 0;
                    valid_reg = 0;
                    done_reg = 0;
                    ambiguous_reg = 0;
                    for (int i = 0; i < 26; i++) begin
                        candidate_mapping[i] = 0;
                    end
                end
            end
            PREPARE: begin
                next_state = GENERATE_CANDIDATES;
            end
            GENERATE_CANDIDATES: begin
                next_state = VERIFY_MAPPING;
            end
            VERIFY_MAPPING: begin
                if (cycle_count < 200) begin
                    next_state = VERIFY_MAPPING;
                    cycle_count = cycle_count + 1;
                end else begin
                    next_state = COMPLETE;
                end
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output assignments
    always @(*) begin
        plaintext = plaintext_reg;
        mapping = mapping_reg;
        valid = valid_reg;
        done = done_reg;
        ambiguous = ambiguous_reg;
    end

endmodule