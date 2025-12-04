module max_unique_chars(
    input clk,
    input rst_n,
    input start,
    input [3:0][63:0] word_array,
    output reg [63:0] result,
    output reg done
);
    typedef enum logic [1:0] { IDLE, COUNT_UNIQUES, COMPARE, DONE } state_t;
    state_t current_state, next_state;
    reg [3:0][63:0] stored_word_array;
    reg [3:0] counts_reg [0:3];
    logic [3:0] unique_count [0:3];

    generate for (genvar i = 0; i < 4; i++) begin : count_unique_gen
        logic [7:0] bytes [0:7];
        logic [7:0] is_unique;
        
        for (genvar j = 0; j < 8; j++) begin : split_bytes
            assign bytes[j] = stored_word_array[i][j*8 +: 8];
        end
        
        for (genvar j = 0; j < 8; j++) begin : byte_comparisons
            logic [7:0] matches;
            
            for (genvar k = 0; k < 8; k++) begin : compare_loop
                assign matches[k] = (j != k) ? (bytes[j] == bytes[k]) : 1'b0;
            end
            
            assign is_unique[j] = ~(|matches);
        end
        
        assign unique_count[i] = is_unique[0] + is_unique[1] + is_unique[2] + is_unique[3]
                               + is_unique[4] + is_unique[5] + is_unique[6] + is_unique[7];
    end endgenerate

    function logic lex_smaller(logic [63:0] wordA, logic [63:0] wordB);
        lex_smaller = 1'b0;
        if (wordA[63:56] < wordB[63:56]) lex_smaller = 1'b1;
        else if (wordA[63:56] > wordB[63:56]) lex_smaller = 1'b0;
        else if (wordA[55:48] < wordB[55:48]) lex_smaller = 1'b1;
        else if (wordA[55:48] > wordB[55:48]) lex_smaller = 1'b0;
        else if (wordA[47:40] < wordB[47:40]) lex_smaller = 1'b1;
        else if (wordA[47:40] > wordB[47:40]) lex_smaller = 1'b0;
        else if (wordA[39:32] < wordB[39:32]) lex_smaller = 1'b1;
        else if (wordA[39:32] > wordB[39:32]) lex_smaller = 1'b0;
        else if (wordA[31:24] < wordB[31:24]) lex_smaller = 1'b1;
        else if (wordA[31:24] > wordB[31:24]) lex_smaller = 1'b0;
        else if (wordA[23:16] < wordB[23:16]) lex_smaller = 1'b1;
        else if (wordA[23:16] > wordB[23:16]) lex_smaller = 1'b0;
        else if (wordA[15:8]  < wordB[15:8] ) lex_smaller = 1'b1;
        else if (wordA[15:8]  > wordB[15:8] ) lex_smaller = 1'b0;
        else if (wordA[7:0]   < wordB[7:0]  ) lex_smaller = 1'b1;
        else if (wordA[7:0]   > wordB[7:0]  ) lex_smaller = 1'b0;
        else lex_smaller = 1'b0;
    endfunction

    logic [1:0] best_index;
    always_comb begin
        logic [3:0] max_count = counts_reg[0];
        logic [3:0] candidate_mask;
        for (int i = 1; i < 4; i++) if (counts_reg[i] > max_count) max_count = counts_reg[i];
        for (int i = 0; i < 4; i++) candidate_mask[i] = (counts_reg[i] == max_count);

        best_index = 0;
        for (int i = 0; i < 4; i++) begin
            if (candidate_mask[i]) begin
                best_index = i;
                break;
            end
        end
        
        for (int i = best_index+1; i < 4; i++) begin
            if (candidate_mask[i]) begin
                if (lex_smaller(stored_word_array[i], stored_word_array[best_index]))
                    best_index = i;
                else if (stored_word_array[i] == stored_word_array[best_index])
                    best_index = (i < best_index) ? i : best_index;
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            stored_word_array <= '0;
            for (int i = 0; i < 4; i++) counts_reg[i] <= '0;
            result <= '0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (current_state)
                IDLE: begin
                    if (start) begin
                        stored_word_array <= word_array;
                        current_state <= COUNT_UNIQUES;
                    end
                end
                COUNT_UNIQUES: begin
                    for (int i = 0; i < 4; i++) counts_reg[i] <= unique_count[i];
                    current_state <= COMPARE;
                end
                COMPARE: begin
                    result <= stored_word_array[best_index];
                    current_state <= DONE;
                end
                DONE: begin
                    done <= 1'b1;
                    current_state <= IDLE;
                end
            endcase
        end
    end
endmodule