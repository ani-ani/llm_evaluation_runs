module string_decimal_validator(input clk, input rst_n, input start, input [7:0][7:0] char_array, output reg valid, output reg done);

localparam IDLE = 2'd0, PROCESSING = 2'd1, DONE = 2'd2;

reg [1:0] state;
reg [2:0] char_index;
reg [7:0] latched_char_array [7:0];
reg valid_flag;
reg decimal_seen;
reg [3:0] digits_before;
reg [1:0] digits_after;
reg before_decimal;
reg [3:0] cycle_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        char_index <= 0;
        latched_char_array <= 8'h00;
        valid_flag <= 1'b1;
        decimal_seen <= 1'b0;
        digits_before <= 4'd0;
        digits_after <= 2'd0;
        before_decimal <= 1'b1;
        cycle_counter <= 4'd0;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                latched_char_array <= char_array;
                state <= PROCESSING;
                char_index <= 0;
                decimal_seen <= 1'b0;
                digits_before <= 4'd0;
                digits_after <= 2'd0;
                before_decimal <= 1'b1;
                cycle_counter <= 4'd10;
            end
        end
        if (state == PROCESSING) begin
            if (cycle_counter > 0) begin
                if (char_index < 8) begin
                    [7:0] current_char;
                    current_char = latched_char_array[char_index];
                    bit is_digit = (current_char >= 8'h30) && (current_char <= 8'h39);
                    bit is_dot = (current_char == 8'h2E);
                    if (is_digit) begin
                        if (before_decimal) begin
                            digits_before = digits_before + 1;
                        end else begin
                            digits_after = digits_after + 1;
                            if (digits_after > 2) begin
                                valid_flag = 1'b0;
                            end
                        end
                    end else if (is_dot) begin
                        if (decimal_seen) begin
                            valid_flag = 1'b0;
                        end else begin
                            decimal_seen = 1'b1;
                            before_decimal = 1'b0;
                        end
                    end else begin
                        valid_flag = 1'b0;
                    end
                    char_index = char_index + 1;
                end
                cycle_counter = cycle_counter - 1;
                if (cycle_counter == 0) begin
                    state <= DONE;
                end
            end
        end
        if (state == DONE) begin
            bit overall_valid;
            if (valid_flag) begin
                if (decimal_seen) begin
                    if (digits_before == 4'd0 || digits_after < 1 || digits_after > 2) begin
                        overall_valid = 1'b0;
                    end else begin
                        overall_valid = 1'b1;
                    end
                end else begin
                    if (digits_before == 4'd0) begin
                        overall_valid = 1'b0;
                    end else begin
                        overall_valid = 1'b1;
                    end
                end
            end else begin
                overall_valid = 1'b0;
            end
            valid <= overall_valid;
            done <= 1'b1;
        end
    end
endmodule