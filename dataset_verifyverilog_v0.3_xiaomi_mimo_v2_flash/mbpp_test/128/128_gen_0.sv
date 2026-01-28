module long_words_filter #(
    parameter MAX_WORD_LEN = 16,
    parameter DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] char_in,
    input wire valid_in,
    input wire end_of_word,
    input wire [5:0] n,
    output reg match_found,
    output reg word_done,
    output reg [DATA_WIDTH-1:0] char_out,
    output reg char_out_valid
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READING = 2'd1;
    localparam [1:0] OUTPUTTING = 2'd2;

    reg [1:0] state;
    reg [5:0] current_len;
    reg [5:0] output_idx;
    reg [DATA_WIDTH-1:0] buffer_0;
    reg [DATA_WIDTH-1:0] buffer_1;
    reg [DATA_WIDTH-1:0] buffer_2;
    reg [DATA_WIDTH-1:0] buffer_3;
    reg [DATA_WIDTH-1:0] buffer_4;
    reg [DATA_WIDTH-1:0] buffer_5;
    reg [DATA_WIDTH-1:0] buffer_6;
    reg [DATA_WIDTH-1:0] buffer_7;
    reg [DATA_WIDTH-1:0] buffer_8;
    reg [DATA_WIDTH-1:0] buffer_9;
    reg [DATA_WIDTH-1:0] buffer_10;
    reg [DATA_WIDTH-1:0] buffer_11;
    reg [DATA_WIDTH-1:0] buffer_12;
    reg [DATA_WIDTH-1:0] buffer_13;
    reg [DATA_WIDTH-1:0] buffer_14;
    reg [DATA_WIDTH-1:0] buffer_15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match_found <= 1'b0;
            word_done <= 1'b0;
            char_out <= 8'd0;
            char_out_valid <= 1'b0;
            current_len <= 6'd0;
            output_idx <= 6'd0;
            buffer_0 <= 8'd0;
            buffer_1 <= 8'd0;
            buffer_2 <= 8'd0;
            buffer_3 <= 8'd0;
            buffer_4 <= 8'd0;
            buffer_5 <= 8'd0;
            buffer_6 <= 8'd0;
            buffer_7 <= 8'd0;
            buffer_8 <= 8'd0;
            buffer_9 <= 8'd0;
            buffer_10 <= 8'd0;
            buffer_11 <= 8'd0;
            buffer_12 <= 8'd0;
            buffer_13 <= 8'd0;
            buffer_14 <= 8'd0;
            buffer_15 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    word_done <= 1'b0;
                    char_out_valid <= 1'b0;
                    match_found <= 1'b0;
                    current_len <= 6'd0;
                    output_idx <= 6'd0;
                    
                    if (start) begin
                        state <= IDLE;
                    end else if (valid_in && char_in != 8'h20) begin
                        buffer_0 <= char_in;
                        current_len <= 6'd1;
                        
                        if (end_of_word) begin
                            if (6'd1 > n) begin
                                match_found <= 1'b1;
                                char_out <= char_in;
                                char_out_valid <= 1'b1;
                                state <= OUTPUTTING;
                                output_idx <= 6'd1;
                            end else begin
                                word_done <= 1'b1;
                                state <= IDLE;
                            end
                        end else begin
                            state <= READING;
                        end
                    end
                end

                READING: begin
                    if (valid_in) begin
                        if (char_in == 8'h20) begin
                            if (current_len > n) begin
                                match_found <= 1'b1;
                                char_out <= buffer_0;
                                char_out_valid <= 1'b1;
                                output_idx <= 6'd1;
                                state <= OUTPUTTING;
                            end else begin
                                word_done <= 1'b1;
                                state <= IDLE;
                            end
                        end else begin
                            if (current_len < MAX_WORD_LEN) begin
                                case (current_len)
                                    6'd0: buffer_0 <= char_in;
                                    6'd1: buffer_1 <= char_in;
                                    6'd2: buffer_2 <= char_in;
                                    6'd3: buffer_3 <= char_in;
                                    6'd4: buffer_4 <= char_in;
                                    6'd5: buffer_5 <= char_in;
                                    6'd6: buffer_6 <= char_in;
                                    6'd7: buffer_7 <= char_in;
                                    6'd8: buffer_8 <= char_in;
                                    6'd9: buffer_9 <= char_in;
                                    6'd10: buffer_10 <= char_in;
                                    6'd11: buffer_11 <= char_in;
                                    6'd12: buffer_12 <= char_in;
                                    6'd13: buffer_13 <= char_in;
                                    6'd14: buffer_14 <= char_in;
                                    6'd15: buffer_15 <= char_in;
                                    default: begin
                                        buffer_0 <= buffer_0;
                                        buffer_1 <= buffer_1;
                                        buffer_2 <= buffer_2;
                                        buffer_3 <= buffer_3;
                                        buffer_4 <= buffer_4;
                                        buffer_5 <= buffer_5;
                                        buffer_6 <= buffer_6;
                                        buffer_7 <= buffer_7;
                                        buffer_8 <= buffer_8;
                                        buffer_9 <= buffer_9;
                                        buffer_10 <= buffer_10;
                                        buffer_11 <= buffer_11;
                                        buffer_12 <= buffer_12;
                                        buffer_13 <= buffer_13;
                                        buffer_14 <= buffer_14;
                                        buffer_15 <= buffer_15;
                                    end
                                endcase
                                current_len <= current_len + 6'd1;
                            end
                            
                            if (end_of_word) begin
                                if (current_len + 6'd1 > n) begin
                                    match_found <= 1'b1;
                                    char_out <= buffer_0;
                                    char_out_valid <= 1'b1;
                                    output_idx <= 6'd1;
                                    state <= OUTPUTTING;
                                end else begin
                                    word_done <= 1'b1;
                                    state <= IDLE;
                                end
                            end
                        end
                    end
                end

                OUTPUTTING: begin
                    if (output_idx < current_len) begin
                        case (output_idx)
                            6'd0: char_out <= buffer_0;
                            6'd1: char_out <= buffer_1;
                            6'd2: char_out <= buffer_2;
                            6'd3: char_out <= buffer_3;
                            6'd4: char_out <= buffer_4;
                            6'd5: char_out <= buffer_5;
                            6'd6: char_out <= buffer_6;
                            6'd7: char_out <= buffer_7;
                            6'd8: char_out <= buffer_8;
                            6'd9: char_out <= buffer_9;
                            6'd10: char_out <= buffer_10;
                            6'd11: char_out <= buffer_11;
                            6'd12: char_out <= buffer_12;
                            6'd13: char_out <= buffer_13;
                            6'd14: char_out <= buffer_14;
                            6'd15: char_out <= buffer_15;
                            default: char_out <= buffer_0;
                        endcase
                        char_out_valid <= 1'b1;
                        output_idx <= output_idx + 6'd1;
                    end else begin
                        char_out_valid <= 1'b0;
                        match_found <= 1'b0;
                        word_done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule