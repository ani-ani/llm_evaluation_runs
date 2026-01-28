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

    // State encoding
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] READING = 2'b01;
    localparam [1:0] OUTPUTTING = 2'b10;

    reg [1:0] state;
    reg [5:0] current_len;
    reg [DATA_WIDTH-1:0] buffer [0:MAX_WORD_LEN-1];
    reg [5:0] output_idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match_found <= 1'b0;
            word_done <= 1'b0;
            char_out <= 8'd0;
            char_out_valid <= 1'b0;
            current_len <= 6'd0;
            output_idx <= 6'd0;
            for (i = 0; i < MAX_WORD_LEN; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
        end else begin
            word_done <= 1'b0;

            case (state)
                IDLE: begin
                    match_found <= 1'b0;
                    char_out_valid <= 1'b0;

                    if (start) begin
                        current_len <= 6'd0;
                        output_idx <= 6'd0;
                        for (i = 0; i < MAX_WORD_LEN; i = i + 1) begin
                            buffer[i] <= 8'd0;
                        end
                    end else if (valid_in && char_in != 8'h20) begin
                        buffer[0] <= char_in;
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
                            end
                        end else begin
                            state <= READING;
                        end
                    end
                end

                READING: begin
                    if (valid_in) begin
                        if (char_in == 8'h20 || end_of_word) begin
                            if (current_len > n) begin
                                match_found <= 1'b1;
                                char_out <= buffer[0];
                                char_out_valid <= 1'b1;
                                output_idx <= 6'd1;
                                state <= OUTPUTTING;
                            end else begin
                                word_done <= 1'b1;
                                state <= IDLE;
                            end
                        end else begin
                            if (current_len < MAX_WORD_LEN) begin
                                buffer[current_len] <= char_in;
                                current_len <= current_len + 6'd1;
                            end
                            
                            if (end_of_word) begin
                                if ((current_len + 6'd1) > n) begin
                                    match_found <= 1'b1;
                                    char_out <= buffer[0];
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
                        char_out <= buffer[output_idx];
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