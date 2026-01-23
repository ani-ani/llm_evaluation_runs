module goldbach_checker(
    input clk,
    input rst_n,
    input start,
    input [5:0] len,
    input [7:0] arr [0:63],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SKIP_WS = 3'd1;
    localparam [2:0] IN_TOKEN = 3'd2;
    localparam [2:0] CHECK_TOKEN = 3'd3;
    localparam [2:0] DONE = 3'd4;
    localparam [2:0] ERROR = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] current_char;
    reg [7:0] token_value;
    reg [7:0] token1, token2, token3;
    reg [5:0] char_index;
    reg [2:0] token_count;
    reg [2:0] digit_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Primality lookup table for 0-255
    function automatic is_prime;
        input [7:0] num;
        begin
            case (num)
                2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251: is_prime = 1'b1;
                default: is_prime = 1'b0;
            endcase
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            char_index <= 6'd0;
            token_count <= 3'd0;
            digit_count <= 3'd0;
            token_value <= 8'd0;
            token1 <= 8'd0;
            token2 <= 8'd0;
            token3 <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    char_index <= 6'd0;
                    token_count <= 3'd0;
                    digit_count <= 3'd0;
                    token_value <= 8'd0;
                    if (start) begin
                        next_state <= SKIP_WS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SKIP_WS: begin
                    if (char_index < len) begin
                        current_char = arr[char_index];
                        if (current_char == 8'd32 || current_char == 8'd9 || current_char == 8'd10 || current_char == 8'd13) begin
                            char_index <= char_index + 6'd1;
                            next_state <= SKIP_WS;
                        end else if (current_char >= 8'd48 && current_char <= 8'd57) begin
                            token_value <= current_char - 8'd48;
                            digit_count <= 3'd1;
                            char_index <= char_index + 6'd1;
                            next_state <= IN_TOKEN;
                        end else begin
                            next_state <= ERROR;
                        end
                    end else begin
                        next_state <= ERROR;
                    end
                end

                IN_TOKEN: begin
                    if (char_index < len) begin
                        current_char = arr[char_index];
                        if (current_char >= 8'd48 && current_char <= 8'd57) begin
                            if (digit_count < 3'd3) begin
                                token_value <= token_value * 8'd10 + (current_char - 8'd48);
                                digit_count <= digit_count + 3'd1;
                                char_index <= char_index + 6'd1;
                                next_state <= IN_TOKEN;
                            end else begin
                                next_state <= ERROR;
                            end
                        end else if (current_char == 8'd32 || current_char == 8'd9 || current_char == 8'd10 || current_char == 8'd13) begin
                            char_index <= char_index + 6'd1;
                            next_state <= CHECK_TOKEN;
                        end else begin
                            next_state <= ERROR;
                        end
                    end else begin
                        next_state <= CHECK_TOKEN;
                    end
                end

                CHECK_TOKEN: begin
                    case (token_count)
                        3'd0: token1 <= token_value;
                        3'd1: token2 <= token_value;
                        3'd2: token3 <= token_value;
                        default: next_state <= ERROR;
                    endcase
                    token_count <= token_count + 3'd1;
                    token_value <= 8'd0;
                    digit_count <= 3'd0;
                    if (token_count == 3'd3) begin
                        next_state <= DONE;
                    end else begin
                        next_state <= SKIP_WS;
                    end
                end

                DONE: begin
                    if (token1 > 8'd3 && token1 <= 8'd255 && (token1 % 2) == 0 && 
                        is_prime(token2) && is_prime(token3) && 
                        token2 + token3 == token1) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                ERROR: begin
                    result <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule