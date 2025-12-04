module word_guess_analyzer(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [95:0] revealed_chars,
    input [3:0] m,
    input [79:0] word_data,
    input word_valid,
    output reg [4:0] result,
    output reg done
);

    // State machine typedef
    typedef enum bit [2:0] {IDLE, SETUP, PROCESS, FINALIZE1, FINALIZE2} state_t;
    state_t state, next_state;

    // Internal registers
    reg [3:0] word_counter;
    reg [25:0] candidate_set;
    reg [25:0] revealed_letters_mask_reg;
    reg [4:0] result_reg;
    reg done_reg;

    // Combinational next state logic
    always_comb begin
        case (state)
            IDLE: next_state = start ? SETUP : IDLE;
            SETUP: next_state = PROCESS;
            PROCESS: begin
                if (word_valid && (word_counter < m)) begin
                    if (word_counter + 1 == m) 
                        next_state = FINALIZE1;
                    else
                        next_state = PROCESS;
                end else begin
                    next_state = PROCESS;
                end
            end
            FINALIZE1: next_state = FINALIZE2;
            FINALIZE2: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential block for state and data updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            word_counter <= 0;
            candidate_set <= 26'h3FFFFFF;  // All 26 bits set to 1
            revealed_letters_mask_reg <= 0;
        end else begin
            state <= next_state;

            // SETUP state actions
            if (next_state == SETUP) begin
                revealed_letters_mask_reg = 0;
                for (int i=0; i<16; i++) begin
                    if (i < n) begin
                        if (revealed_chars[6*i+5] == 1) begin
                            revealed_letters_mask_reg = revealed_letters_mask_reg | (26'h1 << revealed_chars[6*i+4:6*i]);
                        end
                    end
                end
                candidate_set = 26'h3FFFFFF;
                word_counter = 0;
            end

            // PROCESS state actions
            if (state == PROCESS) begin
                if (word_valid && (word_counter < m)) begin
                    // Variable declarations for word processing
                    bit invalid;
                    bit [25:0] hidden_mask;
                    integer i;

                    invalid = 0;
                    hidden_mask = 0;

                    // Check each character position
                    for (i=0; i<n; i++) begin
                        // Get revealed character info
                        bit revealed_flag;
                        bit [4:0] revealed_char;
                        revealed_flag = revealed_chars[6*i+5];
                        revealed_char = revealed_chars[6*i+4:6*i];

                        // Get word character
                        bit [4:0] word_char;
                        word_char = word_data[5*i+4:5*i];

                        if (revealed_flag) begin
                            if (word_char != revealed_char) 
                                invalid = 1;
                        end else begin
                            if (revealed_letters_mask_reg[word_char]) 
                                invalid = 1;
                        end
                    end

                    // If word is valid, build hidden letters mask
                    if (!invalid) begin
                        for (i=0; i<n; i++) begin
                            if (revealed_chars[6*i+5] == 0) begin  // hidden position
                                bit [4:0] word_char;
                                word_char = word_data[5*i+4:5*i];
                                hidden_mask = hidden_mask | (26'h1 << word_char);
                            end
                        end
                        candidate_set = candidate_set & hidden_mask;
                    end

                    // Update word counter
                    word_counter = word_counter + 1;
                end
            end
        end
    end

    // Sequential block for result and done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else begin
            if (state == FINALIZE2) begin
                result <= $countones(candidate_set);
                done <= 1;
            end else begin
                done <= 0;
            end
        end
    end

endmodule
