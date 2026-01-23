module count_upper (
    input clk,
    input rst_n,
    input start,
    input [5:0] str_len,
    input [127:0] str_data,
    output reg [3:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE       = 10'b0000000001;
    localparam CHECK_POS_0 = 10'b0000000010;
    localparam CHECK_POS_2 = 10'b0000000100;
    localparam CHECK_POS_4 = 10'b0000001000;
    localparam CHECK_POS_6 = 10'b0000010000;
    localparam CHECK_POS_8 = 10'b0000100000;
    localparam CHECK_POS_10 = 10'b0001000000;
    localparam CHECK_POS_12 = 10'b0010000000;
    localparam CHECK_POS_14 = 10'b0100000000;
    localparam DONE        = 10'b1000000000;

    reg [9:0] state;
    reg [9:0] next_state;

    // Current position being checked (0, 2, 4, ... 14)
    reg [3:0] current_pos;
    // Extracted character
    reg [7:0] char;
    // Is vowel flag
    reg is_vowel;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_POS_0;
                else
                    next_state = IDLE;
            end
            CHECK_POS_0:  next_state = CHECK_POS_2;
            CHECK_POS_2:  next_state = CHECK_POS_4;
            CHECK_POS_4:  next_state = CHECK_POS_6;
            CHECK_POS_6:  next_state = CHECK_POS_8;
            CHECK_POS_8:  next_state = CHECK_POS_10;
            CHECK_POS_10: next_state = CHECK_POS_12;
            CHECK_POS_12: next_state = CHECK_POS_14;
            CHECK_POS_14: next_state = DONE;
            DONE: begin
                if (start)
                    next_state = CHECK_POS_0;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Helper logic for character extraction and vowel check
    always @(*) begin
        // Default values
        char = 8'b0;
        is_vowel = 1'b0;
        current_pos = 4'b0;

        case (state)
            CHECK_POS_0: begin
                current_pos = 4'd0;
                char = str_data[7:0];
            end
            CHECK_POS_2: begin
                current_pos = 4'd2;
                char = str_data[23:16];
            end
            CHECK_POS_4: begin
                current_pos = 4'd4;
                char = str_data[39:32];
            end
            CHECK_POS_6: begin
                current_pos = 4'd6;
                char = str_data[55:48];
            end
            CHECK_POS_8: begin
                current_pos = 4'd8;
                char = str_data[71:64];
            end
            CHECK_POS_10: begin
                current_pos = 4'd10;
                char = str_data[87:80];
            end
            CHECK_POS_12: begin
                current_pos = 4'd12;
                char = str_data[103:96];
            end
            CHECK_POS_14: begin
                current_pos = 4'd14;
                char = str_data[119:112];
            end
            default: begin
                current_pos = 4'b0;
                char = 8'b0;
            end
        endcase

        // Vowel Lookup (V = A, E, I, O, U)
        if (char == 8'h41 || char == 8'h45 || char == 8'h49 || char == 8'h4F || char == 8'h55) begin
            is_vowel = 1'b1;
        end else begin
            is_vowel = 1'b0;
        end
    end

    // Output Logic & Counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 4'b0;
                    done <= 1'b0;
                end
                CHECK_POS_0, CHECK_POS_2, CHECK_POS_4, CHECK_POS_6, 
                CHECK_POS_8, CHECK_POS_10, CHECK_POS_12, CHECK_POS_14: begin
                    // Increment if within string length and is a vowel
                    if (current_pos < str_len && is_vowel) begin
                        result <= result + 1'b1;
                    end
                    done <= 1'b0;
                end
                DONE: begin
                    done <= 1'b1;
                    // Result holds value
                end
                default: begin
                    result <= 4'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule