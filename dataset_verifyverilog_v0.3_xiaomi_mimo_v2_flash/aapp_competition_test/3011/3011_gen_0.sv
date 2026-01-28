module hill_number_counter(
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    input [3:0] digit_count,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] CHECK_HILL     = 4'd1;
    localparam [3:0] CHECK_DIGIT    = 4'd2;
    localparam [3:0] COUNT_START    = 4'd3;
    localparam [3:0] COUNT_DIGIT    = 4'd4;
    localparam [3:0] COUNT_NEXT     = 4'd5;
    localparam [3:0] INVALID_CASE   = 4'd6;
    localparam [3:0] FINISH         = 4'd7;
    localparam [3:0] WAIT_RESET     = 4'd8;

    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] check_pos;
    reg [3:0] current_digit;
    reg [3:0] prev_digit;
    reg has_fallen;
    reg [31:0] count;
    reg [31:0] partial_result;
    reg is_hill;
    reg counting_done;
    reg [3:0] count_digit_pos;
    reg [3:0] count_last_peak;
    reg [3:0] count_last_digit;
    reg [3:0] count_digits_used;
    reg [31:0] count_limit;
    reg [3:0] count_i;
    reg [3:0] count_j;
    reg count_temp_valid;

    // Helper function to extract 4-bit digit
    function [3:0] get_digit;
        input [31:0] num;
        input [3:0] pos;
    begin
        get_digit = (num >> (pos * 4)) & 4'hF;
    end
    endfunction

    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            count <= 32'd0;
            check_pos <= 4'd0;
            current_digit <= 4'd0;
            prev_digit <= 4'd0;
            has_fallen <= 1'b0;
            partial_result <= 32'd0;
            is_hill <= 1'b0;
            counting_done <= 1'b0;
            count_digit_pos <= 4'd0;
            count_last_peak <= 4'd0;
            count_last_digit <= 4'd0;
            count_digits_used <= 4'd0;
            count_limit <= 32'd0;
            count_i <= 4'd0;
            count_j <= 4'd0;
            count_temp_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 32'd0;
                    partial_result <= 32'd0;
                    is_hill <= 1'b0;
                    counting_done <= 1'b0;
                    if (start) begin
                        state <= CHECK_HILL;
                        check_pos <= 4'd0;
                        has_fallen <= 1'b0;
                    end
                end

                CHECK_HILL: begin
                    if (digit_count == 4'd0) begin
                        is_hill <= 1'b1;
                        state <= COUNT_START;
                    end else if (check_pos < digit_count) begin
                        current_digit <= get_digit(number, check_pos);
                        if (check_pos == 4'd0) begin
                            prev_digit <= 4'd0;
                        end else begin
                            prev_digit <= get_digit(number, check_pos - 4'd1);
                        end
                        state <= CHECK_DIGIT;
                    end else begin
                        is_hill <= 1'b1;
                        state <= COUNT_START;
                    end
                end

                CHECK_DIGIT: begin
                    if (check_pos == 4'd0) begin
                        check_pos <= check_pos + 4'd1;
                        state <= CHECK_HILL;
                    end else begin
                        if (current_digit > prev_digit) begin
                            if (has_fallen) begin
                                is_hill <= 1'b0;
                                state <= INVALID_CASE;
                            end else begin
                                check_pos <= check_pos + 4'd1;
                                state <= CHECK_HILL;
                            end
                        end else if (current_digit < prev_digit) begin
                            has_fallen <= 1'b1;
                            check_pos <= check_pos + 4'd1;
                            state <= CHECK_HILL;
                        end else begin
                            check_pos <= check_pos + 4'd1;
                            state <= CHECK_HILL;
                        end
                    end
                end

                COUNT_START: begin
                    if (!is_hill) begin
                        result <= 32'hFFFFFFFF;
                        done <= 1'b1;
                        state <= WAIT_RESET;
                    end else begin
                        count_digit_pos <= 4'd0;
                        count_last_peak <= 4'd0;
                        count_last_digit <= 4'd0;
                        count_digits_used <= 4'd0;
                        counting_done <= 1'b0;
                        state <= COUNT_DIGIT;
                    end
                end

                COUNT_DIGIT: begin
                    if (counting_done) begin
                        result <= count;
                        done <= 1'b1;
                        state <= WAIT_RESET;
                    end else if (count_digit_pos < 8) begin
                        count_i <= 4'd0;
                        state <= COUNT_NEXT;
                    end else begin
                        counting_done <= 1'b1;
                    end
                end

                COUNT_NEXT: begin
                    if (count_i <= 9) begin
                        if (count_digit_pos == 4'd0) begin
                            if (count_i <= get_digit(number, 4'd0)) begin
                                if (count_digits_used < digit_count - 4'd1) begin
                                    if (count_i <= get_digit(number, count_digits_used + 4'd1)) begin
                                        count <= count + 32'd1;
                                    end
                                end else begin
                                    count <= count + 32'd1;
                                end
                            end
                            count_i <= count_i + 4'd1;
                        end else begin
                            if (count_i > count_last_peak) begin
                                count_j <= count_i;
                                count_limit <= 32'd10;
                                state <= 4'd9;
                            end else begin
                                count_i <= count_i + 4'd1;
                            end
                        end
                    end else begin
                        count_digit_pos <= count_digit_pos + 4'd1;
                        state <= COUNT_DIGIT;
                    end
                end

                INVALID_CASE: begin
                    result <= 32'hFFFFFFFF;
                    done <= 1'b1;
                    state <= WAIT_RESET;
                end

                WAIT_RESET: begin
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule