module words_in_sentence (
    input clk,
    input rst_n,
    input start,
    input [127:0] sentence, // 16 characters * 8 bits, max 16 chars
    input [7:0] valid_len,   // Actual length of input sentence (0-16)
    output reg [127:0] result, // 16 chars result buffer
    output reg [7:0] result_len, // Length of result string
    output reg done
);

// State machine definition
localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;

reg [1:0] state;
reg [7:0] idx;           // Current character index
reg [7:0] word_start;    // Start position of current word
reg [7:0] word_len;      // Length of current word
reg [7:0] res_idx;       // Index in result buffer
reg in_word;             // Flag: currently inside a word
reg is_prime_len;        // Flag: current word length is prime
reg space_needed;        // Flag: need to add space before next word

// Prime check lookup for lengths 0-16 (1 byte each)
// 0=not prime, 1=prime
wire [15:0] prime_table;
assign prime_table = 16'b0000000000000100;                    // bits: 2,3,5,7,11,13 are prime
                    // 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 0
                    // 0  0  1  0  1  0 0 0 1 0 1 0 1 0 0 0

// Extract current character from sentence
wire [7:0] current_char;
assign current_char = sentence[(idx*8) +: 8];

// Check if current word length is prime
wire current_len_is_prime;
assign current_len_is_prime = (word_len > 1) && (word_len <= 15) ? prime_table[word_len] : 0;

// Check if character is space or end of sentence
wire is_space;
assign is_space = (current_char == 8'h20); // ASCII space

wire is_end;
assign is_end = (idx >= valid_len);

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        idx <= 8'd0;
        word_start <= 8'd0;
        word_len <= 8'd0;
        res_idx <= 8'd0;
        in_word <= 1'b0;
        space_needed <= 1'b0;
        done <= 1'b0;
        result <= 128'd0;
        result_len <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    idx <= 8'd0;
                    word_start <= 8'd0;
                    word_len <= 8'd0;
                    res_idx <= 8'd0;
                    in_word <= 1'b0;
                    space_needed <= 1'b0;
                    done <= 1'b0;
                    result <= 128'd0;
                    result_len <= 8'd0;
                end
            end

            PROCESSING: begin
                if (!is_end) begin
                    // Processing characters
                    if (is_space) begin
                        // End of current word
                        if (in_word) begin
                            // Check if word length is prime
                            if (current_len_is_prime) begin
                                // Add space if needed
                                if (space_needed) begin
                                    result[(res_idx*8) +: 8] <= 8'h20;
                                    res_idx <= res_idx + 1'd1;
                                end
                                // Copy word to result
                                for (integer i = 0; i < 16; i = i + 1) begin
                                    if (i < word_len) begin
                                        result[(res_idx+i)*8 +: 8] <= sentence[(word_start+i)*8 +: 8];
                                    end
                                end
                                res_idx <= res_idx + word_len;
                                space_needed <= 1'b1;
                            end
                            in_word <= 1'b0;
                            word_len <= 8'd0;
                        end
                    end else begin
                        // Inside a word
                        if (!in_word) begin
                            word_start <= idx;
                            in_word <= 1'b1;
                            word_len <= 8'd1;
                        end else begin
                            word_len <= word_len + 1'd1;
                        end
                    end
                    idx <= idx + 1'd1;
                end else begin
                    // End of sentence - check last word
                    if (in_word) begin
                        if (current_len_is_prime) begin
                            if (space_needed) begin
                                result[(res_idx*8) +: 8] <= 8'h20;
                                res_idx <= res_idx + 1'd1;
                            end
                            for (integer i = 0; i < 16; i = i + 1) begin
                                if (i < word_len) begin
                                    result[(res_idx+i)*8 +: 8] <= sentence[(word_start+i)*8 +: 8];
                                end
                            end
                            res_idx <= res_idx + word_len;
                        end
                    end
                    result_len <= res_idx;
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            end
        endcase
    end
end

endmodule