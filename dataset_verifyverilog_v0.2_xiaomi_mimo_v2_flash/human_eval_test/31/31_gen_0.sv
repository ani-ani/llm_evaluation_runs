module is_prime(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg is_prime_result,
    output reg done
);

    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_EVEN = 3'b010;
    localparam ITERATE = 3'b011;
    localparam COMPUTE_SQRT = 3'b100;
    localparam DIVIDE = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state, next_state;
    reg [15:0] n_reg;
    reg [15:0] d;
    reg [15:0] d_times_d;
    reg [15:0] quotient;
    reg [7:0] div_cnt;
    reg found_divisor;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: begin
                if (n_reg <= 1 || n_reg == 2) next_state = DONE;
                else next_state = CHECK_EVEN;
            end
            CHECK_EVEN: begin
                if (n_reg[0] == 0) next_state = DONE;
                else next_state = ITERATE;
            end
            ITERATE: next_state = COMPUTE_SQRT;
            COMPUTE_SQRT: next_state = DIVIDE;
            DIVIDE: begin
                if (d_times_d > n_reg) next_state = DONE;
                else if (div_cnt < 16 && quotient >= d) next_state = DIVIDE;
                else if (div_cnt < 16 && quotient < d) begin
                    if (quotient == 0) next_state = DONE;
                    else next_state = ITERATE;
                end
                else next_state = ITERATE;
            end
            DONE: next_state = start ? INIT : DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_prime_result <= 1'b0;
            done <= 1'b0;
            n_reg <= 16'b0;
            d <= 16'b0;
            d_times_d <= 16'b0;
            quotient <= 16'b0;
            div_cnt <= 8'b0;
            found_divisor <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found_divisor <= 1'b0;
                    if (start) n_reg <= n;
                end
                INIT: begin
                    // Nothing needed here, logic is in next_state
                    // n_reg is stable
                end
                CHECK_EVEN: begin
                    d <= 3; // Start checking from 3
                end
                ITERATE: begin
                    d <= d + 2; // Next odd number
                    div_cnt <= 8'b0;
                    found_divisor <= 1'b0;
                end
                COMPUTE_SQRT: begin
                    d_times_d <= d * d;
                    quotient <= n_reg; // Initialize division
                end
                DIVIDE: begin
                    if (d_times_d <= n_reg) begin
                        if (quotient >= d) begin
                            quotient <= quotient - d;
                            div_cnt <= div_cnt + 1;
                        end else if (div_cnt < 16) begin
                            if (quotient == 0) found_divisor <= 1'b1;
                            div_cnt <= 16;
                        end
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    if (n_reg <= 1) is_prime_result <= 1'b0;
                    else if (n_reg == 2) is_prime_result <= 1'b1;
                    else if (n_reg[0] == 0) is_prime_result <= 1'b0;
                    else if (found_divisor) is_prime_result <= 1'b0;
                    else is_prime_result <= 1'b1;
                end
            endcase
        end
    end
endmodule