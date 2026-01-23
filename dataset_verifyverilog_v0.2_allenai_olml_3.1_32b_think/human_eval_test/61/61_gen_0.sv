module correct_bracketing(input clk, input rst_n, input start, input [127:0] brackets, output reg result, output reg done);
reg [1:0] state;
reg [4:0] char_index;
reg signed [4:0] balance;
reg error_occurred;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'b00;
        char_index <= 5'd0;
        balance <= 5'd0;
        error_occurred <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            2'b00: // IDLE
                if (start) begin
                    state <= 2'b01;
                    char_index <= 5'd0;
                    balance <= 5'd0;
                    error_occurred <= 1'b0;
                    result <= 1'b0;
                    done <= 1'b0;
                end else begin
                    state <= 2'b00;
                end
            2'b01: // CHECK_CHAR
                // Extract current character
                reg [7:0] current_char;
                current_char = brackets[(char_index * 8 + 7): char_index * 8];

                // Update balance and check for negative
                if (current_char == 8'h28) begin
                    balance <= balance + 1;
                end else if (current_char == 8'h29) begin
                    balance <= balance - 1;
                    if (balance < 0) begin
                        error_occurred <= 1'b1;
                    end
                end

                // Move to next character
                char_index <= char_index + 1;

                // Check if all characters processed
                if (char_index == 16) begin
                    state <= 2'b10;
                    result <= 1'b0;
                    done <= 1'b0;
                end else begin
                    state <= 2'b01;
                end
            2'b10: // VALIDATE
                result <= (balance == 5'd0) && !error_occurred;
                state <= 2'b11;
                done <= 1'b1;
            2'b11: // DONE
                state <= 2'b11;
                done <= 1'b1;
        endcase
    end
endmodule