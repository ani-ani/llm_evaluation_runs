module haiku_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    output reg [2:0] state_out,
    output reg [7:0] display_char
);

    // FSM States
    localparam IDLE = 3'd0;
    localparam PARSE = 3'd1;
    localparam CHECK = 3'd2;
    localparam VALID = 3'd3;
    localparam INVALID = 3'd4;
    localparam SOLVER = 3'd5; // Replaces CHECK logic state

    // Constants for syllable targets
    localparam TARGET_L1 = 5;
    localparam TARGET_L2 = 7;
    localparam TARGET_L3 = 5;
    localparam MAX_WORDS = 20;

    // Internal Registers
    reg [7:0] text_buffer [0:127]; // Buffer for reconstructed text
    reg [7:0] word_syllables [0:19]; // Syllables per word
    reg [7:0] char_idx;
    reg [7:0] word_idx;
    reg [7:0] word_char_idx;
    reg [2:0] current_syllable_count;

    // Syllable logic flags
    reg in_vowel_group;
    reg prev_was_q;
    reg is_parsing_word;
    reg [7:0] last_alpha_char;
    reg [7:0] next_to_last_alpha_char;

    // Solver registers
    reg [4:0] solver_idx;
    reg [3:0] solver_accum;
    reg [1:0] solver_phase;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_out <= IDLE;
            char_idx <= 8'd0;
            word_idx <= 8'd0;
            in_vowel_group <= 1'b0;
            is_parsing_word <= 1'b0;
            current_syllable_count <= 3'd0;
            prev_was_q <= 1'b0;
            display_char <= 8'd0;
            solver_idx <= 5'd0;
            solver_accum <= 4'd0;
            solver_phase <= 2'd0;
            // Initialize memory to avoid latch inference (though not strictly necessary for functionality)
            for (i = 0; i < 20; i = i + 1) word_syllables[i] <= 8'd0;
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
                        prev_was_q <= 1'b0;
                        last_alpha_char <= 8'd0;
                        next_to_last_alpha_char <= 8'd0;
                        display_char <= 8'd0;
                    end
                end

                PARSE: begin
                    if (char_valid) begin
                        text_buffer[char_idx] <= char_in;
                        display_char <= char_in;

                        // Check if alphabetic
                        if ((char_in >= 8'h41 && char_in <= 8'h5A) || (char_in >= 8'h61 && char_in <= 8'h7A)) begin
                            // --- Logic for syllable counting ---
                            // Convert to lowercase
                            reg [7:0] lower_char;
                            lower_char = (char_in >= 8'h41 && char_in <= 8'h5A) ? (char_in + 8'h20) : char_in;

                            // Check Vowel
                            reg is_vowel;
                            is_vowel = 1'b0;
                            if (lower_char == 8'h61 || lower_char == 8'h65 || lower_char == 8'h69 || 
                                lower_char == 8'h6f || lower_char == 8'h75) is_vowel = 1'b1;

                            // Y Special Case (Treat as vowel unless previous was vowel - heuristic)
                            if (lower_char == 8'h79) begin
                                // If previous was vowel, Y is likely consonant (e.g. 'ay' in 'day').
                                // Simplification for hardware: Treat Y as vowel, but don't double count.
                                if (!in_vowel_group) begin
                                    if (prev_was_q && lower_char == 8'h75) begin
                                        // Q followed by U is already handled below as consonant block
                                    end else begin
                                        // Y starts a group if not in one
                                        if (!prev_was_vowel_reg) is_vowel = 1'b1;
                                    end
                                end
                            end

                            // "QU" is single consonant sound
                            if (prev_was_q && lower_char == 8'h75) begin
                                // 'u' after 'q' is part of consonant block
                                in_vowel_group <= 1'b0;
                                is_vowel = 1'b0;
                            end

                            // Vowel Group Logic
                            if (is_vowel) begin
                                if (!in_vowel_group) begin
                                    current_syllable_count <= current_syllable_count + 1;
                                    in_vowel_group <= 1'b1;
                                end
                            end else begin
                                in_vowel_group <= 1'b0;
                            end

                            // History Updates
                            prev_was_q <= (lower_char == 8'h71);
                            next_to_last_alpha_char <= last_alpha_char;
                            last_alpha_char <= lower_char;
                            word_char_idx <= word_char_idx + 1;

                        end else begin
                            // Not Alpha (Space, Punctuation, Newline)
                            if (is_parsing_word) begin
                                // End of a word - Apply Rules
                                reg [2:0] final_syl;
                                final_syl = current_syllable_count;

                                // Rule: Silent E
                                if (last_alpha_char == 8'h65 && final_syl > 1) begin
                                    // Check 'LE' ending
                                    reg is_le_exception;
                                    is_le_exception = (next_to_last_alpha_char == 8'h6c);

                                    if (!is_le_exception) begin
                                        final_syl = final_syl - 1;
                                    end
                                end

                                if (final_syl < 1) final_syl = 1;

                                // Store word syllable count
                                if (word_idx < MAX_WORDS) begin
                                    word_syllables[word_idx] <= {5'd0, final_syl};
                                    word_idx <= word_idx + 1;
                                end

                                // Reset word parsing state
                                is_parsing_word <= 1'b0;
                                current_syllable_count <= 3'd0;
                            end
                        end

                        // --- Handle End of Input ---
                        if (char_in == 8'h0a || char_idx == 8'd127 || word_idx >= MAX_WORDS) begin
                            if (word_idx > 0) state_out <= SOLVER;
                            else state_out <= INVALID; // No words
                        end else begin
                            // If we see a space/newline that breaks a word, we handled it above.
                            // If we see an alpha, we handle it.
                            // We need to distinguish "start of word" vs "continuation" when we see alpha.
                            // This is handled by 'is_parsing_word' logic.

                            // We need to set is_parsing_word if we just saw an alpha and it wasn't set.
                            // This must be done AFTER the check for non-alpha above.
                            // If we are here, char is alpha.
                            if (!is_parsing_word) begin
                                is_parsing_word <= 1'b1;
                                word_char_idx <= 8'd0;
                                current_syllable_count <= 3'd0;
                                in_vowel_group <= 1'b0;
                                prev_was_q <= 1'b0;
                                // Reset history
                                last_alpha_char <= 8'd0;
                                next_to_last_alpha_char <= 8'd0;
                            end
                            char_idx <= char_idx + 1;
                        end
                    end
                end

                SOLVER: begin
                    // Check syllable sums for 5-7-5 pattern
                    // We iterate through word_syllables array
                    // Line 1: Sum to 5
                    // Line 2: Sum to 7
                    // Line 3: Sum to 5

                    if (solver_idx < word_idx) begin
                        // Determine target based on phase
                        reg [3:0] target;
                        case (solver_phase)
                            2'd0: target = TARGET_L1;
                            2'd1: target = TARGET_L2;
                            2'd2: target = TARGET_L3;
                            default: target = 4'd0;
                        endcase

                        // Check if adding this word exceeds target
                        if (solver_accum + word_syllables[solver_idx] > target) begin
                            state_out <= INVALID;
                        end else begin
                            solver_accum <= solver_accum + word_syllables[solver_idx];
                            solver_idx <= solver_idx + 1;

                            // If we hit the target exactly
                            if (solver_accum + word_syllables[solver_idx] == target) begin
                                if (solver_phase == 2'd2) begin
                                    // Last line completed. Must be end of words.
                                    if (solver_idx == word_idx - 1) begin // Currently adding last word
                                        state_out <= VALID;
                                    end else begin
                                        // Extra words remaining
                                        state_out <= INVALID;
                                    end
                                end else begin
                                    // Next line
                                    solver_phase <= solver_phase + 1;
                                    solver_accum <= 0;
                                end
                            end
                        end
                    end else begin
                        // Ran out of words
                        state_out <= INVALID;
                    end

                    // Safety Timeout: If we are just starting and word_idx is 0 (should be caught earlier)
                    if (word_idx == 0) state_out <= INVALID;
                end

                VALID: begin
                    state_out <= VALID;
                end

                INVALID: begin
                    state_out <= INVALID;
                end
            endcase
        end
    end

    // Helper reg for Y logic
    reg prev_was_vowel_reg;

endmodule
module tb_haiku_solver ();
    reg clk;
    reg rst_n;
    reg start;
    reg [7:0] char_in;
    reg char_valid;
    wire [2:0] state_out;
    wire [7:0] display_char;

    haiku_solver uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .char_in(char_in),
        .char_valid(char_valid),
        .state_out(state_out),
        .display_char(display_char)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_string(input [1023:0] str);
        integer len;
        integer i;
        begin
            len = 0;
            while (str[len*8 +: 8] != 0) len = len + 1;
            for (i = 0; i < len; i = i + 1) begin
                char_in = str[i*8 +: 8];
                char_valid = 1;
                @(posedge clk);
                char_valid = 0;
                @(posedge clk);
            end
            // Send Newline
            char_in = 8'h0a;
            char_valid = 1;
            @(posedge clk);
            char_valid = 0;
            @(posedge clk);
        end
    endtask

    task check_state(input [2:0] expected, input [8*10:0] name);
        begin
            if (state_out !== expected) begin
                $display("Error: Expected %s (%0d), got %0d", name, expected, state_out);
                $finish;
            end else begin
                $display("Pass: %s", name);
            end
        end
    endtask

    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        char_valid = 0;
        char_in = 0;
        #20;
        rst_n = 1;
        #10;

        // Test 1: Simple Valid Haiku (5-7-5)
        $display("--- Test 1: Valid Haiku ---");
        start = 1;
        @(posedge clk);
        start = 0;
        send_string("An old silent pond");
        send_string("A frog jumps into the pond");
        send_string("Splash! Silence again");
        wait(state_out == 3'd3 || state_out == 3'd4);
        check_state(3, "VALID (Test 1)");
        #20;

        // Reset for Test 2
        rst_n = 0;
        #10;
        rst_n = 1;
        #10;

        // Test 2: Invalid (5-7-4)
        $display("--- Test 2: Invalid Haiku (5-7-4) ---");
        start = 1;
        @(posedge clk);
        start = 0;
        send_string("An old silent pond");
        send_string("A frog jumps into the pond");
        send_string("Splash! Silence sil");
        wait(state_out == 3'd3 || state_out == 3'd4);
        check_state(4, "INVALID (Test 2)");
        #20;

        // Reset for Test 3
        rst_n = 0;
        #10;
        rst_n = 1;
        #10;

        // Test 3: Valid with Silent E
        $display("--- Test 3: Valid (Simple Words) ---");
        start = 1;
        @(posedge clk);
        start = 0;
        send_string("Pa Pe Pi Po Pu");
        send_string("Goo D Ca Tu Su So Me");
        send_string("Ba Bi Bu Be Bo");
        wait(state_out == 3'd3 || state_out == 3'd4);
        check_state(3, "VALID (Test 3)");
        #20;

        $display("All Tests Passed!");
        $finish;
    end

endmodule