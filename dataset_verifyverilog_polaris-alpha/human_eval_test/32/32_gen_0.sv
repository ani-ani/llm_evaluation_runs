module polynomial_root_finder(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    input  logic [7:0][31:0]  coeffs,      // coeffs[0]=constant ... coeffs[degree]=highest
    input  logic [2:0]        degree,      // 1-7
    output logic [31:0]       x_out,       // Q16.16
    output logic              done
);

    // Fixed-point Q16.16 utilities
    // 32-bit signed, mult -> 64-bit, then >>16

    // FSM states
    typedef enum logic [3:0] {
        S_IDLE          = 4'd0,
        S_INIT          = 4'd1,
        S_POLY_PREP     = 4'd2,
        S_POLY_ACC      = 4'd3,
        S_DERIV_PREP    = 4'd4,
        S_DERIV_ACC     = 4'd5,
        S_CHECK_CONV    = 4'd6,
        S_PREP_DIV      = 4'd7,
        S_DIV_INIT      = 4'd8,
        S_DIV_RUN       = 4'd9,
        S_UPDATE_X      = 4'd10,
        S_DONE          = 4'd11
    } state_t;

    state_t state, next_state;

    // Iteration counter
    logic [3:0] iter_cnt; // up to 10

    // Current guess
    logic signed [31:0] x_cur;

    // Polynomial and derivative evaluation
    // Horner accumulators (48-bit internal as requested)
    logic signed [47:0] poly_acc;
    logic signed [47:0] deriv_acc;

    // 64-bit multiplication results
    logic signed [63:0] mul_res;

    // Index for Horner loops
    logic [2:0] idx;          // for poly
    logic [2:0] deriv_idx;    // for deriv

    // Stored values for division step
    logic signed [31:0] poly_val_q16;   // poly(x) in Q16.16 (truncated from poly_acc)
    logic signed [31:0] deriv_val_q16;  // derivative(x) Q16.16

    // For magnitude check
    logic [31:0] poly_abs;

    // Divider signals (sequential fixed-latency radix-2 restoring division)
    // We compute delta = poly / deriv in Q16.16.
    // Implementation: signed divide of 32-bit by 32-bit -> 32-bit Q16.16 result.

    logic        div_sign;
    logic [31:0] div_numer_abs;
    logic [31:0] div_denom_abs;

    logic [63:0] div_remainder;
    logic [31:0] div_quotient;
    logic [5:0]  div_bit; // up to 32 steps

    logic signed [31:0] delta_x; // result of division (Q16.16)

    // Convergence threshold |poly(x)| < 0x200
    localparam logic [31:0] CONV_THRESH = 32'h00000200;

    // Iteration limit
    localparam logic [3:0] MAX_ITER = 4'd10;

    // Combinational helpers
    always_comb begin
        // Absolute value of poly_val_q16
        if (poly_val_q16[31] == 1'b1)
            poly_abs = (~poly_val_q16) + 32'd1;
        else
            poly_abs = poly_val_q16;
    end

    // FSM - sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            iter_cnt      <= 4'd0;
            x_cur         <= 32'sd0;
            x_out         <= 32'sd0;
            done          <= 1'b0;

            poly_acc      <= 48'sd0;
            deriv_acc     <= 48'sd0;
            idx           <= 3'd0;
            deriv_idx     <= 3'd0;

            poly_val_q16  <= 32'sd0;
            deriv_val_q16 <= 32'sd0;

            div_sign      <= 1'b0;
            div_numer_abs <= 32'd0;
            div_denom_abs <= 32'd0;
            div_remainder <= 64'd0;
            div_quotient  <= 32'd0;
            div_bit       <= 6'd0;
            delta_x       <= 32'sd0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for new run
                        iter_cnt <= 4'd0;
                        x_cur    <= 32'sd0; // initial guess = 0
                    end
                end

                S_INIT: begin
                    // Prepare for polynomial evaluation
                    // Start from highest coefficient: coeffs[degree]
                    poly_acc <= {{16{coeffs[degree][31]}}, coeffs[degree]};
                    idx      <= degree - 3'd1;
                end

                S_POLY_PREP: begin
                    // Nothing special; fall-through into accumulation
                end

                S_POLY_ACC: begin
                    // Horner: poly_acc = poly_acc * x_cur + coeffs[idx]
                    mul_res  <= $signed(poly_acc[47:16]) * $signed(x_cur); // use upper 32 bits as Q16.16
                    // After mult (Q16.16 * Q16.16 = Q32.32), shift >>16 -> Q16.16, keep 48 bits
                    poly_acc <= {{16{mul_res[63]}}, mul_res[63:16]} + {{16{coeffs[idx][31]}}, coeffs[idx]};
                    if (idx != 3'd0)
                        idx <= idx - 3'd1;
                end

                S_DERIV_PREP: begin
                    // Prepare derivative Horner: if degree==1, derivative is constant coeffs[1]
                    if (degree == 3'd1) begin
                        deriv_acc  <= {{16{coeffs[1][31]}}, coeffs[1]};
                        deriv_idx  <= 3'd0;
                    end else begin
                        // Start from highest derivative coeff: degree * coeffs[degree]
                        // Compute degree * coeffs[degree] in Q16.16
                        // degree (<=7) fits fine.
                        mul_res    <= $signed({{29{1'b0}}, degree}) * $signed(coeffs[degree]);
                        deriv_acc  <= {{16{mul_res[63]}}, mul_res[63:16]};
                        deriv_idx  <= degree - 3'd1;
                    end
                end

                S_DERIV_ACC: begin
                    if (degree > 3'd1) begin
                        // For k from degree-1 down to 1:
                        // accum = accum * x + k * coeffs[k]
                        mul_res <= $signed(deriv_acc[47:16]) * $signed(x_cur);
                        // k = deriv_idx
                        // k * coeffs[deriv_idx]
                        logic signed [63:0] mul_kc;
                        mul_kc = $signed({{29{1'b0}}, deriv_idx}) * $signed(coeffs[deriv_idx]);
                        deriv_acc <= {{16{mul_res[63]}}, mul_res[63:16]} + {{16{mul_kc[63]}}, mul_kc[63:16]};
                        if (deriv_idx != 3'd1)
                            deriv_idx <= deriv_idx - 3'd1;
                    end
                end

                S_CHECK_CONV: begin
                    // Latch final poly/deriv Q16.16 values from 48-bit accum
                    poly_val_q16  <= poly_acc[47:16];
                    if (degree == 3'd1)
                        deriv_val_q16 <= deriv_acc[47:16];
                    else
                        deriv_val_q16 <= deriv_acc[47:16];
                end

                S_PREP_DIV: begin
                    // Prepare signed division for delta = poly / deriv
                    // Avoid division by zero: if derivative very small, terminate.
                    if (deriv_val_q16 == 32'sd0 || deriv_val_q16 == 32'sh00000001 || deriv_val_q16 == -32'sh00000001) begin
                        // Degenerate: stop iterations
                        delta_x <= 32'sd0;
                    end else begin
                        div_sign      <= poly_val_q16[31] ^ deriv_val_q16[31];
                        div_numer_abs <= poly_val_q16[31] ? (~poly_val_q16 + 32'd1) : poly_val_q16;
                        div_denom_abs <= deriv_val_q16[31] ? (~deriv_val_q16 + 32'd1) : deriv_val_q16;
                    end
                end

                S_DIV_INIT: begin
                    // Initialize restoring division for 32-bit / 32-bit -> 32-bit
                    if (deriv_val_q16 == 32'sd0 || deriv_val_q16 == 32'sh00000001 || deriv_val_q16 == -32'sh00000001) begin
                        div_remainder <= 64'd0;
                        div_quotient  <= 32'd0;
                        div_bit       <= 6'd0;
                    end else begin
                        div_remainder <= 64'd0;
                        div_quotient  <= 32'd0;
                        div_bit       <= 6'd32; // perform 32 iterations
                    end
                end

                S_DIV_RUN: begin
                    if (!(deriv_val_q16 == 32'sd0 || deriv_val_q16 == 32'sh00000001 || deriv_val_q16 == -32'sh00000001)) begin
                        if (div_bit != 6'd0) begin
                            // Shift remainder left and bring next bit of numerator
                            div_remainder <= {div_remainder[62:0], div_numer_abs[div_bit-1]};
                            // Trial subtract
                            if ({div_remainder[62:0], div_numer_abs[div_bit-1]} >= {32'd0, div_denom_abs}) begin
                                div_remainder <= ({div_remainder[62:0], div_numer_abs[div_bit-1]} - {32'd0, div_denom_abs});
                                div_quotient  <= {div_quotient[30:0], 1'b1};
                            end else begin
                                div_quotient  <= {div_quotient[30:0], 1'b0};
                            end
                            div_bit <= div_bit - 6'd1;
                        end
                    end
                end

                S_UPDATE_X: begin
                    // Finalize delta_x from quotient, apply sign, and convert to Q16.16
                    if (deriv_val_q16 == 32'sd0 || deriv_val_q16 == 32'sh00000001 || deriv_val_q16 == -32'sh00000001) begin
                        delta_x <= 32'sd0;
                    end else begin
                        // div_quotient currently integer approximation of poly/deriv.
                        // Interpret as Q16.16 by shifting left 16 (i.e., bits for fraction).
                        // To keep within 32 bits, take lower 32 bits after shift.
                        logic signed [47:0] tmp_delta;
                        tmp_delta = $signed({1'b0, div_quotient}) <<< 16;
                        if (div_sign)
                            tmp_delta = -tmp_delta;
                        delta_x <= tmp_delta[31:0];
                    end

                    // Newton step: x_{n+1} = x_n - delta
                    x_cur <= x_cur - delta_x;

                    // Increment iteration counter
                    iter_cnt <= iter_cnt + 4'd1;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    x_out <= x_cur;
                end

                default: begin
                end
            endcase
        end
    end

    // FSM - next state logic
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_INIT;
            end

            S_INIT: begin
                next_state = S_POLY_PREP;
            end

            S_POLY_PREP: begin
                // If degree==0 (not allowed by spec) we would handle differently; here assume 1-7
                next_state = S_POLY_ACC;
            end

            S_POLY_ACC: begin
                if (idx == 3'd0)
                    next_state = S_DERIV_PREP;
                else
                    next_state = S_POLY_ACC;
            end

            S_DERIV_PREP: begin
                if (degree == 3'd1)
                    next_state = S_CHECK_CONV; // derivative is ready
                else
                    next_state = S_DERIV_ACC;
            end

            S_DERIV_ACC: begin
                if (degree == 3'd1)
                    next_state = S_CHECK_CONV;
                else if (deriv_idx == 3'd1)
                    next_state = S_CHECK_CONV;
                else
                    next_state = S_DERIV_ACC;
            end

            S_CHECK_CONV: begin
                // Decide convergence or continue
                if (poly_abs < CONV_THRESH)
                    next_state = S_DONE;
                else if (iter_cnt >= (MAX_ITER - 1))
                    next_state = S_DONE;
                else
                    next_state = S_PREP_DIV;
            end

            S_PREP_DIV: begin
                next_state = S_DIV_INIT;
            end

            S_DIV_INIT: begin
                if (deriv_val_q16 == 32'sd0 || deriv_val_q16 == 32'sh00000001 || deriv_val_q16 == -32'sh00000001)
                    next_state = S_UPDATE_X; // degenerate; no real division
                else
                    next_state = S_DIV_RUN;
            end

            S_DIV_RUN: begin
                if (deriv_val_q16 == 32'sd0 || deriv_val_q16 == 32'sh00000001 || deriv_val_q16 == -32'sh00000001)
                    next_state = S_UPDATE_X;
                else if (div_bit == 6'd0)
                    next_state = S_UPDATE_X;
                else
                    next_state = S_DIV_RUN;
            end

            S_UPDATE_X: begin
                next_state = S_INIT; // start next Newton iteration
            end

            S_DONE: begin
                // Wait until start is deasserted then asserted again
                if (!start)
                    next_state = S_IDLE;
                else
                    next_state = S_DONE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule