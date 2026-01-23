module rescue_planner(
    input clk,
    input rst_n,
    input start,
    input signed [31:0] dx,
    input signed [31:0] dy,
    input signed [31:0] v_max,
    input signed [31:0] t_wind,
    input signed [31:0] vx,
    input signed [31:0] vy,
    input signed [31:0] wx,
    input signed [31:0] wy,
    output reg done,
    output reg [31:0] result
);

    // State encoding
    localparam IDLE      = 5'b00001;
    localparam SETUP     = 5'b00010;
    localparam CALC_WIND = 5'b00100;
    localparam CHECK_DIST= 5'b01000;
    localparam UPDATE    = 5'b10000;

    reg [4:0] state;
    reg [4:0] next_state;

    reg [31:0] low;
    reg [31:0] high;
    reg [31:0] mid;
    reg [5:0] iter_cnt;
    
    reg signed [63:0] wx_val; 
    reg signed [63:0] wy_val;
    reg signed [63:0] time_diff;

    // Scaled Inputs (Arithmetic Shift Right by 4)
    wire signed [31:0] dx_s = dx >>> 4;
    wire signed [31:0] dy_s = dy >>> 4;
    wire signed [31:0] v_max_s = v_max >>> 4;
    wire signed [31:0] t_wind_s = t_wind >>> 4;
    wire signed [31:0] vx_s = vx >>> 4;
    wire signed [31:0] vy_s = vy >>> 4;
    wire signed [31:0] wx_s = wx >>> 4;
    wire signed [31:0] wy_s = wy >>> 4;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:       next_state = start ? SETUP : IDLE;
            SETUP:      next_state = CALC_WIND;
            CALC_WIND:  next_state = CHECK_DIST;
            CHECK_DIST: next_state = UPDATE;
            UPDATE:     next_state = (iter_cnt > 0) ? SETUP : IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 32'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            iter_cnt <= 6'd0;
            wx_val <= 64'sd0;
            wy_val <= 64'sd0;
            time_diff <= 64'sd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                SETUP: begin
                    low <= 32'd0;
                    high <= 32'h1E848000; // Max time (approx 125000.0 in Q16.16)
                    iter_cnt <= 6'd32;
                end

                CALC_WIND: begin
                    mid <= (low + high) >> 1;
                    
                    // Calculate Wind Displacement (Base)
                    wx_val <= (mid * vx_s) >>> 4;
                    wy_val <= (mid * vy_s) >>> 4;
                    
                    // Calculate Time Difference (T - t_wind)
                    if ((mid >>> 4) >= t_wind_s) begin
                        time_diff <= (mid >>> 4) - t_wind_s;
                    end else begin
                        time_diff <= 64'sd0;
                    end
                end

                CHECK_DIST: begin
                    // Apply Correction if in second period
                    if (time_diff != 0) begin
                        wx_val <= wx_val + ((time_diff * (wx_s - vx_s)) >>> 4);
                        wy_val <= wy_val + ((time_diff * (wy_s - vy_s)) >>> 4);
                    end
                end

                UPDATE: begin
                    // 1. Compute Remaining Vector: Target - Wind
                    // Target (dx << 8) matches Wind (Q24.24)
                    wx_val <= (dx <<< 8) - wx_val;
                    wy_val <= (dy <<< 8) - wy_val;
                    
                    // 2. Compute Reachability (v_max * T)
                    time_diff <= ((mid * v_max_s) >>> 4);
                    
                    // 3. Compare (Shift right 12 for fit in 64-bit multiplication)
                    if ( ((wx_val>>>12)*(wx_val>>>12) + (wy_val>>>(12))*(wy_val>>>(12))) <= ((time_diff>>>(12))*(time_diff>>>(12))) ) begin
                        high <= mid; // Time sufficient, search lower
                    end else begin
                        low <= mid + 1; // Time insufficient, search higher
                    end
                    
                    // 4. Decrement Counter and Capture Result
                    iter_cnt <= iter_cnt - 1;
                    if (iter_cnt == 1) begin
                        result <= low;
                    end
                end
            endcase
        end
    end
endmodule