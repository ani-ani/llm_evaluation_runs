module house_purchase_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] L,
    input [7:0] R,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK = 3'b010;
    localparam INCREMENT = 3'b011;
    localparam DONE = 3'b100;

    // State machine
    reg [2:0] state = IDLE;
    reg [7:0] counter = 0;
    reg [31:0] temp_result = 0;

    // Digit extraction
    function [2:0] get_digit;
        input [7:0] num;
        input [1:0] pos;
        begin
            case (pos)
                2'b00: get_digit = num[7:5];
                2'b01: get_digit = num[4:2];
                2'b10: get_digit = num[1:0];
                default: get_digit = 0;
            endcase
        end
    endfunction

    // Check if number is valid
    function automatic bit is_valid;
        input [7:0] num;
        begin
            bit [2:0] d0, d1, d2;
            bit has_4 = 0;
            bit [1:0] lucky_count = 0;
            bit [1:0] digit_count = 0;

            // Extract digits (MSB to LSB)
            d0 = get_digit(num, 2'b00);
            d1 = get_digit(num, 2'b01);
            d2 = get_digit(num, 2'b10);

            // Check for digit '4' and count lucky digits
            if (d0 > 0) begin
                if (d0 == 3'b100) has_4 = 1;
                else if (d0 == 3'b110 || d0 == 3'b1000) lucky_count++;
                digit_count++;
            end
            if (d1 > 0 || d0 > 0) begin
                if (d1 == 3'b100) has_4 = 1;
                else if (d1 == 3'b110 || d1 == 3'b1000) lucky_count++;
                digit_count++;
            end
            if (d2 > 0 || d1 > 0 || d0 > 0) begin
                if (d2 == 3'b100) has_4 = 1;
                else if (d2 == 3'b110 || d2 == 3'b1000) lucky_count++;
                digit_count++;
            end

            // Valid if no '4' and lucky_count == non_lucky_count
            is_valid = !has_4 && (lucky_count == (digit_count - lucky_count));
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 0;
            temp_result <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                    end
                end
                INIT: begin
                    counter <= 0;
                    temp_result <= 0;
                    state <= CHECK;
                end
                CHECK: begin
                    if (counter >= R) begin
                        state <= DONE;
                    end else begin
                        if (counter >= L && is_valid(counter)) begin
                            temp_result <= (temp_result + 1) % MOD;
                        end
                        state <= INCREMENT;
                    end
                end
                INCREMENT: begin
                    counter <= counter + 1;
                    state <= CHECK;
                end
                DONE: begin
                    result <= temp_result;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule