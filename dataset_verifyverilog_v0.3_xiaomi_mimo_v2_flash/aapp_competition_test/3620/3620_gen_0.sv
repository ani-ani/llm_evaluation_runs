module ProperKColorings (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [15:0] k,
    input [15:0] P,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] START     = 3'd1;
    localparam [2:0] EXP_LOOP  = 3'd2;
    localparam [2:0] MULT_LOOP = 3'd3;
    localparam [2:0] MOD_OP    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;

    // Data path registers
    reg [15:0] T;              // (k-1)^(N-1) mod P
    reg [15:0] k_minus_1;      // k-1
    reg [15:0] final_multiplier; // k or T depending on stage
    reg [31:0] product;        // 32-bit product
    reg [31:0] remainder;      // 32-bit remainder for division
    reg [31:0] divisor_reg;    // 32-bit divisor
    reg [31:0] subtrahend;     // P shifted for binary division

    // Counter registers
    reg [2:0] iteration_count; // For exponentiation loop (max 7)
    reg [4:0] div_counter;     // For division loop (max 32)

    // Control signals
    reg clear_state;
    reg init_exp;
    reg load_mult;
    reg calc_prod;
    reg calc_mod;
    reg final_calc;

    // Sequential state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            T <= 16'd0;
            k_minus_1 <= 16'd0;
            final_multiplier <= 16'd0;
            product <= 32'd0;
            remainder <= 32'd0;
            divisor_reg <= 32'd0;
            subtrahend <= 32'd0;
            iteration_count <= 3'd0;
            div_counter <= 5'd0;
        end else begin
            state <= next_state;

            // Default: preserve values unless explicitly updated
            if (clear_state) begin
                result <= 16'd0;
                done <= 1'b0;
                T <= 16'd0;
                k_minus_1 <= 16'd0;
                final_multiplier <= 16'd0;
                product <= 32'd0;
                remainder <= 32'd0;
                divisor_reg <= 32'd0;
                subtrahend <= 32'd0;
                iteration_count <= 3'd0;
                div_counter <= 5'd0;
            end

            // Operation handlers
            if (init_exp) begin
                T <= 16'd1;
                k_minus_1 <= (k > 16'd1) ? (k - 16'd1) : 16'd0;
                iteration_count <= N - 3'd1; // Loop N-1 times
            end

            if (load_mult) begin
                // Prepare for multiplication: product = T * (k-1)
                product <= T * k_minus_1;
                // Need to divide by P to get remainder
                divisor_reg <= {16'd0, P}; // P is 16-bit, stored in 32-bit
                remainder <= T * k_minus_1;
                subtrahend <= {16'd0, P}; // Initialize for binary division
                div_counter <= 5'd0;
            end

            if (calc_prod) begin
                // Compute T * (k-1)
                product <= T * k_minus_1;
                // Load remainder and divisor for MOD_OP
                remainder <= T * k_minus_1;
                divisor_reg <= {16'd0, P};
                subtrahend <= {16'd0, P};
                div_counter <= 5'd0;
                // Decrement exponentiation loop counter
                if (iteration_count > 0)
                    iteration_count <= iteration_count - 3'd1;
            end

            if (calc_mod) begin
                // Binary division algorithm: subtract P, 2P, 4P...
                // Find the largest shift of P that fits in remainder
                // This loop runs until remainder < P
                if (remainder >= divisor_reg) begin
                    // Try subtracting shifted divisor
                    if (remainder >= (divisor_reg << div_counter)) begin
                        remainder <= remainder - (divisor_reg << div_counter);
                    end
                    div_counter <= div_counter + 5'd1;
                    // If counter exceeds 15 (since P is 16-bit), we're done
                    if (div_counter >= 5'd15) begin
                        // Ensure final subtraction for exact division
                        if (remainder >= divisor_reg) begin
                            remainder <= remainder - divisor_reg;
                        end
                    end
                end
            end

            if (final_calc) begin
                // Compute result = k * T mod P
                product <= {16'd0, k} * T;
                remainder <= {16'd0, k} * T;
                divisor_reg <= {16'd0, P};
                subtrahend <= {16'd0, P};
                div_counter <= 5'd0;
            end

            // Update T after modular reduction
            if ((state == EXP_LOOP) && (next_state == EXP_LOOP)) begin
                // Check if we need to reduce modulo P
                if (remainder < divisor_reg) begin
                    T <= remainder[15:0];
                end
            end

            // Update result after final modular reduction
            if ((state == MOD_OP) && (next_state == DONE)) begin
                // Final remainder is the result
                result <= remainder[15:0];
                done <= 1'b1;
            end else if (state == DONE) begin
                done <= 1'b1; // Hold done high in DONE state
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        clear_state = 1'b0;
        init_exp = 1'b0;
        load_mult = 1'b0;
        calc_prod = 1'b0;
        calc_mod = 1'b0;
        final_calc = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    clear_state = 1'b1;
                    next_state = START;
                end
            end

            START: begin
                // Initialize exponentiation loop
                init_exp = 1'b1;
                if (N == 3'd1) begin
                    // N=1, T = (k-1)^0 = 1, skip loop
                    next_state = FINAL_SETUP;
                end else begin
                    next_state = EXP_LOOP;
                end
            end

            EXP_LOOP: begin
                // Perform multiplication and modulo for (k-1)^(N-1)
                if (remainder < divisor_reg) begin
                    // Modulo complete
                    if (iteration_count == 3'd0) begin
                        // Exponentiation done
                        next_state = FINAL_SETUP;
                    end else begin
                        // Continue loop
                        next_state = EXP_LOOP;
                        calc_prod = 1'b1;
                    end
                end else begin
                    // Need more modulo operations
                    calc_mod = 1'b1;
                end
            end

            FINAL_SETUP: begin
                // Prepare for final calculation: result = k * T mod P
                // Update T with current remainder if needed
                if (remainder < divisor_reg) begin
                    T <= remainder[15:0];
                end
                final_calc = 1'b1;
                next_state = FINAL_MOD;
            end

            FINAL_MOD: begin
                // Perform modulo for k * T
                if (remainder < divisor_reg) begin
                    // Modulo complete
                    next_state = DONE;
                end else begin
                    // Need more modulo operations
                    calc_mod = 1'b1;
                end
            end

            DONE: begin
                // Hold done signal high
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