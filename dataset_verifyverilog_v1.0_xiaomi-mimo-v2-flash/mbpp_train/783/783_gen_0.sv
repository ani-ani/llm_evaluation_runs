module rgb_to_hsv (
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

    // Q8.8 fixed-point format: integer 8 bits, fractional 8 bits
    // Value = raw_value / 256.0
    localparam signed [15:0] SCALE_100 = 16'sd25600; // 100 * 256
    localparam signed [15:0] SCALE_360 = 16'sd92160; // 360 * 256
    localparam signed [15:0] SCALE_60  = 16'sd15360; // 60 * 256
    localparam signed [15:0] SCALE_255 = 16'sd65280; // 255 * 256
    localparam signed [15:0] TWO_FIFTY_SIX = 16'sd256;

    // State declarations
    localparam [2:0] IDLE             = 3'd0;
    localparam [2:0] CALC_MAX          = 3'd1;
    localparam [2:0] CALC_DELTA        = 3'd2;
    localparam [2:0] CALC_HSV          = 3'd3;
    localparam [2:0] OUTPUT            = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] r_reg, g_reg, b_reg;
    reg signed [15:0] r_norm, g_norm, b_norm;
    reg signed [15:0] mx, mn, delta;
    reg signed [15:0] h_calc, s_calc, v_calc;
    reg [2:0] max_idx; // 0=r, 1=g, 2=b, 3=equal
    reg [4:0] cycle_count;

    // Division signals (Sequential divider for 16-bit)
    reg div_start;
    reg signed [15:0] div_num, div_den;
    wire signed [15:0] div_result;
    wire div_done;
    
    // Sequential Divider Module (non-restoring algorithm)
    divider_16x16 u_div (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .numerator(div_num),
        .denominator(div_den),
        .quotient(div_result),
        .done(div_done)
    );

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r_reg <= 8'd0;
            g_reg <= 8'd0;
            b_reg <= 8'd0;
            r_norm <= 16'sd0;
            g_norm <= 16'sd0;
            b_norm <= 16'sd0;
            mx <= 16'sd0;
            mn <= 16'sd0;
            delta <= 16'sd0;
            h_calc <= 16'sd0;
            s_calc <= 16'sd0;
            v_calc <= 16'sd0;
            max_idx <= 3'd0;
            cycle_count <= 5'd0;
            done <= 1'b0;
            h <= 16'sd0;
            s <= 16'sd0;
            v <= 16'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        r_reg <= r;
                        g_reg <= g;
                        b_reg <= b;
                        cycle_count <= 5'd0;
                    end
                end
                
                CALC_MAX: begin
                    // Normalize RGB to Q8.8 range 0-1 (actually 0/255)
                    // R_norm = (R * 256) / 255
                    r_norm <= (r_reg * 256) / 255;
                    g_norm <= (g_reg * 256) / 255;
                    b_norm <= (b_reg * 256) / 255;
                end
                
                CALC_DELTA: begin
                    // Find Max and Min using comparators
                    mx <= (r_norm >= g_norm && r_norm >= b_norm) ? r_norm : 
                          (g_norm >= r_norm && g_norm >= b_norm) ? g_norm : b_norm;
                    mn <= (r_norm <= g_norm && r_norm <= b_norm) ? r_norm : 
                          (g_norm <= r_norm && g_norm <= b_norm) ? g_norm : b_norm;
                    
                    // Determine max index for H calculation
                    if (r_norm >= g_norm && r_norm >= b_norm) max_idx <= 3'd0;
                    else if (g_norm >= r_norm && g_norm >= b_norm) max_idx <= 3'd1;
                    else max_idx <= 3'd2;
                end
                
                CALC_HSV: begin
                    delta <= mx - mn;
                    
                    // V = mx * 100 (scaled)
                    v_calc <= (mx * SCALE_100) >>> 8;
                    
                    // S Calculation
                    if (mx == 16'sd0) begin
                        s_calc <= 16'sd0;
                    end else begin
                        // S = (delta / mx) * 100
                        // Input to div is in Q8.8, result needs scaling
                        s_calc <= ((delta * SCALE_100) >>> 8) / mx;
                    end
                    
                    // H Calculation
                    if (mx == mn) begin
                        h_calc <= 16'sd0;
                    end else begin
                        case (max_idx)
                            3'd0: begin // R max
                                // H = 60 * ((g - b) / delta) + 360
                                if (g_norm >= b_norm) begin
                                    h_calc <= ((g_norm - b_norm) * SCALE_60) / delta;
                                end else begin
                                    h_calc <= ((g_norm - b_norm) * SCALE_60) / delta + SCALE_360;
                                end
                            end
                            3'd1: begin // G max
                                // H = 60 * ((b - r) / delta) + 120
                                h_calc <= ((b_norm - r_norm) * SCALE_60) / delta + (SCALE_360 / 3);
                            end
                            3'd2: begin // B max
                                // H = 60 * ((r - g) / delta) + 240
                                h_calc <= ((r_norm - g_norm) * SCALE_60) / delta + ((SCALE_360 * 2) / 3);
                            end
                            default: h_calc <= 16'sd0;
                        endcase
                    end
                end
                
                OUTPUT: begin
                    // Clamp and assign outputs
                    // H is already 0-360 scaled, ensure modulo 360
                    h <= h_calc % SCALE_360;
                    // S and V are 0-100 scaled
                    s <= (s_calc > SCALE_100) ? SCALE_100 : s_calc;
                    v <= (v_calc > SCALE_100) ? SCALE_100 : v_calc;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CALC_MAX;
            end
            CALC_MAX: next_state = CALC_DELTA;
            CALC_DELTA: next_state = CALC_HSV;
            CALC_HSV: next_state = OUTPUT;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule

// 16-bit Sequential Divider (Non-restoring algorithm)
module divider_16x16 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] numerator,
    input wire signed [15:0] denominator,
    output reg signed [15:0] quotient,
    output reg done
);

    localparam [4:0] DIV_IDLE = 5'd0;
    localparam [4:0] DIV_CALC = 5'd1;
    localparam [4:0] DIV_DONE = 5'd2;

    reg [4:0] div_state;
    reg signed [16:0] remainder;
    reg signed [31:0] partial_dividend;
    reg [3:0] bit_count;
    reg sign_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_state <= DIV_IDLE;
            quotient <= 16'sd0;
            done <= 1'b0;
            remainder <= 17'sd0;
            partial_dividend <= 32'sd0;
            bit_count <= 4'd0;
        end else begin
            case (div_state)
                DIV_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        div_state <= DIV_CALC;
                        // Handle signed inputs: store sign and work with absolute values
                        sign_reg <= (numerator < 0) ^ (denominator < 0);
                        remainder <= 17'sd0;
                        partial_dividend <= {16'd0, (numerator[15] ? -numerator : numerator)};
                        bit_count <= 4'd0;
                    end
                end
                
                DIV_CALC: begin
                    // Shift Left
                    partial_dividend <= partial_dividend << 1;
                    remainder <= {remainder[15:0], partial_dividend[31]};
                    
                    // Subtract or Add
                    if (remainder[16] == 1'b0) begin
                        remainder <= remainder - (denominator[15] ? -denominator : denominator);
                    end else begin
                        remainder <= remainder + (denominator[15] ? -denominator : denominator);
                    end
                    
                    bit_count <= bit_count + 4'd1;
                    
                    if (bit_count == 4'd15) begin
                        div_state <= DIV_DONE;
                        if (remainder[16] == 1'b1) begin
                            remainder <= remainder + (denominator[15] ? -denominator : denominator);
                            quotient <= 16'sd0;
                        end
                    end
                end
                
                DIV_DONE: begin
                    // Finalize quotient sign
                    if (sign_reg) begin
                        quotient <= -partial_dividend[15:0];
                    end else begin
                        quotient <= partial_dividend[15:0];
                    end
                    done <= 1'b1;
                    div_state <= DIV_IDLE;
                end
                
                default: div_state <= DIV_IDLE;
            endcase
        end
    end

endmodule