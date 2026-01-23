module cups_and_key_solver (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire last_in,
    input wire [63:0] a_in,
    output reg [31:0] result_x,
    output reg [31:0] result_y,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MOD_EXP = 32'd1000000006;
    localparam INV3 = 32'd333333336;
    localparam MOD_BITS = 30;

    // State definitions
    localparam STATE_IDLE = 3'd0;
    localparam STATE_PROCESS_INPUT = 3'd1;
    localparam STATE_CALC_EXP = 3'd2;
    localparam STATE_FINALIZE = 3'd3;
    localparam STATE_DONE = 3'd4;

    // Registers
    reg [2:0] state;
    reg [MOD_BITS-1:0] mod_acc;
    reg parity_flag;
    reg [MOD_BITS-1:0] exp_reg;
    reg [MOD_BITS-1:0] base;
    reg [MOD_BITS-1:0] power;
    reg [MOD_BITS-1:0] res_exp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            mod_acc <= 0;
            parity_flag <= 0;
            done <= 0;
            result_x <= 0;
            result_y <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 0;
                    if (valid_in) begin
                        mod_acc <= a_in[MOD_BITS-1:0] % MOD_EXP;
                        parity_flag <= ~a_in[0];
                        if (last_in) begin
                            exp_reg <= (a_in[MOD_BITS-1:0] % MOD_EXP - 1 + MOD_EXP) % MOD_EXP;
                            state <= STATE_CALC_EXP;
                            base <= 2;
                            power <= (a_in[MOD_BITS-1:0] % MOD_EXP - 1 + MOD_EXP) % MOD_EXP;
                            res_exp <= 1;
                        end else begin
                            state <= STATE_PROCESS_INPUT;
                        end
                    end
                end

                STATE_PROCESS_INPUT: begin
                    if (valid_in) begin
                        // Update parity
                        parity_flag <= parity_flag | (~a_in[0]);

                        // Calculate new mod_acc and store it
                        mod_acc <= (mod_acc * (a_in[MOD_BITS-1:0] % MOD_EXP)) % MOD_EXP;

                        if (last_in) begin
                            // We need exp = (new_mod_acc - 1) % MOD_EXP
                            // Since mod_acc is updated at the end of the cycle, we must calculate the value now.
                            // Calculate (current_mod_acc * (a_in % MOD_EXP)) % MOD_EXP -> val
                            // exp = (val - 1 + MOD_EXP) % MOD_EXP
                            // We can do this inline because we are assigning to 'exp_reg' which is sequential.
                            // We use the math directly:
                            exp_reg <= ((mod_acc * (a_in[MOD_BITS-1:0] % MOD_EXP)) - 1 + MOD_EXP) % MOD_EXP;

                            state <= STATE_CALC_EXP;
                            base <= 2;
                            power <= ((mod_acc * (a_in[MOD_BITS-1:0] % MOD_EXP)) - 1 + MOD_EXP) % MOD_EXP;
                            res_exp <= 1;
                        end
                    end
                end

                STATE_CALC_EXP: begin
                    if (power > 0) begin
                        // Binary exponentiation step
                        if (power[0]) begin
                            // res_exp = res_exp * base
                            res_exp <= (res_exp * base) % MOD;
                        end
                        // base = base * base
                        base <= (base * base) % MOD;
                        // power = power >> 1
                        power <= power >> 1;
                    end else begin
                        // Exponentiation complete, X is in res_exp
                        state <= STATE_FINALIZE;
                    end
                end

                STATE_FINALIZE: begin
                    if (parity_flag) begin
                        // Even: (X + 1) * inv(3)
                        result_x <= ((res_exp + 1) * INV3) % MOD;
                        result_y <= res_exp;
                    end else begin
                        // Odd: (X - 1) * inv(3)
                        result_x <= ((res_exp - 1 + MOD) * INV3) % MOD;
                        result_y <= res_exp;
                    end
                    state <= STATE_DONE;
                end

                STATE_DONE: begin
                    done <= 1;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule