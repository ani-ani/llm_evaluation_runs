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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] char_idx;
    reg [3:0] next_char_idx;
    reg [7:0] vowel_count;
    reg [7:0] next_vowel_count;
    reg [7:0] current_char;
    reg is_vowel;

    // Character lookup logic (combinational)
    always @(*) begin
        is_vowel = 1'b0;
        // Only check valid characters
        if (char_idx < line_len) begin
            current_char = line_str[char_idx];
            case (current_char)
                8'd97,  // 'a'
                8'd101, // 'e'
                8'd105, // 'i'
                8'd111, // 'o'
                8'd117, // 'u'
                8'd121: // 'y'
                    is_vowel = 1'b1;
                default: is_vowel = 1'b0;
            endcase
        end else begin
            current_char = 8'd0;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_char_idx = char_idx;
        next_vowel_count = vowel_count;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNT;
                    next_char_idx = 4'd0;
                    next_vowel_count = 8'd0;
                end
            end
            
            COUNT: begin
                if (char_idx < line_len) begin
                    if (is_vowel) begin
                        next_vowel_count = vowel_count + 8'd1;
                    end
                    next_char_idx = char_idx + 4'd1;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_idx <= 4'd0;
            vowel_count <= 8'd0;
            match <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            char_idx <= next_char_idx;
            vowel_count <= next_vowel_count;
            
            case (state)
                IDLE: begin
                    match <= 1'b0;
                    done <= 1'b0;
                end
                COMPARE: begin
                    match <= (vowel_count == target_p);
                end
                FINISH: begin
                    done <= 1'b1;
                end
                default: begin
                    match <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule