module rgb_to_hsv(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] r_in,
    input wire [7:0] g_in,
    input wire [7:0] b_in,
    output reg [15:0] h_out,
    output reg [15:0] s_out,
    output reg [15:0] v_out,
    output reg done
);

// Fixed-point format: Q16.16 (16 integer bits, 16 fractional bits)
// Hue output: 0-360 in Q16.16
// Saturation: 0-100 in Q16.16
// Value: 0-100 in Q16.16

// State machine states
localparam [3:0] IDLE = 4'd0;
localparam [3:0] NORM = 4'd1;
localparam [3:0] MX_MN = 4'd2;
localparam [3:0] DF = 4'd3;
localparam [3:0] HUE = 4'd4;
localparam [3:0] SAT = 4'd5;
localparam [3:0] VAL = 4'd6;
localparam [3:0] DONE = 4'd7;

reg [3:0] state, next_state;

// Internal registers for intermediate calculations
reg [15:0] r_norm, g_norm, b_norm;  // Q16.16 normalized (0-1)
reg [15:0] mx, mn, df;              // Q16.16
reg [15:0] h_calc, s_calc, v_calc;  // Q16.16 results
reg [7:0] r_reg, g_reg, b_reg;      // Store inputs

// Multiplication result (for 16x16 -> 32-bit, then truncate)
reg [31:0] mult_result;

// Division state tracking
reg [1:0] div_step;

// Control signals
reg [15:0] divisor;
reg [15:0] dividend;
reg [15:0] quotient;
reg [3:0] div_counter;

// 60*100 = 6000 in Q16.16 = 6000 << 16 = 393216000
// But we'll compute as: (60 << 16) = 3932160
localparam [31:0] SIXTY_FIXED = 32'd3932160;  // 60 in Q16.16
localparam [31:0] SIXTY_FIXED_G = 32'd3932160; // 60 in Q16.16 for green case
localparam [31:0] SIXTY_FIXED_B = 32'd3932160; // 60 in Q16.16 for blue case

// 100 in Q16.16 = 100 << 16 = 6553600
localparam [31:0] HUNDRED_FIXED = 32'd6553600;

// 360 in Q16.16 = 360 << 16 = 23592960
localparam [31:0] THREE_SIXTY_FIXED = 32'd23592960;

// 120 in Q16.16 = 120 << 16 = 7864320
localparam [31:0] ONE_TWENTY_FIXED = 32'd7864320;

// 240 in Q16.16 = 240 << 16 = 15728640
localparam [31:0] TWO_FOURTY_FIXED = 32'd15728640;

// Division by 255 (for normalization)
// 1/255 in Q16.16 ≈ 257 (actually 257.142, but we use 257 for approximation)
// More accurate: 65536/255 = 257 (rounded)
localparam [15:0] INV_255 = 16'd257;

// Helper for max/min
reg [15:0] max_val, min_val;
reg mx_is_r, mx_is_g, mx_is_b;

// Combinational next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = NORM;
        NORM: next_state = MX_MN;
        MX_MN: next_state = DF;
        DF: next_state = HUE;
        HUE: if (div_counter == 4'd15) next_state = SAT;
        SAT: if (div_counter == 4'd15) next_state = VAL;
        VAL: next_state = DONE;
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Sequential state update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        h_out <= 0;
        s_out <= 0;
        v_out <= 0;
        div_counter <= 0;
        r_norm <= 0;
        g_norm <= 0;
        b_norm <= 0;
        mx <= 0;
        mn <= 0;
        df <= 0;
        h_calc <= 0;
        s_calc <= 0;
        v_calc <= 0;
        r_reg <= 0;
        g_reg <= 0;
        b_reg <= 0;
        mult_result <= 0;
        divisor <= 0;
        dividend <= 0;
        quotient <= 0;
        mx_is_r <= 0;
        mx_is_g <= 0;
        mx_is_b <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 0;
                div_counter <= 0;
                if (start) begin
                    r_reg <= r_in;
                    g_reg <= g_in;
                    b_reg <= b_in;
                end
            end
            
            NORM: begin
                // Normalize to 0-1 (divide by 255)
                // Use approximation: multiply by 257 then shift right by 8
                r_norm <= (r_reg * INV_255) >> 8;
                g_norm <= (g_reg * INV_255) >> 8;
                b_norm <= (b_reg * INV_255) >> 8;
            end
            
            MX_MN: begin
                // Find max and min
                if (r_norm >= g_norm && r_norm >= b_norm) begin
                    mx <= r_norm;
                    mx_is_r <= 1; mx_is_g <= 0; mx_is_b <= 0;
                end else if (g_norm >= r_norm && g_norm >= b_norm) begin
                    mx <= g_norm;
                    mx_is_r <= 0; mx_is_g <= 1; mx_is_b <= 0;
                end else begin
                    mx <= b_norm;
                    mx_is_r <= 0; mx_is_g <= 0; mx_is_b <= 1;
                end
                
                if (r_norm <= g_norm && r_norm <= b_norm) begin
                    mn <= r_norm;
                end else if (g_norm <= r_norm && g_norm <= b_norm) begin
                    mn <= g_norm;
                end else begin
                    mn <= b_norm;
                end
            end
            
            DF: begin
                df <= mx - mn;
            end
            
            HUE: begin
                if (div_counter == 0) begin
                    // Check mx == mn
                    if (mx == mn) begin
                        h_calc <= 0;
                        div_counter <= 15; // Skip to next state
                    end else if (mx_is_r) begin
                        // h = (60 * ((g-m)/df) + 360) % 360
                        // First compute (g-m)/df
                        if (df != 0) begin
                            dividend <= (g_norm > mn) ? (g_norm - mn) : 16'd0;
                            divisor <= df;
                            quotient <= 0;
                            div_counter <= 1;
                        end else begin
                            h_calc <= 0;
                            div_counter <= 15;
                        end
                    end else if (mx_is_g) begin
                        // h = (60 * ((b-m)/df) + 120) % 360
                        if (df != 0) begin
                            dividend <= (b_norm > mn) ? (b_norm - mn) : 16'd0;
                            divisor <= df;
                            quotient <= 0;
                            div_counter <= 1;
                        end else begin
                            h_calc <= 0;
                            div_counter <= 15;
                        end
                    end else begin // mx_is_b
                        // h = (60 * ((m-m)/df) + 240) % 360
                        if (df != 0) begin
                            dividend <= (r_norm > mn) ? (r_norm - mn) : 16'd0;
                            divisor <= df;
                            quotient <= 0;
                            div_counter <= 1;
                        end else begin
                            h_calc <= 0;
                            div_counter <= 15;
                        end
                    end
                end else if (div_counter < 16) begin
                    // Long division: Q16.16 ÷ Q16.16 = Q16.16 result
                    if ({quotient, dividend[15:0]} >= {16'd0, divisor}) begin
                        quotient <= quotient + 1;
                        dividend <= {dividend[15:0], 1'b0} - {1'b0, divisor};
                    end else begin
                        dividend <= {dividend[15:0], 1'b0};
                    end
                    div_counter <= div_counter + 1;
                    
                    if (div_counter == 15) begin
                        // Division complete, now multiply by 60 and add offset
                        if (mx_is_r) begin
                            mult_result <= SIXTY_FIXED * quotient;
                            // Will add 360 and modulo in next state transition
                        end else if (mx_is_g) begin
                            mult_result <= SIXTY_FIXED * quotient;
                        end else begin
                            mult_result <= SIXTY_FIXED * quotient;
                        end
                    end
                end
            end
            
            SAT: begin
                if (div_counter == 0) begin
                    // s = (df/mx)*100
                    if (mx != 0 && df != 0) begin
                        dividend <= df;
                        divisor <= mx;
                        quotient <= 0;
                        div_counter <= 1;
                    end else begin
                        s_calc <= 0;
                        div_counter <= 15;
                    end
                end else if (div_counter < 16) begin
                    // Long division
                    if ({quotient, dividend[15:0]} >= {16'd0, divisor}) begin
                        quotient <= quotient + 1;
                        dividend <= {dividend[15:0], 1'b0} - {1'b0, divisor};
                    end else begin
                        dividend <= {dividend[15:0], 1'b0};
                    end
                    div_counter <= div_counter + 1;
                    
                    if (div_counter == 15) begin
                        // Multiply by 100
                        mult_result <= HUNDRED_FIXED * quotient;
                    end
                end
            end
            
            VAL: begin
                // v = mx*100
                v_out <= (mx * 100) >> 16;
                
                // Handle saturation result
                if (div_counter == 15 && mx != 0 && df != 0) begin
                    s_out <= mult_result[31:16];
                end else begin
                    s_out <= 0;
                end
                
                // Handle hue result with modulo 360
                if (mx != mn) begin
                    if (mx_is_r) begin
                        // (60 * ((g-m)/df) + 360) % 360
                        // mult_result = 60 * ((g-m)/df)
                        // Add 360 in Q16.16
                        mult_result <= mult_result + THREE_SIXTY_FIXED;
                    end else if (mx_is_g) begin
                        // (60 * ((b-m)/df) + 120) % 360
                        mult_result <= mult_result + ONE_TWENTY_FIXED;
                    end else begin
                        // (60 * ((r-m)/df) + 240) % 360
                        mult_result <= mult_result + TWO_FOURTY_FIXED;
                    end
                end
            end
            
            DONE: begin
                // Final modulo 360 for hue
                if (mx != mn) begin
                    if (mult_result >= THREE_SIXTY_FIXED) begin
                        h_out <= mult_result - THREE_SIXTY_FIXED;
                    end else begin
                        h_out <= mult_result[31:16];
                    end
                end else begin
                    h_out <= 0;
                end
                done <= 1;
            end
        endcase
    end
end

endmodule