module change_base(
    input clk,
    input rst_n,
    input start,
    input [7:0] x,
    input [3:0] base,
    output reg [31:0] result,
    output reg [3:0] num_digits,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        DONE
    } state_t;

    state_t state;
    reg [7:0] current_value;
    reg [3:0] digit_count;
    reg [31:0] temp_result;
    reg [3:0] remainder;
    reg [3:0] quotient;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_value <= 8'd0;
            digit_count <= 4'd0;
            temp_result <= 32'd0;
            remainder <= 4'd0;
            quotient <= 4'd0;
            i <= 4'd0;
            result <= 32'd0;
            num_digits <= 4'd0;
            done <= 1'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE;
                        current_value <= x;
                        digit_count <= 4'd0;
                        temp_result <= 32'd0;
                        done <= 1'd0;
                    end
                end
                COMPUTE: begin
                    if (current_value == 8'd0) begin
                        state <= DONE;
                    end else begin
                        // Division by base
                        quotient = current_value / base;
                        remainder = current_value % base;
                        
                        // Store remainder as digit
                        temp_result[4*digit_count +: 4] = remainder;
                        digit_count = digit_count + 1;
                        
                        current_value = quotient;
                    end
                end
                DONE: begin
                    // Reverse digits for output
                    for (i = 0; i < digit_count; i = i + 1) begin
                        result[4*i +: 4] = temp_result[4*(digit_count - 1 - i) +: 4];
                    end
                    num_digits = digit_count;
                    done <= 1'd1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule