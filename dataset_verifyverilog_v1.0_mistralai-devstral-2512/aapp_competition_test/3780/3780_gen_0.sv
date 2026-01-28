module RescueDirigibleTimeCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] x1,
    input wire signed [15:0] y1,
    input wire signed [15:0] x2,
    input wire signed [15:0] y2,
    input wire signed [15:0] vmax,
    input wire signed [15:0] t,
    input wire signed [15:0] vx,
    input wire signed [15:0] vy,
    input wire signed [15:0] wx,
    input wire signed [15:0] wy,
    output reg signed [63:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [9:0] iteration_count;
    reg signed [63:0] low, high, T;
    reg signed [63:0] delta_x, delta_y;
    reg signed [63:0] wind_x, wind_y;
    reg signed [63:0] distance_sq, reachable_sq;
    reg signed [63:0] temp_mult1, temp_mult2;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iteration_count <= 10'd0;
            low <= 64'd0;
            high <= 64'd1125899906842624; // 2^48 in Q32.32
            delta_x <= 64'd0;
            delta_y <= 64'd0;
            result <= 64'd0;
            done <= 1'b0;
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
                    next_state = CALCULATING;
                    // Initialize delta values (scale by 2^16 for Q32.32)
                    delta_x = ({16'd0, x2} - {16'd0, x1}) << 16;
                    delta_y = ({16'd0, y2} - {16'd0, y1}) << 16;
                    iteration_count = 10'd0;
                    low = 64'd0;
                    high = 64'd1125899906842624;
                end
            end
            CALCULATING: begin
                if (iteration_count >= 10'd1000) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Binary search computation
    always @(posedge clk) begin
        if (state == CALCULATING) begin
            // Compute midpoint
            T = (low + high) >> 1;

            // Calculate wind effect
            if (T <= {32'd0, t}) begin
                // T <= t: use initial wind
                temp_mult1 = {32'd0, vx} * T;
                temp_mult2 = {32'd0, vy} * T;
                wind_x = temp_mult1[63:32];
                wind_y = temp_mult2[63:32];
            end else begin
                // T > t: use changed wind
                temp_mult1 = {32'd0, vx} * {32'd0, t};
                temp_mult2 = {32'd0, vy} * {32'd0, t};
                wind_x = temp_mult1[63:32] + {32'd0, wx} * (T - {32'd0, t});
                wind_y = temp_mult2[63:32] + {32'd0, wy} * (T - {32'd0, t});
            end

            // Calculate distance squared
            temp_mult1 = delta_x - wind_x;
            temp_mult2 = delta_y - wind_y;
            distance_sq = (temp_mult1 * temp_mult1) >> 32;
            distance_sq = distance_sq + ((temp_mult2 * temp_mult2) >> 32);

            // Calculate reachable distance squared
            temp_mult1 = {32'd0, vmax} * T;
            reachable_sq = (temp_mult1 * temp_mult1) >> 32;

            // Update search range
            if (reachable_sq >= distance_sq) begin
                high = T;
            end else begin
                low = T;
            end

            // Increment iteration counter
            iteration_count = iteration_count + 10'd1;
        end
    end

    // Output result and done signal
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            result <= high;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule