module ChocolateBarAreaCalculation (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [31:0] n,
    input wire [31:0] m,
    input wire [31:0] k,
    output reg [31:0] result,
    output reg valid_out
);

    // --- Parameters and State Definitions ---
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] CHECK       = 4'd1;
    localparam [3:0] SETUP_VAL1  = 4'd2;
    localparam [3:0] CALC_VAL1   = 4'd3;
    localparam [3:0] SETUP_VAL2  = 4'd4;
    localparam [3:0] CALC_VAL2   = 4'd5;
    localparam [3:0] COMPARE     = 4'd6;
    localparam [3:0] DONE        = 4'd7;
    localparam [3:0] SATURATE    = 4'd8;

    // Internal Registers
    reg [3:0] state, next_state;
    reg [31:0] n_reg, m_reg, k_reg;
    reg [63:0] val1_reg, val2_reg; // Store 64-bit intermediate results
    reg [63:0] temp_val;
    reg [31:0] temp_n, temp_m, temp_k;
    reg [31:0] quotient, remainder;
    reg [31:0] divisor;
    reg [31:0] loop_counter;
    localparam [31:0] MAX_ITER = 32'd32; // Max bits for division

    // --- FSM Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid_out <= 1'b0;
            n_reg <= 32'd0;
            m_reg <= 32'd0;
            k_reg <= 32'd0;
            val1_reg <= 64'd0;
            val2_reg <= 64'd0;
            temp_val <= 64'd0;
            temp_n <= 32'd0;
            temp_m <= 32'd0;
            temp_k <= 32'd0;
            quotient <= 32'd0;
            remainder <= 32'd0;
            divisor <= 32'd0;
            loop_counter <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    if (valid_in) begin
                        n_reg <= n;
                        m_reg <= m;
                        k_reg <= k;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check if k > n + m - 2
                    // Note: subtraction handles underflow naturally in unsigned arithmetic
                    if (k_reg > (n_reg + m_reg - 32'd2)) begin
                        // Invalid case
                        state <= DONE;
                        result <= 32'hFFFFFFFF;
                    end else begin
                        state <= SETUP_VAL1;
                    end
                end

                SETUP_VAL1: begin
                    // Prepare for val1 calculation
                    if (k_reg < n_reg) begin
                        // Case 1a: val1 = (n / (k + 1)) * m
                        divisor <= k_reg + 32'd1;
                        temp_n <= n_reg;
                        temp_m <= m_reg;
                        quotient <= 32'd0;
                        remainder <= 32'd0;
                        loop_counter <= 32'd0;
                        state <= CALC_VAL1;
                    end else begin
                        // Case 1b: val1 = m / (k - n + 2)
                        divisor <= k_reg - n_reg + 32'd2;
                        temp_n <= m_reg; // Numerator is m
                        temp_m <= 32'd0; // Not used in this branch
                        quotient <= 32'd0;
                        remainder <= 32'd0;
                        loop_counter <= 32'd0;
                        state <= CALC_VAL1;
                    end
                end

                CALC_VAL1: begin
                    // Sequential Integer Division
                    // Shift-subtract algorithm
                    if (loop_counter < MAX_ITER) begin
                        remainder <= remainder << 1;
                        remainder[0] <= temp_n[31];
                        temp_n <= temp_n << 1;

                        if (remainder >= divisor) begin
                            remainder <= remainder - divisor;
                            quotient <= (quotient << 1) | 1'b1;
                        end else begin
                            quotient <= quotient << 1;
                        end
                        loop_counter <= loop_counter + 32'd1;
                    end else begin
                        // Division done
                        if (k_reg < n_reg) begin
                            // Calculate product: quotient * m
                            // 32-bit * 32-bit -> 64-bit
                            val1_reg <= quotient * temp_m;
                            state <= SETUP_VAL2;
                        end else begin
                            // Single division result
                            val1_reg <= {32'd0, quotient};
                            state <= SETUP_VAL2;
                        end
                    end
                end

                SETUP_VAL2: begin
                    // Prepare for val2 calculation
                    if (k_reg < m_reg) begin
                        // Case 2a: val2 = (m / (k + 1)) * n
                        divisor <= k_reg + 32'd1;
                        temp_n <= m_reg;
                        temp_m <= n_reg;
                        quotient <= 32'd0;
                        remainder <= 32'd0;
                        loop_counter <= 32'd0;
                        state <= CALC_VAL2;
                    end else begin
                        // Case 2b: val2 = n / (k - m + 2)
                        divisor <= k_reg - m_reg + 32'd2;
                        temp_n <= n_reg;
                        temp_m <= 32'd0;
                        quotient <= 32'd0;
                        remainder <= 32'd0;
                        loop_counter <= 32'd0;
                        state <= CALC_VAL2;
                    end
                end

                CALC_VAL2: begin
                    // Sequential Integer Division
                    if (loop_counter < MAX_ITER) begin
                        remainder <= remainder << 1;
                        remainder[0] <= temp_n[31];
                        temp_n <= temp_n << 1;

                        if (remainder >= divisor) begin
                            remainder <= remainder - divisor;
                            quotient <= (quotient << 1) | 1'b1;
                        end else begin
                            quotient <= quotient << 1;
                        end
                        loop_counter <= loop_counter + 32'd1;
                    end else begin
                        // Division done
                        if (k_reg < m_reg) begin
                            // Calculate product: quotient * n
                            val2_reg <= quotient * temp_m;
                        end else begin
                            // Single division result
                            val2_reg <= {32'd0, quotient};
                        end
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compare val1 and val2
                    // Check for saturation (overflow > 32-bit)
                    if (val1_reg[63:32] != 0 || val2_reg[63:32] != 0) begin
                        // Result exceeds 32-bit
                        state <= SATURATE;
                    end else begin
                        // Both fit in 32-bit
                        if (val1_reg > val2_reg) begin
                            result <= val1_reg[31:0];
                        end else begin
                            result <= val2_reg[31:0];
                        end
                        state <= DONE;
                    end
                end

                SATURATE: begin
                    // Saturate to 0xFFFFFFFF
                    result <= 32'hFFFFFFFF;
                    state <= DONE;
                end

                DONE: begin
                    valid_out <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule