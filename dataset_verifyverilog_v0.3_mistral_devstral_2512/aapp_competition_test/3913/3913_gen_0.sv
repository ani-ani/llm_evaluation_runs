module field_of_wonders(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [63:0] pattern,
    input wire [3:0] m,
    input wire [63:0] word0,
    input wire [63:0] word1,
    input wire [63:0] word2,
    input wire [63:0] word3,
    input wire [63:0] word4,
    input wire [63:0] word5,
    input wire [63:0] word6,
    input wire [63:0] word7,
    output reg [4:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_WORDS = 2'd1;
    localparam [1:0] COUNT_LETTERS = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [2:0] word_idx;
    reg [4:0] letter_idx;
    reg [25:0] revealed_mask;
    reg [7:0] valid_words;
    reg [25:0] hidden_masks [0:7];
    reg [3:0] total_valid;
    reg [4:0] result_reg;

    wire [63:0] current_word;
    assign current_word = (word_idx == 3'd0) ? word0 :
                         (word_idx == 3'd1) ? word1 :
                         (word_idx == 3'd2) ? word2 :
                         (word_idx == 3'd3) ? word3 :
                         (word_idx == 3'd4) ? word4 :
                         (word_idx == 3'd5) ? word5 :
                         (word_idx == 3'd6) ? word6 : word7;

    reg valid_flag;
    reg [25:0] hidden_mask;
    integer j;

    always @(*) begin
        valid_flag = 1'b1;
        hidden_mask = 26'd0;
        
        if (state == CHECK_WORDS) begin
            for (j = 0; j < 8; j = j + 1) begin
                if (j < n) begin
                    reg [7:0] char_pat = pattern[8*j +: 8];
                    reg [7:0] char_word = current_word[8*j +: 8];
                    
                    if (char_pat != 8'h2A) begin
                        if (char_pat != char_word) begin
                            valid_flag = 1'b0;
                        end
                    end else begin
                        if (char_word >= 8'h61 && char_word <= 8'h7A) begin
                            reg [4:0] bit_idx = char_word - 8'h61;
                            if (revealed_mask[bit_idx]) begin
                                valid_flag = 1'b0;
                            end else begin
                                hidden_mask[bit_idx] = 1'b1;
                            end
                        end else begin
                            valid_flag = 1'b0;
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            word_idx <= 3'd0;
            letter_idx <= 5'd0;
            result <= 5'd0;
            done <= 1'b0;
            revealed_mask <= 26'd0;
            valid_words <= 8'd0;
            total_valid <= 4'd0;
            result_reg <= 5'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                hidden_masks[i] <= 26'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        revealed_mask <= 26'd0;
                        for (integer k = 0; k < 8; k = k + 1) begin
                            if (k < n) begin
                                reg [7:0] cp = pattern[8*k +: 8];
                                if (cp != 8'h2A && cp >= 8'h61 && cp <= 8'h7A) begin
                                    revealed_mask[cp - 8'h61] <= 1'b1;
                                end
                            end
                        end
                        word_idx <= 3'd0;
                        total_valid <= 4'd0;
                        valid_words <= 8'd0;
                        result_reg <= 5'd0;
                        state <= CHECK_WORDS;
                    end
                end
                
                CHECK_WORDS: begin
                    if (word_idx < m) begin
                        if (valid_flag) begin
                            valid_words[word_idx] <= 1'b1;
                            hidden_masks[word_idx] <= hidden_mask;
                            total_valid <= total_valid + 4'd1;
                        end
                        word_idx <= word_idx + 3'd1;
                    end else begin
                        letter_idx <= 5'd0;
                        state <= COUNT_LETTERS;
                    end
                end
                
                COUNT_LETTERS: begin
                    if (letter_idx < 5'd26) begin
                        if (!revealed_mask[letter_idx]) begin
                            reg [4:0] count = 5'd0;
                            for (integer w = 0; w < 8; w = w + 1) begin
                                if (w < m && valid_words[w] && hidden_masks[w][letter_idx]) begin
                                    count = count + 5'd1;
                                end
                            end
                            if (count == total_valid) begin
                                result_reg <= result_reg + 5'd1;
                            end
                        end
                        letter_idx <= letter_idx + 5'd1;
                    end else begin
                        result <= result_reg;
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule