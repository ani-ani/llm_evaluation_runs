module bug_fixing_optimizer #(
    parameter MAX_BUGS = 2,
    parameter MAX_TIME = 8,
    parameter DATA_WIDTH = 64,
    parameter FRACTION_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] B,
    input wire [3:0] T,
    input wire [DATA_WIDTH-1:0] f,
    input wire [DATA_WIDTH-1:0] p0,
    input wire [DATA_WIDTH-1:0] p1,
    input wire [DATA_WIDTH-1:0] s0,
    input wire [DATA_WIDTH-1:0] s1,
    output reg [DATA_WIDTH-1:0] expected_value,
    output reg done
);

    // State definitions
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_PRECOMP = 4'd1;
    localparam [3:0] S_INIT = 4'd2;
    localparam [3:0] S_LOOP_T = 4'd3;
    localparam [3:0] S_LOOP_STATE = 4'd4;
    localparam [3:0] S_LOOP_BUG = 4'd5;
    localparam [3:0] S_CALC = 4'd6;
    localparam [3:0] S_UPDATE_BEST = 4'd7;
    localparam [3:0] S_STORE = 4'd8;
    localparam [3:0] S_OUTPUT = 4'd9;
    localparam [3:0] S_DONE = 4'd10;
    localparam [3:0] S_PRECOMP_LOOP = 4'd11;

    reg [3:0] state, next_state;

    // Constants
    localparam [3:0] MAX_BUGS_LOCAL = MAX_BUGS;
    localparam [7:0] STATE_SIZE = 8'd64; // (T+2)^B, max 10^2=100
    localparam [3:0] MAX_T = 4'd8;

    // DP memory - flattened for synthesis
    reg [DATA_WIDTH-1:0] dp [0:8][0:63];

    // Precomputed powers
    reg [DATA_WIDTH-1:0] f_power [0:8];

    // Iteration variables
    reg [3:0] t_idx;
    reg [7:0] state_idx;
    reg [1:0] bug_idx;
    reg [3:0] power_idx;

    // Temporary registers
    reg [DATA_WIDTH-1:0] p_current;
    reg [DATA_WIDTH-1:0] one_minus_p;
    reg [DATA_WIDTH-1:0] dp_success;
    reg [DATA_WIDTH-1:0] dp_failure;
    reg [DATA_WIDTH-1:0] term_success;
    reg [DATA_WIDTH-1:0] term_failure;
    reg [DATA_WIDTH-1:0] value;
    reg [DATA_WIDTH-1:0] best;

    // State decoding - combinational
    wire [3:0] bug0_state = state_idx % (T + 2);
    wire [3:0] bug1_state = state_idx / (T + 2);
    wire bug0_fixed = (bug0_state == T + 1);
    wire bug1_fixed = (bug1_state == T + 1);

    wire [3:0] bug0_state_success = T + 1;
    wire [3:0] bug0_state_failure = (bug0_state < T) ? bug0_state + 1 : T;
    wire [3:0] bug1_state_success = T + 1;
    wire [3:0] bug1_state_failure = (bug1_state < T) ? bug1_state + 1 : T;

    wire [7:0] state_success_bug0 = bug0_state_success * (T + 2) + bug1_state;
    wire [7:0] state_failure_bug0 = bug0_state_failure * (T + 2) + bug1_state;
    wire [7:0] state_success_bug1 = bug0_state * (T + 2) + bug1_state_success;
    wire [7:0] state_failure_bug1 = bug0_state * (T + 2) + bug1_state_failure;

    // Fixed-point arithmetic functions
    function [DATA_WIDTH-1:0] fp_mult;
        input [DATA_WIDTH-1:0] a, b;
        reg signed [127:0] prod;
        begin
            prod = a * b;
            fp_mult = prod[95:32];
        end
    endfunction

    function [DATA_WIDTH-1:0] fp_add;
        input [DATA_WIDTH-1:0] a, b;
        begin
            fp_add = a + b;
        end
    endfunction

    function [DATA_WIDTH-1:0] fp_sub;
        input [DATA_WIDTH-1:0] a, b;
        begin
            fp_sub = a - b;
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            expected_value <= 64'd0;
            power_idx <= 4'd0;
            t_idx <= 4'd0;
            state_idx <= 8'd0;
            bug_idx <= 2'd0;
            p_current <= 64'd0;
            one_minus_p <= 64'd0;
            dp_success <= 64'd0;
            dp_failure <= 64'd0;
            term_success <= 64'd0;
            term_failure <= 64'd0;
            value <= 64'd0;
            best <= 64'd0;
            // Initialize dp memory to 0
            for (integer i = 0; i < 9; i = i + 1) begin
                for (integer j = 0; j < 64; j = j + 1) begin
                    dp[i][j] <= 64'd0;
                end
            end
            // Initialize f_power to 0
            for (integer k = 0; k < 9; k = k + 1) begin
                f_power[k] <= 64'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_PRECOMP;
                    end
                end

                S_PRECOMP: begin
                    // Compute f_power[0] = 1.0
                    f_power[0] <= 64'h0000000100000000;
                    power_idx <= 4'd1;
                    state <= S_PRECOMP_LOOP;
                end

                S_PRECOMP_LOOP: begin
                    if (power_idx > T) begin
                        // Precomputation done
                        // Initialize dp[T][*] = 0
                        for (integer i = 0; i < 64; i = i + 1) begin
                            dp[T][i] <= 64'd0;
                        end
                        t_idx <= T - 1;
                        state_idx <= 8'd0;
                        state <= S_LOOP_T;
                    end else begin
                        // f_power[k] = f_power[k-1] * f
                        f_power[power_idx] <= fp_mult(f_power[power_idx - 1], f);
                        power_idx <= power_idx + 1;
                    end
                end

                S_LOOP_T: begin
                    if (t_idx == 8'hFF) begin // t_idx underflows when done
                        state <= S_OUTPUT;
                    end else begin
                        state_idx <= 8'd0;
                        state <= S_LOOP_STATE;
                    end
                end

                S_LOOP_STATE: begin
                    if (state_idx >= STATE_SIZE) begin
                        t_idx <= t_idx - 1;
                        state <= S_LOOP_T;
                    end else begin
                        bug_idx <= 2'd0;
                        best <= 64'd0;
                        state <= S_LOOP_BUG;
                    end
                end

                S_LOOP_BUG: begin
                    if (bug_idx >= MAX_BUGS_LOCAL) begin
                        dp[t_idx][state_idx] <= best;
                        state_idx <= state_idx + 1;
                        state <= S_LOOP_STATE;
                    end else begin
                        if ((bug_idx == 0 && bug0_fixed) || (bug_idx == 1 && bug1_fixed)) begin
                            bug_idx <= bug_idx + 1;
                        end else begin
                            state <= S_CALC;
                        end
                    end
                end

                S_CALC: begin
                    // Calculate value
                    state <= S_UPDATE_BEST;
                end

                S_UPDATE_BEST: begin
                    if (value > best) begin
                        best <= value;
                    end
                    bug_idx <= bug_idx + 1;
                    state <= S_LOOP_BUG;
                end

                S_OUTPUT: begin
                    expected_value <= dp[0][0];
                    done <= 1'b1;
                    state <= S_DONE;
                end

                S_DONE: begin
                    done <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Combinational logic for S_CALC
    always @(*) begin
        value = 64'd0;
        p_current = 64'd0;
        one_minus_p = 64'd0;
        dp_success = 64'd0;
        dp_failure = 64'd0;
        term_success = 64'd0;
        term_failure = 64'd0;

        if (state == S_CALC) begin
            if (bug_idx == 0) begin
                p_current = fp_mult(p0, f_power[bug0_state]);
                one_minus_p = fp_sub(64'h0000000100000000, p_current);
                dp_success = dp[t_idx + 1][state_success_bug0];
                dp_failure = dp[t_idx + 1][state_failure_bug0];
                term_success = fp_mult(p_current, fp_add(s0, dp_success));
            end else begin
                p_current = fp_mult(p1, f_power[bug1_state]);
                one_minus_p = fp_sub(64'h0000000100000000, p_current);
                dp_success = dp[t_idx + 1][state_success_bug1];
                dp_failure = dp[t_idx + 1][state_failure_bug1];
                term_success = fp_mult(p_current, fp_add(s1, dp_success));
            end
            term_failure = fp_mult(one_minus_p, dp_failure);
            value = fp_add(term_success, term_failure);
        end
    end

endmodule