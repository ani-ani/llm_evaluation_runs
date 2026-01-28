module plaque_counter(
    input clk,
    input rst_n,
    input start,
    input [9:0] n_in,
    input [9:0] k_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_CYCLES = 32'd1000;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_POWER1 = 3'd1;
    localparam [2:0] COMPUTE_POWER2 = 3'd2;
    localparam [2:0] MULTIPLY = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] power1_result;
    reg [31:0] power2_result;
    reg [31:0] temp_result;
    reg [9:0] cycle_count;
    reg [9:0] n_reg, k_reg;
    reg [9:0] exponent1, exponent2;
    reg [31:0] base1, base2;
    reg [31:0] current_power;
    reg [9:0] exp_counter;

    // Modular exponentiation function
    function [31:0] mod_exp;
        input [31:0] base;
        input [9:0] exponent;
        reg [31:0] result;
        reg [31:0] current;
        integer i;
        begin
            result = 32'd1;
            current = base % MOD;
            for (i = 0; i < exponent; i = i + 1) begin
                result = (result * current) % MOD;
            end
            mod_exp = result;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            power1_result <= 32'd0;
            power2_result <= 32'd0;
            temp_result <= 32'd0;
            n_reg <= 10'd0;
            k_reg <= 10'd0;
            exponent1 <= 10'd0;
            exponent2 <= 10'd0;
            base1 <= 32'd0;
            base2 <= 32'd0;
            current_power <= 32'd0;
            exp_counter <= 10'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        next_state <= COMPUTE_POWER1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_POWER1: begin
                    // Compute k^(k-1) mod MOD
                    if (k_reg > 10'd0 && k_reg <= n_reg) begin
                        exponent1 <= k_reg - 10'd1;
                        base1 <= k_reg;
                        power1_result <= mod_exp(base1, exponent1);
                    end else if (k_reg == 10'd1) begin
                        power1_result <= 32'd1; // 1^0 = 1
                    end else begin
                        power1_result <= 32'd0; // Invalid case
                    end
                    next_state <= COMPUTE_POWER2;
                end

                COMPUTE_POWER2: begin
                    // Compute (n-k)^(n-k) mod MOD
                    if (k_reg > 10'd0 && k_reg <= n_reg) begin
                        exponent2 <= n_reg - k_reg;
                        base2 <= n_reg - k_reg;
                        power2_result <= mod_exp(base2, exponent2);
                    end else if (k_reg == 10'd1) begin
                        exponent2 <= n_reg - 10'd1;
                        base2 <= n_reg - 10'd1;
                        power2_result <= mod_exp(base2, exponent2);
                    end else begin
                        power2_result <= 32'd0; // Invalid case
                    end
                    next_state <= MULTIPLY;
                end

                MULTIPLY: begin
                    // Multiply the two results
                    temp_result <= (power1_result * power2_result) % MOD;
                    next_state <= FINISH;
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 10'd0;
        end
    end

endmodule