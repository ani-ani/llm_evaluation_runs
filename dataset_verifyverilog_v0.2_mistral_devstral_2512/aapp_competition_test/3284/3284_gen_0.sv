module coprime_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    input [7:0] d,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALC_GCD,
        CHECK_GCD,
        NEXT_PAIR,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] x_reg, y_reg;
    reg [7:0] gcd_a, gcd_b, gcd_temp;
    reg [7:0] gcd_result;
    reg gcd_done;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 0;
            done <= 0;
            x_reg <= 0;
            y_reg <= 0;
            gcd_a <= 0;
            gcd_b <= 0;
            gcd_temp <= 0;
            gcd_result <= 0;
            gcd_done <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        x_reg <= a;
                        y_reg <= c;
                        result <= 0;
                        done <= 0;
                    end
                end

                CALC_GCD: begin
                    // Initialize GCD computation
                    if (gcd_done) begin
                        gcd_a <= x_reg;
                        gcd_b <= y_reg;
                        gcd_done <= 0;
                    end else begin
                        // Euclidean algorithm step
                        if (gcd_b != 0) begin
                            gcd_temp <= gcd_b;
                            gcd_b <= gcd_a % gcd_b;
                            gcd_a <= gcd_temp;
                        end else begin
                            gcd_result <= gcd_a;
                            gcd_done <= 1;
                        end
                    end
                end

                CHECK_GCD: begin
                    if (gcd_result == 1) begin
                        result <= result + 1;
                    end
                    gcd_done <= 0;
                end

                NEXT_PAIR: begin
                    if (y_reg < d) begin
                        y_reg <= y_reg + 1;
                    end else begin
                        y_reg <= c;
                        if (x_reg < b) begin
                            x_reg <= x_reg + 1;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                end

                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_GCD;
                end
            end

            CALC_GCD: begin
                if (gcd_done) begin
                    next_state = CHECK_GCD;
                end
            end

            CHECK_GCD: begin
                next_state = NEXT_PAIR;
            end

            NEXT_PAIR: begin
                if (x_reg == b && y_reg == d) begin
                    next_state = DONE;
                end else begin
                    next_state = CALC_GCD;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule