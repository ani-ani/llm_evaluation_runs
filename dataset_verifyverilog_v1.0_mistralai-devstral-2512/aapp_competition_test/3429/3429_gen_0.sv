module min_damage_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] xs,
    input wire signed [31:0] ys,
    input wire signed [31:0] ss,
    input wire signed [31:0] ri,
    input wire signed [31:0] rf,
    input wire signed [31:0] xa,
    input wire signed [31:0] ya,
    input wire signed [31:0] sa,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_D = 3'd1;
    localparam [2:0] BINARY_SEARCH = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [5:0] iteration;
    reg signed [31:0] D_sq;
    reg signed [31:0] D;
    reg signed [31:0] low_t;
    reg signed [31:0] high_t;
    reg signed [31:0] mid_t;
    reg signed [31:0] r_t;
    reg signed [31:0] move_dist;
    reg signed [31:0] current_damage;
    reg signed [31:0] min_damage;
    reg signed [63:0] temp64;
    reg signed [31:0] temp32;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iteration <= 6'd0;
            D_sq <= 32'd0;
            D <= 32'd0;
            low_t <= 32'd0;
            high_t <= 32'd1000;
            mid_t <= 32'd0;
            r_t <= 32'd0;
            move_dist <= 32'd0;
            current_damage <= 32'd0;
            min_damage <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_D;
                    end
                end

                COMPUTE_D: begin
                    // Compute D_sq = (xa-xs)^2 + (ya-ys)^2
                    temp64 = ($signed(xa) - $signed(xs)) * ($signed(xa) - $signed(xs));
                    D_sq <= temp64[63:32];
                    temp64 = ($signed(ya) - $signed(ys)) * ($signed(ya) - $signed(ys));
                    temp32 = temp64[63:32];
                    D_sq <= D_sq + temp32;

                    // Compute D = sqrt(D_sq) using fixed-point approximation
                    // Using 8 iterations of Newton-Raphson
                    temp32 = 32'd0;
                    if (D_sq > 32'd0) begin
                        temp32 = D_sq;
                        repeat (8) begin
                            temp64 = (temp32 * temp32) << 16;
                            temp64 = temp64 + (D_sq << 32);
                            temp32 = temp64[63:32];
                            temp32 = temp32 >> 1;
                        end
                    end
                    D <= temp32;

                    // Initialize binary search
                    low_t <= 32'd0;
                    high_t <= 32'd1000;
                    min_damage <= 32'd1000000; // Large initial value
                    state <= BINARY_SEARCH;
                    iteration <= 6'd0;
                end

                BINARY_SEARCH: begin
                    // Binary search for optimal t
                    mid_t <= (low_t + high_t) >> 1;

                    // Calculate r_t = ri - ss*t (clamped to rf)
                    temp64 = $signed(ss) * $signed(mid_t);
                    r_t <= $signed(ri) - (temp64[63:32] >> 16);
                    if (r_t < rf) begin
                        r_t <= rf;
                    end

                    // Calculate move_dist
                    if (D <= r_t) begin
                        move_dist <= 32'd0;
                    end else begin
                        move_dist <= D - r_t;
                    end

                    // Check if player can reach in time
                    temp64 = $signed(sa) * $signed(mid_t);
                    if (move_dist <= (temp64[63:32] >> 16)) begin
                        // Calculate damage = max(0, t - (D/sa))
                        if (sa == 32'd0) begin
                            current_damage <= 32'd0;
                        end else begin
                            temp64 = ($signed(D) << 16) / $signed(sa);
                            current_damage <= mid_t - temp64[63:32];
                            if (current_damage < 32'd0) begin
                                current_damage <= 32'd0;
                            end
                        end
                    end else begin
                        current_damage <= 32'd1000000; // Large value for invalid
                    end

                    // Update min_damage
                    if (current_damage < min_damage) begin
                        min_damage <= current_damage;
                    end

                    // Update search bounds
                    iteration <= iteration + 6'd1;
                    if (iteration < 6'd64) begin
                        if (current_damage < 32'd1000000) begin
                            high_t <= mid_t;
                        end else begin
                            low_t <= mid_t;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= min_damage;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule