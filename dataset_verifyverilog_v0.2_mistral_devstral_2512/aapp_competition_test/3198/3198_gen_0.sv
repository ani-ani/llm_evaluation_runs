module typo_detector (
    input clk,
    input rst_n,
    input in_valid,
    input [71:0] in_word,
    input in_is_last,
    output reg out_valid,
    output reg [71:0] out_word,
    output reg done
);

    parameter CHARS = 8;
    parameter MAX_WORDS = 16;
    parameter WORD_BITS = CHARS * 8;

    typedef logic [WORD_BITS-1:0] word_t;

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        CHECK,
        DELETE_GEN,
        VERIFY,
        OUTPUT,
        FINISH
    } state_t;

    state_t current_state, next_state;

    // Memory for storing words
    word_t word_mem [0:MAX_WORDS-1];
    logic [3:0] word_count;
    logic [3:0] current_word_idx;
    logic [3:0] check_word_idx;
    logic [2:0] delete_idx;
    logic [3:0] verify_idx;

    // Temporary storage for current word and deletion variants
    word_t current_word;
    word_t deletion_variant;
    logic variant_match;

    // Initialize state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            word_count <= 0;
            current_word_idx <= 0;
            check_word_idx <= 0;
            delete_idx <= 0;
            verify_idx <= 0;
            current_word <= 0;
            deletion_variant <= 0;
            variant_match <= 0;
            out_valid <= 0;
            out_word <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (in_valid) next_state = LOAD;
            end
            LOAD: begin
                next_state = CHECK;
            end
            CHECK: begin
                if (check_word_idx < word_count) begin
                    if (delete_idx == 0) next_state = DELETE_GEN;
                    else if (delete_idx < CHARS) next_state = DELETE_GEN;
                    else next_state = VERIFY;
                end else begin
                    if (in_is_last && in_valid) next_state = FINISH;
                    else if (in_valid) next_state = LOAD;
                    else next_state = IDLE;
                end
            end
            DELETE_GEN: begin
                next_state = VERIFY;
            end
            VERIFY: begin
                if (verify_idx < word_count) begin
                    if (variant_match) next_state = OUTPUT;
                    else next_state = CHECK;
                end else begin
                    next_state = CHECK;
                end
            end
            OUTPUT: begin
                next_state = CHECK;
            end
            FINISH: begin
                next_state = FINISH;
            end
            default: next_state = IDLE;
        endcase
    end

    // State actions
    always_ff @(posedge clk) begin
        case (current_state)
            LOAD: begin
                if (in_valid) begin
                    word_mem[word_count] <= in_word;
                    current_word <= in_word;
                    word_count <= word_count + 1;
                    current_word_idx <= word_count;
                end
            end
            CHECK: begin
                if (check_word_idx < word_count) begin
                    if (delete_idx == 0) begin
                        delete_idx <= 0;
                        deletion_variant <= generate_deletion_variant(current_word, delete_idx);
                    end else if (delete_idx < CHARS) begin
                        delete_idx <= delete_idx + 1;
                        deletion_variant <= generate_deletion_variant(current_word, delete_idx);
                    end else begin
                        check_word_idx <= check_word_idx + 1;
                        delete_idx <= 0;
                    end
                end else begin
                    check_word_idx <= 0;
                    if (in_is_last && in_valid) begin
                        done <= 1;
                    end
                end
            end
            DELETE_GEN: begin
                deletion_variant <= generate_deletion_variant(current_word, delete_idx);
            end
            VERIFY: begin
                if (verify_idx < word_count) begin
                    variant_match <= (deletion_variant == word_mem[verify_idx]);
                    if (variant_match) begin
                        out_valid <= 1;
                        out_word <= current_word;
                    end
                    verify_idx <= verify_idx + 1;
                end else begin
                    verify_idx <= 0;
                end
            end
            OUTPUT: begin
                out_valid <= 1;
                out_word <= current_word;
            end
            FINISH: begin
                done <= 1;
            end
        endcase
    end

    // Function to generate deletion variant
    function word_t generate_deletion_variant(input word_t word, input logic [2:0] idx);
        word_t variant;
        logic [7:0] char;
        logic [2:0] i, j;
        
        variant = 0;
        j = 0;
        for (i = 0; i < CHARS; i = i + 1) begin
            if (i != idx) begin
                char = word[(i+1)*8-1 : i*8];
                variant[(j+1)*8-1 : j*8] = char;
                j = j + 1;
            end
        end
        return variant;
    endfunction

endmodule