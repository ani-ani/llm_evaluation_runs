module primitive_search_steps (
    input clk,
    input rst_n,
    input start,
    input [7:0] query_word [8],
    input db_word_en,
    input [7:0] db_word [8],
    input [2:0] db_word_index,
    output reg [15:0] result,
    output reg done
);

reg [7:0] db_words [8][8];

reg [2:0] word_count = 3'd0;

reg [2:0] state = 3'd0; // IDLE=0, LOAD_DB=1, PROCESSING=2, DONE=3

reg [2:0] current_word_idx = 3'd0;
reg [15:0] accumulated_steps = 16'd0;

function [7:0] lcp_length;
    input [7:0] query_bytes [8];
    input [7:0] db_bytes [8];
    begin
        lcp_length = 8'd0;
        if (query_bytes[0] == db_bytes[0]) lcp_length = 8'd1;
        if (query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd2;
        if (query_bytes[2] == db_bytes[2] && query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd3;
        if (query_bytes[3] == db_bytes[3] && query_bytes[2] == db_bytes[2] && query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd4;
        if (query_bytes[4] == db_bytes[4] && query_bytes[3] == db_bytes[3] && query_bytes[2] == db_bytes[2] && query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd5;
        if (query_bytes[5] == db_bytes[5] && query_bytes[4] == db_bytes[4] && query_bytes[3] == db_bytes[3] && query_bytes[2] == db_bytes[2] && query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd6;
        if (query_bytes[6] == db_bytes[6] && query_bytes[5] == db_bytes[5] && query_bytes[4] == db_bytes[4] && query_bytes[3] == db_bytes[3] && query_bytes[2] == db_bytes[2] && query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd7;
        if (query_bytes[7] == db_bytes[7] && query_bytes[6] == db_bytes[6] && query_bytes[5] == db_bytes[5] && query_bytes[4] == db_bytes[4] && query_bytes[3] == db_bytes[3] && query_bytes[2] == db_bytes[2] && query_bytes[1] == db_bytes[1] && query_bytes[0] == db_bytes[0]) lcp_length = 8'd8;
    endfunction

reg [2:0] next_state;

always @(negedge rst_n) begin
    state <= 3'd0;
    word_count <= 3'd0;
    current_word_idx <= 3'd0;
    accumulated_steps <= 16'd0;
    result <= 16'd0;
    done <= 1'b0;
    next_state <= 3'd0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        word_count <= 3'd0;
        current_word_idx <= 3'd0;
        accumulated_steps <= 16'd0;
        result <= 16'd0;
        done <= 1'b0;
        next_state <= 3'd0;
    end else begin
        case (state)
            3'd0: begin // IDLE
                if (db_word_en) begin
                    // Load the word into the database
                    db_words[db_word_index][0] <= db_word[0];
                    db_words[db_word_index][1] <= db_word[1];
                    db_words[db_word_index][2] <= db_word[2];
                    db_words[db_word_index][3] <= db_word[3];
                    db_words[db_word_index][4] <= db_word[4];
                    db_words[db_word_index][5] <= db_word[5];
                    db_words[db_word_index][6] <= db_word[6];
                    db_words[db_word_index][7] <= db_word[7];
                    word_count <= word_count + 1;
                    next_state = 3'd1; // LOAD_DB
                end else if (start && (word_count == 3'd8)) begin
                    next_state = 3'd2; // PROCESSING
                    current_word_idx <= 3'd0;
                    accumulated_steps <= 16'd0;
                end
            end
            3'd1: begin // LOAD_DB
                next_state = 3'd0; // return to IDLE
            end
            3'd2: begin // PROCESSING
                if (current_word_idx < 8) begin
                    wire [7:0] current_db_word [8];
                    assign current_db_word = db_words[current_word_idx];
                    wire [7:0] lcp_len = lcp_length(query_word, current_db_word);
                    if (lcp_len == 8) begin
                        accumulated_steps <= accumulated_steps + 1 + lcp_len;
                        next_state = 3'd3; // DONE
                        result <= accumulated_steps;
                        done <= 1'b1;
                    end else begin
                        accumulated_steps <= accumulated_steps + 1 + lcp_len;
                        current_word_idx <= current_word_idx + 1;
                    end
                end else begin
                    next_state = 3'd3; // DONE
                    result <= accumulated_steps;
                    done <= 1'b1;
                end
            end
            3'd3: begin // DONE
                next_state = 3'd3;
            end
        endcase
        state <= next_state;
    end
end
endmodule