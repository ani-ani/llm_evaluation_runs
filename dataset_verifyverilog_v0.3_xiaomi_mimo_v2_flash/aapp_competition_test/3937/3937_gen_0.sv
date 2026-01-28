module sequence_in_gcd_table (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] n,
    input wire [63:0] m,
    input wire [3:0] k,
    input wire [63:0] a_0,
    input wire [63:0] a_1,
    input wire [63:0] a_2,
    input wire [63:0] a_3,
    input wire [63:0] a_4,
    input wire [63:0] a_5,
    input wire [63:0] a_6,
    input wire [63:0] a_7,
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_LCM = 4'd1;
    localparam [3:0] SOLVE_CRT = 4'd2;
    localparam [3:0] CHECK_GCD = 4'd3;
    localparam [3:0] VERIFY_RESULT = 4'd4;
    localparam [3:0] FINISH = 4'd5;

    reg [3:0] state;
    reg [63:0] lcm_val;
    reg [63:0] crt_R;
    reg [63:0] crt_M;
    reg [3:0] iter_idx;
    reg [63:0] gcd_a;
    reg [63:0] gcd_b;
    reg gcd_start;
    wire [63:0] gcd_result;
    wire gcd_done;
    reg [63:0] j0;
    reg [63:0] temp_result;
    reg [63:0] a_reg [0:7];
    reg [1:0] gcd_state;
    reg [63:0] x_reg;
    reg [63:0] y_reg;
    reg [63:0] a_gcd;
    reg [63:0] b_gcd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            lcm_val <= 64'd1;
            crt_R <= 64'd0;
            crt_M <= 64'd1;
            iter_idx <= 4'd0;
            j0 <= 64'd0;
            gcd_start <= 0;
            gcd_state <= 2'd0;
            a_gcd <= 64'd0;
            b_gcd <= 64'd0;
            x_reg <= 64'd0;
            y_reg <= 64'd0;
            a_reg[0] <= 64'd0;
            a_reg[1] <= 64'd0;
            a_reg[2] <= 64'd0;
            a_reg[3] <= 64'd0;
            a_reg[4] <= 64'd0;
            a_reg[5] <= 64'd0;
            a_reg[6] <= 64'd0;
            a_reg[7] <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE_LCM;
                        iter_idx <= 4'd0;
                        lcm_val <= 64'd1;
                        a_reg[0] <= a_0;
                        a_reg[1] <= a_1;
                        a_reg[2] <= a_2;
                        a_reg[3] <= a_3;
                        a_reg[4] <= a_4;
                        a_reg[5] <= a_5;
                        a_reg[6] <= a_6;
                        a_reg[7] <= a_7;
                    end
                end

                COMPUTE_LCM: begin
                    if (iter_idx < k) begin
                        if (!gcd_start) begin
                            gcd_a <= lcm_val;
                            gcd_b <= a_reg[iter_idx];
                            gcd_start <= 1;
                            gcd_state <= 2'd0;
                            a_gcd <= lcm_val;
                            b_gcd <= a_reg[iter_idx];
                        end else begin
                            if (gcd_state == 2'd0) begin
                                if (b_gcd == 64'd0) begin
                                    gcd_result <= a_gcd;
                                    gcd_done <= 1'b1;
                                    gcd_state <= 2'd2;
                                end else begin
                                    x_reg <= a_gcd;
                                    y_reg <= b_gcd;
                                    a_gcd <= b_gcd;
                                    if (y_reg != 0) begin
                                        b_gcd <= x_reg % y_reg;
                                    end
                                    gcd_state <= 2'd1;
                                end
                            end else if (gcd_state == 2'd1) begin
                                if (b_gcd == 64'd0) begin
                                    gcd_result <= a_gcd;
                                    gcd_done <= 1'b1;
                                    gcd_state <= 2'd2;
                                end else begin
                                    x_reg <= a_gcd;
                                    y_reg <= b_gcd;
                                    a_gcd <= b_gcd;
                                    if (y_reg != 0) begin
                                        b_gcd <= x_reg % y_reg;
                                    end
                                end
                            end else begin
                                gcd_start <= 0;
                                gcd_done <= 1'b0;
                                if (gcd_result != 0) begin
                                    temp_result <= (lcm_val * a_reg[iter_idx]) / gcd_result;
                                    state <= COMPUTE_LCM;
                                end else begin
                                    state <= FINISH;
                                    result <= 0;
                                end
                                iter_idx <= iter_idx + 1;
                                lcm_val <= temp_result;
                            end
                        end
                    end else begin
                        if (lcm_val > n) begin
                            result <= 0;
                            state <= FINISH;
                        end else begin
                            state <= SOLVE_CRT;
                            iter_idx <= 4'd0;
                            crt_R <= 64'd0;
                            crt_M <= 64'd1;
                        end
                    end
                end

                SOLVE_CRT: begin
                    if (iter_idx < k) begin
                        state <= SOLVE_CRT;
                        iter_idx <= iter_idx + 1;
                    end else begin
                        j0 <= crt_R;
                        state <= CHECK_GCD;
                        iter_idx <= 4'd0;
                    end
                end

                CHECK_GCD: begin
                    if (iter_idx < k) begin
                        if (!gcd_start) begin
                            gcd_a <= lcm_val;
                            gcd_b <= j0 + iter_idx;
                            gcd_start <= 1;
                            gcd_state <= 2'd0;
                            a_gcd <= lcm_val;
                            b_gcd <= j0 + iter_idx;
                        end else begin
                            if (gcd_state == 2'd0) begin
                                if (b_gcd == 64'd0) begin
                                    gcd_result <= a_gcd;
                                    gcd_done <= 1'b1;
                                    gcd_state <= 2'd2;
                                end else begin
                                    x_reg <= a_gcd;
                                    y_reg <= b_gcd;
                                    a_gcd <= b_gcd;
                                    if (y_reg != 0) begin
                                        b_gcd <= x_reg % y_reg;
                                    end
                                    gcd_state <= 2'd1;
                                end
                            end else if (gcd_state == 2'd1) begin
                                if (b_gcd == 64'd0) begin
                                    gcd_result <= a_gcd;
                                    gcd_done <= 1'b1;
                                    gcd_state <= 2'd2;
                                end else begin
                                    x_reg <= a_gcd;
                                    y_reg <= b_gcd;
                                    a_gcd <= b_gcd;
                                    if (y_reg != 0) begin
                                        b_gcd <= x_reg % y_reg;
                                    end
                                end
                            end else begin
                                gcd_start <= 0;
                                gcd_done <= 1'b0;
                                if (gcd_result != a_reg[iter_idx]) begin
                                    result <= 0;
                                    state <= FINISH;
                                end else if (iter_idx == k - 1) begin
                                    state <= VERIFY_RESULT;
                                end
                                iter_idx <= iter_idx + 1;
                            end
                        end
                    end
                end

                VERIFY_RESULT: begin
                    if (j0 + k - 1 <= m && j0 >= 1) begin
                        result <= 1;
                    end else begin
                        result <= 0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule