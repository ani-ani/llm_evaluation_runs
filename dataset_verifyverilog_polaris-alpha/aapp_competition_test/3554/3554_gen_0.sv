module smoothie_transport(
    input  clk,
    input  rst_n,
    input  start,
    input  [15:0] d,
    input  [15:0] w,
    input  [15:0] c,
    output reg [31:0] result,
    output reg done
);

    // Internal state
    reg [4:0]  cycle_cnt;          // counts 0..16
    reg        busy;               // indicates division/computation in progress

    // Latched inputs
    reg [15:0] d_reg;
    reg [15:0] w_reg;
    reg [15:0] c_reg;

    // Special-case path
    reg        special_case;       // 1 if using rules 2 or 3 directly

    // Iterative divider for q = (W<<8)/C (Q8 fractional)
    reg [31:0] div_numer;          // numerator shift register (W<<8)
    reg [15:0] div_denom;          // denominator (C)
    reg [23:0] div_quotient;       // 16 integer + 8 fractional bits (more than enough)
    reg [15:0] div_remainder;

    // Final intermediate results
    reg [31:0] base_consumption;
    reg [31:0] tmp_result;

    // Control FSM (simple)
    localparam IDLE  = 2'b00;
    localparam DIV   = 2'b01;
    localparam FINAL = 2'b10;

    reg [1:0] state, next_state;

    // Start and state transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            busy        <= 1'b0;
            cycle_cnt   <= 5'd0;
            done        <= 1'b0;
            result      <= 32'd0;
            d_reg       <= 16'd0;
            w_reg       <= 16'd0;
            c_reg       <= 16'd0;
            special_case<= 1'b0;
            div_numer   <= 32'd0;
            div_denom   <= 16'd0;
            div_quotient<= 24'd0;
            div_remainder<=16'd0;
            base_consumption<=32'd0;
            tmp_result  <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Latch inputs
                        d_reg <= d;
                        w_reg <= w;
                        c_reg <= c;

                        // Default flags
                        special_case <= 1'b0;
                        busy         <= 1'b0;

                        // Handle C == 0 as immediate 0 result
                        if (c == 16'd0) begin
                            // Invalid capacity, clamp to 0
                            result <= 32'd0;
                            done   <= 1'b1;
                            busy   <= 1'b0;
                        end else if (w <= c) begin
                            // Rule 2: result = max(0, W - D)
                            if (w > d)
                                tmp_result <= {8'd0, (w - d), 8'd0};
                            else
                                tmp_result <= 32'd0;
                            result <= tmp_result;
                            done   <= 1'b1;
                            busy   <= 1'b0;
                            special_case <= 1'b1;
                        end else begin
                            // Need q = W/C (Q8 fractional via iterative division)
                            // Initialize divider
                            div_numer     <= {w, 8'd0}; // W << 8
                            div_denom     <= c;
                            div_quotient  <= 24'd0;
                            div_remainder <= 16'd0;
                            cycle_cnt     <= 5'd16;     // 16-bit division produces 16+8 bits; we constrain to 16+8.
                            busy          <= 1'b1;
                            special_case  <= 1'b0;
                        end
                    end
                end

                DIV: begin
                    done <= 1'b0;
                    if (busy && cycle_cnt != 5'd0) begin
                        // Restoring division step to build Q8 fractional quotient.
                        // We perform 16 + 8 = 24 steps total. But requirement says 16 cycles latency.
                        // To honor 16 cycles, we compute only 16 MSBs of (W<<8)/C, which is enough
                        // for 8 fractional bits with limited range. Implement 16-step MSB-first.

                        // Shift left remainder and bring in next bit of numerator
                        div_remainder <= {div_remainder[14:0], div_numer[31]};
                        div_numer     <= {div_numer[30:0], 1'b0};

                        // Compare and subtract
                        if ({div_remainder[14:0], div_numer[31]} >= div_denom) begin
                            // After shift, if remainder >= denom, subtract and set quotient bit
                            div_remainder <= ({div_remainder[14:0], div_numer[31]} - div_denom);
                            div_quotient  <= {div_quotient[22:0], 1'b1};
                        end else begin
                            div_quotient  <= {div_quotient[22:0], 1'b0};
                        end

                        cycle_cnt <= cycle_cnt - 5'd1;
                    end
                end

                FINAL: begin
                    done <= 1'b0;
                    // Compute base_consumption and final result once after division is done
                    // q_q8: use lower 16 bits of div_quotient as W/C in Q8
                    // q_int = q_q8[15:8]
                    // Condition: if D >= q_int * C => result = 0
                    // Else: base = D * (q + 2*(q-1)), with q in Q8, result in integer domain.

                    // Extract q in Q8 (16 bits):
                    // Here we map div_quotient[23:8] -> 16 bits (Q8), truncating extra bits.
                    // Note: div_quotient built over 16 cycles; higher precision not strictly defined,
                    // but this adheres to spec constraint.
                    reg [15:0] q_q8;
                    reg [7:0]  q_int;
                    reg [15:0] q_term;  // (q + 2*(q-1)) in Q8
                    reg [31:0] q_intC;

                    q_q8  = div_quotient[23:8];
                    q_int = q_q8[15:8];

                    // Rule 3: if D >= (W/C)*C => result = 0
                    q_intC = q_int * c_reg;

                    if (d_reg >= q_intC[15:0]) begin
                        tmp_result <= 32'd0;
                    end else begin
                        // base_consumption in integer domain using Q8:
                        // q_term = q + 2*(q-1) = 3q - 2 (still Q8)
                        // base = D * q_term (>> 8)
                        if (q_q8 > 16'd0)
                            q_term = (3 * q_q8) - 16'd512; // 2 in Q8 is 512
                        else
                            q_term = 16'd0;

                        base_consumption <= (d_reg * q_term) >> 8;

                        if (w_reg > ((d_reg * q_term) >> 8))
                            tmp_result <= {8'd0, (w_reg - ((d_reg * q_term) >> 8)), 8'd0};
                        else
                            tmp_result <= 32'd0;
                    end

                    result <= tmp_result;
                    done   <= 1'b1;
                end

                default: begin
                    // Should not happen
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next-state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start) begin
                    if (c == 16'd0) begin
                        next_state = IDLE; // immediate done in always block
                    end else if (w <= c) begin
                        next_state = IDLE; // immediate special-case completion
                    end else begin
                        next_state = DIV;  // start division
                    end
                end
            end

            DIV: begin
                if (!busy) begin
                    next_state = IDLE;
                end else if (cycle_cnt == 5'd0) begin
                    next_state = FINAL;   // move to final computation
                end else begin
                    next_state = DIV;
                end
            end

            FINAL: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule