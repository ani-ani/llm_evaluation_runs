module linear_congruence_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] expr_char_0,
    input [7:0] expr_char_1,
    input [7:0] expr_char_2,
    input [7:0] expr_char_3,
    input [7:0] expr_char_4,
    input [7:0] expr_char_5,
    input [7:0] expr_char_6,
    input [7:0] expr_char_7,
    input [19:0] P,
    input [19:0] M,
    output reg [19:0] result_x,
    output reg done,
    output reg error
);

    // State definitions
    localparam IDLE      = 4'b0000;
    localparam PARSE     = 4'b0001;
    localparam PREP_EE   = 4'b0010;
    localparam EE_LOOP   = 4'b0011;
    localparam NORM_T    = 4'b0100;
    localparam PREP_MULT = 4'b0101;
    localparam DIV_LOOP  = 4'b0110;
    localparam DONE_S    = 4'b1000;
    localparam ERROR_S   = 4'b1001;

    reg [3:0] state;
    reg [7:0] expr [0:7];
    reg [2:0] parse_idx;
    reg [19:0] A_reg;
    reg [19:0] B_reg;
    reg parsing_A;
    reg [19:0] num_buf;
    reg has_num;
    reg found_x;
    reg [19:0] C;
    
    // EEA registers
    reg [19:0] r0, r1;
    reg [19:0] t0, t1;
    reg [19:0] q_eea;
    
    // Multiplication/Division registers
    reg [39:0] prod;
    reg [5:0] div_cnt; 
    reg [19:0] div_rem;

    // Combinational helper for EEA
    wire [19:0] t_next;
    assign t_next = t0 - (q_eea * t1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            result_x <= 20'd0;
        end else begin
            done <= 1'b0;
            error <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        parse_idx <= 3'd0;
                        A_reg <= 20'd0;
                        B_reg <= 20'd0;
                        parsing_A <= 1'b1;
                        num_buf <= 20'd0;
                        has_num <= 1'b0;
                        found_x <= 1'b0;
                        expr[0] <= expr_char_0;
                        expr[1] <= expr_char_1;
                        expr[2] <= expr_char_2;
                        expr[3] <= expr_char_3;
                        expr[4] <= expr_char_4;
                        expr[5] <= expr_char_5;
                        expr[6] <= expr_char_6;
                        expr[7] <= expr_char_7;
                    end
                end

                PARSE: begin
                    if (parse_idx < 8) begin
                        case (expr[parse_idx])
                            8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,8'h38,8'h39: begin 
                                has_num <= 1'b1;
                                num_buf <= num_buf * 10 + (expr[parse_idx] - 8'h30);
                            end
                            8'h78: begin // 'x'
                                found_x <= 1'b1;
                                if (!has_num) begin
                                    if (parsing_A) A_reg <= 20'd1;
                                    else B_reg <= 20'd1;
                                end else begin
                                    if (parsing_A) A_reg <= num_buf;
                                    else B_reg <= num_buf;
                                    num_buf <= 20'd0;
                                    has_num <= 1'b0;
                                end
                            end
                            8'h2B: begin // '+'
                                if (has_num) begin
                                    if (parsing_A) B_reg <= num_buf;
                                    else A_reg <= num_buf;
                                    num_buf <= 20'd0;
                                    has_num <= 1'b0;
                                end
                                parsing_A <= 1'b0;
                            end
                            8'h2A: begin // '*'
                                if (has_num) begin
                                    A_reg <= num_buf;
                                    num_buf <= 20'd0;
                                    has_num <= 1'b0;
                                end
                            end
                            default: ; 
                        endcase
                        parse_idx <= parse_idx + 1;
                    end else begin
                        if (has_num) begin
                            if (parsing_A) begin
                                if (found_x) B_reg <= num_buf;
                                else B_reg <= num_buf; 
                            end else begin
                                A_reg <= num_buf;
                            end
                        end
                        
                        if (found_x) begin
                            if (A_reg == 0) A_reg <= 20'd1;
                            state <= PREP_EE;
                        end else begin
                            A_reg <= 20'd0;
                            state <= PREP_EE;
                        end
                    end
                end

                PREP_EE: begin
                    if (P >= B_reg) C <= P - B_reg;
                    else C <= (P + M) - B_reg;

                    if (A_reg == 0) begin
                        if ((P >= B_reg ? (P - B_reg) : (P + M - B_reg)) == 0) begin
                            result_x <= 20'd0;
                            state <= DONE_S;
                        end else begin
                            state <= ERROR_S;
                        end
                    end else begin
                        r0 <= M;
                        r1 <= A_reg;
                        t0 <= 20'd0;
                        t1 <= 20'd1;
                        state <= EE_LOOP;
                    end
                end

                EE_LOOP: begin
                    if (r1 != 0) begin
                        q_eea <= r0 / r1;
                        r0 <= r1;
                        r1 <= r0 % r1;
                        t0 <= t1;
                        t1 <= t_next;
                    end else begin
                        if (r0 != 1) begin
                            state <= ERROR_S;
                        end else begin
                            if (t0 >= M) begin
                                t0 <= t0 - M;
                                state <= NORM_T;
                            end else begin
                                state <= PREP_MULT;
                            end
                        end
                    end
                end

                NORM_T: begin
                    if (t0 >= M) begin
                        t0 <= t0 - M;
                    end else begin
                        state <= PREP_MULT;
                    end
                end

                PREP_MULT: begin
                    prod <= C * t0;
                    div_cnt <= 6'd39;
                    div_rem <= 20'd0;
                    state <= DIV_LOOP;
                end

                DIV_LOOP: begin
                    // Note: The loop is self-contained here by managing div_cnt
                    // We perform one step of shift-subtract division per cycle
                    begin
                        reg [20:0] next_rem;
                        next_rem = {div_rem[18:0], prod[div_cnt]};
                        if (next_rem >= M) begin
                            div_rem <= next_rem - M;
                        end else begin
                            div_rem <= next_rem[19:0];
                        end
                    end
                    
                    if (div_cnt == 0) begin
                        // Final update happens in this cycle, but the value used is the one just computed?
                        // The computed value is in div_rem (blocking vs non-blocking careful here).
                        // Actually, the update `div_rem <= ...` takes effect next cycle.
                        // So when div_cnt == 0, we need to output the final remainder.
                        // But the remainder calculation for the last bit (bit 0) is done now.
                        // However, `div_rem` is updated non-blocking. So next cycle it will be correct.
                        // We need to output `div_rem` next cycle or compute it now.
                        // To be safe and simple, we update result_x in next state or calculate it now.
                        // Since `next_rem` is local, we can check it.
                        // Or, just go to DONE_S and let the `DIV_LOOP` state process the last bit? 
                        // Yes, let's do: If div_cnt == 0, we set result_x = next_rem >= M ? next_rem - M : next_rem, then go DONE.
                        // But we need to capture `next_rem` locally.
                        reg [20:0] final_rem_val;
                        final_rem_val = (next_rem >= M) ? (next_rem - M) : next_rem;
                        result_x <= final_rem_val[19:0];
                        state <= DONE_S;
                    end else begin
                        div_cnt <= div_cnt - 1;
                    end
                end

                DONE_S: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                ERROR_S: begin
                    error <= 1'b1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule