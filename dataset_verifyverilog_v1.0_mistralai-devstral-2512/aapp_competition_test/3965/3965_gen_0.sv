module verse_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] line_str [0:15],
    input [3:0] line_len,
    input [7:0] target_p,
    output reg match,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] vowel_count;
    reg [3:0] char_index;
    reg [7:0] current_char;
    reg is_vowel;

    // Vowel detection using casex (combinational)
    always @(*) begin
        is_vowel = 1'b0;
        casex (current_char)
            8'd97, 8'd101, 8'd105, 8'd111, 8'd117, 8'd121: is_vowel = 1'b1;
            default: is_vowel = 1'b0;
        endcase
    end

    // State machine and counting logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            vowel_count <= 8'd0;
            char_index <= 4'd0;
            current_char <= 8'd0;
            match <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    match <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        vowel_count <= 8'd0;
                        char_index <= 4'd0;
                        next_state <= COUNT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT: begin
                    if (char_index < line_len) begin
                        current_char <= line_str[char_index];
                        if (is_vowel) begin
                            vowel_count <= vowel_count + 8'd1;
                        end
                        char_index <= char_index + 4'd1;
                        next_state <= COUNT;
                    end else begin
                        next_state <= COMPARE;
                    end
                end

                COMPARE: begin
                    if (vowel_count == target_p) begin
                        match <= 1'b1;
                    end else begin
                        match <= 1'b0;
                    end
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    match <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule