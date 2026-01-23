module pattern_probability_sorter (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_patterns,
    input [7:0] pattern_length,
    input [5:0][63:0] predictions,
    output reg [2:0] sorted_indices [7:0],
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        PARSE,
        COMPUTE_SCORES,
        SORT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] pattern_idx;
    reg [7:0] char_idx;
    reg [7:0] pattern_char [7:0][7:0]; // 8 patterns, 8 chars each
    reg [31:0] score [7:0]; // Q16.16 scores
    reg [2:0] temp_indices [7:0];
    reg [2:0] i, j;
    reg [31:0] temp_score;
    reg [31:0] reciprocal_3powL;
    reg [7:0] L;
    reg [7:0] overlap_count;
    reg [31:0] n_minus_L_plus_1;

    // Precomputed 3^L values (for L=1 to 8)
    localparam [31:0] pow3 [7:0] = '{3, 9, 27, 81, 243, 729, 2187, 6561};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            pattern_idx <= 0;
            char_idx <= 0;
            i <= 0;
            j <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PARSE;
            end
            PARSE: begin
                if (char_idx == 7) begin
                    if (pattern_idx == num_patterns - 1) begin
                        next_state = COMPUTE_SCORES;
                    end else begin
                        pattern_idx = pattern_idx + 1;
                        char_idx = 0;
                    end
                end else begin
                    char_idx = char_idx + 1;
                end
            end
            COMPUTE_SCORES: begin
                if (pattern_idx == num_patterns - 1) begin
                    next_state = SORT;
                end else begin
                    pattern_idx = pattern_idx + 1;
                end
            end
            SORT: begin
                if (i == 7 && j == 7) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Parse patterns
    always @(posedge clk) begin
        if (current_state == PARSE) begin
            pattern_char[pattern_idx][char_idx] = predictions[pattern_idx][char_idx * 8 +: 8];
        end
    end

    // Compute scores
    always @(posedge clk) begin
        if (current_state == COMPUTE_SCORES) begin
            L = pattern_length;
            n_minus_L_plus_1 = 64 - L + 1;
            reciprocal_3powL = 65536 / pow3[L - 1]; // Q16.16 approximation
            overlap_count = compute_overlap(pattern_char[pattern_idx], L);
            temp_score = n_minus_L_plus_1 * reciprocal_3powL;
            temp_score = temp_score * (32768 - (overlap_count << 16)) >> 16; // (1 - overlap_factor)
            score[pattern_idx] = temp_score;
        end
    end

    // Sorting (bubble sort)
    always @(posedge clk) begin
        if (current_state == SORT) begin
            if (j < 7) begin
                if (score[j] < score[j + 1]) begin
                    temp_score = score[j];
                    score[j] = score[j + 1];
                    score[j + 1] = temp_score;
                    temp_indices[j] = j;
                    temp_indices[j + 1] = j + 1;
                end
                j = j + 1;
            end else begin
                j = 0;
                i = i + 1;
            end
        end
    end

    // Output sorted indices
    always @(posedge clk) begin
        if (current_state == DONE) begin
            done <= 1;
            for (int k = 0; k < 8; k = k + 1) begin
                sorted_indices[k] = temp_indices[k];
            end
        end else begin
            done <= 0;
        end
    end

    // Compute overlap function
    function [7:0] compute_overlap;
        input [7:0] pattern [7:0];
        input [7:0] L;
        reg [7:0] count;
        reg [7:0] k;
        begin
            count = 0;
            for (k = 1; k < L; k = k + 1) begin
                if (pattern[k] == pattern[0] && pattern[k + 1] == pattern[1] && pattern[k + 2] == pattern[2]) begin
                    count = count + 1;
                end
            end
            compute_overlap = count;
        end
    endfunction

endmodule