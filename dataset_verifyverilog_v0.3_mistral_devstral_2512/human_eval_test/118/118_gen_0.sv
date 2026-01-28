module get_closest_vowel(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] LOAD  = 3'd1;
    localparam [2:0] SCAN  = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE  = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [7:0] char_ram [0:15];
    reg [7:0] current_char;
    reg [7:0] vowel_found;
    reg is_vowel;
    reg left_consonant_found;
    reg right_consonant_found;
    reg [3:0] left_index;
    reg [3:0] right_index;

    // Vowel detection function
    function is_vowel_func;
        input [7:0] c;
        begin
            is_vowel_func = (c == 8'd97 || c == 8'd101 || c == 8'd105 || c == 8'd111 || c == 8'd117 ||
                           c == 8'd65 || c == 8'd69 || c == 8'd73 || c == 8'd79 || c == 8'd85);
        end
    endfunction

    // Consonant detection function
    function is_consonant_func;
        input [7:0] c;
        begin
            is_consonant_func = ((c >= 8'd65 && c <= 8'd90) || (c >= 8'd97 && c <= 8'd122)) && !is_vowel_func(c);
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            result <= 8'd0;
            done <= 1'b0;
            vowel_found <= 8'd0;
            is_vowel <= 1'b0;
            left_consonant_found <= 1'b0;
            right_consonant_found <= 1'b0;
            left_index <= 4'd0;
            right_index <= 4'd0;
            current_char <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                if (index == len - 1'b1) begin
                    next_state = SCAN;
                end else begin
                    next_state = LOAD;
                end
            end

            SCAN: begin
                if (index == 4'd0) begin
                    if (vowel_found != 8'd0) begin
                        next_state = CHECK;
                    end else begin
                        next_state = DONE;
                    end
                end else begin
                    next_state = SCAN;
                end
            end

            CHECK: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
        end else begin
            if (state == LOAD) begin
                char_ram[index] <= char_in;
                index <= index + 1'b1;
            end
        end
    end

    // Scan state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
            vowel_found <= 8'd0;
            is_vowel <= 1'b0;
            left_consonant_found <= 1'b0;
            right_consonant_found <= 1'b0;
            left_index <= 4'd0;
            right_index <= 4'd0;
            current_char <= 8'd0;
        end else begin
            if (state == SCAN) begin
                current_char <= char_ram[index];
                is_vowel <= is_vowel_func(current_char);

                if (is_vowel) begin
                    vowel_found <= current_char;
                    left_consonant_found <= 1'b0;
                    right_consonant_found <= 1'b0;
                    left_index <= index - 1'b1;
                    right_index <= index + 1'b1;

                    // Check left consonant
                    if (left_index >= 4'd0 && left_index < len) begin
                        left_consonant_found <= is_consonant_func(char_ram[left_index]);
                    end

                    // Check right consonant
                    if (right_index >= 4'd0 && right_index < len) begin
                        right_consonant_found <= is_consonant_func(char_ram[right_index]);
                    end

                    if (left_consonant_found && right_consonant_found) begin
                        index <= 4'd0;
                    end else begin
                        index <= index - 1'b1;
                    end
                end else begin
                    index <= index - 1'b1;
                end
            end
        end
    end

    // Check state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            if (state == CHECK) begin
                if (vowel_found != 8'd0 && left_consonant_found && right_consonant_found) begin
                    result <= vowel_found;
                    done <= 1'b1;
                end else begin
                    result <= 8'd0;
                    done <= 1'b1;
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule