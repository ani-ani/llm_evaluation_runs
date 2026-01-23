module pokenom_painter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] M,
    input wire [3:0] N,
    input wire [3:0] c_0, c_1, c_2, c_3, c_4, c_5, c_6, c_7,
    output reg done,
    output reg [31:0] X,
    output reg [31:0] Y_m
);

    parameter MOD = 100003;

    // State definitions
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] READ_C = 5'd1;
    localparam [4:0] COMPUTE_T = 5'd2;
    localparam [4:0] SETUP_FACT = 5'd3;
    localparam [4:0] COMPUTE_FACT = 5'd4;
    localparam [4:0] SETUP_BLUE = 5'd5;
    localparam [4:0] COMPUTE_BLUE = 5'd6;
    localparam [4:0] SETUP_RED = 5'd7;
    localparam [4:0] COMPUTE_RED = 5'd8;
    localparam [4:0] COMPUTE_NUMERATOR = 5'd9;
    localparam [4:0] COMPUTE_DENOMINATOR = 5'd10;
    localparam [4:0] COMPUTE_INV_SETUP = 5'd11;
    localparam [4:0] COMPUTE_INV_LOOP = 5'd12;
    localparam [4:0] COMPUTE_INV_DONE = 5'd13;
    localparam [4:0] COMPUTE_RESULT = 5'd14;
    localparam [4:0] DONE_STATE = 5'd15;

    // Internal registers
    reg [4:0] state;
    reg [3:0] i, j, k;
    reg [7:0] S, T, T_minus_2;
    reg [31:0] fact, H_blue, H_red, numerator, denominator, inv_denom;
    reg [3:0] c_reg_0, c_reg_1, c_reg_2, c_reg_3, c_reg_4, c_reg_5, c_reg_6, c_reg_7;
    reg [3:0] B_cols, R_cols;
    reg [3:0] red_col_heights_0, red_col_heights_1, red_col_heights_2, red_col_heights_3;
    reg [3:0] red_col_heights_4, red_col_heights_5, red_col_heights_6, red_col_heights_7;
    reg [31:0] a_euclid, b_euclid, x0_euclid, x1_euclid;
    reg [31:0] euclid_temp;
    reg signed [31:0] x0_signed, x1_signed, quotient_signed;
    reg euclid_done;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            X <= 32'd0;
            Y_m <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            S <= 8'd0;
            T <= 8'd0;
            T_minus_2 <= 8'd0;
            fact <= 32'd0;
            H_blue <= 32'd0;
            H_red <= 32'd0;
            numerator <= 32'd0;
            denominator <= 32'd0;
            inv_denom <= 32'd0;
            c_reg_0 <= 4'd0;
            c_reg_1 <= 4'd0;
            c_reg_2 <= 4'd0;
            c_reg_3 <= 4'd0;
            c_reg_4 <= 4'd0;
            c_reg_5 <= 4'd0;
            c_reg_6 <= 4'd0;
            c_reg_7 <= 4'd0;
            B_cols <= 4'd0;
            R_cols <= 4'd0;
            red_col_heights_0 <= 4'd0;
            red_col_heights_1 <= 4'd0;
            red_col_heights_2 <= 4'd0;
            red_col_heights_3 <= 4'd0;
            red_col_heights_4 <= 4'd0;
            red_col_heights_5 <= 4'd0;
            red_col_heights_6 <= 4'd0;
            red_col_heights_7 <= 4'd0;
            a_euclid <= 32'd0;
            b_euclid <= 32'd0;
            x0_euclid <= 32'd0;
            x1_euclid <= 32'd0;
            x0_signed <= 32'd0;
            x1_signed <= 32'd0;
            quotient_signed <= 32'd0;
            euclid_temp <= 32'd0;
            euclid_done <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            cycle_counter <= cycle_counter + 8'd1;
            if (cycle_counter >= MAX_CYCLES && state != IDLE) begin
                state <= DONE_STATE;
            end
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= READ_C;
                        i <= 4'd0;
                        S <= 8'd0;
                    end
                end

                READ_C: begin
                    if (i < N) begin
                        case (i)
                            4'd0: begin c_reg_0 <= c_0; S <= S + c_0; end
                            4'd1: begin c_reg_1 <= c_1; S <= S + c_1; end
                            4'd2: begin c_reg_2 <= c_2; S <= S + c_2; end
                            4'd3: begin c_reg_3 <= c_3; S <= S + c_3; end
                            4'd4: begin c_reg_4 <= c_4; S <= S + c_4; end
                            4'd5: begin c_reg_5 <= c_5; S <= S + c_5; end
                            4'd6: begin c_reg_6 <= c_6; S <= S + c_6; end
                            4'd7: begin c_reg_7 <= c_7; S <= S + c_7; end
                        endcase
                        i <= i + 4'd1;
                    end else begin
                        state <= COMPUTE_T;
                    end
                end

                COMPUTE_T: begin
                    T <= M * N;
                    T_minus_2 <= M * N - 8'd2;
                    state <= SETUP_FACT;
                    fact <= 32'd1;
                    i <= 4'd1;
                end

                SETUP_FACT: begin
                    if (i <= T_minus_2) begin
                        fact <= (fact * i) % MOD;
                        i <= i + 4'd1;
                    end else begin
                        state <= SETUP_BLUE;
                    end
                end

                SETUP_BLUE: begin
                    B_cols <= 4'd0;
                    for (k = 4'd0; k < 8'd8; k = k + 4'd1) begin
                        if (k < N) begin
                            if (get_c(k) > 4'd0) B_cols <= k + 4'd1;
                        end
                    end
                    H_blue <= 32'd1;
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= COMPUTE_BLUE;
                end

                COMPUTE_BLUE: begin
                    if (i < B_cols) begin
                        if (j < get_c(i)) begin
                            integer count_right;
                            count_right = 0;
                            for (k = i + 4'd1; k < B_cols; k = k + 4'd1) begin
                                if (get_c(k) > j) count_right = count_right + 1;
                            end
                            H_blue <= (H_blue * (j + count_right + 1)) % MOD;
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        state <= SETUP_RED;
                    end
                end

                SETUP_RED: begin
                    for (k = 4'd0; k < 8'd8; k = k + 4'd1) begin
                        if (k < N) begin
                            red_col_heights(k) <= M - get_c(N - 4'd1 - k);
                        end else begin
                            red_col_heights(k) <= 4'd0;
                        end
                    end
                    R_cols <= 4'd0;
                    for (k = 4'd0; k < 8'd8; k = k + 4'd1) begin
                        if (k < N) begin
                            if (get_red_height(k) > 4'd0) R_cols <= k + 4'd1;
                        end
                    end
                    H_red <= 32'd1;
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= COMPUTE_RED;
                end

                COMPUTE_RED: begin
                    if (i < R_cols) begin
                        if (j < get_red_height(i)) begin
                            integer count_right;
                            count_right = 0;
                            for (k = i + 4'd1; k < R_cols; k = k + 4'd1) begin
                                if (get_red_height(k) > j) count_right = count_right + 1;
                            end
                            H_red <= (H_red * (j + count_right + 1)) % MOD;
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        state <= COMPUTE_NUMERATOR;
                    end
                end

                COMPUTE_NUMERATOR: begin
                    numerator <= (((fact * S) % MOD) * (T - S)) % MOD;
                    state <= COMPUTE_DENOMINATOR;
                end

                COMPUTE_DENOMINATOR: begin
                    denominator <= (H_blue * H_red) % MOD;
                    state <= COMPUTE_INV_SETUP;
                end

                COMPUTE_INV_SETUP: begin
                    if (denominator == 32'd0) begin
                        inv_denom <= 32'd0;
                        state <= COMPUTE_INV_DONE;
                    end else begin
                        a_euclid <= denominator;
                        b_euclid <= MOD;
                        x0_euclid <= 32'd1;
                        x1_euclid <= 32'd0;
                        x0_signed <= 32'd1;
                        x1_signed <= 32'd0;
                        state <= COMPUTE_INV_LOOP;
                    end
                end

                COMPUTE_INV_LOOP: begin
                    if (b_euclid != 32'd0) begin
                        quotient_signed <= a_euclid / b_euclid;
                        euclid_temp <= a_euclid % b_euclid;
                        // Update x0, x1
                        x1_signed <= x0_signed - (a_euclid / b_euclid) * x1_signed;
                        x0_signed <= x1_signed;
                        a_euclid <= b_euclid;
                        b_euclid <= euclid_temp;
                    end else begin
                        state <= COMPUTE_INV_DONE;
                    end
                end

                COMPUTE_INV_DONE: begin
                    if (x0_signed < 0) begin
                        inv_denom <= x0_signed + MOD;
                    end else begin
                        inv_denom <= x0_signed % MOD;
                    end
                    state <= COMPUTE_RESULT;
                end

                COMPUTE_RESULT: begin
                    Y_m <= (numerator * inv_denom) % MOD;
                    X <= 32'd0;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    function automatic [3:0] get_c;
        input [3:0] idx;
        case (idx)
            4'd0: get_c = c_reg_0;
            4'd1: get_c = c_reg_1;
            4'd2: get_c = c_reg_2;
            4'd3: get_c = c_reg_3;
            4'd4: get_c = c_reg_4;
            4'd5: get_c = c_reg_5;
            4'd6: get_c = c_reg_6;
            4'd7: get_c = c_reg_7;
            default: get_c = 4'd0;
        endcase
    endfunction

    function automatic [3:0] get_red_height;
        input [3:0] idx;
        case (idx)
            4'd0: get_red_height = red_col_heights_0;
            4'd1: get_red_height = red_col_heights_1;
            4'd2: get_red_height = red_col_heights_2;
            4'd3: get_red_height = red_col_heights_3;
            4'd4: get_red_height = red_col_heights_4;
            4'd5: get_red_height = red_col_heights_5;
            4'd6: get_red_height = red_col_heights_6;
            4'd7: get_red_height = red_col_heights_7;
            default: get_red_height = 4'd0;
        endcase
    endfunction

    task red_col_heights;
        input [3:0] idx;
        input [3:0] val;
        case (idx)
            4'd0: red_col_heights_0 <= val;
            4'd1: red_col_heights_1 <= val;
            4'd2: red_col_heights_2 <= val;
            4'd3: red_col_heights_3 <= val;
            4'd4: red_col_heights_4 <= val;
            4'd5: red_col_heights_5 <= val;
            4'd6: red_col_heights_6 <= val;
            4'd7: red_col_heights_7 <= val;
        endcase
    endtask

endmodule