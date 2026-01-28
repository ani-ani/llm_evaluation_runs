module max_fruit_slicing(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_points,
    input wire signed [31:0] x [0:15],
    input wire signed [31:0] y [0:15],
    output reg [4:0] result,
    output reg done,
    output reg busy
);

    // Constants
    localparam [3:0] MAX_POINTS = 4'd16;
    localparam [12:0] MAX_CYCLES = 13'd4000;
    localparam [31:0] ONE = 32'd65536;  // 1.0 in Q16.16
    localparam [31:0] ZERO = 32'd0;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [12:0] cycle_count;
    reg [4:0] max_count;
    reg [4:0] current_count;
    reg [4:0] i_reg, j_reg, k_reg;
    reg signed [31:0] A_reg, B_reg, C_reg;
    reg signed [31:0] x_i, y_i, x_j, y_j;
    reg signed [31:0] dx, dy;
    reg signed [63:0] dx_sq, dy_sq, dist_sq;
    reg signed [63:0] temp_A, temp_B, temp_C;
    reg signed [63:0] distance_sq;
    reg signed [63:0] accum;
    reg [3:0] num_points_reg;
    reg signed [31:0] x_reg [0:15];
    reg signed [31:0] y_reg [0:15];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 13'd0;
            max_count <= 5'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            k_reg <= 5'd0;
            A_reg <= 32'd0;
            B_reg <= 32'd0;
            C_reg <= 32'd0;
            num_points_reg <= 4'd0;
            for (integer i = 0; i < 16; i = i + 1) begin
                x_reg[i] <= 32'd0;
                y_reg[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    num_points_reg <= num_points;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        x_reg[i] <= x[i];
                        y_reg[i] <= y[i];
                    end
                    max_count <= 5'd0;
                    i_reg <= 5'd0;
                    j_reg <= 5'd0;
                    k_reg <= 5'd0;
                    cycle_count <= 13'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= cycle_count + 13'd1;

                    // Generate candidate lines
                    if (cycle_count < MAX_CYCLES) begin
                        // Get current points
                        x_i <= x_reg[i_reg];
                        y_i <= y_reg[i_reg];
                        x_j <= x_reg[j_reg];
                        y_j <= y_reg[j_reg];

                        // Calculate line coefficients
                        dx <= x_j - x_i;
                        dy <= y_j - y_i;

                        // Calculate line through centers (offset = 0)
                        if (dx != 0 || dy != 0) begin
                            // Line: (y_j - y_i)(x - x_i) - (x_j - x_i)(y - y_i) = 0
                            // A = dy, B = -dx, C = dx*y_i - dy*x_i
                            A_reg <= dy;
                            B_reg <= -dx;
                            C_reg <= (dx * y_i - dy * x_i);
                        end else begin
                            // Degenerate case: same point, skip
                            A_reg <= 32'd0;
                            B_reg <= 32'd0;
                            C_reg <= 32'd0;
                        end

                        // Count intersections for this line
                        current_count <= 5'd0;
                        for (integer k = 0; k < num_points_reg; k = k + 1) begin
                            // Distance = |A*x_k + B*y_k + C| / sqrt(A^2 + B^2)
                            // We compare |A*x_k + B*y_k + C| <= sqrt(A^2 + B^2) * 1.0
                            // To avoid division, compare squared distance
                            accum <= A_reg * x_reg[k] + B_reg * y_reg[k] + C_reg;
                            distance_sq <= accum * accum;

                            // Calculate denominator squared
                            dx_sq <= dx * dx;
                            dy_sq <= dy * dy;
                            dist_sq <= dx_sq + dy_sq;

                            // Compare distance_sq <= dist_sq * (1.0)^2
                            if (distance_sq <= dist_sq) begin
                                current_count <= current_count + 5'd1;
                            end
                        end

                        // Update max count
                        if (current_count > max_count) begin
                            max_count <= current_count;
                        end

                        // Move to next line
                        j_reg <= j_reg + 5'd1;
                        if (j_reg >= num_points_reg) begin
                            j_reg <= 5'd0;
                            i_reg <= i_reg + 5'd1;
                            if (i_reg >= num_points_reg) begin
                                next_state <= FINISH;
                            end
                        end
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    result <= max_count;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 5'd0;
                end
            endcase
        end
    end

endmodule