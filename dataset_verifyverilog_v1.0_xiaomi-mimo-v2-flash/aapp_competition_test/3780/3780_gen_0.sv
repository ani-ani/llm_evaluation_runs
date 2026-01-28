module RescueDirigibleSolver (
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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_1 = 3'd1;
    localparam [2:0] CALC_2 = 3'd2;
    localparam [2:0] CALC_3 = 3'd3;
    localparam [2:0] CALC_4 = 3'd4;
    localparam [2:0] ITERATE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg signed [31:0] delta_x, delta_y;
    reg signed [63:0] low, high, T;
    reg signed [63:0] wind_x, wind_y;
    reg signed [63:0] dist_sq, reach_sq;
    reg [9:0] iteration_count;
    reg signed [63:0] temp1, temp2, temp3;
    reg [2:0] calc_step;

    // Constants
    localparam signed [63:0] ZERO = 64'sd0;
    localparam signed [63:0] ONE_FIXED = 64'sd1 << 32;
    localparam signed [63:0] HIGH_INIT = 64'sd1 << 48;
    localparam signed [63:0] MAX_ITER = 10'd1000;

    // Multiplication results (64-bit from 32x32)
    wire signed [63:0] mult1_out, mult2_out, mult3_out, mult4_out;
    wire signed [63:0] mult5_out, mult6_out, mult7_out, mult8_out;
    wire signed [63:0] mult9_out, mult10_out, mult11_out, mult12_out;

    // Multiplier logic (Q32.32 * Q32.32 = Q64.64, shift to Q32.32)
    assign mult1_out = (T >>> 16) * vmax; // vmax * T
    assign mult2_out = mult1_out >>> 16; // vmax * T (Q32.32)
    assign mult3_out = mult2_out * mult2_out; // (vmax * T)^2

    assign mult4_out = (wind_x >>> 16) * (wind_x >>> 16); // wind_x^2
    assign mult5_out = mult4_out >>> 32; // wind_x^2 (Q32.32)

    assign mult6_out = (wind_y >>> 16) * (wind_y >>> 16); // wind_y^2
    assign mult7_out = mult6_out >>> 32; // wind_y^2 (Q32.32)

    assign mult8_out = (T >>> 16) * (T >>> 16); // T^2 for distance calc
    assign mult9_out = mult8_out >>> 32; // T^2 (Q32.32)

    assign mult10_out = (T - t) >>> 16; // (T - t) in Q16.16
    assign mult11_out = mult10_out * wx; // wx * (T - t)
    assign mult12_out = mult10_out * wy; // wy * (T - t)

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'sd0;
            done <= 1'b0;
            delta_x <= 32'sd0;
            delta_y <= 32'sd0;
            low <= 64'sd0;
            high <= 64'sd0;
            T <= 64'sd0;
            wind_x <= 64'sd0;
            wind_y <= 64'sd0;
            dist_sq <= 64'sd0;
            reach_sq <= 64'sd0;
            iteration_count <= 10'd0;
            calc_step <= 3'd0;
            temp1 <= 64'sd0;
            temp2 <= 64'sd0;
            temp3 <= 64'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iteration_count <= 10'd0;
                    calc_step <= 3'd0;
                    if (start) begin
                        // Compute delta_x and delta_y in Q16.16, then convert to Q32.32
                        delta_x <= ({x2[15], x2, 16'b0} - {x1[15], x1, 16'b0});
                        delta_y <= ({y2[15], y2, 16'b0} - {y1[15], y1, 16'b0});
                        low <= 64'sd0;
                        high <= HIGH_INIT;
                    end
                end

                CALC_1: begin
                    T <= (low + high) >>> 1;
                end

                CALC_2: begin
                    // Compute wind effect
                    if (T <= { {48{t[15]}}, t, 16'b0 }) begin
                        wind_x <= (vx * (T >>> 16));
                        wind_y <= (vy * (T >>> 16));
                    end else begin
                        wind_x <= (vx * t) + mult11_out;
                        wind_y <= (vy * t) + mult12_out;
                    end
                end

                CALC_3: begin
                    // Compute remaining distance squared
                    // (Δx - wind_x) and (Δy - wind_y)
                    temp1 <= (delta_x <<< 16) - wind_x;
                    temp2 <= (delta_y <<< 16) - wind_y;
                end

                CALC_4: begin
                    // Square the components
                    dist_sq <= ((temp1 >>> 16) * (temp1 >>> 16)) >>> 32;
                    dist_sq <= dist_sq + (((temp2 >>> 16) * (temp2 >>> 16)) >>> 32);
                    reach_sq <= mult3_out;
                end

                ITERATE: begin
                    // Binary search update
                    if (reach_sq >= dist_sq) begin
                        high <= T;
                    end else begin
                        low <= T;
                    end
                    iteration_count <= iteration_count + 10'd1;
                end

                DONE_STATE: begin
                    result <= high;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CALC_1;
            
            CALC_1: next_state = CALC_2;
            
            CALC_2: next_state = CALC_3;
            
            CALC_3: next_state = CALC_4;
            
            CALC_4: next_state = ITERATE;
            
            ITERATE: begin
                if (iteration_count >= MAX_ITER) next_state = DONE_STATE;
                else next_state = CALC_1;
            end
            
            DONE_STATE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

endmodule