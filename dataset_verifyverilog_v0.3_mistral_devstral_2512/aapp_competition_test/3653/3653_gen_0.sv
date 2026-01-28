module dog_chain (
    input clk,
    input rst_n,
    input start,
    input [15:0] L,
    input signed [15:0] x1, y1, x2, y2,
    output reg done,
    output reg [7:0] R
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_ABC = 3'd1;
    localparam [2:0] COMPUTE_SQRT = 3'd2;
    localparam [2:0] COMPUTE_D = 3'd3;
    localparam [2:0] ITER_LOOP = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] L_reg;
    reg signed [15:0] x1_reg, y1_reg, x2_reg, y2_reg;
    reg signed [31:0] a, b, c;
    reg [31:0] S;
    reg [31:0] denom;
    reg [31:0] d_val;
    reg [7:0] r_iter;
    reg [31:0] area_val;
    reg [31:0] l_val;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // PI in Q16.16 format
    localparam [31:0] PI_FIXED = 32'd205887;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            R <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_ABC;
                end
            end

            COMPUTE_ABC: begin
                next_state = COMPUTE_SQRT;
            end

            COMPUTE_SQRT: begin
                next_state = COMPUTE_D;
            end

            COMPUTE_D: begin
                next_state = ITER_LOOP;
            end

            ITER_LOOP: begin
                if (r_iter >= 8'd200 || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            L_reg <= 16'd0;
            x1_reg <= 16'd0;
            y1_reg <= 16'd0;
            x2_reg <= 16'd0;
            y2_reg <= 16'd0;
            a <= 32'd0;
            b <= 32'd0;
            c <= 32'd0;
            S <= 32'd0;
            denom <= 32'd0;
            d_val <= 32'd0;
            r_iter <= 8'd0;
            area_val <= 32'd0;
            l_val <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end

                COMPUTE_ABC: begin
                    L_reg <= L;
                    x1_reg <= x1;
                    y1_reg <= y1;
                    x2_reg <= x2;
                    y2_reg <= y2;
                    a <= y2_reg - y1_reg;
                    b <= x1_reg - x2_reg;
                    c <= x2_reg * y1_reg - x1_reg * y2_reg;
                    l_val <= L_reg << 16;
                end

                COMPUTE_SQRT: begin
                    S <= a * a + b * b;
                end

                COMPUTE_D: begin
                    // Compute denominator = sqrt(S)
                    // Using iterative approximation
                    reg [31:0] temp_denom;
                    temp_denom = 32'd0;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        temp_denom = (temp_denom + (S >> temp_denom)) >> 1;
                    end
                    denom <= temp_denom;
                    d_val <= (c < 0) ? -c : c;
                    d_val <= (d_val << 16) / denom;
                end

                ITER_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (r_iter < 8'd200) begin
                        reg [31:0] x;
                        reg [31:0] arccos_x;
                        reg [31:0] sqrt_1_x2;
                        reg [31:0] R_sq;
                        reg [31:0] d_sq;

                        R_sq = r_iter * r_iter;
                        d_sq = (d_val * d_val) >> 16;

                        if (d_sq >= R_sq) begin
                            area_val <= PI_FIXED * R_sq;
                        end else begin
                            x = (d_val << 16) / r_iter;
                            arccos_x = compute_arccos(x);
                            sqrt_1_x2 = compute_sqrt_1_x2(x);
                            area_val <= PI_FIXED * R_sq - (R_sq * arccos_x) + (d_val * sqrt_1_x2);
                        end

                        if (area_val >= l_val) begin
                            R <= r_iter;
                        end else begin
                            r_iter <= r_iter + 8'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    L_reg <= 16'd0;
                    x1_reg <= 16'd0;
                    y1_reg <= 16'd0;
                    x2_reg <= 16'd0;
                    y2_reg <= 16'd0;
                    a <= 32'd0;
                    b <= 32'd0;
                    c <= 32'd0;
                    S <= 32'd0;
                    denom <= 32'd0;
                    d_val <= 32'd0;
                    r_iter <= 8'd0;
                    area_val <= 32'd0;
                    l_val <= 32'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

    // Helper functions for arccos and sqrt(1-x^2)
    function [31:0] compute_arccos(input [31:0] x);
        reg [31:0] result;
        reg [31:0] x_sq;
        reg [31:0] term;
        reg [31:0] sum;
        integer i;

        x_sq = (x * x) >> 16;
        sum = 32'd0;
        term = x;

        for (i = 0; i < 10; i = i + 1) begin
            term = (term * x_sq) >> 16;
            if (i % 2 == 0) begin
                sum = sum + term / (i + 1);
            end else begin
                sum = sum - term / (i + 1);
            end
        end

        result = PI_FIXED / 2 - sum;
        compute_arccos = result;
    endfunction

    function [31:0] compute_sqrt_1_x2(input [31:0] x);
        reg [31:0] result;
        reg [31:0] x_sq;
        reg [31:0] temp;

        x_sq = (x * x) >> 16;
        temp = 32'd1 << 16;

        for (integer i = 0; i < 16; i = i + 1) begin
            temp = (temp + (32'd1 << 16) - x_sq) / 2;
        end

        result = temp;
        compute_sqrt_1_x2 = result;
    endfunction

endmodule