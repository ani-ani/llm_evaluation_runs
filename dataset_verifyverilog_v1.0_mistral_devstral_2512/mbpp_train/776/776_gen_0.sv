module char_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [4:0] str_len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [4:0] pos;
    reg [7:0] count;
    reg [7:0] current_char;
    reg [7:0] left_char;
    reg [7:0] right_char;
    reg is_vowel_current;
    reg is_vowel_left;
    reg is_vowel_right;
    reg meets_criteria;

    // Vowel detection function
    function [7:0] is_vowel(input [7:0] c);
        if (c == 8'd97 || c == 8'd101 || c == 8'd105 || c == 8'd111 || c == 8'd117)
            is_vowel = 8'd1;
        else
            is_vowel = 8'd0;
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 5'd0;
            count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    pos = 5'd0;
                    count = 8'd0;
                end
            end
            PROCESS: begin
                if (pos == str_len - 1) begin
                    next_state = FINISH;
                end else begin
                    pos = pos + 5'd1;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(*) begin
        current_char = char_array[pos];
        is_vowel_current = is_vowel(current_char);

        // Get left and right characters
        if (pos == 5'd0) begin
            left_char = 8'd0;
            is_vowel_left = 8'd0;
        end else begin
            left_char = char_array[pos - 1];
            is_vowel_left = is_vowel(left_char);
        end

        if (pos == str_len - 1) begin
            right_char = 8'd0;
            is_vowel_right = 8'd0;
        end else begin
            right_char = char_array[pos + 1];
            is_vowel_right = is_vowel(right_char);
        end

        // Check if current character meets criteria
        meets_criteria = !is_vowel_current && (is_vowel_left || is_vowel_right);
    end

    // Update count and result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'd0;
            result <= 8'd0;
        end else begin
            if (state == PROCESS && meets_criteria) begin
                count <= count + 8'd1;
            end
            if (state == FINISH) begin
                result <= count;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule