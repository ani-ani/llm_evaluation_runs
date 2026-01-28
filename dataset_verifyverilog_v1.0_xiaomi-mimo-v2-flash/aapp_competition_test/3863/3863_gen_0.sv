module count_distinct_cyclic_palindromes (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] N_in,
    input wire [31:0] K_in,
    input wire [31:0] MOD_in,
    output reg [63:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FIND_DIVISORS_START = 4'd1;
    localparam [3:0] FIND_DIVISORS_LOOP = 4'd2;
    localparam [3:0] COMPUTE_F_START = 4'd3;
    localparam [3:0] COMPUTE_F_EXP = 4'd4;
    localparam [3:0] CLEAN_F_START = 4'd5;
    localparam [3:0] CLEAN_F_INNER = 4'd6;
    localparam [3:0] SUM_START = 4'd7;
    localparam [3:0] SUM_LOOP = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    // Module constants
    localparam [15:0] MAX_DIVISORS = 16'd256;
    localparam [7:0] MAX_EXP_CYCLES = 8'd32;
    localparam [7:0] MAX_INNER_CYCLES = 8'd32;
    localparam [63:0] MOD = 64'd1000000007;

    // Internal registers
    reg [3:0] state, next_state;
    reg [31:0] N_reg, K_reg;
    reg [15:0] div_count;
    reg [15:0] clean_idx;
    reg [15:0] outer_idx;
    reg [15:0] inner_idx;
    reg [7:0] exp_cycles;
    reg [7:0] inner_cycles;
    reg [63:0] temp_result;
    reg [63:0] partial_sum;
    reg [63:0] divisor_val;
    reg [63:0] exponent_val;
    reg [63:0] base_val;
    reg [63:0] exp_result;
    reg [63:0] f_clean_reg;
    reg [63:0] f_reg;
    reg [63:0] sum_reg;
    reg [63:0] divisor_sq;  // For sqrt computation
    reg is_odd;
    reg [3:0] loop_counter;

    // Arrays - using unpacked arrays for synthesis compatibility
    reg [15:0] divisors [0:255];  // Store divisors
    reg [63:0] f_values [0:255];  // f(d) values
    reg [63:0] f_clean_values [0:255];  // f_clean(d) values

    // Helper function: modular multiplication with 64-bit intermediate
    function automatic [63:0] mod_mult(input [63:0] a, input [63:0] b);
        reg [127:0] temp;
        begin
            temp = a * b;
            mod_mult = temp % MOD;
        end
    endfunction

    // Helper function: modular addition with wrap
    function automatic [63:0] mod_add(input [63:0] a, input [63:0] b);
        reg [63:0] sum;
        begin
            sum = a + b;
            if (sum >= MOD)
                mod_add = sum - MOD;
            else
                mod_add = sum;
        end
    endfunction

    // Helper function: modular subtraction
    function automatic [63:0] mod_sub(input [63:0] a, input [63:0] b);
        reg [63:0] diff;
        begin
            if (a >= b)
                diff = a - b;
            else
                diff = MOD + a - b;
            mod_sub = diff;
        end
    endfunction

    // Helper function: modular exponentiation (binary method)
    function automatic [63:0] mod_pow(input [63:0] base, input [31:0] exp);
        reg [63:0] result;
        reg [31:0] e;
        reg [63:0] b;
        begin
            result = 64'd1;
            b = base % MOD;
            e = exp;
            while (e > 0) begin
                if (e[0])
                    result = mod_mult(result, b);
                b = mod_mult(b, b);
                e = e >> 1;
            end
            mod_pow = result;
        end
    endfunction

    // Combinational logic for ceil division
    wire [31:0] ceil_div_2;
    assign ceil_div_2 = (divisor_val[0]) ? ((divisor_val >> 1) + 1) : (divisor_val >> 1);

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            N_reg <= 32'd0;
            K_reg <= 32'd0;
            div_count <= 16'd0;
            clean_idx <= 16'd0;
            outer_idx <= 16'd0;
            inner_idx <= 16'd0;
            exp_cycles <= 8'd0;
            inner_cycles <= 8'd0;
            temp_result <= 64'd0;
            partial_sum <= 64'd0;
            divisor_val <= 64'd0;
            exponent_val <= 64'd0;
            base_val <= 64'd0;
            exp_result <= 64'd0;
            f_clean_reg <= 64'd0;
            f_reg <= 64'd0;
            sum_reg <= 64'd0;
            divisor_sq <= 64'd0;
            result <= 64'd0;
            done <= 1'b0;
            valid <= 1'b0;
            is_odd <= 1'b0;
            loop_counter <= 4'd0;
            // Initialize arrays to 0
            for (integer i = 0; i < 256; i = i + 1) begin
                divisors[i] <= 16'd0;
                f_values[i] <= 64'd0;
                f_clean_values[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        N_reg <= N_in;
                        K_reg <= K_in;
                        state <= FIND_DIVISORS_START;
                    end
                end

                FIND_DIVISORS_START: begin
                    div_count <= 16'd0;
                    divisor_sq <= 64'd1;
                    state <= FIND_DIVISORS_LOOP;
                end

                FIND_DIVISORS_LOOP: begin
                    if (divisor_sq * divisor_sq > N_reg) begin
                        // Done finding divisors
                        state <= COMPUTE_F_START;
                    end else begin
                        if ((N_reg % divisor_sq) == 0) begin
                            // Add divisor
                            if (div_count < MAX_DIVISORS) begin
                                divisors[div_count] <= divisor_sq[15:0];
                                div_count <= div_count + 16'd1;
                            end
                            // Add complement if different
                            reg [31:0] complement;
                            complement = N_reg / divisor_sq;
                            if (complement != divisor_sq) begin
                                if (div_count < MAX_DIVISORS) begin
                                    divisors[div_count] <= complement[15:0];
                                    div_count <= div_count + 16'd1;
                                end
                            end
                        end
                        divisor_sq <= divisor_sq + 64'd1;
                    end
                end

                COMPUTE_F_START: begin
                    outer_idx <= 16'd0;
                    state <= COMPUTE_F_EXP;
                end

                COMPUTE_F_EXP: begin
                    if (outer_idx < div_count) begin
                        // Compute f(d) = K^ceil(d/2) mod MOD
                        divisor_val <= {48'd0, divisors[outer_idx]};
                        if (divisors[outer_idx][0]) begin
                            exponent_val <= {32'd0, (divisors[outer_idx] >> 1) + 16'd1};
                        end else begin
                            exponent_val <= {32'd0, (divisors[outer_idx] >> 1)};
                        end
                        base_val <= {32'd0, K_reg};
                        exp_cycles <= 8'd0;
                        exp_result <= 64'd1;
                        state <= COMPUTE_F_EXP;
                        // Start binary exponentiation
                        loop_counter <= 4'd0;
                    end else begin
                        state <= CLEAN_F_START;
                    end
                end

                // Combinational exponentiation loop state
                CLEAN_F_START: begin
                    clean_idx <= 16'd0;
                    state <= CLEAN_F_INNER;
                end

                CLEAN_F_INNER: begin
                    if (clean_idx < div_count) begin
                        // f_clean(d) = f(d) - sum_{e|d, e<d} f_clean(e)
                        f_clean_reg <= f_values[clean_idx];
                        inner_idx <= 16'd0;
                        inner_cycles <= 8'd0;
                        state <= CLEAN_F_INNER;
                    end else begin
                        state <= SUM_START;
                    end
                end

                SUM_START: begin
                    outer_idx <= 16'd0;
                    sum_reg <= 64'd0;
                    state <= SUM_LOOP;
                end

                SUM_LOOP: begin
                    if (outer_idx < div_count) begin
                        divisor_val <= {48'd0, divisors[outer_idx]};
                        is_odd <= divisors[outer_idx][0];
                        if (divisors[outer_idx][0]) begin
                            // odd: d * f_clean(d)
                            temp_result <= mod_mult(
                                {48'd0, divisors[outer_idx]},
                                f_clean_values[outer_idx]
                            );
                        end else begin
                            // even: d/2 * f_clean(d)
                            temp_result <= mod_mult(
                                {48'd0, (divisors[outer_idx] >> 1)},
                                f_clean_values[outer_idx]
                            );
                        end
                        sum_reg <= mod_add(sum_reg, temp_result);
                        outer_idx <= outer_idx + 16'd1;
                    end else begin
                        result <= sum_reg;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational exponentiation logic
    always @(*) begin
        case (state)
            COMPUTE_F_EXP: begin
                if (exp_cycles < MAX_EXP_CYCLES && outer_idx < div_count) begin
                    // Binary exponentiation step
                    reg [63:0] new_result;
                    reg [63:0] new_base;
                    new_result = exp_result;
                    new_base = base_val;
                    
                    // Process bits from MSB to LSB
                    reg [31:0] bit_pos;
                    bit_pos = 31 - exp_cycles;
                    
                    if (bit_pos < 32 && exponent_val[bit_pos]) begin
                        new_result = mod_mult(new_result, new_base);
                    end
                    if (bit_pos > 0) begin
                        new_base = mod_mult(new_base, new_base);
                    end
                    
                    // Update registers
                    temp_result = new_result;
                    base_val = new_base;
                    exp_cycles = exp_cycles + 8'd1;
                end else if (outer_idx < div_count) begin
                    // Store result and move to next divisor
                    f_values[outer_idx] = temp_result;
                    outer_idx = outer_idx + 16'd1;
                    exp_cycles = 8'd0;
                end
            end

            CLEAN_F_INNER: begin
                if (inner_idx < clean_idx && inner_cycles < MAX_INNER_CYCLES) begin
                    // Check if divisors[inner_idx] divides divisors[clean_idx]
                    if (divisors[clean_idx] % divisors[inner_idx] == 0) begin
                        f_clean_reg = mod_sub(f_clean_reg, f_clean_values[inner_idx]);
                    end
                    inner_idx = inner_idx + 16'd1;
                    inner_cycles = inner_cycles + 8'd1;
                end else if (clean_idx < div_count) begin
                    // Store cleaned value
                    f_clean_values[clean_idx] = f_clean_reg;
                    clean_idx = clean_idx + 16'd1;
                end
            end

            default: begin
                // No combinational logic
            end
        endcase
    end

endmodule