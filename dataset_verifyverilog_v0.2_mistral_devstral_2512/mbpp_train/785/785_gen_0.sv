module tuple_parser (
    input clk,
    input rst_n,
    input start,
    input [63:0] tuple_str,
    output reg [2:0][7:0] result,
    output reg done,
    output reg error
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        PARSE_OPEN,
        PARSE_NUM1,
        PARSE_SEP1,
        PARSE_NUM2,
        PARSE_SEP2,
        PARSE_NUM3,
        PARSE_CLOSE,
        DONE,
        ERROR
    } state_t;

    state_t current_state, next_state;
    reg [2:0] char_pos;
    reg [7:0] current_char;
    reg [7:0] num1, num2, num3;
    reg [7:0] current_num;
    reg [1:0] num_index;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            char_pos <= 0;
            current_char <= 0;
            num1 <= 0;
            num2 <= 0;
            num3 <= 0;
            current_num <= 0;
            num_index <= 0;
            done <= 0;
            error <= 0;
            result[0] <= 0;
            result[1] <= 0;
            result[2] <= 0;
        end else begin
            current_state <= next_state;
            if (next_state == IDLE && start) begin
                char_pos <= 0;
                current_char <= 0;
                num1 <= 0;
                num2 <= 0;
                num3 <= 0;
                current_num <= 0;
                num_index <= 0;
                done <= 0;
                error <= 0;
                result[0] <= 0;
                result[1] <= 0;
                result[2] <= 0;
            end else if (current_state != next_state) begin
                if (next_state == PARSE_NUM1 || next_state == PARSE_NUM2 || next_state == PARSE_NUM3) begin
                    current_num <= 0;
                end
                if (next_state == DONE) begin
                    result[0] <= num1;
                    result[1] <= num2;
                    result[2] <= num3;
                    done <= 1;
                end
                if (next_state == ERROR) begin
                    error <= 1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE_OPEN;
                    current_char = tuple_str[63:56];
                end
            end
            PARSE_OPEN: begin
                if (current_char == "(") begin
                    next_state = PARSE_NUM1;
                    char_pos = 1;
                    current_char = tuple_str[55:48];
                end else begin
                    next_state = ERROR;
                end
            end
            PARSE_NUM1: begin
                if (current_char == ",") begin
                    num1 = current_num;
                    next_state = PARSE_SEP1;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else if (current_char == ")") begin
                    num1 = current_num;
                    next_state = PARSE_CLOSE;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else if (current_char >= "0" && current_char <= "9") begin
                    current_num = current_num * 10 + (current_char - "0");
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else begin
                    next_state = ERROR;
                end
            end
            PARSE_SEP1: begin
                if (current_char == ",") begin
                    next_state = PARSE_NUM2;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else begin
                    next_state = ERROR;
                end
            end
            PARSE_NUM2: begin
                if (current_char == ",") begin
                    num2 = current_num;
                    next_state = PARSE_SEP2;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else if (current_char == ")") begin
                    num2 = current_num;
                    next_state = PARSE_CLOSE;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else if (current_char >= "0" && current_char <= "9") begin
                    current_num = current_num * 10 + (current_char - "0");
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else begin
                    next_state = ERROR;
                end
            end
            PARSE_SEP2: begin
                if (current_char == ",") begin
                    next_state = PARSE_NUM3;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else begin
                    next_state = ERROR;
                end
            end
            PARSE_NUM3: begin
                if (current_char == ")") begin
                    num3 = current_num;
                    next_state = PARSE_CLOSE;
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else if (current_char >= "0" && current_char <= "9") begin
                    current_num = current_num * 10 + (current_char - "0");
                    char_pos = char_pos + 1;
                    current_char = tuple_str[63 - (char_pos * 8): 56 - (char_pos * 8)];
                end else begin
                    next_state = ERROR;
                end
            end
            PARSE_CLOSE: begin
                if (current_char == ")") begin
                    next_state = DONE;
                end else begin
                    next_state = ERROR;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            ERROR: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule