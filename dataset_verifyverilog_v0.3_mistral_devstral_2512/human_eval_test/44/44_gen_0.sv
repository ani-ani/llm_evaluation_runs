module change_base(
    input clk,
    input rst_n,
    input start,
    input [11:0] x,
    input [2:0] base,
    output reg [127:0] result_str,
    output reg [3:0] str_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] DIVIDE = 2'd1;
    localparam [1:0] REVERSE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [11:0] current_x;
    reg [11:0] quotient;
    reg [2:0] remainder;
    reg [3:0] digit_count;
    reg [3:0] stack_ptr;
    reg [3:0] output_ptr;
    reg [3:0] temp_digits [0:11];
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_x <= 12'd0;
            quotient <= 12'd0;
            remainder <= 3'd0;
            digit_count <= 4'd0;
            stack_ptr <= 4'd0;
            output_ptr <= 4'd0;
            result_str <= 128'd0;
            str_len <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 12; i = i + 1) begin
                temp_digits[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_x <= x;
                        digit_count <= 4'd0;
                        stack_ptr <= 4'd0;
                        output_ptr <= 4'd0;
                        state <= DIVIDE;
                    end
                end

                DIVIDE: begin
                    if (current_x == 12'd0) begin
                        state <= REVERSE;
                    end else begin
                        quotient <= 12'd0;
                        remainder <= current_x[2:0];
                        while (current_x >= base) begin
                            current_x <= current_x - base;
                            quotient <= quotient + 12'd1;
                        end
                        remainder <= current_x[2:0];
                        temp_digits[stack_ptr] <= remainder + 3'd0;
                        stack_ptr <= stack_ptr + 4'd1;
                        current_x <= quotient;
                    end
                end

                REVERSE: begin
                    if (output_ptr < stack_ptr) begin
                        result_str[(127 - (output_ptr * 8)) : (120 - (output_ptr * 8))] <= temp_digits[stack_ptr - 1 - output_ptr];
                        output_ptr <= output_ptr + 4'd1;
                    end else begin
                        str_len <= stack_ptr;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule