module start_withp (
    input [79:0] input_string,
    output reg [7:0] word1_char0,
    output reg [7:0] word1_char1,
    output reg [7:0] word1_char2,
    output reg [7:0] word1_char3,
    output reg [7:0] word1_char4,
    output reg [7:0] word1_char5,
    output reg [7:0] word1_char6,
    output reg [7:0] word1_char7,
    output reg [7:0] word2_char0,
    output reg [7:0] word2_char1,
    output reg [7:0] word2_char2,
    output reg [7:0] word2_char3,
    output reg [7:0] word2_char4,
    output reg [7:0] word2_char5,
    output reg [7:0] word2_char6,
    output reg [7:0] word2_char7,
    output reg found
);

    reg [7:0] word1 [0:7];
    reg [7:0] word2 [0:7];
    reg [7:0] current_word [0:7];
    reg [3:0] word1_len;
    reg [3:0] word2_len;
    reg [3:0] current_word_len;
    reg [3:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    reg [3:0] word_count;
    reg is_word_start;
    reg is_alphabetic;
    reg is_p_or_P;

    parameter IDLE = 4'b0000;
    parameter FIND_FIRST_WORD = 4'b0001;
    parameter EXTRACT_FIRST_WORD = 4'b0010;
    parameter FIND_SECOND_WORD = 4'b0011;
    parameter EXTRACT_SECOND_WORD = 4'b0100;
    parameter DONE = 4'b0101;

    always @* begin
        found = 1'b0;
        word1_char0 = 8'b0;
        word1_char1 = 8'b0;
        word1_char2 = 8'b0;
        word1_char3 = 8'b0;
        word1_char4 = 8'b0;
        word1_char5 = 8'b0;
        word1_char6 = 8'b0;
        word1_char7 = 8'b0;
        word2_char0 = 8'b0;
        word2_char1 = 8'b0;
        word2_char2 = 8'b0;
        word2_char3 = 8'b0;
        word2_char4 = 8'b0;
        word2_char5 = 8'b0;
        word2_char6 = 8'b0;
        word2_char7 = 8'b0;

        state = IDLE;
        word_count = 4'b0000;
        word1_len = 4'b0000;
        word2_len = 4'b0000;
        current_word_len = 4'b0000;

        for (i = 0; i < 10; i = i + 1) begin
            if (state == IDLE) begin
                if ((input_string[i*8 +: 8] == 8'h50 || input_string[i*8 +: 8] == 8'h70) && 
                    (i == 0 || !is_alphabetic_char(input_string[(i-1)*8 +: 8]))) begin
                    state = EXTRACT_FIRST_WORD;
                    current_word_len = 4'b0000;
                    j = i;
                end
            end
            else if (state == EXTRACT_FIRST_WORD) begin
                if (current_word_len < 8 && is_alphabetic_char(input_string[j*8 +: 8])) begin
                    current_word[current_word_len] = input_string[j*8 +: 8];
                    current_word_len = current_word_len + 1;
                    j = j + 1;
                end else begin
                    word1_len = current_word_len;
                    for (k = 0; k < 8; k = k + 1) begin
                        word1[k] = (k < word1_len) ? current_word[k] : 8'b0;
                    end
                    state = FIND_SECOND_WORD;
                    i = j;
                end
            end
            else if (state == FIND_SECOND_WORD) begin
                if ((input_string[i*8 +: 8] == 8'h50 || input_string[i*8 +: 8] == 8'h70) && 
                    (i == 0 || !is_alphabetic_char(input_string[(i-1)*8 +: 8]))) begin
                    state = EXTRACT_SECOND_WORD;
                    current_word_len = 4'b0000;
                    j = i;
                end
            end
            else if (state == EXTRACT_SECOND_WORD) begin
                if (current_word_len < 8 && is_alphabetic_char(input_string[j*8 +: 8])) begin
                    current_word[current_word_len] = input_string[j*8 +: 8];
                    current_word_len = current_word_len + 1;
                    j = j + 1;
                end else begin
                    word2_len = current_word_len;
                    for (k = 0; k < 8; k = k + 1) begin
                        word2[k] = (k < word2_len) ? current_word[k] : 8'b0;
                    end
                    state = DONE;
                    found = 1'b1;
                end
            end
        end

        if (found) begin
            word1_char0 = word1[0];
            word1_char1 = word1[1];
            word1_char2 = word1[2];
            word1_char3 = word1[3];
            word1_char4 = word1[4];
            word1_char5 = word1[5];
            word1_char6 = word1[6];
            word1_char7 = word1[7];
            word2_char0 = word2[0];
            word2_char1 = word2[1];
            word2_char2 = word2[2];
            word2_char3 = word2[3];
            word2_char4 = word2[4];
            word2_char5 = word2[5];
            word2_char6 = word2[6];
            word2_char7 = word2[7];
        end
    end

    function is_alphabetic_char;
        input [7:0] char;
        begin
            is_alphabetic_char = ((char >= 8'h41 && char <= 8'h5A) || (char >= 8'h61 && char <= 8'h7A));
        end
    endfunction

endmodule