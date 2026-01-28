module whitespace_replacer(
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

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS = 4'd1;
    localparam [3:0] FINISH = 4'd2;

    reg [3:0] state;
    reg [3:0] counter;
    reg [7:0] current_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
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
                    if (start) begin
                        state <= PROCESS;
                        counter <= 4'd0;
                    end
                end
                PROCESS: begin
                    if (counter < length) begin
                        case (counter)
                            4'd0: current_char = input_string_0;
                            4'd1: current_char = input_string_1;
                            4'd2: current_char = input_string_2;
                            4'd3: current_char = input_string_3;
                            4'd4: current_char = input_string_4;
                            4'd5: current_char = input_string_5;
                            4'd6: current_char = input_string_6;
                            4'd7: current_char = input_string_7;
                            4'd8: current_char = input_string_8;
                            4'd9: current_char = input_string_9;
                            4'd10: current_char = input_string_10;
                            4'd11: current_char = input_string_11;
                            4'd12: current_char = input_string_12;
                            4'd13: current_char = input_string_13;
                            4'd14: current_char = input_string_14;
                            4'd15: current_char = input_string_15;
                            default: current_char = 8'd0;
                        endcase
                        if (current_char == 8'd32) begin
                            current_char = 8'd95;
                        end else if (current_char == 8'd95) begin
                            current_char = 8'd32;
                        end
                        case (counter)
                            4'd0: result_0 <= current_char;
                            4'd1: result_1 <= current_char;
                            4'd2: result_2 <= current_char;
                            4'd3: result_3 <= current_char;
                            4'd4: result_4 <= current_char;
                            4'd5: result_5 <= current_char;
                            4'd6: result_6 <= current_char;
                            4'd7: result_7 <= current_char;
                            4'd8: result_8 <= current_char;
                            4'd9: result_9 <= current_char;
                            4'd10: result_10 <= current_char;
                            4'd11: result_11 <= current_char;
                            4'd12: result_12 <= current_char;
                            4'd13: result_13 <= current_char;
                            4'd14: result_14 <= current_char;
                            4'd15: result_15 <= current_char;
                        endcase
                        counter <= counter + 4'd1;
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

    always @(*) begin
        if (counter >= length) begin
            case (counter)
                4'd0: result_0 = 8'd0;
                4'd1: result_1 = 8'd0;
                4'd2: result_2 = 8'd0;
                4'd3: result_3 = 8'd0;
                4'd4: result_4 = 8'd0;
                4'd5: result_5 = 8'd0;
                4'd6: result_6 = 8'd0;
                4'd7: result_7 = 8'd0;
                4'd8: result_8 = 8'd0;
                4'd9: result_9 = 8'd0;
                4'd10: result_10 = 8'd0;
                4'd11: result_11 = 8'd0;
                4'd12: result_12 = 8'd0;
                4'd13: result_13 = 8'd0;
                4'd14: result_14 = 8'd0;
                4'd15: result_15 = 8'd0;
            endcase
        end
    end

endmodule