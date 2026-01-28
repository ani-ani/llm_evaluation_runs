module count_substring(
    input clk,
    input rst_n,
    input start,
    input [127:0] string_data,
    input [127:0] substring_data,
    input [3:0] string_len,
    input [3:0] substring_len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LEN = 3'd1;
    localparam [2:0] SETUP_LOOP = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] NEXT_POS = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] result_reg;
    reg [7:0] count;
    reg [3:0] pos;
    reg [3:0] char_idx;
    reg [7:0] str_char;
    reg [7:0] sub_char;
    reg match_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Extract characters from packed arrays
    always @(*) begin
        // Get character from main string at position pos + char_idx
        str_char = string_data[(pos + char_idx) * 8 +: 8];
        // Get character from substring at position char_idx
        sub_char = substring_data[char_idx * 8 +: 8];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            result_reg <= 8'd0;
            done <= 1'b0;
            count <= 8'd0;
            pos <= 4'd0;
            char_idx <= 4'd0;
            match_flag <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        result_reg <= 8'd0;
                        count <= 8'd0;
                        pos <= 4'd0;
                        char_idx <= 4'd0;
                        state <= CHECK_LEN;
                    end
                end

                CHECK_LEN: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if substring fits in main string
                    if (substring_len > string_len || substring_len == 4'd0 || string_len == 4'd0) begin
                        state <= FINISH;
                    end else begin
                        state <= SETUP_LOOP;
                    end
                end

                SETUP_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    char_idx <= 4'd0;
                    match_flag <= 1'b1;
                    state <= COMPARE;
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_idx < substring_len) begin
                        // Check if we can read from string (pos + char_idx < string_len)
                        if ((pos + char_idx) < string_len) begin
                            if (str_char != sub_char) begin
                                match_flag <= 1'b0;
                            end
                            char_idx <= char_idx + 4'd1;
                            state <= COMPARE;
                        end else begin
                            // Ran out of string characters
                            match_flag <= 1'b0;
                            state <= INCREMENT;
                        end
                    end else begin
                        // Finished comparing all characters
                        state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (match_flag && char_idx == substring_len) begin
                        count <= count + 8'd1;
                    end
                    pos <= pos + 4'd1;
                    state <= NEXT_POS;
                end

                NEXT_POS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if we've checked all positions
                    if ((string_len - substring_len) <= pos || cycle_count >= MAX_CYCLES) begin
                        result_reg <= count;
                        state <= FINISH;
                    end else begin
                        state <= SETUP_LOOP;
                    end
                end

                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule