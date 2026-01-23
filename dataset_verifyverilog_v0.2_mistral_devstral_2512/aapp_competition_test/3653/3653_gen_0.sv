module dog_chain_solver (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] x1, y1, x2, y2,
    input [15:0] L,
    output reg [15:0] R_result,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        CALC_D_NOM,
        CALC_D_DENOM,
        CALC_D,
        INIT_SEARCH,
        CALC_AREA_R_SQ,
        CALC_AREA_ACOS,
        CALC_AREA_SQRT,
        UPDATE,
        DONE
    } state_t;

    state_t state;

    // Fixed-point Q16.16
    typedef logic [31:0] q16_16;

    // Internal registers
    q16_16 d_fixed;
    q16_16 R_fixed;
    q16_16 R_sq_fixed;
    q16_16 d_sq_fixed;
    q16_16 temp_fixed;
    q16_16 area_fixed;

    reg [15:0] R_int;
    reg [7:0] search_counter;
    reg [7:0] sqrt_counter;
    reg [7:0] acos_counter;

    reg [31:0] sqrt_val;
    reg [31:0] acos_val;

    // Distance calculation
    reg signed [31:0] nom;
    reg [31:0] denom;

    // Area calculation
    reg [31:0] d_sq;
    reg [31:0] R_sq;
    reg [31:0] d_over_R;
    reg [31:0] sqrt_R_sq_minus_d_sq;

    // Constants
    parameter PI_Q16_16 = 32'h0001_921F; // pi in Q16.16
    parameter HALF_PI_Q16_16 = 32'h0000_C90F; // pi/2 in Q16.16

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            R_result <= 0;
            d_fixed <= 0;
            R_fixed <= 0;
            R_sq_fixed <= 0;
            d_sq_fixed <= 0;
            temp_fixed <= 0;
            area_fixed <= 0;
            R_int <= 0;
            search_counter <= 0;
            sqrt_counter <= 0;
            acos_counter <= 0;
            sqrt_val <= 0;
            acos_val <= 0;
            nom <= 0;
            denom <= 0;
            d_sq <= 0;
            R_sq <= 0;
            d_over_R <= 0;
            sqrt_R_sq_minus_d_sq <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALC_D_NOM;
                    end
                end

                CALC_D_NOM: begin
                    // Calculate numerator: |x2*y1 - y2*x1|
                    nom = $signed({x2, 16'b0}) * $signed({y1, 16'b0}) - $signed({y2, 16'b0}) * $signed({x1, 16'b0});
                    if (nom[31]) nom = -nom;
                    state <= CALC_D_DENOM;
                end

                CALC_D_DENOM: begin
                    // Calculate denominator: sqrt((y2-y1)^2 + (x2-x1)^2)
                    reg signed [15:0] dx = x2 - x1;
                    reg signed [15:0] dy = y2 - y1;
                    denom = $signed({dx, 16'b0}) * $signed({dx, 16'b0}) + $signed({dy, 16'b0}) * $signed({dy, 16'b0});
                    state <= CALC_D;
                end

                CALC_D: begin
                    // Calculate d = nom / sqrt(denom)
                    if (denom == 0) begin
                        d_fixed <= 0;
                    end else begin
                        // Newton-Raphson for sqrt
                        reg [31:0] x = 32'h4000_0000; // Initial guess (1.0 in Q16.16)
                        reg [31:0] x_next;
                        reg [31:0] denom_fixed = {16'b0, denom[31:16]};
                        for (int i = 0; i < 10; i++) begin
                            x_next = x - ((x * x - denom_fixed) >> 1) / x;
                            x = x_next;
                        end
                        d_fixed <= nom / x;
                    end
                    state <= INIT_SEARCH;
                end

                INIT_SEARCH: begin
                    R_int <= 1;
                    search_counter <= 0;
                    state <= CALC_AREA_R_SQ;
                end

                CALC_AREA_R_SQ: begin
                    // Calculate R^2 in Q16.16
                    R_fixed = {16'b0, R_int};
                    R_sq_fixed = R_fixed * R_fixed;
                    state <= CALC_AREA_ACOS;
                end

                CALC_AREA_ACOS: begin
                    // Calculate acos(d/R) or acos(-d/R)
                    if (d_fixed == 0) begin
                        acos_val = HALF_PI_Q16_16;
                    end else if (d_fixed >= R_fixed) begin
                        acos_val = 0;
                    end else begin
                        // Calculate d/R
                        d_over_R = (d_fixed << 16) / R_fixed;
                        // Approximate acos using polynomial
                        reg [31:0] x = d_over_R;
                        reg [31:0] x_sq = x * x;
                        reg [31:0] x_cu = x_sq * x;
                        acos_val = HALF_PI_Q16_16 - x - (x_cu >> 6); // Simplified approximation
                    end
                    state <= CALC_AREA_SQRT;
                end

                CALC_AREA_SQRT: begin
                    // Calculate sqrt(R^2 - d^2)
                    if (d_fixed >= R_fixed) begin
                        sqrt_R_sq_minus_d_sq = 0;
                    end else begin
                        reg [31:0] R_sq_minus_d_sq = R_sq_fixed - (d_fixed * d_fixed);
                        reg [31:0] x = 32'h4000_0000; // Initial guess (1.0 in Q16.16)
                        reg [31:0] x_next;
                        for (int i = 0; i < 10; i++) begin
                            x_next = x - ((x * x - R_sq_minus_d_sq) >> 1) / x;
                            x = x_next;
                        end
                        sqrt_R_sq_minus_d_sq = x;
                    end
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Calculate area
                    if (d_fixed == 0) begin
                        area_fixed = (R_sq_fixed * PI_Q16_16) >> 16;
                    end else if (d_fixed >= R_fixed) begin
                        area_fixed = (R_sq_fixed * PI_Q16_16) >> 16;
                    end else begin
                        area_fixed = (R_sq_fixed * acos_val) >> 16 + (d_fixed * sqrt_R_sq_minus_d_sq) >> 16;
                    end

                    // Compare with L (convert L to Q16.16)
                    reg [31:0] L_fixed = {16'b0, L};
                    if (area_fixed >= L_fixed) begin
                        R_result <= R_int;
                        state <= DONE;
                    end else begin
                        R_int <= R_int + 1;
                        if (R_int > 256) begin
                            R_result <= 256;
                            state <= DONE;
                        end else begin
                            state <= CALC_AREA_R_SQ;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule