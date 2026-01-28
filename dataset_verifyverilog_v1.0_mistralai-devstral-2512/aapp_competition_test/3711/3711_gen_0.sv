module chocolate_cut(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [31:0] n,
    input wire [31:0] m,
    input wire [31:0] k,
    output reg [31:0] result,
    output reg valid_out
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] CALC_VAL1 = 3'd2;
    localparam [2:0] CALC_VAL2 = 3'd3;
    localparam [2:0] COMPARE   = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    reg [2:0] state, next_state;

    // Internal registers for calculations
    reg [63:0] val1, val2;
    reg [31:0] temp_n, temp_m, temp_k;
    reg [31:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Division helper registers
    reg [63:0] dividend, divisor;
    reg [63:0] quotient, remainder;
    reg [5:0] div_cycle;
    reg div_start;
    reg [63:0] div_result;

    // Multiplication helper registers
    reg [63:0] mult_a, mult_b;
    reg [63:0] mult_result_reg;
    reg [5:0] mult_cycle;
    reg mult_start;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid_out <= 1'b0;
            cycle_count <= 8'd0;
            val1 <= 64'd0;
            val2 <= 64'd0;
            temp_n <= 32'd0;
            temp_m <= 32'd0;
            temp_k <= 32'd0;
            dividend <= 64'd0;
            divisor <= 64'd0;
            quotient <= 64'd0;
            remainder <= 64'd0;
            div_cycle <= 6'd0;
            div_start <= 1'b0;
            div_result <= 64'd0;
            mult_a <= 64'd0;
            mult_b <= 64'd0;
            mult_result_reg <= 64'd0;
            mult_cycle <= 6'd0;
            mult_start <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (valid_in) begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                if (k > n + m - 2) begin
                    next_state = DONE;
                end else begin
                    next_state = CALC_VAL1;
                end
            end

            CALC_VAL1: begin
                if (!div_start && !mult_start) begin
                    next_state = CALC_VAL2;
                end
            end

            CALC_VAL2: begin
                if (!div_start && !mult_start) begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Division logic (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cycle <= 6'd0;
            div_start <= 1'b0;
            quotient <= 64'd0;
            remainder <= 64'd0;
        end else begin
            if (div_start) begin
                if (div_cycle == 0) begin
                    quotient <= 64'd0;
                    remainder <= dividend;
                end else begin
                    remainder <= remainder - divisor;
                    if (remainder[63]) begin
                        remainder <= remainder + divisor;
                        quotient[div_cycle - 1] <= 1'b0;
                    end else begin
                        quotient[div_cycle - 1] <= 1'b1;
                    end
                end
                div_cycle <= div_cycle + 6'd1;
                if (div_cycle == 64) begin
                    div_result <= quotient;
                    div_start <= 1'b0;
                    div_cycle <= 6'd0;
                end
            end
        end
    end

    // Multiplication logic (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_cycle <= 6'd0;
            mult_start <= 1'b0;
            mult_result_reg <= 64'd0;
        end else begin
            if (mult_start) begin
                if (mult_cycle == 0) begin
                    mult_result_reg <= 64'd0;
                end else begin
                    if (mult_b[mult_cycle - 1]) begin
                        mult_result_reg <= mult_result_reg + (mult_a << (mult_cycle - 1));
                    end
                end
                mult_cycle <= mult_cycle + 6'd1;
                if (mult_cycle == 64) begin
                    mult_start <= 1'b0;
                    mult_cycle <= 6'd0;
                end
            end
        end
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialization already done
        end else begin
            case (state)
                CHECK: begin
                    if (k > n + m - 2) begin
                        result <= 32'hFFFFFFFF;
                        valid_out <= 1'b1;
                    end
                end

                CALC_VAL1: begin
                    if (k < n) begin
                        // val1 = (n / (k + 1)) * m
                        dividend <= {32'd0, n};
                        divisor <= {32'd0, k + 32'd1};
                        div_start <= 1'b1;
                        temp_n <= n;
                        temp_m <= m;
                        temp_k <= k;
                    end else begin
                        // val1 = m / (k - n + 2)
                        dividend <= {32'd0, m};
                        divisor <= {32'd0, k - n + 32'd2};
                        div_start <= 1'b1;
                        temp_n <= n;
                        temp_m <= m;
                        temp_k <= k;
                    end
                    if (!div_start && !mult_start) begin
                        mult_a <= div_result;
                        mult_b <= {32'd0, temp_m};
                        mult_start <= 1'b1;
                    end
                    if (!mult_start) begin
                        val1 <= mult_result_reg;
                    end
                end

                CALC_VAL2: begin
                    if (k < m) begin
                        // val2 = (m / (k + 1)) * n
                        dividend <= {32'd0, m};
                        divisor <= {32'd0, k + 32'd1};
                        div_start <= 1'b1;
                        temp_n <= n;
                        temp_m <= m;
                        temp_k <= k;
                    end else begin
                        // val2 = n / (k - m + 2)
                        dividend <= {32'd0, n};
                        divisor <= {32'd0, k - m + 32'd2};
                        div_start <= 1'b1;
                        temp_n <= n;
                        temp_m <= m;
                        temp_k <= k;
                    end
                    if (!div_start && !mult_start) begin
                        mult_a <= div_result;
                        mult_b <= {32'd0, temp_n};
                        mult_start <= 1'b1;
                    end
                    if (!mult_start) begin
                        val2 <= mult_result_reg;
                    end
                end

                COMPARE: begin
                    if (val1 > val2) begin
                        if (val1 > 32'hFFFFFFFF) begin
                            result <= 32'hFFFFFFFF;
                        end else begin
                            result <= val1[31:0];
                        end
                    end else begin
                        if (val2 > 32'hFFFFFFFF) begin
                            result <= 32'hFFFFFFFF;
                        end else begin
                            result <= val2[31:0];
                        end
                    end
                    valid_out <= 1'b1;
                end

                DONE: begin
                    valid_out <= 1'b0;
                end

                default: begin
                    // Do nothing
                end
            endcase
        end
    end

endmodule