module rgb_to_hsv(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] r,
    input wire [7:0] g,
    input wire [7:0] b,
    output reg signed [15:0] h,
    output reg signed [15:0] s,
    output reg signed [15:0] v,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATE_MAX = 3'd1;
    localparam [2:0] CALCULATE_DELTA = 3'd2;
    localparam [2:0] CALCULATE_HSV = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for normalized RGB (Q8.8 format)
    reg signed [15:0] r_norm;
    reg signed [15:0] g_norm;
    reg signed [15:0] b_norm;

    // Internal registers for max, min, delta
    reg signed [15:0] mx;
    reg signed [15:0] mn;
    reg signed [15:0] delta;

    // Internal registers for intermediate calculations
    reg signed [15:0] temp_h;
    reg signed [15:0] temp_s;
    reg signed [15:0] temp_v;

    // Lookup table for division by 255 (Q8.8 format)
    reg signed [15:0] div255_lut [0:255];
    integer i;

    // Initialize lookup table for division by 255
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            div255_lut[i] = (i << 8) / 255;
        end
    end

    // FSM for RGB to HSV conversion
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            r_norm <= 16'd0;
            g_norm <= 16'd0;
            b_norm <= 16'd0;
            mx <= 16'd0;
            mn <= 16'd0;
            delta <= 16'd0;
            temp_h <= 16'd0;
            temp_s <= 16'd0;
            temp_v <= 16'd0;
            h <= 16'd0;
            s <= 16'd0;
            v <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CALCULATE_MAX;
                        // Normalize RGB to Q8.8 format
                        r_norm <= div255_lut[r];
                        g_norm <= div255_lut[g];
                        b_norm <= div255_lut[b];
                    end
                end

                CALCULATE_MAX: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find max and min of normalized RGB
                    mx <= r_norm;
                    if (g_norm > mx) mx <= g_norm;
                    if (b_norm > mx) mx <= b_norm;

                    mn <= r_norm;
                    if (g_norm < mn) mn <= g_norm;
                    if (b_norm < mn) mn <= b_norm;

                    state <= CALCULATE_DELTA;
                end

                CALCULATE_DELTA: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate delta = mx - mn
                    delta <= mx - mn;
                    state <= CALCULATE_HSV;
                end

                CALCULATE_HSV: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate V = mx * 100 (Q8.8 format)
                    temp_v <= (mx * 16'd100) >> 8;

                    // Calculate S
                    if (mx == 16'd0) begin
                        temp_s <= 16'd0;
                    end else begin
                        // S = (delta / mx) * 100 (Q8.8 format)
                        temp_s <= ((delta << 8) / mx) * 16'd100 >> 8;
                    end

                    // Calculate H
                    if (delta == 16'd0) begin
                        temp_h <= 16'd0;
                    end else begin
                        if (mx == r_norm) begin
                            // H = (60 * ((g-b)/delta) + 360) % 360
                            temp_h <= (60 * ((g_norm - b_norm) << 8) / delta + 360) % 360;
                        end else if (mx == g_norm) begin
                            // H = (60 * ((b-r)/delta) + 120) % 360
                            temp_h <= (60 * ((b_norm - r_norm) << 8) / delta + 120) % 360;
                        end else begin
                            // H = (60 * ((r-g)/delta) + 240) % 360
                            temp_h <= (60 * ((r_norm - g_norm) << 8) / delta + 240) % 360;
                        end
                    end

                    state <= OUTPUT;
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Output results
                    h <= temp_h;
                    s <= temp_s;
                    v <= temp_v;
                    done <= 1'b1;

                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule