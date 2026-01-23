module babylonian_sqrt (
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    output reg [31:0] sqrt_result,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        INIT,
        ITERATE,
        DONE
    } state_t;

    state_t current_state, next_state;
    reg [31:0] g; // Current guess
    reg [31:0] n; // number / g
    reg [31:0] sum; // g + n
    reg [4:0] iteration_count; // 16 iterations

    // Division state machine
    typedef enum logic [1:0] {
        DIV_IDLE,
        DIV_COMPUTE
    } div_state_t;

    div_state_t div_current_state, div_next_state;
    reg [31:0] dividend, divisor;
    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [4:0] div_bit_count;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            sqrt_result <= 32'b0;
            iteration_count <= 5'b0;
        end else begin
            current_state <= next_state;
            done <= (current_state == DONE);
            if (current_state == DONE) begin
                sqrt_result <= g;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = ITERATE;
            end
            ITERATE: begin
                if (iteration_count == 15) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Initial guess
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            g <= 32'b0;
        end else if (current_state == INIT) begin
            if (number == 0) begin
                g <= 0;
                next_state = DONE;
            end else begin
                g <= number >> 1; // Initial guess = number / 2
            end
        end
    end

    // Division state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_current_state <= DIV_IDLE;
            quotient <= 32'b0;
            remainder <= 32'b0;
            div_bit_count <= 5'b0;
        end else begin
            div_current_state <= div_next_state;
            case (div_current_state)
                DIV_IDLE: begin
                    // Do nothing
                end
                DIV_COMPUTE: begin
                    if (div_bit_count < 32) begin
                        // Shift remainder and quotient
                        remainder <= {remainder[30:0], dividend[31]};
                        quotient <= {quotient[30:0], dividend[31]};
                        dividend <= {dividend[30:0], 1'b0};
                        
                        // Subtract if possible
                        if (remainder >= divisor) begin
                            remainder <= remainder - divisor;
                            quotient[0] <= 1'b1;
                        end
                        
                        div_bit_count <= div_bit_count + 1;
                    end
                end
            endcase
        end
    end

    // Division next state
    always @(*) begin
        div_next_state = div_current_state;
        case (div_current_state)
            DIV_IDLE: begin
                if (current_state == ITERATE) div_next_state = DIV_COMPUTE;
            end
            DIV_COMPUTE: begin
                if (div_bit_count == 31) div_next_state = DIV_IDLE;
            end
        endcase
    end

    // Iteration logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iteration_count <= 5'b0;
        end else if (current_state == ITERATE && div_current_state == DIV_IDLE) begin
            // Start division
            dividend <= number;
            divisor <= g;
            div_bit_count <= 5'b0;
            quotient <= 32'b0;
            remainder <= 32'b0;
            
            // After division completes
            if (div_current_state == DIV_IDLE && div_bit_count == 32) begin
                n <= quotient; // n = number / g
                sum <= g + n; // sum = g + n
                g <= sum >> 1; // g = sum / 2
                iteration_count <= iteration_count + 1;
            end
        end
    end

endmodule