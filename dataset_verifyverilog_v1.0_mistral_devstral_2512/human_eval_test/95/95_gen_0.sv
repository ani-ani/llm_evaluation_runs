module check_dict_case(
    input clk,
    input rst_n,
    input start,
    input [63:0] keys [0:7],
    input [2:0] num_keys,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CHECK_LOOP = 2'd1;
    localparam [1:0] VALIDATE  = 2'd2;
    localparam [1:0] COMPLETE  = 2'd3;

    reg [1:0] state, next_state;
    reg [2:0] index;
    reg [7:0] current_char;
    reg is_lowercase;
    reg is_uppercase;
    reg is_valid;
    reg first_key_case;
    reg [2:0] char_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            char_index <= 3'd0;
            is_lowercase <= 1'b0;
            is_uppercase <= 1'b0;
            is_valid <= 1'b0;
            first_key_case <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_LOOP;
                    index <= 3'd0;
                    char_index <= 3'd0;
                    is_lowercase <= 1'b0;
                    is_uppercase <= 1'b0;
                    is_valid <= 1'b0;
                    first_key_case <= 1'b0;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            end

            CHECK_LOOP: begin
                if (index == num_keys) begin
                    next_state = VALIDATE;
                end else begin
                    current_char = keys[index][char_index * 8 +: 8];
                    if (current_char == 8'd0) begin
                        if (char_index == 3'd0) begin
                            is_valid <= 1'b0;
                        end
                        next_state = CHECK_LOOP;
                        char_index <= 3'd0;
                        index <= index + 3'd1;
                    end else begin
                        if (current_char >= 8'd65 && current_char <= 8'd90) begin
                            is_uppercase <= 1'b1;
                        end else if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            is_lowercase <= 1'b1;
                        end else begin
                            is_valid <= 1'b0;
                        end
                        char_index <= char_index + 3'd1;
                    end
                end
            end

            VALIDATE: begin
                if (num_keys == 3'd0) begin
                    result <= 1'b0;
                end else if (!is_valid) begin
                    result <= 1'b0;
                end else if (is_lowercase && is_uppercase) begin
                    result <= 1'b0;
                end else begin
                    result <= 1'b1;
                end
                next_state = COMPLETE;
            end

            COMPLETE: begin
                done <= 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule