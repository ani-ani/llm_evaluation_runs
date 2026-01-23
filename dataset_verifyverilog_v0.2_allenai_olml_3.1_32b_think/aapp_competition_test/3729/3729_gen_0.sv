module probability_calculator (
    input clk,
    input rst_n,
    input start,
    input [16:0] f,
    input [16:0] w,
    input [16:0] h,
    output reg [31:0] result,
    output reg done
);

// Parameters
localparam MOD = 10'd1000000007;
localparam MAX_N = 200000;

// LUT for factorials mod MOD
reg [31:0] fac [0:MAX_N];

// State machine signals
reg [2:0] state, next_state;
localparam IDLE = 3'd0, PREPARE=3'd1, CALCULATE=3'd2, COMPUTE_INVERSE=3'd3, COMPUTE_RESULT=3'd4, DONE_STATE=3'd5;

// Registers for results and temporary variables
reg [31:0] total_count, valid_count, inv_total;
reg [31:0] sum_valid, k;
reg [31:0] n, r;
// Variables for intermediate calculations in CALCULATE state
reg [31:0] temp_h, temp_w_div, temp_f1, K_max;
reg [31:0] term1, term2, n1, r1, n2, r2;

// Output registers
reg [31:0] result;
reg done;

// Function for modular exponentiation
function [31:0] pow_mod;
input [31:0] base, exponent, mod;
reg [31:0] result = 1;
reg [31:0] current_base = base % mod;

for (int i = 31; i >= 0; i--) begin
    if (exponent & (1 << i)) begin
        result = result * current_base % mod;
    end
    current_base = current_base * current_base % mod;
end
pow_mod = result;
endfunction

// State machine logic
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 0;
        done <= 0;
        total_count <= 0;
        valid_count <= 0;
        inv_total <= 0;
        sum_valid <= 0;
        // Initialize other registers to 0
        k <= 0;
        n <= 0;
        r <= 0;
        temp_h <= 0;
        temp_w_div <= 0;
        temp_f1 <= 0;
        K_max <= 0;
        term1 <= 0;
        term2 <= 0;
        n1 <= 0;
        r1 <= 0;
        n2 <= 0;
        r2 <= 0;
    end else begin
        state <= next_state;
    end
end

// Next state and output logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: 
            if (start) next_state = PREPARE;
            else next_state = IDLE;
        PREPARE:
            next_state = CALCULATE;
        CALCULATE:
            // Calculate total_count = C(f + w, w)
            n = f + w;
            r = w;
            if (n > MAX_N || r < 0 || r > n) begin
                total_count = 0;
            end else begin
                total_count = fac[n];
                total_count = total_count * pow_mod(fac[r], MOD-2, MOD) % MOD;
                total_count = total_count * pow_mod(fac[n - r], MOD-2, MOD) % MOD;
            end

            // Calculate valid_count
            if (w == 0) begin
                valid_count = 1;
            end else begin
                temp_h = h + 1;
                temp_w_div = w / temp_h;
                temp_f1 = f + 1;
                if (temp_w_div < temp_f1) begin
                    K_max = temp_w_div;
                end else begin
                    K_max = temp_f1;
                end
                sum_valid = 0;
                // Loop from k=1 to 32
                for (k = 1; k <= 32; k++) begin
                    if (k > K_max) begin
                        // Do nothing
                    end else begin
                        // Calculate term1 = C(f+1, k)
                        n1 = f + 1;
                        r1 = k;
                        if (n1 > MAX_N || r1 < 0 || r1 > n1) begin
                            term1 = 0;
                        end else begin
                            term1 = fac[n1];
                            term1 = term1 * pow_mod(fac[r1], MOD-2, MOD) % MOD;
                            term1 = term1 * pow_mod(fac[n1 - r1], MOD-2, MOD) % MOD;
                        end

                        // Calculate term2 = C(w - k*h -1, k-1)
                        n2 = w - (k * h) - 1;
                        r2 = k - 1;
                        if (n2 < 0 || r2 < 0 || r2 > n2) begin
                            term2 = 0;
                        end else begin
                            term2 = fac[n2];
                            term2 = term2 * pow_mod(fac[r2], MOD-2, MOD) % MOD;
                            term2 = term2 * pow_mod(fac[n2 - r2], MOD-2, MOD) % MOD;
                        end

                        sum_valid = sum_valid + term1 * term2;
                    end
                end
                valid_count = sum_valid % MOD;
            end
            next_state = COMPUTE_INVERSE;
        COMPUTE_INVERSE:
            if (total_count == 0) begin
                inv_total = 0;
            end else begin
                inv_total = pow_mod(total_count, MOD-2, MOD);
            end
            next_state = COMPUTE_RESULT;
        COMPUTE_RESULT:
            result = valid_count * inv_total % MOD;
            done = 1; // Assert done immediately?
            next_state = DONE_STATE;
        DONE_STATE:
            next_state = DONE_STATE;
            done = 1;
        default: next_state = IDLE;
    endcase
end

endmodule