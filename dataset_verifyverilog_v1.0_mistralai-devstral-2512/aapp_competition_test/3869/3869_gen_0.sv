module rectangle_intersection_area(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] w_i,
    input wire [15:0] h_i,
    input wire [7:0] alpha_i,
    output reg [31:0] area_o,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Internal registers for computation
    reg [15:0] w_reg, h_reg;
    reg [7:0] alpha_reg;
    reg [15:0] alpha_normalized;
    reg [15:0] sin_alpha, cos_alpha, tan_alpha, tan_half_alpha;
    reg [31:0] w_scaled, h_scaled;
    reg [31:0] w_sq, h_sq, wh_product;
    reg [31:0] term1, term2, term3, term4;
    reg [31:0] area_result;
    reg [15:0] min_wh;

    // CORDIC constants for 64 iterations
    localparam [15:0] CORDIC_ANGLES [0:63] = '{16'd45, 16'd26, 16'd14, 16'd7, 16'd4, 16'd2, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0};
    localparam [15:0] CORDIC_K = 16'd764; // 0.607252935 in Q8.8

    // CORDIC computation for sin and cos
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area_o <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            w_reg <= 16'd0;
            h_reg <= 16'd0;
            alpha_reg <= 8'd0;
            alpha_normalized <= 16'd0;
            sin_alpha <= 16'd0;
            cos_alpha <= 16'd0;
            tan_alpha <= 16'd0;
            tan_half_alpha <= 16'd0;
            w_scaled <= 32'd0;
            h_scaled <= 32'd0;
            w_sq <= 32'd0;
            h_sq <= 32'd0;
            wh_product <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            term3 <= 32'd0;
            term4 <= 32'd0;
            area_result <= 32'd0;
            min_wh <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        w_reg <= w_i;
                        h_reg <= h_i;
                        alpha_reg <= alpha_i;
                        // Normalize angle
                        if (alpha_i > 8'd90) begin
                            alpha_normalized <= 16'd180 - (alpha_i << 8);
                        end else begin
                            alpha_normalized <= alpha_i << 8;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute sin and cos using CORDIC
                    if (cycle_count == 8'd1) begin
                        // Initialize CORDIC
                        reg [15:0] x, y, z;
                        integer i;
                        x <= CORDIC_K;
                        y <= 16'd0;
                        z <= alpha_normalized;
                        
                        for (i = 0; i < 64; i = i + 1) begin
                            reg [15:0] x_next, y_next, z_next;
                            reg [15:0] angle = CORDIC_ANGLES[i];
                            
                            if (z[15]) begin
                                x_next <= x + (y >>> i);
                                y_next <= y - (x >>> i);
                                z_next <= z - angle;
                            end else begin
                                x_next <= x - (y >>> i);
                                y_next <= y + (x >>> i);
                                z_next <= z + angle;
                            end
                            
                            x <= x_next;
                            y <= y_next;
                            z <= z_next;
                        end
                        
                        cos_alpha <= x;
                        sin_alpha <= y;
                    end
                    
                    // Compute tan(alpha) = sin/cos
                    if (cycle_count == 8'd2) begin
                        if (cos_alpha != 16'd0) begin
                            tan_alpha <= (sin_alpha << 16) / cos_alpha;
                        end else begin
                            tan_alpha <= 32'd0; // Avoid division by zero
                        end
                    end
                    
                    // Compute tan(alpha/2) using double angle formula
                    if (cycle_count == 8'd3) begin
                        reg [31:0] tan_alpha_scaled = tan_alpha;
                        reg [31:0] numerator = 16'd256 - (cos_alpha << 8);
                        reg [31:0] denominator = 16'd256 + (cos_alpha << 8);
                        
                        if (denominator != 32'd0) begin
                            tan_half_alpha <= (numerator << 16) / denominator;
                        end else begin
                            tan_half_alpha <= 32'd0;
                        end
                    end
                    
                    // Scale w and h to Q16.16
                    if (cycle_count == 8'd4) begin
                        w_scaled <= w_reg << 16;
                        h_scaled <= h_reg << 16;
                    end
                    
                    // Compute w*h
                    if (cycle_count == 8'd5) begin
                        wh_product <= w_scaled * h_scaled;
                    end
                    
                    // Check for special cases
                    if (cycle_count == 8'd6) begin
                        if (alpha_normalized == 16'd0) begin
                            area_result <= wh_product;
                            state <= FINISH;
                        end else if (alpha_normalized >= 8'd90 << 8) begin
                            // min(w,h)^2 / sin(alpha)
                            if (w_reg < h_reg) begin
                                min_wh <= w_reg;
                            end else begin
                                min_wh <= h_reg;
                            end
                            
                            reg [31:0] min_wh_sq = (min_wh << 16) * (min_wh << 16);
                            if (sin_alpha != 16'd0) begin
                                area_result <= (min_wh_sq << 16) / (sin_alpha << 16);
                            end else begin
                                area_result <= 32'd0;
                            end
                            state <= FINISH;
                        end
                    end
                    
                    // General case: 0 < alpha < 90
                    if (cycle_count == 8'd7) begin
                        reg [31:0] h_tan_half = (h_scaled * tan_half_alpha) >>> 16;
                        reg [31:0] w_tan_half = (w_scaled * tan_half_alpha) >>> 16;
                        
                        term1 <= (w_scaled - h_tan_half) * (w_scaled - h_tan_half);
                        term2 <= term1 * tan_alpha;
                        term3 <= (h_scaled - w_tan_half) * (h_scaled - w_tan_half);
                        term4 <= term3 * tan_alpha;
                        
                        area_result <= wh_product - ((term2 + term4) >>> 2);
                        state <= FINISH;
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
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