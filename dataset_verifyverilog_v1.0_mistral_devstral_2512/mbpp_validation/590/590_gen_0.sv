module PolarRectConverter(
    input clk,
    input rst_n,
    input start,
    input mode,
    input signed [31:0] in1,
    input signed [31:0] in2,
    output reg signed [31:0] out1,
    output reg signed [31:0] out2,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Internal registers for computation
    reg signed [31:0] x_reg, y_reg;
    reg signed [31:0] r_reg, theta_reg;
    reg signed [31:0] temp1, temp2;
    reg signed [31:0] cos_theta, sin_theta;
    
    // Pre-computed values for atan2 approximation
    localparam signed [31:0] PI = 32'sd205887;  // Q16.16
    localparam signed [31:0] PI_OVER_4 = 32'sd16457;  // Q16.16
    localparam signed [31:0] PI_OVER_2 = 32'sd102943;  // Q16.16
    localparam signed [31:0] THREE_PI_OVER_4 = 32'sd154414;  // Q16.16
    
    // CORDIC constants (scaled by 2^16)
    localparam signed [31:0] CORDIC_K = 32'sd60725;  // 0.60725 * 2^16
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            out1 <= 32'd0;
            out2 <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            x_reg <= 32'd0;
            y_reg <= 32'd0;
            r_reg <= 32'd0;
            theta_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Initialize computation registers
                        if (mode) begin  // Polar to Rectangular
                            r_reg <= in1;
                            theta_reg <= in2;
                        end else begin  // Rectangular to Polar
                            x_reg <= in1;
                            y_reg <= in2;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (mode) begin  // Polar to Rectangular: x = r*cos(theta), y = r*sin(theta)
                        // Approximate cos and sin using piecewise linear
                        temp1 = theta_reg;
                        
                        // Normalize theta to [0, PI/2]
                        if (temp1 < 32'd0) begin
                            temp1 = -temp1;
                        end
                        
                        if (temp1 > PI_OVER_2) begin
                            temp1 = PI - temp1;
                        end
                        
                        if (temp1 > PI_OVER_4) begin
                            temp1 = PI_OVER_2 - temp1;
                        end
                        
                        // Linear approximation for cos and sin in [0, PI/4]
                        // cos(theta) ≈ 1 - theta^2/2
                        // sin(theta) ≈ theta - theta^3/6
                        temp2 = (temp1 * temp1) >> 16;  // theta^2
                        cos_theta = 32'sd65536 - (temp2 >> 1);  // 1 - theta^2/2
                        
                        temp2 = (temp1 * temp2) >> 16;  // theta^3
                        sin_theta = temp1 - (temp2 >> 3);  // theta - theta^3/6
                        
                        // Compute x and y
                        out1 <= (r_reg * cos_theta) >> 16;
                        out2 <= (r_reg * sin_theta) >> 16;
                        
                        state <= FINISH;
                    end else begin  // Rectangular to Polar: r = sqrt(x^2 + y^2), theta = atan2(y, x)
                        // Check for zero vector
                        if (x_reg == 32'd0 && y_reg == 32'd0) begin
                            error <= 1'b1;
                            state <= FINISH;
                        end else begin
                            // Compute r = sqrt(x^2 + y^2)
                            temp1 = (x_reg * x_reg) >> 16;
                            temp2 = (y_reg * y_reg) >> 16;
                            r_reg = temp1 + temp2;
                            
                            // Approximate sqrt using Newton-Raphson (2 iterations)
                            if (r_reg > 32'd0) begin
                                temp1 = r_reg;
                                temp2 = (temp1 + (r_reg << 16) / temp1) >> 1;
                                temp1 = (temp2 + (r_reg << 16) / temp2) >> 1;
                                r_reg = temp1;
                            end
                            
                            // Compute theta = atan2(y, x)
                            if (x_reg == 32'd0) begin
                                if (y_reg > 32'd0) begin
                                    theta_reg = PI_OVER_2;
                                end else begin
                                    theta_reg = -PI_OVER_2;
                                end
                            end else begin
                                // Compute atan(y/x) using piecewise linear approximation
                                temp1 = (y_reg << 16) / x_reg;  // y/x in Q16.16
                                
                                // Limit to [-1, 1] range
                                if (temp1 > 32'sd65536) begin
                                    temp1 = 32'sd65536;
                                end else if (temp1 < -32'sd65536) begin
                                    temp1 = -32'sd65536;
                                end
                                
                                // Approximate atan(z) for z in [-1, 1]
                                // atan(z) ≈ z - z^3/3 + z^5/5
                                temp2 = (temp1 * temp1) >> 16;  // z^2
                                temp2 = (temp1 * temp2) >> 16;  // z^3
                                theta_reg = temp1 - (temp2 >> 2);  // z - z^3/3
                                
                                temp2 = (temp2 * temp2) >> 16;  // z^6
                                temp2 = (temp1 * temp2) >> 16;  // z^7
                                theta_reg = theta_reg + (temp2 >> 3);  // + z^5/5
                                
                                // Adjust quadrant
                                if (x_reg < 32'd0) begin
                                    if (y_reg >= 32'd0) begin
                                        theta_reg = theta_reg + PI;
                                    end else begin
                                        theta_reg = theta_reg - PI;
                                    end
                                end else if (y_reg < 32'd0) begin
                                    theta_reg = -theta_reg;
                                end
                            end
                            
                            out1 <= r_reg;
                            out2 <= theta_reg;
                            state <= FINISH;
                        end
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule