module polar_rect_converter (
    input clk,
    input rst_n,
    input start,
    input [1:0] mode,
    input [31:0] input_a,
    input [31:0] input_b,
    output reg [31:0] output_x,
    output reg [31:0] output_y,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATE_SQRT = 2'b01;
    localparam CALCULATE_TRIG = 2'b10;
    localparam DONE = 2'b11;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [5:0] counter;
    reg [5:0] next_counter;
    
    // Operation registers
    reg op_mode; // 0: polar->rect, 1: rect->polar
    reg [31:0] r_reg; // r or x
    reg [31:0] theta_reg; // theta or y
    
    // Intermediate computation registers
    reg [63:0] sqrt_val; // 64-bit for sqrt accumulation
    reg [63:0] sqrt_remainder;
    reg [31:0] sqrt_result;
    
    reg [63:0] xCORDIC; // CORDIC x
    reg [63:0] yCORDIC; // CORDIC y
    reg [63:0] zCORDIC; // CORDIC z (angle)
    reg [31:0] atan_result;
    
    // Trig state machine
    reg trig_done;
    reg [31:0] cos_val;
    reg [31:0] sin_val;
    
    // Constants
    localparam [31:0] ONE = 32'h00010000; // 1.0 in Q16.16
    localparam [31:0] PI = 32'h0003243F; // 3.14159265
    localparam [31:0] TWO_PI = 32'h0006487F; // 2*PI
    localparam [31:0] PI_HALF = 32'h00019220; // PI/2
    localparam [31:0] PI_QUARTER = 32'h0000C910; // PI/4
    localparam [31:0] CORDIC_K = 32'h00009B74; // 0.607252935 in Q16.16
    
    // CORDIC angle table (16 entries, angles = atan(2^-i))
    reg [31:0] cordic_angles [0:15];
    
    // Initialize angle table
    initial begin
        cordic_angles[0] = 32'h00019220; // atan(1) = PI/4 = 0.7854
        cordic_angles[1] = 32'h0000ED63; // atan(0.5) = 0.4636
        cordic_angles[2] = 32'h00007BAB; // atan(0.25) = 0.2450
        cordic_angles[3] = 32'h00003F89; // atan(0.125) = 0.1227
        cordic_angles[4] = 32'h00001FF2; // atan(0.0625) = 0.0612
        cordic_angles[5] = 32'h00000FFE; // atan(0.03125) = 0.0306
        cordic_angles[6] = 32'h000007FF; // atan(0.015625) = 0.0153
        cordic_angles[7] = 32'h00000400; // atan(0.0078125) = 0.00765
        cordic_angles[8] = 32'h00000200; // atan(0.00390625) = 0.00382
        cordic_angles[9] = 32'h00000100; // atan(0.001953125) = 0.00191
        cordic_angles[10] = 32'h00000080; // atan(0.0009765625) = 0.00095
        cordic_angles[11] = 32'h00000040; // atan(0.00048828125) = 0.000478
        cordic_angles[12] = 32'h00000020; // atan(0.000244140625) = 0.000239
        cordic_angles[13] = 32'h00000010; // atan(0.0001220703125) = 0.000119
        cordic_angles[14] = 32'h00000008; // atan(0.00006103515625) = 0.0000598
        cordic_angles[15] = 32'h00000004; // atan(0.000030517578125) = 0.0000299
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 6'd0;
            done <= 1'b0;
            output_x <= 32'd0;
            output_y <= 32'd0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            
            if (state == IDLE && start) begin
                op_mode <= mode;
                r_reg <= input_a;
                theta_reg <= input_b;
                done <= 1'b0;
            end
            
            // State-specific register updates
            case (state)
                IDLE: begin
                    // Register inputs handled above
                end
                
                CALCULATE_SQRT: begin
                    if (counter == 6'd0) begin
                        // Initialize sqrt: shift remainder and clear result
                        sqrt_val <= {32'd0, r_reg}; // x^2 or y^2 will be multiplied later
                        sqrt_remainder <= 64'd0;
                        sqrt_result <= 32'd0;
                    end else if (counter <= 6'd16) begin
                        // Bit-by-bit sqrt algorithm
                        // Working on sqrt(x^2 + y^2) where x=r_reg, y=theta_reg for polar->rect
                        // For rect->polar: sqrt(x^2 + y^2) where x=r_reg, y=theta_reg
                        // Actually we need to compute sqrt of sum of squares
                        
                        // Let's restructure: use r_reg as x, theta_reg as y for sqrt calculation
                        // First iteration computes the sum
                    end
                    
                    // We'll handle the sqrt logic in combinational block
                end
                
                CALCULATE_TRIG: begin
                    if (op_mode == 1'b1) begin
                        // Rect to Polar: atan2(y, x) using CORDIC
                        if (counter == 6'd0) begin
                            // Initialize CORDIC: scale inputs and set angle to 0
                            if (r_reg[31]) begin // negative x
                                xCORDIC <= {16'd0, -r_reg[31:16], r_reg[15:0]}; // abs(x) << 16
                                yCORDIC <= {16'd0, theta_reg[31:16], theta_reg[15:0]}; // y << 16
                                zCORDIC <= -{16'd0, PI}; // start at -PI
                            end else begin
                                xCORDIC <= {16'd0, r_reg[31:16], r_reg[15:0]}; // x << 16
                                yCORDIC <= {16'd0, theta_reg[31:16], theta_reg[15:0]}; // y << 16
                                zCORDIC <= 64'd0;
                            end
                            atan_result <= 32'd0;
                        end else if (counter <= 6'd16) begin
                            // CORDIC iteration
                            if (yCORDIC[63]) begin // y negative, rotate clockwise
                                xCORDIC <= xCORDIC + (yCORDIC >>> counter);
                                yCORDIC <= yCORDIC - (xCORDIC >>> counter);
                                zCORDIC <= zCORDIC - {1'b0, cordic_angles[counter-1]};
                            end else begin // y positive, rotate counter-clockwise
                                xCORDIC <= xCORDIC - (yCORDIC >>> counter);
                                yCORDIC <= yCORDIC + (xCORDIC >>> counter);
                                zCORDIC <= zCORDIC + {1'b0, cordic_angles[counter-1]};
                            end
                        end else if (counter == 6'd17) begin
                            // Normalize and store result
                            atan_result <= zCORDIC[47:16]; // Extract Q16.16
                        end
                    end else begin
                        // Polar to Rect: r * cos(theta) and r * sin(theta)
                        // Using CORDIC rotation mode
                        if (counter == 6'd0) begin
                            // Initialize
                            xCORDIC <= {16'd0, CORDIC_K}; // x = K (1.0)
                            yCORDIC <= 64'd0;
                            zCORDIC <= {16'd0, theta_reg}; // angle input
                            
                            // Handle quadrant to keep angle in -PI/2 to PI/2
                            if (theta_reg >= PI && theta_reg < TWO_PI) begin
                                zCORDIC <= {16'd0, theta_reg} - {16'd0, TWO_PI};
                            end else if (theta_reg >= PI_HALF && theta_reg < PI) begin
                                zCORDIC <= {16'd0, theta_reg} - {16'd0, PI_HALF};
                                // Swap and negate
                                xCORDIC <= 64'd0;
                                yCORDIC <= {16'd0, CORDIC_K};
                            end else if (theta_reg >= PI_QUARTER && theta_reg < PI_HALF) begin
                                zCORDIC <= {16'd0, PI_HALF} - {16'd0, theta_reg};
                                xCORDIC <= 64'd0;
                                yCORDIC <= {16'd0, CORDIC_K};
                            end
                        end else if (counter <= 6'd16) begin
                            // CORDIC rotation
                            if (zCORDIC[63]) begin // negative angle, rotate clockwise
                                xCORDIC <= xCORDIC + (yCORDIC >>> counter);
                                yCORDIC <= yCORDIC - (xCORDIC >>> counter);
                                zCORDIC <= zCORDIC + {1'b0, cordic_angles[counter-1]};
                            end else begin
                                xCORDIC <= xCORDIC - (yCORDIC >>> counter);
                                yCORDIC <= yCORDIC + (xCORDIC >>> counter);
                                zCORDIC <= zCORDIC - {1'b0, cordic_angles[counter-1]};
                            end
                        end else if (counter == 6'd17) begin
                            // Multiply by r and handle quadrant
                            cos_val <= (xCORDIC[47:16] * r_reg) >>> 16;
                            sin_val <= (yCORDIC[47:16] * r_reg) >>> 16;
                        end
                    end
                end
                
                DONE: begin
                    if (op_mode == 1'b1) begin
                        // Rect to Polar: sqrt result in output_x, atan2 in output_y
                        output_x <= sqrt_result;
                        output_y <= atan_result;
                    end else begin
                        // Polar to Rect: cos*r in output_x, sin*r in output_y
                        output_x <= cos_val;
                        output_y <= sin_val;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_counter = counter;
        trig_done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (mode == 1'b1) begin
                        // Rect to Polar: needs sqrt and atan2
                        next_state = CALCULATE_SQRT;
                    end else begin
                        // Polar to Rect: needs trig
                        next_state = CALCULATE_TRIG;
                    end
                    next_counter = 6'd0;
                end
            end
            
            CALCULATE_SQRT: begin
                // Compute sqrt(x^2 + y^2) in 16 iterations + 2 cycles
                if (counter < 6'd16) begin
                    next_counter = counter + 6'd1;
                    next_state = CALCULATE_SQRT;
                end else if (counter == 6'd16) begin
                    // Transition to atan2 calculation
                    next_counter = 6'd0;
                    next_state = CALCULATE_TRIG;
                end
            end
            
            CALCULATE_TRIG: begin
                if (counter < 6'd17) begin
                    next_counter = counter + 6'd1;
                    next_state = CALCULATE_TRIG;
                end else begin
                    next_state = DONE;
                    next_counter = 6'd0;
                end
            end
            
            DONE: begin
                next_state = IDLE;
                next_counter = 6'd0;
            end
        endcase
    end
    
    // Combinational sqrt logic (separate from sequential)
    always @(*) begin
        if (state == CALCULATE_SQRT && counter < 6'd16) begin
            // First, calculate sum of squares
            if (counter == 6'd0) begin
                // x^2 + y^2 (all 64-bit)
                sqrt_val = (r_reg * r_reg) + (theta_reg * theta_reg);
                sqrt_remainder = 64'd0;
                sqrt_result = 32'd0;
            end else begin
                // Bit-by-bit sqrt
                reg [63:0] test;
                test = {sqrt_result[30:0], 1'b1}; // try next bit
                test = test * test;
                
                if ({sqrt_remainder[61:0], sqrt_val[63:62]} >= test) begin
                    sqrt_remainder = {sqrt_remainder[61:0], sqrt_val[63:62]} - test;
                    sqrt_result = {sqrt_result[30:0], 1'b1};
                end else begin
                    sqrt_remainder = {sqrt_remainder[61:0], sqrt_val[63:62]};
                    sqrt_result = {sqrt_result[30:0], 1'b0};
                end
                sqrt_val = sqrt_val << 2;
            end
        end else if (state == CALCULATE_SQRT && counter == 6'd16) begin
            // Finalize sqrt (16-bit to 16.16 conversion)
            sqrt_result = sqrt_result; // Already the result
        end
    end

endmodule
