module dice_expectation(
    input  clk,
    input  rst_n,
    input  start,
    input  [2:0] m,      // dice faces (1-8)
    input  [3:0] n,      // toss count (1-16)
    output reg [31:0] result,  // Q16.16 result
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        S_IDLE      = 3'd0,
        S_PREP      = 3'd1,
        S_DIV_WAIT1 = 3'd2,
        S_DIV_WAIT2 = 3'd3,
        S_NEXT_I    = 3'd4,
        S_EXP       = 3'd5,
        S_SUB       = 3'd6,
        S_DONE      = 3'd7
    } state_t;

    state_t state, next_state;

    // Registers
    reg [2:0]  m_reg;              // latched m
    reg [3:0]  n_reg;              // latched n
    reg [31:0] inv_m_q16;          // 1/m in Q16.16
    reg [2:0]  i_reg;              // current i (1..m-1)
    reg [31:0] base_q16;           // (i/m) in Q16.16
    reg [31:0] pow_q16;            // current power accumulator in Q16.16
    reg [4:0]  exp_count;          // exponentiation cycle counter (1..n)
    reg [31:0] sum_q16;            // accumulated sum of (i/m)^n

    // Wires
    wire [31:0] m_q16 = {13'd0, m_reg, 16'd0}; // m as Q16.16

    // 1/m computation (combinational, but accounted as 2-cycle latency by FSM)
    // Max m is 8, 16-bit numerator is enough.
    wire [31:0] inv_m_q16_next = (m_reg != 0) ? (32'd65536 / m_reg) : 32'd0;

    // Fixed-point multiply Q16.16 * Q16.16 -> Q16.16
    function automatic [31:0] q16_mul(input [31:0] a, input [31:0] b);
        reg [63:0] prod;
        begin
            prod = a * b;
            q16_mul = prod[47:16];
        end
    endfunction

    // Sequential state / registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            m_reg      <= 3'd0;
            n_reg      <= 4'd0;
            inv_m_q16  <= 32'd0;
            i_reg      <= 3'd0;
            base_q16   <= 32'd0;
            pow_q16    <= 32'd0;
            exp_count  <= 5'd0;
            sum_q16    <= 32'd0;
            result     <= 32'd0;
            done       <= 1'b0;
        end else begin
            state <= next_state;

            // Default done low unless explicitly set in DONE state
            if (state != S_DONE)
                done <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        m_reg     <= m;
                        n_reg     <= n;
                        sum_q16   <= 32'd0;
                        i_reg     <= 3'd0;
                        inv_m_q16 <= 32'd0; // will be filled after latency
                    end
                end

                S_PREP: begin
                    // No register updates beyond what was set in IDLE
                end

                S_DIV_WAIT1: begin
                    // First latency cycle for 1/m; no visible update
                end

                S_DIV_WAIT2: begin
                    // Second latency cycle: capture 1/m result
                    inv_m_q16 <= inv_m_q16_next;
                end

                S_NEXT_I: begin
                    if (i_reg == 0) begin
                        // start with i = 1
                        i_reg <= 3'd1;
                    end else begin
                        i_reg <= i_reg + 3'd1;
                    end

                    // base_q16 = i * inv_m_q16
                    base_q16  <= q16_mul({29'd0, (i_reg == 0 ? 3'd1 : (i_reg + 3'd1))}, inv_m_q16);
                    // Initialize pow accumulator for exponentiation next state
                    pow_q16   <= 32'd0;
                    exp_count <= 5'd0;
                end

                S_EXP: begin
                    if (exp_count == 0) begin
                        // First cycle: pow = base, exp_count = 1
                        pow_q16   <= base_q16;
                        exp_count <= 5'd1;
                    end else if (exp_count < n_reg) begin
                        // Multiply by base each cycle
                        pow_q16   <= q16_mul(pow_q16, base_q16);
                        exp_count <= exp_count + 5'd1;
                    end
                end

                S_SUB: begin
                    // Accumulate sum_q16 += pow_q16 (which is (i/m)^n)
                    sum_q16 <= sum_q16 + pow_q16;
                end

                S_DONE: begin
                    // Compute final result: E = m - sum((i/m)^n)
                    // result_q16 = m_q16 - sum_q16
                    result <= m_q16 - sum_q16;
                    done   <= 1'b1;
                end

                default: ;
            endcase
        end
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_PREP;
            end

            S_PREP: begin
                // Move into 1/m latency pipeline
                next_state = S_DIV_WAIT1;
            end

            S_DIV_WAIT1: begin
                next_state = S_DIV_WAIT2;
            end

            S_DIV_WAIT2: begin
                // After capturing inv_m_q16, proceed to first i
                if (m_reg > 1)
                    next_state = S_NEXT_I;
                else
                    // If m == 1, sum is empty, E = 1
                    next_state = S_DONE;
            end

            S_NEXT_I: begin
                // Immediately go to exponentiation for current i
                next_state = S_EXP;
            end

            S_EXP: begin
                if (n_reg == 0) begin
                    // Degenerate (not expected per spec), treat as pow=1 in next state
                    next_state = S_SUB;
                end else if (exp_count == 0) begin
                    // Just initialized, stay until at least one multiply/assign done
                    next_state = S_EXP;
                end else if (exp_count < n_reg) begin
                    // Continue exponentiation
                    next_state = S_EXP;
                end else begin
                    // Completed n multiplications -> have (i/m)^n
                    next_state = S_SUB;
                end
            end

            S_SUB: begin
                // Decide whether more terms or finish
                if (i_reg < (m_reg - 1)) begin
                    next_state = S_NEXT_I;
                end else begin
                    next_state = S_DONE;
                end
            end

            S_DONE: begin
                // After one cycle with done=1, go back to IDLE
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule