module count_up_to(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    output reg [143:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PREPARE_CHECK = 4'd1;
    localparam [3:0] DIV_LOOP = 4'd2;
    localparam [3:0] CHECK_DIVISIBILITY = 4'd3;
    localparam [3:0] CHECK_COMPLETE = 4'd4;
    localparam [3:0] UPDATE_RESULT = 4'd5;
    localparam [3:0] INCREMENT = 4'd6;
    localparam [3:0] DONE = 4'd7;

    // Register declarations
    reg [3:0] state;
    reg [5:0] current_number;
    reg [5:0] divisor;
    reg [5:0] remainder;
    reg [3:0] prime_count;
    reg [143:0] result_reg;
    reg is_prime;
    reg [7:0] i;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_number <= 6'd0;
            divisor <= 6'd0;
            remainder <= 6'd0;
            prime_count <= 4'd0;
            result_reg <= 144'd0;
            is_prime <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < 18; i = i + 1) begin
                result_reg[(i*8)+7:i*8] <= 8'd255;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PREPARE_CHECK;
                        current_number <= 6'd2;
                        prime_count <= 4'd0;
                        for (i = 0; i < 18; i = i + 1) begin
                            result_reg[(i*8)+7:i*8] <= 8'd255;
                        end
                    end
                end

                PREPARE_CHECK: begin
                    divisor <= 6'd2;
                    is_prime <= 1'b1;
                    state <= DIV_LOOP;
                end

                DIV_LOOP: begin
                    if (divisor >= current_number) begin
                        state <= CHECK_COMPLETE;
                    end else begin
                        state <= CHECK_DIVISIBILITY;
                    end
                end

                CHECK_DIVISIBILITY: begin
                    remainder <= current_number;
                    while (remainder >= divisor) begin
                        remainder <= remainder - divisor;
                    end
                    if (remainder == 6'd0) begin
                        is_prime <= 1'b0;
                        state <= INCREMENT;
                    end else begin
                        divisor <= divisor + 6'd1;
                        state <= DIV_LOOP;
                    end
                end

                CHECK_COMPLETE: begin
                    if (is_prime) begin
                        state <= UPDATE_RESULT;
                    end else begin
                        state <= INCREMENT;
                    end
                end

                UPDATE_RESULT: begin
                    result_reg[(prime_count*8)+7:prime_count*8] <= current_number;
                    prime_count <= prime_count + 4'd1;
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    current_number <= current_number + 6'd1;
                    if (current_number >= n) begin
                        state <= DONE;
                    end else begin
                        state <= PREPARE_CHECK;
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