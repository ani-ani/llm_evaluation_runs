module UppercaseVowelCounter(
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
    input [7:0] char_8,
    input [7:0] char_9,
    input [7:0] char_10,
    input [7:0] char_11,
    input [7:0] char_12,
    input [7:0] char_13,
    input [7:0] char_14,
    input [7:0] char_15,
    input [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] count;
    reg [7:0] current_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            count <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNT;
                        index <= 4'd0;
                        count <= 4'd0;
                    end
                end

                COUNT: begin
                    // Select current character based on index
                    case (index)
                        4'd0: current_char = char_0;
                        4'd1: current_char = char_1;
                        4'd2: current_char = char_2;
                        4'd3: current_char = char_3;
                        4'd4: current_char = char_4;
                        4'd5: current_char = char_5;
                        4'd6: current_char = char_6;
                        4'd7: current_char = char_7;
                        4'd8: current_char = char_8;
                        4'd9: current_char = char_9;
                        4'd10: current_char = char_10;
                        4'd11: current_char = char_11;
                        4'd12: current_char = char_12;
                        4'd13: current_char = char_13;
                        4'd14: current_char = char_14;
                        4'd15: current_char = char_15;
                        default: current_char = 8'd0;
                    endcase

                    // Check if index is even and character is uppercase vowel
                    if ((index % 2 == 0) && (current_char == 8'd65 || current_char == 8'd69 || current_char == 8'd73 || current_char == 8'd79 || current_char == 8'd85)) begin
                        count <= count + 4'd1;
                    end

                    // Move to next index or finish
                    if (index == len - 1) begin
                        state <= FINISH;
                        result <= count;
                    end else begin
                        index <= index + 4'd1;
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