module tuple_parser (input clk, input rst_n, input start, input [63:0] tuple_str, output reg [2:0][7:0] result, output reg done, output reg error);
localparam IDLE = 3'd0, PARSE_OPEN =1, IN_NUM1_FIRST=2, IN_NUM1_SECOND=3, AFTER_NUM1_SEP=4, IN_NUM2_FIRST=5, IN_NUM2_SECOND=6, AFTER_NUM2_SEP=7, IN_NUM3_FIRST=8, IN_NUM3_SECOND=9, AFTER_NUM3=10, CHECK_CLOSE=11, DONE=12, ERROR=13;
reg [3:0] state, [2:0] current_position;
reg [7:0] num1, num2, num3;
reg [2:0][7:0] result_reg;
wire [7:0] current_char;
assign current_char = tuple_str[ (63 - current_position*8) : (63 - current_position*8 -7) ];
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_position <= 0;
        num1 <= 0;
        num2 <= 0;
        num3 <= 0;
        result_reg <= 0;
        done <= 0;
        error <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                if (current_position == 0) begin
                    if (current_char == '(') begin
                        state <= PARSE_OPEN;
                        current_position <= 1;
                    end else begin
                        error <= 1;
                        state <= ERROR;
                    end
                end else begin
                    error <= 1;
                    state <= ERROR;
                end
            end else begin
                state <= IDLE;
            end
        end else if (state == PARSE_OPEN) begin
            if (current_char >= '0' && current_char <= '9') begin
                num1 <= current_char - '0';
                state <= IN_NUM1_FIRST;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == IN_NUM1_FIRST) begin
            if (current_char >= '0' && current_char <= '9') begin
                num1 <= num1 * 10 + (current_char - '0');
                current_position <= current_position + 1;
                state <= IN_NUM1_SECOND;
            end else if (current_char == ',') begin
                state <= AFTER_NUM1_SEP;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == IN_NUM1_SECOND) begin
            if (current_char == ',') begin
                state <= AFTER_NUM1_SEP;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == AFTER_NUM1_SEP) begin
            if (current_char >= '0' && current_char <= '9') begin
                num2 <= current_char - '0';
                state <= IN_NUM2_FIRST;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == IN_NUM2_FIRST) begin
            if (current_char >= '0' && current_char <= '9') begin
                num2 <= num2 * 10 + (current_char - '0');
                current_position <= current_position + 1;
                state <= IN_NUM2_SECOND;
            end else if (current_char == ',') begin
                state <= AFTER_NUM2_SEP;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == IN_NUM2_SECOND) begin
            if (current_char == ',') begin
                state <= AFTER_NUM2_SEP;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == AFTER_NUM2_SEP) begin
            if (current_char >= '0' && current_char <= '9') begin
                num3 <= current_char - '0';
                state <= IN_NUM3_FIRST;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == IN_NUM3_FIRST) begin
            if (current_char >= '0' && current_char <= '9') begin
                num3 <= num3 * 10 + (current_char - '0');
                current_position <= current_position + 1;
                state <= IN_NUM3_SECOND;
            end else if (current_char == ')') begin
                state <= AFTER_NUM3;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == IN_NUM3_SECOND) begin
            if (current_char == ')') begin
                state <= AFTER_NUM3;
                current_position <= current_position + 1;
            end else begin
                error <= 1;
                state <= ERROR;
            end
        end else if (state == AFTER_NUM3) begin
            state <= CHECK_CLOSE;
        end else if (state == CHECK_CLOSE) begin
            if (current_position > 7) begin
                done <= 1;
                state <= DONE;
                result_reg <= {{num1}, {num2}, {num3}};
            end else begin
                if (current_char != ' ') begin
                    error <= 1;
                    state <= ERROR;
                end else begin
                    current_position <= current_position + 1;
                end
            end
        end else if (state == DONE) begin
            result <= result_reg;
            done <=1;
        end else if (state == ERROR) begin
            error <=1;
        end
    end
endmodule