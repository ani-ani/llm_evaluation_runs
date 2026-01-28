module LCM_Finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE    = 4'd0;
    localparam [3:0] INIT    = 4'd1;
    localparam [3:0] LOOP_I  = 4'd2;
    localparam [3:0] LOOP_J  = 4'd3;
    localparam [3:0] LOOP_K  = 4'd4;
    localparam [3:0] GCD1    = 4'd5;
    localparam [3:0] LCM1    = 4'd6;
    localparam [3:0] GCD2    = 4'd7;
    localparam [3:0] LCM2    = 4'd8;
    localparam [3:0] UPDATE  = 4'd9;
    localparam [3:0] DONE    = 4'd10;

    // Register declarations
    reg [3:0] state, next_state;
    reg [15:0] i_reg, j_reg, k_reg, search_start;
    reg [31:0] max_lcm, current_lcm;
    reg [15:0] a_gcd1, b_gcd1, a_gcd2, b_gcd2;
    reg [31:0] product1, product2;
    reg [15:0] gcd1_result, gcd2_result;
    reg [31:0] lcm1_result, lcm2_result;
    reg [15:0] temp_a, temp_b;
    reg [31:0] temp_product;
    reg [15:0] temp_gcd;
    reg [31:0] temp_lcm;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd300000;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_reg <= 16'd0;
            j_reg <= 16'd0;
            k_reg <= 16'd0;
            search_start <= 16'd0;
            max_lcm <= 32'd0;
            current_lcm <= 32'd0;
            a_gcd1 <= 16'd0;
            b_gcd1 <= 16'd0;
            a_gcd2 <= 16'd0;
            b_gcd2 <= 16'd0;
            product1 <= 32'd0;
            product2 <= 32'd0;
            gcd1_result <= 16'd0;
            gcd2_result <= 16'd0;
            lcm1_result <= 32'd0;
            lcm2_result <= 32'd0;
            temp_a <= 16'd0;
            temp_b <= 16'd0;
            temp_product <= 32'd0;
            temp_gcd <= 16'd0;
            temp_lcm <= 32'd0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    i_reg <= n;
                    search_start <= (n > 16'd63) ? (n - 16'd63) : 16'd1;
                    max_lcm <= 32'd0;
                    cycle_count <= 16'd0;
                    next_state <= LOOP_I;
                end

                LOOP_I: begin
                    if (i_reg < search_start) begin
                        next_state <= DONE;
                    end else begin
                        j_reg <= i_reg;
                        next_state <= LOOP_J;
                    end
                end

                LOOP_J: begin
                    if (j_reg < search_start) begin
                        i_reg <= i_reg - 16'd1;
                        next_state <= LOOP_I;
                    end else begin
                        k_reg <= j_reg;
                        next_state <= LOOP_K;
                    end
                end

                LOOP_K: begin
                    if (k_reg < search_start) begin
                        j_reg <= j_reg - 16'd1;
                        next_state <= LOOP_J;
                    end else begin
                        a_gcd1 <= i_reg;
                        b_gcd1 <= j_reg;
                        next_state <= GCD1;
                    end
                end

                GCD1: begin
                    if (a_gcd1 == b_gcd1) begin
                        gcd1_result <= a_gcd1;
                        next_state <= LCM1;
                    end else if (a_gcd1 > b_gcd1) begin
                        a_gcd1 <= a_gcd1 - b_gcd1;
                    end else begin
                        b_gcd1 <= b_gcd1 - a_gcd1;
                    end
                end

                LCM1: begin
                    product1 <= {16'd0, i_reg} * {16'd0, j_reg};
                    if (gcd1_result == 16'd0) begin
                        lcm1_result <= 32'd0;
                    end else begin
                        lcm1_result <= product1 / gcd1_result;
                    end
                    a_gcd2 <= lcm1_result[15:0];
                    b_gcd2 <= k_reg;
                    next_state <= GCD2;
                end

                GCD2: begin
                    if (a_gcd2 == b_gcd2) begin
                        gcd2_result <= a_gcd2;
                        next_state <= LCM2;
                    end else if (a_gcd2 > b_gcd2) begin
                        a_gcd2 <= a_gcd2 - b_gcd2;
                    end else begin
                        b_gcd2 <= b_gcd2 - a_gcd2;
                    end
                end

                LCM2: begin
                    product2 <= lcm1_result * {16'd0, k_reg};
                    if (gcd2_result == 16'd0) begin
                        lcm2_result <= 32'd0;
                    end else begin
                        lcm2_result <= product2 / gcd2_result;
                    end
                    next_state <= UPDATE;
                end

                UPDATE: begin
                    if (lcm2_result > max_lcm) begin
                        max_lcm <= lcm2_result;
                    end
                    k_reg <= k_reg - 16'd1;
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end else begin
                        next_state <= LOOP_K;
                    end
                end

                DONE: begin
                    result <= max_lcm;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Combinational logic for next state
    always @(*) begin
        next_state = state;
    end

endmodule