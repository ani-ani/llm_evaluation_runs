module burger_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    input wire [9:0] k_in,
    input wire [9:0] a_in,
    input wire [9:0] b_in,
    output reg [31:0] min_stops,
    output reg [31:0] max_stops,
    output reg done
    );

    // Registers
    reg [7:0] i_cnt;
    reg [2:0] step_idx;      // 0-3 for s1, s2, s3, s4
    reg signed [11:0] step_val_temp; // Signed to handle negative intermediate values
    reg [10:0] L_reg;      // L value to be fed to GCD
    reg [10:0] S_reg;      // S value to be fed to GCD
    reg gcd_start;
    wire gcd_done;
    wire [10:0] gcd_res;

    // Output registers
    reg [31:0] min_stops;
    reg [31:0] max_stops;
    reg done;

    // Instantiate GCD module (sequential/iterative)
    gcd_unit gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a_in(S_reg),
        .b_in(L_reg),
        .gcd_out(gcd_res),
        .done(gcd_done)
    );

    // State Machine Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_cnt <= 0;
            step_idx <= 0;
            min_stops <= 32'hFFFFFFFF;
            max_stops <= 0;
            done <= 0;
            gcd_start <= 0;
            step_val_temp <= 0;
            S_reg <= 0;
            L_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= ITERATE_LOOP;
                        i_cnt <= 0;
                        step_idx <= 0;
                        min_stops <= 32'hFFFFFFFF;
                        max_stops <= 0;
                        S_reg <= n_in * k_in; // Calculate S
                    end
                end

                ITERATE_LOOP: begin
                    reg signed [31:0] base_ik;
                    base_ik = i_cnt * k_in;

                    begin : step_calc_block
                        reg signed [31:0] val;
                        val = 0;
                        case (step_idx)
                            2'd0: val = base_ik + b_in - a_in;
                            2'd1: val = base_ik + b_in + a_in;
                            2'd2: val = base_ik - b_in - a_in;
                            2'd3: val = base_ik - b_in + a_in;
                        endcase
                        step_val_temp <= val[10:0]; // Truncate to 11 bits signed (should be safe as S <= 1024)
                    end

                    state <= CALC_GCD;
                    gcd_start <= 1;

                    reg signed [31:0] step_current;
                    step_current = 0;
                    case (step_idx)
                        2'd0: step_current = base_ik + b_in - a_in;
                        2'd1: step_current = base_ik + b_in + a_in;
                        2'd2: step_current = base_ik - b_in - a_in;
                        2'd3: step_current = base_ik - b_in + a_in;
                    endcase

                    reg [10:0] l_temp;
                    integer mod_res;

                    if (S_reg == 0) l_temp = 0; // Avoid div by zero
                    else begin
                        mod_res = step_current % S_reg;
                        if (mod_res < 0)
                            mod_res = mod_res + S_reg;
                        l_temp = mod_res;
                    end

                    L_reg <= l_temp;
                    if (l_temp == 0) begin
                        gcd_res_reg <= S_reg; // Placeholder for GCD result
                        state <= UPDATE_RESULT;
                        gcd_start <= 0;
                    end else begin
                        state <= CALC_GCD;
                        gcd_start <= 1;
                    end
                end

                CALC_GCD: begin
                    gcd_start <= 0; // Pulse down
                    if (gcd_done) begin
                        state <= UPDATE_RESULT;
                        gcd_res_reg <= gcd_res;
                    end
                end

                UPDATE_RESULT: begin
                    reg [31:0] current_stops;
                    if (gcd_res_reg != 0)
                        current_stops = S_reg / gcd_res_reg;
                    else
                        current_stops = 32'hFFFF_FFFF; // Error case

                    if (current_stops < min_stops)
                        min_stops <= current_stops;
                    if (current_stops > max_stops)
                        max_stops <= current_stops;

                    if (step_idx == 3) begin
                        step_idx <= 0;
                        if (i_cnt == (n_in - 1)) begin
                            state <= DONE;
                        end else begin
                            i_cnt <= i_cnt + 1;
                            state <= ITERATE_LOOP;
                        end
                    end else begin
                        step_idx <= step_idx + 1;
                        state <= ITERATE_LOOP;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start)
                        state <= IDLE;
                    else 
                        state <= DONE;
                end
            endcase
        end
    end

endmodule

module gcd_unit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [10:0] a_in,
    input wire [10:0] b_in,
    output reg [10:0] gcd_out,
    output reg done
    );

    reg [10:0] a_reg, b_reg;
    reg busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            done <= 0;
            gcd_out <= 0;
        end else begin
            if (start && !busy) begin
                a_reg <= a_in;
                b_reg <= b_in;
                busy <= 1;
                done <= 0;
            end else if (busy) begin
                if (a_reg == b_reg) begin
                    gcd_out <= a_reg;
                    done <= 1;
                    busy <= 0;
                end else if (a_reg > b_reg) begin
                    a_reg <= a_reg - b_reg;
                end else begin
                    b_reg <= b_reg - a_reg;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule