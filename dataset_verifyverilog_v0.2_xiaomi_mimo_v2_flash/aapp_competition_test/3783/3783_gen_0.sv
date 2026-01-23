module subset_cost_sum (
    input clk,
    input rst_n,
    input start,
    input [19:0] n,
    input [12:0] k,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MOD_W = 33; // wider for intermediate subtraction

    // State definitions
    localparam IDLE = 4'd0;
    localparam CALC_FACT = 4'd1;
    localparam CALC_STIRLING = 4'd2;
    localparam CALC_RESULT = 4'd3;
    localparam DONE_STATE = 4'd4;

    // Control Registers
    reg [3:0] state;
    reg [12:0] i_cnt; // General purpose counter
    reg [12:0] j_cnt; // Inner loop counter
    reg [12:0] k_reg; // Stored k
    reg [19:0] n_reg; // Stored n

    // BRAMs for Stirling Numbers
    reg [31:0] mem_A [0:5000];
    reg [31:0] mem_B [0:5000];
    reg [31:0] mem_C [0:5000]; // For inverse array

    // Multiplier inputs
    reg [31:0] op_a;
    reg [31:0] op_b;
    wire [63:0] prod_result;
    assign prod_result = op_a * op_b;

    // Temporary Registers
    reg [31:0] stirling_prev_val; // S(k-1, i)
    reg [31:0] stirling_prev_val_m1; // S(k-1, i-1)
    reg [31:0] stirling_curr_val; // S(k, i)

    reg [31:0] fact_reg; // i!
    reg [31:0] inv_fact_reg; // (i!)^-1
    reg [31:0] falling_fact_reg; // N*(N-1)*...*(N-i+1)

    reg [31:0] pow2N_reg; // 2^N
    reg [31:0] inv_pow2i_reg; // 2^(-i)

    reg [63:0] term_sum; // Accumulated result

    // Multiplication/Modulo Unit control
    reg mult_start;
    reg mult_done;
    reg [1:0] mult_step;

    // Division/Inverse Logic Registers
    reg exp_start;
    reg [31:0] exp_base;
    reg [31:0] exp_power; // 32-bit exponent, but we only need up to 5000 for inv(i) or MOD-2 for others
    reg exp_done;
    reg [31:0] exp_result;

    // Exponentiation State Machine (Binary Exponentiation)
    reg [31:0] exp_val_base;
    reg [31:0] exp_val_power;
    reg [31:0] exp_res;
    reg [5:0] exp_bit_cnt;
    reg exp_running;

    // Modular Exponentiation Unit (uses the Mult/Mod unit)
    reg [1:0] exp_state;
    reg [31:0] exp_res_buf;
    reg [31:0] exp_base_buf;
    reg [31:0] exp_pow_buf;

    // Shared Modulo Multiplier
    reg [31:0] ma, mb;
    reg m_start;
    reg m_done;
    reg [1:0] m_state; // 0: idle, 1: mult, 2: mod
    reg [63:0] m_prod;
    reg [31:0] m_res;

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            // Reset multiplications
            m_start <= 0;
            mult_start <= 0;
            exp_start <= 0;
            exp_done <= 1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        k_reg <= k;
                        n_reg <= n;
                        // Initialize counters
                        i_cnt <= 1;
                        j_cnt <= 1;
                        state <= CALC_FACT;
                    end
                end

                CALC_FACT: begin
                    // Compute 2^N and inverse array
                    if (i_cnt <= k_reg) begin
                        // Compute 2^N
                        if (i_cnt == 1) begin
                            exp_val_base <= 2;
                            exp_val_power <= n_reg;
                            exp_res <= 1;
                            exp_bit_cnt <= 0;
                            exp_start <= 1;
                        end
                        // Compute inverse array
                        if (exp_done) begin
                            if (i_cnt == 1) begin
                                pow2N_reg <= exp_res;
                                inv_pow2i_reg <= 1;
                            end
                            exp_val_base <= i_cnt;
                            exp_val_power <= MOD - 2;
                            exp_res <= 1;
                            exp_bit_cnt <= 0;
                            exp_start <= 1;
                        end
                        if (exp_done) begin
                            mem_C[i_cnt] <= exp_res;
                            i_cnt <= i_cnt + 1;
                        end
                    end else begin
                        state <= CALC_STIRLING;
                    end
                end

                CALC_STIRLING: begin
                    // Compute Stirling numbers
                    if (i_cnt <= k_reg) begin
                        if (j_cnt <= i_cnt) begin
                            // Read S(k-1, j-1) and S(k-1, j)
                            if (j_cnt == 1) begin
                                stirling_prev_val_m1 <= mem_A[j_cnt - 1];
                            end else begin
                                stirling_prev_val <= mem_A[j_cnt - 1];
                            end
                            stirling_prev_val_m1 <= mem_A[j_cnt];
                            // Compute S(k, j)
                            stirling_curr_val <= stirling_prev_val_m1 + j_cnt * stirling_prev_val;
                            // Write S(k, j) to mem_B
                            mem_B[j_cnt] <= stirling_curr_val;
                            j_cnt <= j_cnt + 1;
                        end else begin
                            j_cnt <= 1;
                            i_cnt <= i_cnt + 1;
                            // Swap BRAMs
                            if (i_cnt % 2 == 0) begin
                                mem_A <= mem_B;
                            end else begin
                                mem_B <= mem_A;
                            end
                        end
                    end else begin
                        state <= CALC_RESULT;
                    end
                end

                CALC_RESULT: begin
                    // Compute the result
                    if (i_cnt <= k_reg) begin
                        // Read S(k, i) from mem_B
                        stirling_curr_val <= mem_B[i_cnt];
                        // Compute i!
                        fact_reg <= fact_reg * i_cnt;
                        // Compute inv_fact[i]
                        inv_fact_reg <= inv_fact_reg * mem_C[i_cnt];
                        // Compute falling factorial
                        falling_fact_reg <= falling_fact_reg * (n_reg - i_cnt + 1);
                        // Compute 2^(N-i)
                        inv_pow2i_reg <= inv_pow2i_reg * 500000004;
                        // Compute term
                        op_a <= stirling_curr_val;
                        op_b <= fact_reg;
                        m_start <= 1;
                        if (m_done) begin
                            op_a <= m_res;
                            op_b <= falling_fact_reg;
                            m_start <= 1;
                            if (m_done) begin
                                op_a <= m_res;
                                op_b <= inv_fact_reg;
                                m_start <= 1;
                                if (m_done) begin
                                    op_a <= m_res;
                                    op_b <= inv_pow2i_reg;
                                    m_start <= 1;
                                    if (m_done) begin
                                        term_sum <= term_sum + m_res;
                                        i_cnt <= i_cnt + 1;
                                    end
                                end
                            end
                        end
                    end else begin
                        // Finalize result
                        result <= term_sum % MOD;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Modular Exponentiation Unit
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_state <= 0;
            exp_done <= 1;
            m_start <= 0;
        end else begin
            case (exp_state)
                0: begin // Idle
                    if (exp_start) begin
                        exp_res_buf <= 1;
                        exp_base_buf <= exp_base;
                        exp_pow_buf <= exp_power;
                        exp_state <= 1;
                        exp_done <= 0;
                    end
                end
                1: begin // Loop
                    if (exp_pow_buf == 0) begin
                        exp_state <= 2;
                    end else begin
                        if (exp_pow_buf[0]) begin
                            if (m_done) begin
                                exp_res_buf <= m_res;
                            end
                        end
                        exp_base_buf <= (exp_base_buf * exp_base_buf) % MOD;
                        exp_pow_buf <= exp_pow_buf >> 1;
                    end
                end
                2: begin
                    exp_done <= 1;
                    exp_state <= 0;
                end
            endcase
        end
    end

    // Shared Modulo Multiplier
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_state <= 0;
            m_done <= 1;
        end else begin
            case (m_state)
                0: begin // Idle
                    if (m_start) begin
                        m_prod <= ma * mb; // Combinatorial mult
                        m_state <= 1;
                        m_done <= 0;
                    end
                end
                1: begin // Modulo Reduction Step 1 (Prepare)
                    m_res <= (m_prod[63:32] * 294967269 + m_prod[31:0]) % MOD;
                    m_state <= 2;
                end
                2: begin // Done
                    m_done <= 1;
                    m_state <= 0;
                end
            endcase
        end
    end

    // Exponentiation State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_start <= 0;
            exp_done <= 1;
        end else begin
            if (exp_start) begin
                if (exp_bit_cnt < 32) begin
                    if (exp_val_power[0]) begin
                        exp_res <= (exp_res * exp_val_base) % MOD;
                    end
                    exp_val_base <= (exp_val_base * exp_val_base) % MOD;
                    exp_val_power <= exp_val_power >> 1;
                    exp_bit_cnt <= exp_bit_cnt + 1;
                end else begin
                    exp_done <= 1;
                    exp_start <= 0;
                end
            end
        end
    end
endmodule
