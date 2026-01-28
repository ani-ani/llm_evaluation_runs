module sphere_area_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] radius,
    output reg [31:0] result,
    output reg done
);

    // Fixed-point constants
    localparam [31:0] FIXED_PI = 32'h0003243F;  // Q16.16: 3.14159
    localparam [31:0] FIXED_FOUR = 32'h00040000;  // Q16.16: 4.0
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] STAGE1 = 2'd1;  // r^2
    localparam [1:0] STAGE2 = 2'd2;  // multiply by pi
    localparam [1:0] STAGE3 = 2'd3;  // multiply by 4
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] radius_reg;
    reg [31:0] result_reg;
    reg [31:0] temp_stage1;  // r^2 stored as Q0.16
    reg [31:0] temp_stage2;  // r^2 * pi stored as Q16.16
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for multiplication
    wire [31:0] r_squared;
    wire [63:0] stage2_mult;  // 32x32 = 64 bit
    wire [63:0] stage3_mult;  // 32x32 = 64 bit
    
    // r^2 calculation: 8-bit * 8-bit = 16-bit (Q0.16 format)
    wire [15:0] r_sq_16;
    assign r_sq_16 = radius_reg * radius_reg;
    assign r_squared = {16'd0, r_sq_16};  // Extend to 32-bit
    
    // Stage 2: r^2 * pi (32x32 = 64)
    assign stage2_mult = r_squared * FIXED_PI;
    
    // Stage 3: (r^2 * pi) * 4 (32x32 = 64)
    assign stage3_mult = temp_stage2 * FIXED_FOUR;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? STAGE1 : IDLE;
            STAGE1:     next_state = STAGE2;
            STAGE2:     next_state = STAGE3;
            STAGE3:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            radius_reg <= 8'd0;
            result_reg <= 32'd0;
            temp_stage1 <= 32'd0;
            temp_stage2 <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            // Update state
            state <= next_state;
            
            // Cycle counter (safety)
            if (state == IDLE && start) begin
                cycle_count <= 8'd0;
            end else if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        radius_reg <= radius;
                    end
                end
                
                STAGE1: begin
                    // Calculate r^2 and store in Q16.16 format
                    // r^2 is 16-bit Q0.16, shift left by 16 bits
                    temp_stage1 <= {r_sq_16, 16'd0};
                end
                
                STAGE2: begin
                    // Multiply r^2 by pi, take middle 32 bits
                    // stage2_mult[47:16] gives Q16.16 result
                    temp_stage2 <= stage2_mult[47:16];
                end
                
                STAGE3: begin
                    // Multiply by 4, take middle 32 bits
                    // Final result in Q16.16 format
                    result_reg <= stage3_mult[47:16];
                    result <= stage3_mult[47:16];
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule