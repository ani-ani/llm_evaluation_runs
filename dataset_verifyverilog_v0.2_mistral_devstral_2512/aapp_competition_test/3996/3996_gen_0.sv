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
    localparam MOD = 32'h3B9ACA01; // 10^9+7
    localparam MOD_MINUS_1 = 32'h3B9ACA00; // 10^9+6
    localparam INV_3 = 32'h23863AFB; // Modular inverse of 3 mod 10^9+7

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PROCESS_INPUT,
        CALC_EXP,
        CALC_FINAL,
        DONE
    } state_t;

    // Registers
    state_t state, next_state;
    reg [31:0] mod_acc;
    reg parity_flag;
    reg [31:0] exp;
    reg [31:0] X;
    reg [31:0] N;
    reg [31:0] base;
    reg [31:0] result;
    reg [31:0] exponent;
    reg [5:0] bit_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mod_acc <= 32'h00000001; // Initialize to 1
            parity_flag <= 1'b0;
            exp <= 32'h00000000;
            X <= 32'h00000000;
            N <= 32'h00000000;
            base <= 32'h00000002; // Base for exponentiation
            result <= 32'h00000001; // Initialize result to 1
            exponent <= 32'h00000000;
            bit_counter <= 6'h00;
            result_x <= 32'h00000000;
            result_y <= 32'h00000000;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (valid_in) begin
                        mod_acc <= (a_in % MOD_MINUS_1);
                        parity_flag <= (a_in[0] == 1'b0) ? 1'b1 : 1'b0;
                        if (last_in) begin
                            next_state <= CALC_EXP;
                        end else begin
                            next_state <= PROCESS_INPUT;
                        end
                    end
                end
                
                PROCESS_INPUT: begin
                    if (valid_in) begin
                        mod_acc <= (mod_acc * (a_in % MOD_MINUS_1)) % MOD_MINUS_1;
                        parity_flag <= parity_flag | (a_in[0] == 1'b0);
                        if (last_in) begin
                            next_state <= CALC_EXP;
                        end
                    end
                end
                
                CALC_EXP: begin
                    if (bit_counter == 6'h00) begin
                        exp <= (mod_acc - 1 + MOD_MINUS_1) % MOD_MINUS_1;
                        exponent <= exp;
                        result <= 32'h00000001;
                        base <= 32'h00000002;
                        bit_counter <= 6'h20; // Start from MSB
                    end else begin
                        bit_counter <= bit_counter - 1;
                        if (exponent[bit_counter]) begin
                            result <= (result * base) % MOD;
                        end
                        base <= (base * base) % MOD;
                        if (bit_counter == 6'h00) begin
                            X <= result;
                            next_state <= CALC_FINAL;
                        end
                    end
                end
                
                CALC_FINAL: begin
                    if (parity_flag) begin
                        N <= (X + 1) % MOD;
                    end else begin
                        N <= (X - 1 + MOD) % MOD;
                    end
                    N <= (N * INV_3) % MOD;
                    result_x <= X;
                    result_y <= N;
                    done <= 1'b1;
                    next_state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
    end

endmodule