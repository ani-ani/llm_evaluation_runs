module exponial_mod(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    input [15:0] m,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CALC_BASE,
        RECURSE,
        POWER,
        DONE
    } state_t;

    // State registers
    state_t state, next_state;

    // Data registers
    reg [15:0] current_n;
    reg [15:0] current_m;
    reg [15:0] exp_result;
    reg [15:0] power_base;
    reg [15:0] power_exp;
    reg [15:0] power_result;
    reg [15:0] counter;
    reg [15:0] depth;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'b0;
            current_n <= 16'b0;
            current_m <= 16'b0;
            exp_result <= 16'b0;
            power_base <= 16'b0;
            power_exp <= 16'b0;
            power_result <= 16'b0;
            counter <= 16'b0;
            depth <= 16'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_BASE;
                    current_n = n;
                    current_m = m;
                    depth = 0;
                end
            end
            CALC_BASE: begin
                if (current_n == 1) begin
                    next_state = DONE;
                    result = 1 % current_m;
                end else begin
                    next_state = RECURSE;
                end
            end
            RECURSE: begin
                if (exp_result != 0) begin
                    next_state = POWER;
                    power_base = current_n;
                    power_exp = exp_result;
                    power_result = 1;
                    counter = 0;
                end
            end
            POWER: begin
                if (power_exp == 0) begin
                    next_state = DONE;
                    result = power_result;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (state)
                CALC_BASE: begin
                    if (current_n > 1) begin
                        current_n <= current_n - 1;
                        depth <= depth + 1;
                    end
                end
                RECURSE: begin
                    if (current_n == 1) begin
                        exp_result <= 1 % current_m;
                    end
                end
                POWER: begin
                    if (power_exp > 0) begin
                        if (power_exp[0]) begin
                            power_result <= (power_result * power_base) % current_m;
                        end
                        power_base <= (power_base * power_base) % current_m;
                        power_exp <= power_exp >> 1;
                        counter <= counter + 1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule