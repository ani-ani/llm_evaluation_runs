module best_friends(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd998244353;
    localparam INV2 = 32'd499122177;
    localparam INV5 = 32'd598946612;
    localparam MULT1000 = 32'd1000;
    localparam MULT4 = 32'd4;

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_POW5_NM1 = 3'b001;
    localparam CALC_POW5_N = 3'b010;
    localparam CALC_COMP_A = 3'b011;
    localparam CALC_COMP_B = 3'b100;
    localparam CALC_COMP_SUB = 3'b101;
    localparam CALC_FINAL_1 = 3'b110;
    localparam CALC_FINAL_2 = 3'b111;
    localparam DONE = 4'b1000;

    reg [3:0] state;
    reg [3:0] sub_state;
    reg [3:0] n_reg;
    reg [3:0] loop_cnt;
    reg [31:0] p5_nm1;
    reg [31:0] p5_n;
    reg [31:0] comp;
    reg [31:0] term1;
    reg [31:0] term2;
    reg [31:0] res_val;
    reg [31:0] val_a;
    reg [31:0] val_b;
    reg [31:0] temp;
    reg [31:0] step;

    // State logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sub_state <= 0;
            done <= 0;
            result <= 0;
            p5_nm1 <= 0;
            p5_n <= 0;
            comp <= 0;
            term1 <= 0;
            term2 <= 0;
            res_val <= 0;
            val_a <= 0;
            val_b <= 0;
            temp <= 0;
            step <= 0;
            loop_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n;
                        if (n == 0) begin
                            result <= 0;
                            done <= 1;
                        end else if (n == 1) begin
                            result <= 10;
                            done <= 1;
                        end else begin
                            state <= CALC_POW5_NM1;
                            loop_cnt <= n - 1;
                            p5_nm1 <= 1;
                            sub_state <= 0;
                        end
                    end
                end

                CALC_POW5_NM1: begin
                    if (sub_state == 0) begin
                        val_a <= p5_nm1;
                        val_b <= 5;
                        sub_state <= 1;
                        step <= 0;
                    end else if (sub_state == 1) begin
                        if (step < 32) begin
                            if (val_b[0]) begin
                                temp <= val_a + temp;
                            end
                            temp <= temp >> 1;
                            val_b <= val_b >> 1;
                            step <= step + 1;
                        end else begin
                            p5_nm1 <= temp;
                            sub_state <= 2;
                            step <= 0;
                        end
                    end else if (sub_state == 2) begin
                        if (p5_nm1 >= MOD) begin
                            p5_nm1 <= p5_nm1 - MOD;
                        end else begin
                            if (loop_cnt > 0) begin
                                loop_cnt <= loop_cnt - 1;
                                sub_state <= 0;
                            end else begin
                                state <= CALC_POW5_N;
                                p5_n <= p5_nm1 * 5;
                                if (p5_n >= MOD) begin
                                    p5_n <= p5_n - MOD;
                                end
                                sub_state <= 0;
                            end
                        end
                    end
                end

                CALC_POW5_N: begin
                    if (sub_state == 0) begin
                        val_a <= p5_n;
                        val_b <= 1000;
                        sub_state <= 1;
                        step <= 0;
                    end else if (sub_state == 1) begin
                        if (step < 32) begin
                            if (val_b[0]) begin
                                temp <= val_a + temp;
                            end
                            temp <= temp >> 1;
                            val_b <= val_b >> 1;
                            step <= step + 1;
                        end else begin
                            term1 <= temp;
                            sub_state <= 2;
                            step <= 0;
                        end
                    end else if (sub_state == 2) begin
                        if (term1 >= MOD) begin
                            term1 <= term1 - MOD;
                        end else begin
                            if (n_reg[0]) begin
                                comp <= term1;
                                state <= CALC_FINAL_1;
                            end else begin
                                state <= CALC_COMP_B;
                                sub_state <= 0;
                            end
                        end
                    end
                end

                CALC_COMP_B: begin
                    if (sub_state == 0) begin
                        val_a <= p5_nm1;
                        val_b <= 4;
                        sub_state <= 1;
                        step <= 0;
                    end else if (sub_state == 1) begin
                        if (step < 32) begin
                            if (val_b[0]) begin
                                temp <= val_a + temp;
                            end
                            temp <= temp >> 1;
                            val_b <= val_b >> 1;
                            step <= step + 1;
                        end else begin
                            term2 <= temp;
                            sub_state <= 2;
                            step <= 0;
                        end
                    end else if (sub_state == 2) begin
                        if (term2 >= MOD) begin
                            term2 <= term2 - MOD;
                        end else begin
                            state <= CALC_COMP_SUB;
                            sub_state <= 0;
                        end
                    end
                end

                CALC_COMP_SUB: begin
                    if (term1 >= term2) begin
                        comp <= term1 - term2;
                    end else begin
                        comp <= term1 + MOD - term2;
                    end
                    state <= CALC_FINAL_1;
                end

                CALC_FINAL_1: begin
                    if (sub_state == 0) begin
                        val_a <= comp;
                        val_b <= comp - 1;
                        sub_state <= 1;
                        step <= 0;
                    end else if (sub_state == 1) begin
                        if (step < 32) begin
                            if (val_b[0]) begin
                                temp <= val_a + temp;
                            end
                            temp <= temp >> 1;
                            val_b <= val_b >> 1;
                            step <= step + 1;
                        end else begin
                            res_val <= temp;
                            sub_state <= 2;
                            step <= 0;
                        end
                    end else if (sub_state == 2) begin
                        if (res_val >= MOD) begin
                            res_val <= res_val - MOD;
                        end else begin
                            state <= CALC_FINAL_2;
                            sub_state <= 0;
                        end
                    end
                end

                CALC_FINAL_2: begin
                    if (sub_state == 0) begin
                        val_a <= res_val;
                        val_b <= INV2;
                        sub_state <= 1;
                        step <= 0;
                    end else if (sub_state == 1) begin
                        if (step < 32) begin
                            if (val_b[0]) begin
                                temp <= val_a + temp;
                            end
                            temp <= temp >> 1;
                            val_b <= val_b >> 1;
                            step <= step + 1;
                        end else begin
                            result <= temp;
                            sub_state <= 2;
                            step <= 0;
                        end
                    end else if (sub_state == 2) begin
                        if (result >= MOD) begin
                            result <= result - MOD;
                        end else begin
                            state <= DONE;
                            done <= 1;
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule
