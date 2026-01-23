module bracket_fix_checker (input clk, input rst_n, input start, input [7:0] char_in, input valid_in, output reg result, output reg done);
reg [2:0] state;
reg signed [3:0] balance;
reg signed [3:0] min_balance;
reg [2:0] char_count;
reg final_evaluation;

always @(negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'b000;
        balance <= 4'd0;
        min_balance <= 4'd0;
        char_count <= 3'd0;
        final_evaluation <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            3'b000 : 
                if (start) begin
                    state <= 3'b001;
                    balance <= 4'd0;
                    min_balance <= 4'd0;
                    char_count <= 3'd0;
                    final_evaluation <= 1'b0;
                end
            endcase

            3'b001 : 
                if (valid_in) begin
                    integer current_char;
                    current_char = char_in;
                    if (current_char == 8'h28) begin
                        balance = balance + 1;
                    end else if (current_char == 8'h29) begin
                        balance = balance - 1;
                    end
                    if (balance < min_balance) begin
                        min_balance = balance;
                    end
                    if (char_count == 3'd6) begin
                        final_evaluation <= 1'b1;
                    end
                    char_count <= char_count + 1;
                end

                if (final_evaluation) begin
                    result <= (balance == 4'd0 && min_balance >= -1) ? 1'b1 : 1'b0;
                    done <= 1'b1;
                    state <= 3'b010;
                    final_evaluation <= 1'b0;
                end
            endcase

            3'b010 : 
                state <= 3'b010;
        endcase
    end
end
endmodule