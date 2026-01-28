module TypoDetector(
    input clk,
    input rst_n,
    input start,
    input [3:0] word_count,
    input [3:0] word_len [0:15],
    input [127:0] word_data [0:15],
    output reg [3:0] result_index,
    output reg is_typo,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SETUP = 3'd1;
    localparam [2:0] CHECK_DELETIONS = 3'd2;
    localparam [2:0] VERIFY_EXISTENCE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] NEXT_WORD = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] current_word_index;
    reg [3:0] deletion_pos;
    reg [3:0] compare_index;
    reg [3:0] cycle_count;
    reg [127:0] current_word;
    reg [127:0] candidate_word;
    reg [3:0] current_word_length;
    reg candidate_found;

    // Word storage registers
    reg [127:0] stored_words [0:15];
    reg [3:0] stored_lengths [0:15];

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_word_index <= 4'd0;
            deletion_pos <= 4'd0;
            compare_index <= 4'd0;
            cycle_count <= 4'd0;
            current_word <= 128'd0;
            candidate_word <= 128'd0;
            current_word_length <= 4'd0;
            candidate_found <= 1'b0;
            result_index <= 4'd0;
            is_typo <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;

            // Initialize stored words and lengths
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                stored_words[i] <= 128'd0;
                stored_lengths[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                busy = 1'b0;
                done = 1'b0;
                if (start) begin
                    next_state = SETUP;
                    busy = 1'b1;
                end
            end

            SETUP: begin
                // Load current word and length
                current_word = word_data[current_word_index];
                current_word_length = word_len[current_word_index];

                // Store all words and lengths
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    stored_words[i] = word_data[i];
                    stored_lengths[i] = word_len[i];
                end

                next_state = CHECK_DELETIONS;
                deletion_pos = 4'd0;
                candidate_found = 1'b0;
            end

            CHECK_DELETIONS: begin
                // Generate candidate by deleting character at deletion_pos
                integer i;
                candidate_word = 128'd0;
                for (i = 0; i < current_word_length; i = i + 1) begin
                    if (i < deletion_pos) begin
                        candidate_word[(i*8)+7:i*8] = current_word[(i*8)+7:i*8];
                    end else if (i > deletion_pos) begin
                        candidate_word[((i-1)*8)+7:(i-1)*8] = current_word[(i*8)+7:i*8];
                    end
                end

                next_state = VERIFY_EXISTENCE;
                compare_index = 4'd0;
            end

            VERIFY_EXISTENCE: begin
                // Compare candidate with all other words
                reg [127:0] compare_word;
                reg [3:0] compare_length;
                reg match;
                integer i;

                compare_word = stored_words[compare_index];
                compare_length = stored_lengths[compare_index];

                // Check if lengths match (candidate length = current_word_length - 1)
                if (compare_length == current_word_length - 1) begin
                    match = 1'b1;
                    for (i = 0; i < compare_length; i = i + 1) begin
                        if (candidate_word[(i*8)+7:i*8] != compare_word[(i*8)+7:i*8]) begin
                            match = 1'b0;
                        end
                    end
                end else begin
                    match = 1'b0;
                end

                // If match found and not same word
                if (match && (compare_index != current_word_index)) begin
                    candidate_found = 1'b1;
                end

                // Move to next word or finish
                if (compare_index == word_count - 1) begin
                    if (candidate_found || deletion_pos == current_word_length - 1) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = CHECK_DELETIONS;
                        deletion_pos = deletion_pos + 4'd1;
                    end
                end else begin
                    compare_index = compare_index + 4'd1;
                end
            end

            OUTPUT: begin
                result_index = current_word_index;
                is_typo = candidate_found;
                next_state = NEXT_WORD;
            end

            NEXT_WORD: begin
                if (current_word_index == word_count - 1) begin
                    next_state = IDLE;
                    done = 1'b1;
                    busy = 1'b0;
                end else begin
                    next_state = SETUP;
                    current_word_index = current_word_index + 4'd1;
                end
            end

            default: begin
                next_state = IDLE;
                busy = 1'b0;
            end
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 4'd0;
        end else if (state != IDLE) begin
            if (cycle_count == 4'd15) begin
                cycle_count <= 4'd0;
            end else begin
                cycle_count <= cycle_count + 4'd1;
            end
        end
    end

endmodule