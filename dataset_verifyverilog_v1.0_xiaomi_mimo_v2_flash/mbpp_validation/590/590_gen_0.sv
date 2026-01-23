module PolarRectConverter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire mode,
    input wire [31:0] in1,
    input wire [31:0] in2,
    output reg [31:0] out1,
    output reg [31:0] out2,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] ITERATE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] ERROR     = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Input storage
    reg [31:0] x_reg, y_reg, r_reg, theta_reg;
    reg mode_reg;
    
    // CORDIC iteration variables (signed for signed operations)
    reg signed [31:0] x_iter, y_iter, z_iter;
    reg [3:0] iter_count;
    localparam [3:0] ITERATIONS = 4'd13;
    
    // Pre-computed atan2 values for CORDIC (Q16.16)
    // These are arctan(2^-i) for i=0 to 12
    reg signed [31:0] atan_table [0:12];
    
    // Initialize atan table
    initial begin
        atan_table[0]  = 32'sh0000C90F;  // pi/4 = 45 deg
        atan_table[1]  = 32'sh000066F6;  // arctan(1/2) ~ 26.565 deg
        atan_table[2]  = 32'sh00003572;  // arctan(1/4) ~ 14.036 deg
        atan_table[3]  = 32'sh00001C5C;  // arctan(1/8) ~ 7.125 deg
        atan_table[4]  = 32'sh00000E28;  // arctan(1/16) ~ 3.576 deg
        atan_table[5]  = 32'sh00000716;  // arctan(1/32) ~ 1.790 deg
        atan_table[6]  = 32'sh0000038B;  // arctan(1/64) ~ 0.895 deg
        atan_table[7]  = 32'sh000001C5;  // arctan(1/128) ~ 0.447 deg
        atan_table[8]  = 32'sh000000E2;  // arctan(1/256) ~ 0.224 deg
        atan_table[9]  = 32'sh00000071;  // arctan(1/512) ~ 0.112 deg
        atan_table[10] = 32'sh00000038;  // arctan(1/1024) ~ 0.056 deg
        atan_table[11] = 32'sh0000001C;  // arctan(1/2048) ~ 0.028 deg
        atan_table[12] = 32'sh0000000E;  // arctan(1/4096) ~ 0.014 deg
    end

    // Pre-computed cos/sin values for polar to rectangular (Q16.16)
    // Using common angles: 0, pi/2, pi, 3pi/2, and intermediate steps
    reg [31:0] cos_table [0:15];
    reg [31:0] sin_table [0:15];
    
    initial begin
        // cos(0) = 1.0, sin(0) = 0.0
        cos_table[0]  = 32'sh00010000; sin_table[0]  = 32'sh00000000;
        // cos(pi/12) ~ 0.9659, sin(pi/12) ~ 0.2588
        cos_table[1]  = 32'sh000F9D81; sin_table[1]  = 32'sh0004245F;
        // cos(pi/6) ~ 0.8660, sin(pi/6) = 0.5
        cos_table[2]  = 32'sh000DDB3D; sin_table[2]  = 32'sh00080000;
        // cos(pi/4) ~ 0.7071, sin(pi/4) = 0.7071
        cos_table[3]  = 32'sh000B504F; sin_table[3]  = 32'sh000B504F;
        // cos(pi/3) = 0.5, sin(pi/3) ~ 0.8660
        cos_table[4]  = 32'sh00080000; sin_table[4]  = 32'sh000DDB3D;
        // cos(5pi/12) ~ 0.2588, sin(5pi/12) ~ 0.9659
        cos_table[5]  = 32'sh0004245F; sin_table[5]  = 32'sh000F9D81;
        // cos(pi/2) = 0, sin(pi/2) = 1.0
        cos_table[6]  = 32'sh00000000; sin_table[6]  = 32'sh00010000;
        // cos(7pi/12) ~ -0.2588, sin(7pi/12) ~ 0.9659
        cos_table[7]  = 32'shFFFBDBA1; sin_table[7]  = 32'sh000F9D81;
        // cos(2pi/3) = -0.5, sin(2pi/3) ~ 0.8660
        cos_table[8]  = 32'shFF800000; sin_table[8]  = 32'sh000DDB3D;
        // cos(3pi/4) ~ -0.7071, sin(3pi/4) = 0.7071
        cos_table[9]  = 32'shFF4AFB51; sin_table[9]  = 32'sh000B504F;
        // cos(5pi/6) ~ -0.8660, sin(5pi/6) = 0.5
        cos_table[10] = 32'shFF224AC3; sin_table[10] = 32'sh00080000;
        // cos(pi) = -1.0, sin(pi) = 0
        cos_table[11] = 32'shFF000000; sin_table[11] = 32'sh00000000;
        // cos(7pi/6) ~ -0.8660, sin(7pi/6) = -0.5
        cos_table[12] = 32'shFE224AC3; sin_table[12] = 32'shFF800000;
        // cos(5pi/4) ~ -0.7071, sin(5pi/4) = -0.7071
        cos_table[13] = 32'shFDB04FB1; sin_table[13] = 32'shFF4AFB51;
        // cos(4pi/3) = -0.5, sin(4pi/3) ~ -0.8660
        cos_table[14] = 32'shFF800000; sin_table[14] = 32'shFE224AC3;
        // cos(3pi/2) = 0, sin(3pi/2) = -1.0
        cos_table[15] = 32'sh00000000; sin_table[15] = 32'shFF000000;
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out1 <= 32'd0;
            out2 <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            iter_count <= 4'd0;
            x_reg <= 32'd0;
            y_reg <= 32'd0;
            r_reg <= 32'd0;
            theta_reg <= 32'd0;
            mode_reg <= 1'b0;
            x_iter <= 32'd0;
            y_iter <= 32'd0;
            z_iter <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    iter_count <= 4'd0;
                end
                
                LOAD: begin
                    mode_reg <= mode;
                    x_reg <= in1;
                    y_reg <= in2;
                    r_reg <= 32'd0;
                    theta_reg <= 32'd0;
                    error <= 1'b0;
                    
                    // Check for invalid input (zero vector)
                    if ((in1 == 32'd0) && (in2 == 32'd0)) begin
                        error <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    // Initialize CORDIC based on mode
                    if (!mode_reg) begin
                        // Rectangular to Polar: Initialize with x_reg, y_reg
                        // Check quadrant and adjust
                        x_iter <= (x_reg[31] != y_reg[31]) ? -x_reg : x_reg;
                        y_iter <= (x_reg[31] == y_reg[31]) ? y_reg : -y_reg;
                        z_iter <= 32'd0;
                    end else begin
                        // Polar to Rectangular: Use approximation
                        // Find quadrant from theta_reg[31:28]
                        x_iter <= x_reg;
                        y_iter <= y_reg;
                        z_iter <= in2; // theta
                    end
                end
                
                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (!mode_reg) begin
                        // Rectangular to Polar CORDIC
                        if (iter_count < ITERATIONS) begin
                            if (y_iter < 32'sd0) begin
                                x_iter <= x_iter - (y_iter >>> iter_count);
                                y_iter <= y_iter + (x_iter >>> iter_count);
                                z_iter <= z_iter - atan_table[iter_count];
                            end else begin
                                x_iter <= x_iter + (y_iter >>> iter_count);
                                y_iter <= y_iter - (x_iter >>> iter_count);
                                z_iter <= z_iter + atan_table[iter_count];
                            end
                            iter_count <= iter_count + 4'd1;
                        end
                    end else begin
                        // Polar to Rectangular (simplified multiplication)
                        if (iter_count < 4'd4) begin
                            iter_count <= iter_count + 4'd1;
                            // Simplified: approximate with shift and add
                            case (iter_count)
                                4'd0: begin
                                    x_iter <= (x_reg >>> 4) + (x_reg >>> 6); // x * 0.67
                                    y_iter <= (x_reg >>> 4) - (x_reg >>> 8); // x * 0.06
                                end
                                4'd1: begin
                                    x_iter <= x_iter - (y_reg >>> 3);
                                    y_iter <= y_iter + (x_reg >>> 3);
                                end
                                4'd2: begin
                                    x_iter <= x_iter + (y_reg >>> 5);
                                    y_iter <= y_iter - (x_reg >>> 5);
                                end
                                4'd3: begin
                                    x_iter <= x_iter - (y_reg >>> 7);
                                    y_iter <= y_iter + (x_reg >>> 7);
                                end
                            endcase
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    
                    if (!mode_reg) begin
                        // Output: r, theta
                        out1 <= x_iter;  // r in Q16.16
                        out2 <= z_iter;  // theta in Q16.16
                    end else begin
                        // Output: x, y
                        out1 <= x_iter;
                        out2 <= y_iter;
                    end
                    
                    if (error) begin
                        out1 <= 32'd0;
                        out2 <= 32'd0;
                    end
                end
                
                ERROR: begin
                    done <= 1'b1;
                    error <= 1'b1;
                    out1 <= 32'd0;
                    out2 <= 32'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                next_state = ITERATE;
            end
            
            ITERATE: begin
                if (error) begin
                    next_state = ERROR;
                end else if (!mode_reg && (iter_count >= ITERATIONS)) begin
                    // Rectangular to Polar complete
                    next_state = FINISH;
                end else if (mode_reg && (iter_count >= 4'd4)) begin
                    // Polar to Rectangular complete
                    next_state = FINISH;
                end else if (cycle_count >= MAX_CYCLES) begin
                    // Timeout protection
                    next_state = ERROR;
                end else begin
                    next_state = ITERATE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            ERROR: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule