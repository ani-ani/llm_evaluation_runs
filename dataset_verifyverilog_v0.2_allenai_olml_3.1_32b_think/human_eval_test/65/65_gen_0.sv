module circular_shift (
    input clk,
    input rst_n,
    input start,
    input [31:0] x,
    input [7:0] shift,
    output reg [31:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam EXTRACT = 2'b01;
    localparam SHIFT = 2'b10;
    localparam RECONSTRUCT = 2'b11;

    reg [1:0] state;
    reg [3:0] digits [0:9];
    reg [3:0] res_digits [0:9];
    reg [7:0] digit_count;
    reg [7:0] shift_idx;
    reg [31:0] temp_x;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            temp_x <= 0;
            digit_count <=0;
            shift_idx <=0;
            digits[0] <=0; digits[1] <=0; digits[2] <=0; digits[3] <=0;
            digits[4] <=0; digits[5] <=0; digits[6] <=0; digits[7] <=0;
            digits[8] <=0; digits[9] <=0;
            res_digits[0] <=0; res_digits[1] <=0; res_digits[2] <=0; res_digits[3] <=0;
            res_digits[4] <=0; res_digits[5] <=0; res_digits[6] <=0; res_digits[7] <=0;
            res_digits[8] <=0; res_digits[9] <=0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= EXTRACT;
                        temp_x <= x;
                        digit_count <=0;
                        shift_idx <=0;
                        digits[0] <=0; digits[1] <=0; digits[2] <=0; digits[3] <=0;
                        digits[4] <=0; digits[5] <=0; digits[6] <=0; digits[7] <=0;
                        digits[8] <=0; digits[9] <=0;
                        res_digits[0] <=0; res_digits[1] <=0; res_digits[2] <=0; res_digits[3] <=0;
                        res_digits[4] <=0; res_digits[5] <=0; res_digits[6] <=0; res_digits[7] <=0;
                        res_digits[8] <=0; res_digits[9] <=0;
                    end
                end

                EXTRACT: begin
                    if (temp_x == 0) begin
                        if (digit_count == 0) begin
                            digit_count <= 1;
                            digits[0] <= 0;
                            shift_idx <=0;
                            state <= SHIFT;
                        end else begin
                            state <= SHIFT;
                            shift_idx <=0;
                        end
                    end else begin
                        if (digit_count <10) begin
                            digits[digit_count] <= temp_x %10;
                            temp_x <= temp_x /10;
                            digit_count <= digit_count +1;
                        end else begin
                            state <= SHIFT;
                            shift_idx <=0;
                        end
                    end
                end

                SHIFT: begin
                    if (shift_idx < digit_count) begin
                        if (shift >= digit_count) begin
                            res_digits[shift_idx] <= digits[digit_count - 1 - shift_idx];
                        end else begin
                            res_digits[shift_idx] <= digits[ (shift_idx + (shift % digit_count)) % digit_count ];
                        end
                        shift_idx <= shift_idx +1;
                    end else begin
                        state <= RECONSTRUCT;
                        shift_idx <=0;
                        result <=0;
                    end
                end

                RECONSTRUCT: begin
                    if (shift_idx < digit_count) begin
                        result <= result *10 + res_digits[shift_idx];
                        shift_idx <= shift_idx +1;
                    end else begin
                        state <= IDLE;
                        done <= 1;
                    end
                end
            endcase
        end
    end
endmodule