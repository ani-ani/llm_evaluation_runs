module sequence_in_gcd_table (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] n,
    input wire [63:0] m,
    input wire [3:0] k,
    input wire [63:0] a [0:7],
    output reg result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_LCM = 3'd1;
    localparam [2:0] SOLVE_CRT = 3'd2;
    localparam [2:0] CHECK_GCD = 3'd3;
    localparam [2:0] VERIFY_RESULT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [63:0] lcm_val;
    reg [63:0] crt_R, crt_M;
    reg [3:0] iter_idx;
    reg [63:0] gcd_a, gcd_b;
    reg gcd_start;
    wire [63:0] gcd_result;
    wire gcd_done;
    reg [63:0] j0;
    reg [63:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    gcd_unit gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a(gcd_a),
        .b(gcd_b),
        .result(gcd_result),
        .done(gcd_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            lcm_val <= 64'd1;
            crt_R <= 64'd0;
            crt_M <= 64'd1;
            iter_idx <= 4'd0;
            j0 <= 64'd0;
            gcd_start <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_LCM;
                        iter_idx <= 4'd0;
                        lcm_val <= 64'd1;
                        cycle_count <= 8'd0;
                    end
                end

                COMPUTE_LCM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (iter_idx < k && cycle_count < MAX_CYCLES) begin
                        if (!gcd_start) begin
                            gcd_a <= lcm_val;
                            gcd_b <= a[iter_idx];
                            gcd_start <= 1'b1;
                        end else if (gcd_done) begin
                            gcd_start <= 1'b0;
                            if (gcd_result != 64'd0) begin
                                temp_result <= (lcm_val * a[iter_idx]) / gcd_result;
                                if (temp_result > n) begin
                                    result <= 1'b0;
                                    state <= FINISH;
                                end else begin
                                    lcm_val <= temp_result;
                                    iter_idx <= iter_idx + 4'd1;
                                end
                            end else begin
                                result <= 1'b0;
                                state <= FINISH;
                            end
                        end
                    end else begin
                        if (cycle_count >= MAX_CYCLES) begin
                            result <= 1'b0;
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
                    cycle_count <= cycle_count + 8'd1;
                    if (iter_idx < k && cycle_count < MAX_CYCLES) begin
                        state <= SOLVE_CRT;
                        iter_idx <= iter_idx + 4'd1;
                    end else begin
                        if (cycle_count >= MAX_CYCLES) begin
                            result <= 1'b0;
                            state <= FINISH;
                        end else begin
                            j0 <= crt_R;
                            state <= CHECK_GCD;
                            iter_idx <= 4'd0;
                        end
                    end
                end

                CHECK_GCD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (iter_idx < k && cycle_count < MAX_CYCLES) begin
                        if (!gcd_start) begin
                            gcd_a <= lcm_val;
                            gcd_b <= j0 + iter_idx;
                            gcd_start <= 1'b1;
                        end else if (gcd_done) begin
                            gcd_start <= 1'b0;
                            if (gcd_result != a[iter_idx]) begin
                                result <= 1'b0;
                                state <= FINISH;
                            end else if (iter_idx == k - 4'd1) begin
                                state <= VERIFY_RESULT;
                            end
                            iter_idx <= iter_idx + 4'd1;
                        end
                    end else begin
                        if (cycle_count >= MAX_CYCLES) begin
                            result <= 1'b0;
                            state <= FINISH;
                        end
                    end
                end

                VERIFY_RESULT: begin
                    if (j0 + k - 4'd1 <= m && j0 >= 64'd1) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
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

module gcd_unit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] a,
    input wire [63:0] b,
    output reg [63:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [63:0] x, y;
    reg [63:0] a_reg, b_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        a_reg <= a;
                        b_reg <= b;
                        state <= COMPUTE;
                        done <= 1'b0;
                    end
                end

                COMPUTE: begin
                    if (b_reg == 64'd0) begin
                        result <= a_reg;
                        state <= FINISH;
                    end else begin
                        x <= a_reg;
                        y <= b_reg;
                        a_reg <= y;
                        b_reg <= x % y;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule