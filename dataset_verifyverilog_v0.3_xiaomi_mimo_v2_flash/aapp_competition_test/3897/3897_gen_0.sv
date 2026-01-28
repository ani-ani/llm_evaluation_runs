module decomposition_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] exp0, exp1, exp2, exp3, exp4, exp5, exp6, exp7, exp8, exp9, exp10,
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] MOD = 32'd1000000007;
    localparam [3:0] MAX_PRIMES = 4'd11;

    // State encoding
    localparam [2:0] IDLE           = 3'b000;
    localparam [2:0] COMPUTE_BINOM  = 3'b001;
    localparam [2:0] NUMERATOR_LOOP = 3'b010;
    localparam [2:0] MULTIPLY       = 3'b011;
    localparam [2:0] MULTIPLY_INV   = 3'b100;
    localparam [2:0] ACCUMULATE     = 3'b101;
    localparam [2:0] UPDATE         = 3'b110;
    localparam [2:0] DONE           = 3'b111;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] n_reg;
    reg [4:0] exp_reg [0:10];
    reg [31:0] numerator;
    reg [31:0] binom;
    reg [3:0] prime_index;
    reg [3:0] loop_i;

    // Multiplication unit registers
    reg [31:0] mul_a_reg, mul_b_reg;
    reg [31:0] mul_result;
    reg [5:0] mul_count;
    reg mul_start, mul_done;
    reg [31:0] mul_a, mul_b;

    // Inverse factorial lookup table
    wire [31:0] inv_fact [0:7];
    assign inv_fact[0] = 32'd1;
    assign inv_fact[1] = 32'd1;
    assign inv_fact[2] = 32'd500000004;
    assign inv_fact[3] = 32'd166666668;
    assign inv_fact[4] = 32'd41666667;
    assign inv_fact[5] = 32'd808333337;
    assign inv_fact[6] = 32'd201388893;
    assign inv_fact[7] = 32'd35791429;

    // Cycle counter to prevent infinite loops
    reg [31:0] cycle_counter;
    localparam [31:0] MAX_CYCLES = 32'd100000;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            n_reg <= 4'd0;
            numerator <= 32'd0;
            binom <= 32'd0;
            prime_index <= 4'd0;
            loop_i <= 4'd0;
            mul_a_reg <= 32'd0;
            mul_b_reg <= 32'd0;
            mul_result <= 32'd0;
            mul_count <= 6'd0;
            mul_start <= 1'b0;
            mul_done <= 1'b0;
            mul_a <= 32'd0;
            mul_b <= 32'd0;
            cycle_counter <= 32'd0;
            // Initialize exp_reg array
            exp_reg[0] <= 5'd0;
            exp_reg[1] <= 5'd0;
            exp_reg[2] <= 5'd0;
            exp_reg[3] <= 5'd0;
            exp_reg[4] <= 5'd0;
            exp_reg[5] <= 5'd0;
            exp_reg[6] <= 5'd0;
            exp_reg[7] <= 5'd0;
            exp_reg[8] <= 5'd0;
            exp_reg[9] <= 5'd0;
            exp_reg[10] <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 32'd0;
                    if (start) begin
                        n_reg <= n;
                        exp_reg[0] <= exp0;
                        exp_reg[1] <= exp1;
                        exp_reg[2] <= exp2;
                        exp_reg[3] <= exp3;
                        exp_reg[4] <= exp4;
                        exp_reg[5] <= exp5;
                        exp_reg[6] <= exp6;
                        exp_reg[7] <= exp7;
                        exp_reg[8] <= exp8;
                        exp_reg[9] <= exp9;
                        exp_reg[10] <= exp10;
                        result <= 32'd1;
                        prime_index <= 4'd0;
                        state <= COMPUTE_BINOM;
                    end
                end

                COMPUTE_BINOM: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (prime_index < MAX_PRIMES) begin
                        if (exp_reg[prime_index] > 5'd0) begin
                            numerator <= 32'd1;
                            loop_i <= 4'd1;
                            state <= NUMERATOR_LOOP;
                        end else begin
                            prime_index <= prime_index + 4'd1;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                NUMERATOR_LOOP: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (loop_i < n_reg) begin
                        mul_a <= numerator;
                        mul_b <= {27'd0, exp_reg[prime_index]} + {27'd0, loop_i};
                        mul_start <= 1'b1;
                        state <= MULTIPLY;
                    end else begin
                        mul_a <= numerator;
                        mul_b <= inv_fact[n_reg - 4'd1];
                        mul_start <= 1'b1;
                        state <= MULTIPLY_INV;
                    end
                end

                MULTIPLY: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    if (mul_start) mul_start <= 1'b0;
                    if (mul_done) begin
                        numerator <= mul_result;
                        loop_i <= loop_i + 4'd1;
                        state <= NUMERATOR_LOOP;
                        mul_done <= 1'b0;
                    end
                end

                MULTIPLY_INV: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    if (mul_start) mul_start <= 1'b0;
                    if (mul_done) begin
                        binom <= mul_result;
                        state <= ACCUMULATE;
                        mul_done <= 1'b0;
                    end
                end

                ACCUMULATE: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    mul_a <= result;
                    mul_b <= binom;
                    mul_start <= 1'b1;
                    state <= UPDATE;
                end

                UPDATE: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    if (mul_start) mul_start <= 1'b0;
                    if (mul_done) begin
                        result <= mul_result;
                        prime_index <= prime_index + 4'd1;
                        state <= COMPUTE_BINOM;
                        mul_done <= 1'b0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Multiplication unit (32-bit shift-add with modulo)
            if (mul_start) begin
                mul_count <= 6'd32;
                mul_result <= 32'd0;
                mul_b_reg <= mul_b;
                mul_a_reg <= mul_a;
            end else if (mul_count > 6'd0) begin
                // Add if LSB of multiplier is 1
                if (mul_b_reg[0]) begin
                    if (mul_result + mul_a_reg >= MOD)
                        mul_result <= mul_result + mul_a_reg - MOD;
                    else
                        mul_result <= mul_result + mul_a_reg;
                end
                // Double multiplicand
                mul_a_reg <= {mul_a_reg[30:0], 1'b0};
                if (mul_a_reg >= MOD)
                    mul_a_reg <= mul_a_reg - MOD;
                // Shift multiplier
                mul_b_reg <= mul_b_reg >> 1;
                mul_count <= mul_count - 6'd1;
            end else if (mul_count == 6'd0 && (state == MULTIPLY || state == MULTIPLY_INV || state == UPDATE)) begin
                mul_done <= 1'b1;
            end
        end
    end
endmodule