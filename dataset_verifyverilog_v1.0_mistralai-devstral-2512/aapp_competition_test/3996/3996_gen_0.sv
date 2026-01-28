module CupsAndKeyProbability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [59:0] a_val,
    input wire a_valid,
    input wire input_done,
    output reg result_valid,
    output reg [31:0] x,
    output reg [31:0] y
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MOD_MINUS_1 = 32'd1000000006;
    localparam [31:0] INV2 = 32'd500000004;
    localparam [31:0] INV3 = 32'd333333336;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ACCUMULATE = 3'd1;
    localparam [2:0] CALC_POW2 = 3'd2;
    localparam [2:0] CALC_RESULT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] prod_mod;
    reg parity;
    reg [31:0] pow2_val;
    reg [31:0] q_val;
    reg [31:0] x_val;
    reg [31:0] y_val;
    reg [31:0] exponent;
    reg [31:0] base;
    reg [31:0] result;
    reg [5:0] exp_counter;
    reg [31:0] temp;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            prod_mod <= 32'd1;
            parity <= 1'b0;
            pow2_val <= 32'd0;
            q_val <= 32'd0;
            x_val <= 32'd0;
            y_val <= 32'd0;
            exponent <= 32'd0;
            base <= 32'd0;
            result <= 32'd0;
            exp_counter <= 6'd0;
            temp <= 32'd0;
            result_valid <= 1'b0;
            x <= 32'd0;
            y <= 32'd0;
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
                    next_state = ACCUMULATE;
                    prod_mod = 32'd1;
                    parity = 1'b0;
                end
            end
            ACCUMULATE: begin
                if (input_done) begin
                    next_state = CALC_POW2;
                    exponent = prod_mod;
                    base = 32'd2;
                    result = 32'd1;
                    exp_counter = 32'd0;
                end
            end
            CALC_POW2: begin
                if (exp_counter >= 32'd30) begin
                    next_state = CALC_RESULT;
                    pow2_val = result;
                end
            end
            CALC_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (start) begin
                    next_state = ACCUMULATE;
                    prod_mod = 32'd1;
                    parity = 1'b0;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Accumulation logic
    always @(posedge clk) begin
        if (state == ACCUMULATE && a_valid && !input_done) begin
            // Compute a_val mod (MOD-1)
            temp = a_val % MOD_MINUS_1;
            // Update product mod (MOD-1)
            prod_mod <= (prod_mod * temp) % MOD_MINUS_1;
            // Update parity (if LSB is 0, number is even)
            parity <= parity | (~a_val[0]);
        end
    end

    // Modular exponentiation (2^exponent mod MOD)
    always @(posedge clk) begin
        if (state == CALC_POW2) begin
            if (exponent[exp_counter]) begin
                result <= (result * base) % MOD;
            end
            base <= (base * base) % MOD;
            exp_counter <= exp_counter + 1'b1;
        end
    end

    // Result calculation
    always @(posedge clk) begin
        if (state == CALC_RESULT) begin
            // Calculate q = 2^(n-1) mod MOD
            q_val <= (pow2_val * INV2) % MOD;
            // Calculate x based on parity
            if (parity) begin
                // n is even: x = (q + 1) * inv3 mod MOD
                x_val <= ((q_val + 32'd1) * INV3) % MOD;
            end else begin
                // n is odd: x = (q - 1) * inv3 mod MOD
                x_val <= ((q_val - 32'd1 + MOD) * INV3) % MOD;
            end
            y_val <= pow2_val;
            result_valid <= 1'b1;
            x <= x_val;
            y <= y_val;
        end else begin
            result_valid <= 1'b0;
        end
    end

endmodule