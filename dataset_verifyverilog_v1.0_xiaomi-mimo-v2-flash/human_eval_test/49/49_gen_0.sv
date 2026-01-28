module modular_exp_2n (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] p,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SQUARING = 3'd2;
    localparam [2:0] SQUARING_WAIT = 3'd3;
    localparam [2:0] MULTIPLY = 3'd4;
    localparam [2:0] MULTIPLY_WAIT = 3'd5;
    localparam [2:0] BIT_SHIFT = 3'd6;
    localparam [2:0] FINISH = 3'd7;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] n_reg, p_reg, bit_counter;
    reg [15:0] current_result;
    reg [15:0] operand_a, operand_b, mul_temp;
    reg mult_start, squaring_done;
    reg [1:0] mult_cycle;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Multiplication result (16-bit result from 16x16 multiplication)
    wire [15:0] mult_result;
    assign mult_result = operand_a[7:0] * operand_b[7:0];

    // Modulo operation: result = dividend % divisor using repeated subtraction
    // Returns 0 if divisor is 0
    wire [15:0] mod_result;
    wire [15:0] dividend;
    wire [7:0] divisor;
    reg [15:0] mod_intermediate;
    
    // Use combinational logic for modulo
    function [15:0] compute_mod;
        input [15:0] dividend_in;
        input [7:0] divisor_in;
        reg [15:0] temp;
        begin
            if (divisor_in == 8'd0) begin
                compute_mod = 16'd0;
            end else begin
                temp = dividend_in;
                while (temp >= divisor_in) begin
                    temp = temp - divisor_in;
                end
                compute_mod = temp;
            end
        end
    endfunction

    // FSM next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = SQUARING;
            SQUARING: next_state = SQUARING_WAIT;
            SQUARING_WAIT: next_state = (mult_cycle == 2'd2) ? BIT_SHIFT : SQUARING_WAIT;
            BIT_SHIFT: begin
                if (bit_counter == 8'd0) next_state = FINISH;
                else if (n_reg[0]) next_state = MULTIPLY;
                else next_state = SQUARING;
            end
            MULTIPLY: next_state = MULTIPLY_WAIT;
            MULTIPLY_WAIT: next_state = (mult_cycle == 2'd2) ? SQUARING : MULTIPLY_WAIT;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 8'd0;
            p_reg <= 8'd0;
            bit_counter <= 8'd0;
            current_result <= 16'd0;
            operand_a <= 16'd0;
            operand_b <= 16'd0;
            mult_cycle <= 2'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    cycle_count <= 8'd0;
                end

                LOAD: begin
                    n_reg <= n;
                    p_reg <= p;
                    bit_counter <= 8'd8;
                    // Initial result = 1 mod p
                    if (p == 8'd0) begin
                        current_result <= 16'd0;
                    end else begin
                        current_result <= 16'd1 % p;
                    end
                    mult_cycle <= 2'd0;
                end

                SQUARING: begin
                    // Start squaring: result = (current_result * current_result) % p
                    operand_a <= current_result;
                    operand_b <= current_result;
                    mult_cycle <= 2'd1;
                end

                SQUARING_WAIT: begin
                    if (mult_cycle == 2'd1) begin
                        mul_temp <= mult_result;
                        mult_cycle <= 2'd2;
                    end else if (mult_cycle == 2'd2) begin
                        // Compute modulo
                        current_result <= compute_mod(mul_temp, p_reg);
                    end
                end

                BIT_SHIFT: begin
                    // Right shift n_reg to check next bit
                    n_reg <= n_reg >> 1;
                    bit_counter <= bit_counter - 8'd1;
                end

                MULTIPLY: begin
                    // Multiply by 2: result = (current_result * 2) % p
                    operand_a <= current_result;
                    operand_b <= 16'd2;
                    mult_cycle <= 2'd1;
                end

                MULTIPLY_WAIT: begin
                    if (mult_cycle == 2'd1) begin
                        mul_temp <= mult_result;
                        mult_cycle <= 2'd2;
                    end else if (mult_cycle == 2'd2) begin
                        current_result <= compute_mod(mul_temp, p_reg);
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= current_result;
                end
            endcase

            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= IDLE;
                done <= 1'b1;
                result <= 16'd0;
            end
        end
    end

endmodule