module IntersectionArea(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] w_i,
    input wire [15:0] h_i,
    input wire [7:0] alpha_i,
    output reg [31:0] area_o,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] NORMALIZE     = 4'd1;
    localparam [3:0] CHECK_ALPHA   = 4'd2;
    localparam [3:0] COMPUTE_TAN_HALF = 4'd3;
    localparam [3:4] COMPUTE_TAN_FULL = 4'd4;
    localparam [3:0] COMPUTE_SIN   = 4'd5;
    localparam [3:0] COMPUTE_AREA  = 4'd6;
    localparam [3:0] COMPUTE_CLIP  = 4'd7;
    localparam [3:0] FINISH        = 4'd8;

    reg [3:0] state;
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd500;

    // Fixed-point format conversions
    // Q8.8 input: value = input / 256
    // Q16.16 internal: value = internal / 65536
    // Conversion: Q16.16 = Q8.8 << 8

    // Intermediate registers
    reg [15:0] w_reg, h_reg;
    reg [7:0] alpha_reg;
    reg [7:0] alpha_norm;
    reg [15:0] min_wh;
    
    // Q16.16 registers for intermediate results
    reg [31:0] w_q, h_q;
    reg [31:0] tan_half_q;
    reg [31:0] tan_full_q;
    reg [31:0] sin_alpha_q;
    reg [31:0] area_result;
    
    // For CORDIC iterations
    reg [7:0] cordic_idx;
    reg [31:0] x_cordic, y_cordic, z_cordic;
    reg [31:0] x_cordic_next, y_cordic_next, z_cordic_next;
    
    // Precomputed CORDIC lookup tables (scaled to Q16.16)
    // atan(2^-i) for i=0 to 7 (sufficient for Q16.16 precision)
    wire [31:0] atan_table [0:7];
    assign atan_table[0] = 32'h3243F;  // atan(1) = 45 degrees
    assign atan_table[1] = 32'h1DAC6;  // atan(1/2) ~ 26.565 degrees
    assign atan_table[2] = 32'h0FAD7;  // atan(1/4) ~ 14.036 degrees
    assign atan_table[3] = 32'h07F5A;  // atan(1/8) ~ 7.125 degrees
    assign atan_table[4] = 32'h03FAB;  // atan(1/16) ~ 3.576 degrees
    assign atan_table[5] = 32'h01FF5;  // atan(1/32) ~ 1.790 degrees
    assign atan_table[6] = 32'h00FFA;  // atan(1/64) ~ 0.895 degrees
    assign atan_table[7] = 32'h007FD;  // atan(1/128) ~ 0.448 degrees
    
    // K-factor for CORDIC (1.646760258...)
    // K = 0.9972723 * 65536 = 0x7FFF
    localparam [15:0] CORDIC_K = 16'h7FFF;
    
    // Helper variables for arithmetic
    reg [63:0] temp_mult;
    reg [63:0] temp_mult2;
    reg [31:0] temp_sum;
    reg [31:0] temp_diff;
    
    // Combinational helper signals for multiplication results
    wire [63:0] mult_w_h = w_q * h_q;
    wire [63:0] mult_t2_t = tan_half_q * tan_half_q;
    wire [63:0] mult_t_t = tan_full_q * tan_full_q;
    wire [63:0] mult_w_tan = w_q * tan_half_q;
    wire [63:0] mult_h_tan = h_q * tan_half_q;
    
    // For clipping case
    wire [63:0] min_wh_sq = {min_wh, 16'd0} * {min_wh, 16'd0};  // Q16.16 squared
    wire [63:0] mult_sin = sin_alpha_q * {min_wh, 16'd0};
    
    // Angle normalization helper
    wire [7:0] alpha_check = (alpha_i > 8'd180) ? 8'd180 : alpha_i;
    wire [7:0] alpha_norm_temp = (alpha_check > 8'd90) ? (8'd180 - alpha_check) : alpha_check;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            area_o <= 32'd0;
            cycle_count <= 9'd0;
            w_reg <= 16'd0;
            h_reg <= 16'd0;
            alpha_reg <= 8'd0;
            alpha_norm <= 8'd0;
            min_wh <= 16'd0;
            w_q <= 32'd0;
            h_q <= 32'd0;
            tan_half_q <= 32'd0;
            tan_full_q <= 32'd0;
            sin_alpha_q <= 32'd0;
            area_result <= 32'd0;
            cordic_idx <= 8'd0;
            x_cordic <= 32'd0;
            y_cordic <= 32'd0;
            z_cordic <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                    if (start) begin
                        w_reg <= w_i;
                        h_reg <= h_i;
                        alpha_reg <= alpha_i;
                        state <= NORMALIZE;
                    end
                end
                
                NORMALIZE: begin
                    // Normalize angle to 0-90 degrees
                    if (alpha_reg > 8'd180)
                        alpha_norm <= 8'd180;
                    else if (alpha_reg > 8'd90)
                        alpha_norm <= 8'd180 - alpha_reg;
                    else
                        alpha_norm <= alpha_reg;
                    
                    // Convert to Q16.16
                    w_q <= {8'd0, w_reg, 8'd0};
                    h_q <= {8'd0, h_reg, 8'd0};
                    
                    // Find min(w,h) for clipping case
                    if (w_reg < h_reg)
                        min_wh <= w_reg;
                    else
                        min_wh <= h_reg;
                    
                    state <= CHECK_ALPHA;
                end
                
                CHECK_ALPHA: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    if (alpha_norm == 8'd0) begin
                        // alpha = 0, area = w * h
                        area_result <= mult_w_h[47:16];  // Q16.16
                        state <= FINISH;
                    end else if (alpha_norm >= 8'd90) begin
                        // alpha >= 90, clipped rectangle case
                        // area = min(w,h)^2 / sin(alpha)
                        state <= COMPUTE_SIN;
                    end else begin
                        // 0 < alpha < 90, compute tan(alpha/2)
                        state <= COMPUTE_TAN_HALF;
                    end
                end
                
                COMPUTE_TAN_HALF: begin
                    // Compute tan(alpha/2) using CORDIC
                    // Start with x=1, y=tan(angle), z=angle
                    // Use half-angle formula or direct CORDIC
                    // For simplicity, we'll compute sin/cos and derive tan
                    
                    // Initialize CORDIC for alpha/2
                    if (cordic_idx == 8'd0) begin
                        // Convert alpha_norm/2 to radians (approx)
                        // alpha in degrees, scale factor for Q16.16: (pi/180)/2 = 0.0087266
                        // For 8-bit alpha_norm (0-90), convert to Q16.16
                        // Using lookup: 1 degree = 11459/256 radians in Q16.16
                        // alpha/2 = alpha_norm * 0.5
                        // We'll use a direct lookup for alpha/2
                        
                        // Use CORDIC to compute sin(alpha/2)
                        x_cordic <= 32'h10000;  // 1.0 in Q16.16
                        y_cordic <= 32'd0;
                        // Convert alpha_norm/2 to radians in Q16.16
                        // 1 degree = 11459/256 = 44.76 Q16.16
                        // alpha_norm/2 * 44.76
                        z_cordic <= (alpha_norm >> 1) * 8'd45;  // Approximate
                        cordic_idx <= 8'd0;
                    end else begin
                        // CORDIC iteration
                        if (cordic_idx < 8'd8) begin
                            z_cordic_next = z_cordic;
                            x_cordic_next = x_cordic;
                            y_cordic_next = y_cordic;
                            
                            if (z_cordic < 32'h80000000) begin
                                // Positive angle
                                z_cordic_next = z_cordic - atan_table[cordic_idx[2:0]];
                                x_cordic_next = x_cordic - (y_cordic >> cordic_idx);
                                y_cordic_next = y_cordic + (x_cordic >> cordic_idx);
                            end else begin
                                // Negative angle
                                z_cordic_next = z_cordic + atan_table[cordic_idx[2:0]];
                                x_cordic_next = x_cordic + (y_cordic >> cordic_idx);
                                y_cordic_next = y_cordic - (x_cordic >> cordic_idx);
                            end
                            
                            x_cordic <= x_cordic_next;
                            y_cordic <= y_cordic_next;
                            z_cordic <= z_cordic_next;
                            cordic_idx <= cordic_idx + 8'd1;
                        end else begin
                            // Get sin(alpha/2) = y_cordic * K
                            // Get cos(alpha/2) = x_cordic * K
                            temp_mult = y_cordic * CORDIC_K;
                            temp_mult2 = x_cordic * CORDIC_K;
                            
                            // sin(alpha/2) in Q16.16
                            reg [31:0] sin_half;
                            sin_half = temp_mult[47:16];
                            
                            // cos(alpha/2) in Q16.16
                            reg [31:0] cos_half;
                            cos_half = temp_mult2[47:16];
                            
                            // tan(alpha/2) = sin_half / cos_half
                            // Use division: result = (sin_half << 16) / cos_half
                            // For fixed-point division
                            if (cos_half != 0) begin
                                tan_half_q <= (sin_half << 16) / cos_half;
                            end else begin
                                tan_half_q <= 32'h7FFFFFFF;  // Max value
                            end
                            
                            cordic_idx <= 8'd0;
                            state <= COMPUTE_TAN_FULL;
                        end
                    end
                end
                
                COMPUTE_TAN_FULL: begin
                    // Compute tan(alpha) using double angle formula
                    // tan(2x) = 2*tan(x) / (1 - tan(x)^2)
                    
                    temp_mult = tan_half_q * tan_half_q;  // tan^2
                    temp_mult2 = temp_mult >> 16;  // Q16.16
                    
                    // denominator = 1 - tan_half^2
                    // 1.0 in Q16.16 = 65536
                    temp_sum = 32'h10000 - temp_mult2[31:0];
                    
                    // numerator = 2 * tan_half
                    temp_diff = tan_half_q << 1;
                    
                    if (temp_sum != 0) begin
                        tan_full_q <= (temp_diff << 16) / temp_sum;
                    end else begin
                        tan_full_q <= 32'h7FFFFFFF;
                    end
                    
                    // Reset CORDIC for alpha computation
                    cordic_idx <= 8'd0;
                    state <= COMPUTE_SIN;
                end
                
                COMPUTE_SIN: begin
                    // Compute sin(alpha) using CORDIC
                    if (cordic_idx == 8'd0) begin
                        x_cordic <= 32'h10000;  // 1.0
                        y_cordic <= 32'd0;
                        // Convert alpha_norm to radians in Q16.16
                        // 1 degree ≈ 44.76 Q16.16
                        z_cordic <= alpha_norm * 8'd45;  // Approximate
                        cordic_idx <= 8'd0;
                    end else begin
                        if (cordic_idx < 8'd8) begin
                            if (z_cordic < 32'h80000000) begin
                                z_cordic_next = z_cordic - atan_table[cordic_idx[2:0]];
                                x_cordic_next = x_cordic - (y_cordic >> cordic_idx);
                                y_cordic_next = y_cordic + (x_cordic >> cordic_idx);
                            end else begin
                                z_cordic_next = z_cordic + atan_table[cordic_idx[2:0]];
                                x_cordic_next = x_cordic + (y_cordic >> cordic_idx);
                                y_cordic_next = y_cordic - (x_cordic >> cordic_idx);
                            end
                            x_cordic <= x_cordic_next;
                            y_cordic <= y_cordic_next;
                            z_cordic <= z_cordic_next;
                            cordic_idx <= cordic_idx + 8'd1;
                        end else begin
                            // sin(alpha) = y_cordic * K
                            temp_mult = y_cordic * CORDIC_K;
                            sin_alpha_q <= temp_mult[47:16];
                            
                            if (alpha_norm >= 8'd90) begin
                                state <= COMPUTE_CLIP;
                            end else begin
                                state <= COMPUTE_AREA;
                            end
                        end
                    end
                end
                
                COMPUTE_AREA: begin
                    // area = w*h - ( (w - h*tan_half)^2 * tan_full + (h - w*tan_half)^2 * tan_full ) / 4
                    
                    // w_t = w * tan_half
                    temp_mult = mult_w_tan;
                    reg [31:0] w_t;
                    w_t = temp_mult[47:16];
                    
                    // h_t = h * tan_half
                    temp_mult = mult_h_tan;
                    reg [31:0] h_t;
                    h_t = temp_mult[47:16];
                    
                    // (w - h*t)^2
                    temp_diff = (w_q > h_t) ? (w_q - h_t) : (h_t - w_q);
                    temp_mult = temp_diff * temp_diff;
                    reg [31:0] term1;
                    term1 = temp_mult[47:16];
                    
                    // (h - w*t)^2
                    temp_sum = (h_q > w_t) ? (h_q - w_t) : (w_t - h_q);
                    temp_mult = temp_sum * temp_sum;
                    reg [31:0] term2;
                    term2 = temp_mult[47:16];
                    
                    // term1 * tan_full
                    temp_mult = term1 * tan_full_q;
                    reg [31:0] term1_t;
                    term1_t = temp_mult[47:16];
                    
                    // term2 * tan_full
                    temp_mult = term2 * tan_full_q;
                    reg [31:0] term2_t;
                    term2_t = temp_mult[47:16];
                    
                    // sum and divide by 4
                    temp_sum = term1_t + term2_t;
                    reg [31:0] sub_term;
                    sub_term = temp_sum >> 2;
                    
                    // w*h
                    reg [31:0] wh;
                    wh = mult_w_h[47:16];
                    
                    // Final area
                    if (wh > sub_term)
                        area_result <= wh - sub_term;
                    else
                        area_result <= 32'd0;
                    
                    state <= FINISH;
                end
                
                COMPUTE_CLIP: begin
                    // area = min(w,h)^2 / sin(alpha)
                    // min_wh is in Q8.8, convert to Q16.16
                    reg [31:0] min_wh_q;
                    min_wh_q = {8'd0, min_wh, 8'd0};
                    
                    // min_wh^2
                    temp_mult = min_wh_q * min_wh_q;
                    reg [31:0] min_sq;
                    min_sq = temp_mult[47:16];
                    
                    // division by sin(alpha)
                    if (sin_alpha_q != 0) begin
                        // result = (min_sq << 16) / sin_alpha_q
                        area_result <= (min_sq << 16) / sin_alpha_q;
                    end else begin
                        area_result <= 32'd0;
                    end
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    area_o <= area_result;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule