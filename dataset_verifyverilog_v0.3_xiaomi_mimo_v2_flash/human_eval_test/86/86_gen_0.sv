module anti_shuffle (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] CAPTURE  = 2'd1;
    localparam [1:0] SORTING  = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Internal registers for input capture
    reg [7:0] char_reg_0;
    reg [7:0] char_reg_1;
    reg [7:0] char_reg_2;
    reg [7:0] char_reg_3;
    reg [7:0] char_reg_4;
    reg [7:0] char_reg_5;
    reg [7:0] char_reg_6;
    reg [7:0] char_reg_7;

    // Bubble sort state and counters
    reg [1:0] state;
    reg [2:0] pass_counter;    // 0 to 7 passes needed for 8 elements
    reg [2:0] compare_counter; // 0 to 6 comparisons per pass
    reg [2:0] word_start_idx;  // Start index of current word
    reg [2:0] word_end_idx;    // End index of current word
    reg [2:0] current_pos;     // Position for checking word boundaries
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd120;

    // Temporary registers for swap
    reg [7:0] temp_char;
    reg swap_needed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            pass_counter <= 3'd0;
            compare_counter <= 3'd0;
            word_start_idx <= 3'd0;
            word_end_idx <= 3'd0;
            current_pos <= 3'd0;
            // Initialize output registers
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            // Initialize character registers
            char_reg_0 <= 8'd0;
            char_reg_1 <= 8'd0;
            char_reg_2 <= 8'd0;
            char_reg_3 <= 8'd0;
            char_reg_4 <= 8'd0;
            char_reg_5 <= 8'd0;
            char_reg_6 <= 8'd0;
            char_reg_7 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    pass_counter <= 3'd0;
                    compare_counter <= 3'd0;
                    word_start_idx <= 3'd0;
                    word_end_idx <= 3'd0;
                    current_pos <= 3'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    // Capture all 8 input characters
                    char_reg_0 <= char_0;
                    char_reg_1 <= char_1;
                    char_reg_2 <= char_2;
                    char_reg_3 <= char_3;
                    char_reg_4 <= char_4;
                    char_reg_5 <= char_5;
                    char_reg_6 <= char_6;
                    char_reg_7 <= char_7;
                    // Initialize output as copy of input
                    result_0 <= char_0;
                    result_1 <= char_1;
                    result_2 <= char_2;
                    result_3 <= char_3;
                    result_4 <= char_4;
                    result_5 <= char_5;
                    result_6 <= char_6;
                    result_7 <= char_7;
                    state <= SORTING;
                end

                SORTING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Find next word to sort
                    if (pass_counter == 3'd0 && compare_counter == 3'd0) begin
                        // Find word boundaries for current position
                        if (current_pos < 3'd8) begin
                            // Check if current position starts a word (not space)
                            case (current_pos)
                                3'd0: begin
                                    if (char_reg_0 != 8'h20) begin
                                        word_start_idx <= 3'd0;
                                        // Find word end
                                        if (char_reg_1 == 8'h20) word_end_idx <= 3'd0;
                                        else if (char_reg_2 == 8'h20) word_end_idx <= 3'd1;
                                        else if (char_reg_3 == 8'h20) word_end_idx <= 3'd2;
                                        else if (char_reg_4 == 8'h20) word_end_idx <= 3'd3;
                                        else if (char_reg_5 == 8'h20) word_end_idx <= 3'd4;
                                        else if (char_reg_6 == 8'h20) word_end_idx <= 3'd5;
                                        else if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd1: begin
                                    if (char_reg_1 != 8'h20 && char_reg_0 == 8'h20) begin
                                        word_start_idx <= 3'd1;
                                        if (char_reg_2 == 8'h20) word_end_idx <= 3'd1;
                                        else if (char_reg_3 == 8'h20) word_end_idx <= 3'd2;
                                        else if (char_reg_4 == 8'h20) word_end_idx <= 3'd3;
                                        else if (char_reg_5 == 8'h20) word_end_idx <= 3'd4;
                                        else if (char_reg_6 == 8'h20) word_end_idx <= 3'd5;
                                        else if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd2: begin
                                    if (char_reg_2 != 8'h20 && char_reg_1 == 8'h20) begin
                                        word_start_idx <= 3'd2;
                                        if (char_reg_3 == 8'h20) word_end_idx <= 3'd2;
                                        else if (char_reg_4 == 8'h20) word_end_idx <= 3'd3;
                                        else if (char_reg_5 == 8'h20) word_end_idx <= 3'd4;
                                        else if (char_reg_6 == 8'h20) word_end_idx <= 3'd5;
                                        else if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd3: begin
                                    if (char_reg_3 != 8'h20 && char_reg_2 == 8'h20) begin
                                        word_start_idx <= 3'd3;
                                        if (char_reg_4 == 8'h20) word_end_idx <= 3'd3;
                                        else if (char_reg_5 == 8'h20) word_end_idx <= 3'd4;
                                        else if (char_reg_6 == 8'h20) word_end_idx <= 3'd5;
                                        else if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd4: begin
                                    if (char_reg_4 != 8'h20 && char_reg_3 == 8'h20) begin
                                        word_start_idx <= 3'd4;
                                        if (char_reg_5 == 8'h20) word_end_idx <= 3'd4;
                                        else if (char_reg_6 == 8'h20) word_end_idx <= 3'd5;
                                        else if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd5: begin
                                    if (char_reg_5 != 8'h20 && char_reg_4 == 8'h20) begin
                                        word_start_idx <= 3'd5;
                                        if (char_reg_6 == 8'h20) word_end_idx <= 3'd5;
                                        else if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd6: begin
                                    if (char_reg_6 != 8'h20 && char_reg_5 == 8'h20) begin
                                        word_start_idx <= 3'd6;
                                        if (char_reg_7 == 8'h20) word_end_idx <= 3'd6;
                                        else word_end_idx <= 3'd7;
                                    end
                                end
                                3'd7: begin
                                    if (char_reg_7 != 8'h20 && char_reg_6 == 8'h20) begin
                                        word_start_idx <= 3'd7;
                                        word_end_idx <= 3'd7;
                                    end
                                end
                            endcase
                            // Move to next position for next word search
                            current_pos <= current_pos + 3'd1;
                        end
                    end

                    // Bubble sort logic for current word
                    if (word_end_idx >= word_start_idx) begin
                        // Check if current comparison is within word bounds
                        if (compare_counter >= word_start_idx && compare_counter < word_end_idx) begin
                            // Get characters at compare_counter and compare_counter+1
                            case (compare_counter)
                                3'd0: begin
                                    if (result_0 > result_1) begin
                                        temp_char <= result_0;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                                3'd1: begin
                                    if (result_1 > result_2) begin
                                        temp_char <= result_1;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                                3'd2: begin
                                    if (result_2 > result_3) begin
                                        temp_char <= result_2;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                                3'd3: begin
                                    if (result_3 > result_4) begin
                                        temp_char <= result_3;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                                3'd4: begin
                                    if (result_4 > result_5) begin
                                        temp_char <= result_4;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                                3'd5: begin
                                    if (result_5 > result_6) begin
                                        temp_char <= result_5;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                                3'd6: begin
                                    if (result_6 > result_7) begin
                                        temp_char <= result_6;
                                        swap_needed <= 1'b1;
                                    end else begin
                                        swap_needed <= 1'b0;
                                    end
                                end
                            endcase

                            // Perform swap if needed (next cycle)
                            if (swap_needed) begin
                                case (compare_counter)
                                    3'd0: begin
                                        result_0 <= result_1;
                                        result_1 <= temp_char;
                                    end
                                    3'd1: begin
                                        result_1 <= result_2;
                                        result_2 <= temp_char;
                                    end
                                    3'd2: begin
                                        result_2 <= result_3;
                                        result_3 <= temp_char;
                                    end
                                    3'd3: begin
                                        result_3 <= result_4;
                                        result_4 <= temp_char;
                                    end
                                    3'd4: begin
                                        result_4 <= result_5;
                                        result_5 <= temp_char;
                                    end
                                    3'd5: begin
                                        result_5 <= result_6;
                                        result_6 <= temp_char;
                                    end
                                    3'd6: begin
                                        result_6 <= result_7;
                                        result_7 <= temp_char;
                                    end
                                endcase
                            end
                        end

                        // Increment compare counter
                        if (compare_counter < 3'd7) begin
                            compare_counter <= compare_counter + 3'd1;
                        end else begin
                            compare_counter <= 3'd0;
                            // End of pass - move to next word or finish
                            if (pass_counter < 3'd7) begin
                                pass_counter <= pass_counter + 3'd1;
                            end else begin
                                // All passes complete for current word
                                pass_counter <= 3'd0;
                                // Reset word search for next word
                                if (current_pos >= 3'd8) begin
                                    state <= COMPLETE;
                                end
                            end
                        end
                    end else begin
                        // No word at this position or space - skip to next
                        if (compare_counter < 3'd7) begin
                            compare_counter <= compare_counter + 3'd1;
                        end else begin
                            compare_counter <= 3'd0;
                            if (pass_counter < 3'd7) begin
                                pass_counter <= pass_counter + 3'd1;
                            end else begin
                                pass_counter <= 3'd0;
                                if (current_pos >= 3'd8) begin
                                    state <= COMPLETE;
                                end
                            end
                        end
                    end

                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule