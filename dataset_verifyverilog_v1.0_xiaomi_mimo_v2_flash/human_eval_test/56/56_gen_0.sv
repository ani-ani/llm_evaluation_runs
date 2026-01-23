module bracket_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // ASCII constants
    localparam [7:0] LT_CHAR = 8'h3C;  // '<'
    localparam [7:0] GT_CHAR = 8'h3E;  // '>'

    // Maximum string length
    localparam [3:0] MAX_LEN = 4'd8;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] stack;  // Stack up to 8 levels (3-bit counter)
    reg [3:0] char_count;
    reg result_reg;
    reg [3:0] cycle_count;  // Timeout protection
    localparam [3:0] MAX_CYCLES = 4'd12;

    // State transition and next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            stack <= 3'd0;
            char_count <= 4'd0;
            result_reg <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    char_count <= 4'd0;
                    if (start) begin
                        state <= PROCESSING;
                        stack <= 3'd0;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (valid_in && char_count < MAX_LEN) begin
                        if (char_in == LT_CHAR) begin
                            // Push '<' to stack
                            if (stack < 3'd7) begin
                                stack <= stack + 3'd1;
                            end else begin
                                // Stack overflow - invalid
                                result_reg <= 1'b0;
                                state <= DONE;
                            end
                        end else if (char_in == GT_CHAR) begin
                            // Pop '>' from stack
                            if (stack > 3'd0) begin
                                stack <= stack - 3'd1;
                            end else begin
                                // Stack underflow - invalid
                                result_reg <= 1'b0;
                                state <= DONE;
                            end
                        end
                        // Increment character count for any valid character
                        char_count <= char_count + 4'd1;
                    end else begin
                        // End of input or max length reached
                        if (stack == 3'd0) begin
                            result_reg <= 1'b1;  // Stack empty = valid
                        end else begin
                            result_reg <= 1'b0;  // Stack not empty = invalid
                        end
                        state <= DONE;
                    end

                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        result_reg <= 1'b0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule