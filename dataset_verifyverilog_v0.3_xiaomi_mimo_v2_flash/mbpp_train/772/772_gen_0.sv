module word_k_remover (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] k_len,
    input wire [3:0] str_len,
    output reg [7:0] char_out,
    output reg [3:0] out_idx,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] READ_CHAR    = 4'd1;
    localparam [3:0] STORE_CHAR   = 4'd2;
    localparam [3:0] CHECK_SPACE  = 4'd3;
    localparam [3:0] CALC_LEN     = 4'd4;
    localparam [3:0] DECIDE       = 4'd5;
    localparam [3:0] OUTPUT_WORD  = 4'd6;
    localparam [3:0] OUTPUT_SPACE = 4'd7;
    localparam [3:0] SKIP_SPACE   = 4'd8;
    localparam [3:0] FINISH       = 4'd9;

    // Internal registers
    reg [3:0] state;
    reg [3:0] in_idx;
    reg [3:0] word_len;
    reg [3:0] temp_idx;
    reg remove_flag;
    reg [7:0] temp_chars [0:7];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            out_idx <= 4'd0;
            in_idx <= 4'd0;
            word_len <= 4'd0;
            temp_idx <= 4'd0;
            remove_flag <= 1'b0;
            char_out <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_chars[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    out_idx <= 4'd0;
                    in_idx <= 4'd0;
                    word_len <= 4'd0;
                    temp_idx <= 4'd0;
                    remove_flag <= 1'b0;
                    if (start && str_len > 0) begin
                        state <= READ_CHAR;
                    end
                end

                READ_CHAR: begin
                    // Wait for external memory to provide char_in based on in_idx
                    // Check for space or end of string
                    if (char_in == 8'h20 || in_idx == str_len) begin
                        state <= CHECK_SPACE;
                    end else begin
                        state <= STORE_CHAR;
                    end
                end

                STORE_CHAR: begin
                    if (temp_idx < 8) begin
                        temp_chars[temp_idx] <= char_in;
                        temp_idx <= temp_idx + 1;
                        word_len <= word_len + 1;
                    end
                    in_idx <= in_idx + 1;
                    state <= READ_CHAR;
                end

                CHECK_SPACE: begin
                    // Determine if word should be removed
                    if (word_len == k_len && word_len > 0) begin
                        remove_flag <= 1'b1;
                    end else begin
                        remove_flag <= 1'b0;
                    end
                    temp_idx <= 4'd0;
                    state <= DECIDE;
                end

                DECIDE: begin
                    if (remove_flag) begin
                        // If we have more input, need to skip the space delimiter
                        if (in_idx < str_len) begin
                            state <= SKIP_SPACE;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= OUTPUT_WORD;
                    end
                end

                OUTPUT_WORD: begin
                    if (temp_idx < word_len) begin
                        char_out <= temp_chars[temp_idx];
                        out_valid <= 1'b1;
                        temp_idx <= temp_idx + 1;
                        out_idx <= out_idx + 1;
                        state <= OUTPUT_WORD;
                    end else begin
                        out_valid <= 1'b0;
                        word_len <= 4'd0;
                        if (in_idx < str_len) begin
                            state <= OUTPUT_SPACE;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                OUTPUT_SPACE: begin
                    char_out <= 8'h20;
                    out_valid <= 1'b1;
                    out_idx <= out_idx + 1;
                    state <= SKIP_SPACE;
                end

                SKIP_SPACE: begin
                    out_valid <= 1'b0;
                    // Consume the delimiter space if it exists
                    if (in_idx < str_len) begin
                        in_idx <= in_idx + 1;
                    end
                    word_len <= 4'd0;
                    temp_idx <= 4'd0;
                    // Only go back to read if we haven't reached the end
                    if (in_idx < str_len) begin
                        state <= READ_CHAR;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule