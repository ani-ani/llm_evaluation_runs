module DeliveryTimeSolver (
    input clk,
    input rst_n,
    input start,
    input [15:0] A_x, A_y,
    input [15:0] B_x, B_y,
    input [31:0] L_M,
    input [15:0] C_x, C_y,
    input [15:0] D_x, D_y,
    input [31:0] L_N,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_BIN   = 3'd1;
    localparam [2:0] CHECK_S    = 3'd2;
    localparam [2:0] UPDATE_BIN = 3'd3;
    localparam [2:0] FINISH     = 3'd4;
    localparam [2:0] IMPOSSIBLE = 3'd5;

    // Parameters
    localparam [15:0] SCALE         = 16'd256;
    localparam [31:0] SCALE_SQ      = 32'd65536;
    localparam [31:0] MAX_ITER      = 32'd24;
    localparam [31:0] UPPER_BOUND   = 32'h00FFFFFF; // ~16 million
    localparam [31:0] SHIFT_FRAC    = 32'd8;

    // Internal registers
    reg [2:0] state;
    reg [31:0] low, high, mid;
    reg [31:0] t1, t2;
    reg [7:0] s;
    reg [7:0] u;
    reg [15:0] Mx, My;
    reg [15:0] Nx, Ny;
    reg [31:0] dx, dy;
    reg [63:0] dist_sq_reg;
    reg [31:0] threshold;
    reg [31:0] T_sq;
    reg [31:0] cycle_cnt;
    reg feas_flag;
    reg [31:0] result_reg;
    reg [31:0] temp_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= 32'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            s <= 8'd0;
            u <= 8'd0;
            Mx <= 16'd0;
            My <= 16'd0;
            Nx <= 16'd0;
            Ny <= 16'd0;
            dx <= 32'd0;
            dy <= 32'd0;
            dist_sq_reg <= 64'd0;
            threshold <= 32'd0;
            T_sq <= 32'd0;
            cycle_cnt <= 32'd0;
            feas_flag <= 1'b0;
            result_reg <= 32'd0;
            temp_val <= 32'd0;
            t1 <= 32'd0;
            t2 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        low <= 32'd0;
                        high <= UPPER_BOUND;
                        cycle_cnt <= 32'd0;
                        state <= INIT_BIN;
                    end
                end

                INIT_BIN: begin
                    mid <= (low + high) >> 1;
                    s <= 8'd0;
                    feas_flag <= 1'b0;
                    state <= CHECK_S;
                end

                CHECK_S: begin
                    // Compute t1 = (s * L_M) >> 8
                    t1 <= (s * L_M) >> 8;
                    // Check if s is done
                    if (s > 8'd255) begin
                        state <= UPDATE_BIN;
                    end else begin
                        // Compute t2 = t1 + mid
                        t2 <= t1 + mid;
                        if (t2 > L_N) begin
                            // This s is infeasible, try next
                            if (s == 8'd255) begin
                                state <= UPDATE_BIN;
                            end else begin
                                s <= s + 1;
                            end
                        end else begin
                            // Compute u = (t2 * 256) / L_N
                            if (L_N == 32'd0) begin
                                // L_N cannot be zero, but handle gracefully
                                state <= UPDATE_BIN;
                            end else begin
                                u <= (t2 * SCALE) / L_N;
                                // Check u <= 255 in next cycle
                                temp_val <= (t2 * SCALE) / L_N;
                                state <= CHECK_S + 1; // Go to next step
                            end
                        end
                    end
                end

                (CHECK_S + 1): begin // Step for u comparison
                    if (temp_val > 8'd255) begin
                        if (s == 8'd255) begin
                            state <= UPDATE_BIN;
                        end else begin
                            s <= s + 1;
                            state <= CHECK_S;
                        end
                    end else begin
                        // Compute Mx, My, Nx, Ny
                        Mx <= A_x + ((B_x - A_x) * s) >> 8;
                        My <= A_y + ((B_y - A_y) * s) >> 8;
                        Nx <= C_x + ((D_x - C_x) * temp_val) >> 8;
                        Ny <= C_y + ((D_y - C_y) * temp_val) >> 8;
                        state <= CHECK_S + 2;
                    end
                end

                (CHECK_S + 2): begin // Step for dx, dy
                    // dx = Mx - Nx (sign extended)
                    if (Mx >= Nx) begin
                        dx <= Mx - Nx;
                    end else begin
                        dx <= (32'hFFFF0000 | (Mx - Nx));
                    end
                    // dy = My - Ny (sign extended)
                    if (My >= Ny) begin
                        dy <= My - Ny;
                    end else begin
                        dy <= (32'hFFFF0000 | (My - Ny));
                    end
                    state <= CHECK_S + 3;
                end

                (CHECK_S + 3): begin // Step for distance squared
                    // dist_sq = dx^2 + dy^2
                    // Using 64-bit accumulator for safety
                    dist_sq_reg <= (dx * dx) + (dy * dy);
                    state <= CHECK_S + 4;
                end

                (CHECK_S + 4): begin // Step for comparison
                    // threshold = dist_sq * 65536
                    threshold <= dist_sq_reg[47:16]; // Approximate shift right 16 (div 65536)
                    // T_sq = mid * mid
                    T_sq <= mid * mid;
                    state <= CHECK_S + 5;
                end

                (CHECK_S + 5): begin // Final check for this s
                    if (dist_sq_reg[47:16] <= (mid * mid)) begin
                        feas_flag <= 1'b1;
                        state <= UPDATE_BIN; // Feasible, stop checking s
                    end else begin
                        if (s == 8'd255) begin
                            state <= UPDATE_BIN;
                        end else begin
                            s <= s + 1;
                            state <= CHECK_S;
                        end
                    end
                end

                UPDATE_BIN: begin
                    if (feas_flag) begin
                        high <= mid;
                    end else begin
                        low <= mid + 1;
                    end
                    if (high - low <= 1 || cycle_cnt >= MAX_ITER) begin
                        result_reg <= high;
                        state <= FINISH;
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                        state <= INIT_BIN;
                    end
                end

                FINISH: begin
                    // Final check if result_reg is truly feasible (simplified)
                    // If result_reg is 0, check feasibility
                    if (result_reg == 32'd0) begin
                        // Check if distance can be 0
                        if (A_x == C_x && A_y == C_y && B_x == D_x && B_y == D_y) begin
                            result <= 32'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // 0 is not feasible, find minimum
                            result <= 32'd1 << 8; // 1.0
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end else begin
                        // Shift left 8 to get Q16.16
                        result <= result_reg << 8;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule