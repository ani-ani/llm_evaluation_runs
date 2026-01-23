module translator_matcher (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_translators,
    input [3:0] num_languages,
    input [1:0] translator_lang1 [0:15],
    input [1:0] translator_lang2 [0:15],
    output reg [3:0] pair1 [0:7],
    output reg [3:0] pair2 [0:7],
    output reg [3:0] num_pairs,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        CHECK_MATCHING,
        FOUND_MATCHING,
        IMPOSSIBLE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] paired_mask;
    reg [3:0] current_translator;
    reg [3:0] current_pair_index;
    reg [3:0] temp_pair1 [0:7];
    reg [3:0] temp_pair2 [0:7];
    reg [3:0] temp_num_pairs;

    // Check if two translators share a language
    function logic share_language;
        input [3:0] t1, t2;
        begin
            share_language = (translator_lang1[t1] == translator_lang1[t2]) ||
                            (translator_lang1[t1] == translator_lang2[t2]) ||
                            (translator_lang2[t1] == translator_lang1[t2]) ||
                            (translator_lang2[t1] == translator_lang2[t2]);
        end
    endfunction

    // Check if all translators are paired
    function logic all_paired;
        begin
            all_paired = (paired_mask == {16{1'b1}});
        end
    endfunction

    // Find next unpaired translator
    function [3:0] find_next_unpaired;
        input [15:0] mask;
        begin
            for (int i = 0; i < 16; i++) begin
                if (!mask[i]) begin
                    find_next_unpaired = i;
                    return;
                end
            end
            find_next_unpaired = 16;
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            paired_mask <= 16'b0;
            current_translator <= 0;
            current_pair_index <= 0;
            temp_num_pairs <= 0;
            valid <= 0;
            impossible <= 0;
            done <= 0;
            num_pairs <= 0;
            for (int i = 0; i < 8; i++) begin
                pair1[i] <= 0;
                pair2[i] <= 0;
                temp_pair1[i] <= 0;
                temp_pair2[i] <= 0;
            end
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Check if num_translators is odd
                        if (num_translators[0]) begin
                            next_state = IMPOSSIBLE;
                        end else begin
                            paired_mask <= 16'b0;
                            current_translator <= 0;
                            current_pair_index <= 0;
                            temp_num_pairs <= 0;
                            next_state = CHECK_MATCHING;
                        end
                    end
                end

                CHECK_MATCHING: begin
                    if (all_paired()) begin
                        next_state = FOUND_MATCHING;
                    end else begin
                        // Find next unpaired translator
                        current_translator = find_next_unpaired(paired_mask);
                        if (current_translator == 16) begin
                            next_state = IMPOSSIBLE;
                        end else begin
                            // Try to pair with other unpaired translators
                            for (int i = current_translator + 1; i < num_translators; i++) begin
                                if (!paired_mask[i] && share_language(current_translator, i)) begin
                                    // Pair them
                                    paired_mask[current_translator] = 1;
                                    paired_mask[i] = 1;
                                    temp_pair1[current_pair_index] = current_translator;
                                    temp_pair2[current_pair_index] = i;
                                    current_pair_index = current_pair_index + 1;
                                    temp_num_pairs = temp_num_pairs + 1;
                                    break;
                                end
                            end
                            // If no pair found, backtrack
                            if (!paired_mask[current_translator]) begin
                                if (current_pair_index > 0) begin
                                    current_pair_index = current_pair_index - 1;
                                    paired_mask[temp_pair1[current_pair_index]] = 0;
                                    paired_mask[temp_pair2[current_pair_index]] = 0;
                                end else begin
                                    next_state = IMPOSSIBLE;
                                end
                            end
                        end
                    end
                end

                FOUND_MATCHING: begin
                    valid <= 1;
                    done <= 1;
                    num_pairs <= temp_num_pairs;
                    for (int i = 0; i < 8; i++) begin
                        pair1[i] <= temp_pair1[i];
                        pair2[i] <= temp_pair2[i];
                    end
                    next_state = IDLE;
                end

                IMPOSSIBLE: begin
                    impossible <= 1;
                    done <= 1;
                    next_state = IDLE;
                end

                default: next_state = IDLE;
            endcase
        end
    end

    // Default assignments
    always @(*) begin
        next_state = current_state;
    end

endmodule