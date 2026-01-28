module correct_bracketing(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input done_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_CHAR  = 3'd1;
    localparam [2:0] VERIFY_FINAL = 3'd2;
    localparam [2:0] DONE_STATE  = 3'd3;

    reg [2:0] state, next_state;
    reg [4:0] bracket_counter;
    reg [3:0] char_index;
    reg [3:0] max_length;
    localparam [3:0] MAX_LENGTH = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bracket_counter <= 5'd0;
            char_index <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                result = 1'b0;
                done = 1'b0;
                if (start) begin
                    next_state = CHECK_CHAR;
                    bracket_counter = 5'd0;
                    char_index = 4'd0;
                end
            end

            CHECK_CHAR: begin
                done = 1'b0;
                if (valid_in) begin
                    if (char_in == 8'd40) begin  // '('
                        bracket_counter = bracket_counter + 5'd1;
                    end else if (char_in == 8'd41) begin  // ')'
                        if (bracket_counter == 5'd0) begin
                            result = 1'b0;
                            next_state = VERIFY_FINAL;
                        end else begin
                            bracket_counter = bracket_counter - 5'd1;
                        end
                    end
                    char_index = char_index + 4'd1;
                end
                if (done_in) begin
                    next_state = VERIFY_FINAL;
                end
            end

            VERIFY_FINAL: begin
                if (bracket_counter == 5'd0) begin
                    result = 1'b1;
                end else begin
                    result = 1'b0;
                end
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule