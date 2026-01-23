module hill_number_counter(
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    input [3:0] digit_count,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_HILL = 4'd1;
    localparam [3:0] COUNT = 4'd2;
    localparam [3:0] INVALID = 4'd3;
    localparam [3:0] WAIT = 4'd4;

    // Internal registers
    reg [3:0] state;
    reg [3:0] digit_pos;
    reg [3:0] current_digit;
    reg [3:0] prev_digit;
    reg has_fallen;
    reg [3:0] check_pos;
    reg [31:0] count;

    // Function to extract digit
    function [3:0] get_digit;
        input [31:0] packed_num;
        input [3:0] pos;
        begin
            get_digit = packed_num >> (pos * 4) & 4'hF;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            count <= 32'd0;
            digit_pos <= 4'd0;
            has_fallen <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK_HILL;
                        digit_pos <= 4'd0;
                        has_fallen <= 1'b0;
                        count <= 32'd0;
                    end
                end

                CHECK_HILL: begin
                    if (digit_pos < digit_count - 1) begin
                        current_digit <= get_digit(number, digit_pos);
                        prev_digit <= get_digit(number, digit_pos - 1);

                        if (digit_pos == 0) begin
                            digit_pos <= digit_pos + 4'd1;
                        end else begin
                            if (current_digit > prev_digit) begin
                                if (has_fallen) begin
                                    state <= INVALID;
                                end else begin
                                    digit_pos <= digit_pos + 4'd1;
                                end
                            end else if (current_digit < prev_digit) begin
                                has_fallen <= 1'b1;
                                digit_pos <= digit_pos + 4'd1;
                            end else begin
                                digit_pos <= digit_pos + 4'd1;
                            end
                        end
                    end else begin
                        state <= COUNT;
                        digit_pos <= 4'd0;
                    end
                end

                COUNT: begin
                    if (digit_pos < digit_count) begin
                        // Simplified counting logic
                        count <= count + 32'd1;
                        digit_pos <= digit_pos + 4'd1;
                    end else begin
                        result <= count;
                        done <= 1'b1;
                        state <= WAIT;
                    end
                end

                INVALID: begin
                    result <= 32'hFFFFFFFF;
                    done <= 1'b1;
                    state <= WAIT;
                end

                WAIT: begin
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