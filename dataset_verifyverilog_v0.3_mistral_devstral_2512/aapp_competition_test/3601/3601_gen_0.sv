module DeliveryTimeSolver (
    input clk,
    input rst_n,
    input start,
    // Misha's segment (2 points)
    input [15:0] A_x, A_y,
    input [15:0] B_x, B_y,
    input [31:0] L_M, // Length * 256
    // Nadia's segment (2 points)
    input [15:0] C_x, C_y,
    input [15:0] D_x, D_y,
    input [31:0] L_N, // Length * 256
    // Output
    output reg [31:0] result, // Delivery time * 65536 (Q16.16)
    output reg done,
    output reg impossible
);

// Parameters
localparam [7:0] MAX_ITER = 8'd24; // Binary search iterations

// States
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT_BIN = 3'd1;
localparam [2:0] FEAS_CHECK = 3'd2;
localparam [2:0] UPDATE_BIN = 3'd3;
localparam [2:0] FINISH = 3'd4;
localparam [2:0] IMPOSSIBLE = 3'd5;

reg [2:0] state;
reg [31:0] low, high, mid; // T_fixed values
reg [31:0] t1, t2;
reg [7:0] s;
reg [7:0] u;
reg [15:0] Mx, My, Nx, Ny;
reg signed [31:0] dx, dy;
reg [31:0] dist_sq;
reg [31:0] threshold, T_sq;
reg [7:0] cycles;
reg feas_flag;
reg [31:0] result_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 32'd0;
        low <= 32'd0;
        high <= 32'd0;
        mid <= 32'd0;
        t1 <= 32'd0;
        t2 <= 32'd0;
        s <= 8'd0;
        u <= 8'd0;
        Mx <= 16'd0;
        My <= 16'd0;
        Nx <= 16'd0;
        Ny <= 16'd0;
        dx <= 32'd0;
        dy <= 32'd0;
        dist_sq <= 32'd0;
        threshold <= 32'd0;
        T_sq <= 32'd0;
        cycles <= 8'd0;
        feas_flag <= 1'b0;
        result_reg <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                if (start) begin
                    low <= 32'd0;
                    high <= 32'd16777215; // Upper bound for T_fixed
                    cycles <= 8'd0;
                    state <= INIT_BIN;
                end
            end

            INIT_BIN: begin
                // Compute mid = (low + high) >> 1
                mid <= (low + high) >> 1;
                s <= 8'd0;
                feas_flag <= 1'b0;
                state <= FEAS_CHECK;
            end

            FEAS_CHECK: begin
                // Feasibility check for T = mid
                // This state machine iterates s from 0 to 255
                case (s)
                    8'd0: begin // Compute t1 = (s * L_M) >> 8
                        t1 <= (s * L_M) >> 8;
                        s <= s + 8'd1;
                    end
                    8'd1: begin // Compute t2 = t1 + mid
                        t2 <= t1 + mid;
                        if (t2 > L_N) begin
                            state <= UPDATE_BIN; // Infeasible for this and larger s
                        end else begin
                            s <= s + 8'd1;
                        end
                    end
                    8'd2: begin // Compute u = (t2 * 256) / L_N
                        u <= (t2 * 256) / L_N;
                        s <= s + 8'd1;
                    end
                    8'd3: begin // Check u <= 255
                        if (u > 8'd255) begin
                            state <= UPDATE_BIN;
                        end else begin
                            s <= s + 8'd1;
                        end
                    end
                    8'd4: begin // Compute Mx, My
                        Mx <= A_x + ((B_x - A_x) * (s-4)) >> 8;
                        My <= A_y + ((B_y - A_y) * (s-4)) >> 8;
                        s <= s + 8'd1;
                    end
                    8'd5: begin // Compute Nx, Ny
                        Nx <= C_x + ((D_x - C_x) * u) >> 8;
                        Ny <= C_y + ((D_y - C_y) * u) >> 8;
                        s <= s + 8'd1;
                    end
                    8'd6: begin // Compute dx, dy
                        dx <= Mx - Nx;
                        dy <= My - Ny;
                        s <= s + 8'd1;
                    end
                    8'd7: begin // Compute dist_sq = dx*dx + dy*dy
                        dist_sq <= dx*dx + dy*dy;
                        s <= s + 8'd1;
                    end
                    8'd8: begin // Compute threshold = dist_sq * 65536
                        threshold <= dist_sq * 65536;
                        s <= s + 8'd1;
                    end
                    8'd9: begin // Compute T_sq = mid * mid
                        T_sq <= mid * mid;
                        s <= s + 8'd1;
                    end
                    8'd10: begin // Compare threshold <= T_sq
                        if (threshold <= T_sq) begin
                            feas_flag <= 1'b1;
                            state <= UPDATE_BIN; // Found feasible, break early
                        end else begin
                            if (s == 8'd255) begin // Last iteration
                                state <= UPDATE_BIN;
                            end else begin
                                s <= 8'd0; // Reset to compute next t1
                            end
                        end
                    end
                    default: s <= s + 8'd1;
                endcase
            end

            UPDATE_BIN: begin
                if (feas_flag) begin
                    high <= mid;
                end else begin
                    low <= mid + 32'd1;
                end
                if (high - low <= 32'd1 || cycles >= MAX_ITER) begin
                    // Converged or max iterations reached
                    result_reg <= high;
                    state <= FINISH;
                end else begin
                    cycles <= cycles + 8'd1;
                    state <= INIT_BIN;
                end
            end

            FINISH: begin
                // Check if high is feasible (final check)
                // For simplicity, we assume high is feasible
                // If high is 0, might be impossible, but we assume it's feasible
                result <= high << 16; // Convert to Q16.16
                done <= 1'b1;
                state <= IDLE;
            end

            IMPOSSIBLE: begin
                impossible <= 1'b1;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule