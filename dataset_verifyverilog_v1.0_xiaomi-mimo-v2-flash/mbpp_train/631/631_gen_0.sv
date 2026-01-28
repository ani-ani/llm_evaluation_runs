module StringSwapWhitespaceUnderscore (
    input clk,
    input rst_n,
    input start,
    input [7:0] input_string_0,
    input [7:0] input_string_1,
    input [7:0] input_string_2,
    input [7:0] input_string_3,
    input [7:0] input_string_4,
    input [7:0] input_string_5,
    input [7:0] input_string_6,
    input [7:0] input_string_7,
    input [7:0] input_string_8,
    input [7:0] input_string_9,
    input [7:0] input_string_10,
    input [7:0] input_string_11,
    input [7:0] input_string_12,
    input [7:0] input_string_13,
    input [7:0] input_string_14,
    input [7:0] input_string_15,
    input [3:0] length,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [7:0] result_8,
    output reg [7:0] result_9,
    output reg [7:0] result_10,
    output reg [7:0] result_11,
    output reg [7:0] result_12,
    output reg [7:0] result_13,
    output reg [7:0] result_14,
    output reg [7:0] result_15,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;  // Current character index (0-15)
    reg [7:0] temp_char;

    // ASCII constants
    localparam [7:0] ASCII_SPACE = 8'd32;
    localparam [7:0] ASCII_UNDERSCORE = 8'd95;
    localparam [7:0] ASCII_NULL = 8'd0;

    // Combinational logic for character lookup and transformation
    reg [7:0] current_input;
    reg [7:0] transformed;
    
    // Input selector (combinational)
    always @(*) begin
        case (index)
            4'd0: current_input = input_string_0;
            4'd1: current_input = input_string_1;
            4'd2: current_input = input_string_2;
            4'd3: current_input = input_string_3;
            4'd4: current_input = input_string_4;
            4'd5: current_input = input_string_5;
            4'd6: current_input = input_string_6;
            4'd7: current_input = input_string_7;
            4'd8: current_input = input_string_8;
            4'd9: current_input = input_string_9;
            4'd10: current_input = input_string_10;
            4'd11: current_input = input_string_11;
            4'd12: current_input = input_string_12;
            4'd13: current_input = input_string_13;
            4'd14: current_input = input_string_14;
            4'd15: current_input = input_string_15;
            default: current_input = 8'd0;
        endcase
    end

    // Transformation logic (combinational)
    always @(*) begin
        if (index < length) begin
            if (current_input == ASCII_SPACE) begin
                transformed = ASCII_UNDERSCORE;
            end else if (current_input == ASCII_UNDERSCORE) begin
                transformed = ASCII_SPACE;
            end else begin
                transformed = current_input;
            end
        end else begin
            transformed = ASCII_NULL;
        end
    end

    // Sequential state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            result_8 <= 8'd0;
            result_9 <= 8'd0;
            result_10 <= 8'd0;
            result_11 <= 8'd0;
            result_12 <= 8'd0;
            result_13 <= 8'd0;
            result_14 <= 8'd0;
            result_15 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    // Store transformed character to appropriate result port
                    case (index)
                        4'd0: result_0 <= transformed;
                        4'd1: result_1 <= transformed;
                        4'd2: result_2 <= transformed;
                        4'd3: result_3 <= transformed;
                        4'd4: result_4 <= transformed;
                        4'd5: result_5 <= transformed;
                        4'd6: result_6 <= transformed;
                        4'd7: result_7 <= transformed;
                        4'd8: result_8 <= transformed;
                        4'd9: result_9 <= transformed;
                        4'd10: result_10 <= transformed;
                        4'd11: result_11 <= transformed;
                        4'd12: result_12 <= transformed;
                        4'd13: result_13 <= transformed;
                        4'd14: result_14 <= transformed;
                        4'd15: result_15 <= transformed;
                        default: begin
                            result_0 <= result_0;
                            result_1 <= result_1;
                            result_2 <= result_2;
                            result_3 <= result_3;
                            result_4 <= result_4;
                            result_5 <= result_5;
                            result_6 <= result_6;
                            result_7 <= result_7;
                            result_8 <= result_8;
                            result_9 <= result_9;
                            result_10 <= result_10;
                            result_11 <= result_11;
                            result_12 <= result_12;
                            result_13 <= result_13;
                            result_14 <= result_14;
                            result_15 <= result_15;
                        end
                    endcase

                    // Move to next index or finish
                    if (index == 4'd15) begin
                        state <= FINISH;
                        index <= 4'd0;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule