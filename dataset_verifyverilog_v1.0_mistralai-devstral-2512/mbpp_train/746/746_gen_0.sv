module SectorAreaCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] radius,
    input wire [31:0] angle,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    // Fixed-point constants
    localparam [31:0] PI_Q16_16      = 32'h3243F;  // 3.14159265
    localparam [31:0] RECIP_360_Q16_16 = 32'h15E;   // 0.002777...
    localparam [31:0] MAX_ANGLE_Q16_16 = 32'h01680000; // 360.0
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] cycle_count;
    reg [31:0] r_squared;
    reg [31:0] pi_times_r_squared;
    reg [31:0] pi_r_sq_times_angle;
    reg [31:0] final_result;
    reg angle_valid;
    
    // Cycle counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
            r_squared <= 32'd0;
            pi_times_r_squared <= 32'd0;
            pi_r_sq_times_angle <= 32'd0;
            final_result <= 32'd0;
            angle_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Check if angle is valid
                        angle_valid <= (angle <= MAX_ANGLE_Q16_16);
                        
                        if (angle_valid) begin
                            state <= COMPUTE;
                        end else begin
                            error <= 1'b1;
                            result <= 32'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Pipeline computation
                    if (cycle_count == 8'd1) begin
                        // Step 1: r_squared = radius * radius (Q16.16 * Q16.16 = Q32.32)
                        // We keep upper 32 bits (Q16.16)
                        r_squared <= (radius * radius) >> 16;
                    end else if (cycle_count == 8'd2) begin
                        // Step 2: pi_times_r_squared = PI * r_squared (Q16.16 * Q16.16 = Q32.32)
                        // Keep upper 32 bits (Q16.16)
                        pi_times_r_squared <= (PI_Q16_16 * r_squared) >> 16;
                    end else if (cycle_count == 8'd3) begin
                        // Step 3: pi_r_sq_times_angle = pi_times_r_squared * angle (Q16.16 * Q16.16 = Q32.32)
                        // Keep upper 32 bits (Q16.16)
                        pi_r_sq_times_angle <= (pi_times_r_squared * angle) >> 16;
                    end else if (cycle_count == 8'd4) begin
                        // Step 4: final_result = pi_r_sq_times_angle * RECIP_360 (Q16.16 * Q16.16 = Q32.32)
                        // Keep upper 32 bits (Q16.16)
                        final_result <= (pi_r_sq_times_angle * RECIP_360_Q16_16) >> 16;
                        
                        // Clamp to valid range (0 to 65535.0)
                        if (final_result > 32'h03FF0000) begin
                            final_result <= 32'h03FF0000;
                        end
                        
                        state <= DONE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Timeout - force completion
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    if (angle_valid) begin
                        result <= final_result;
                        done <= 1'b1;
                    end else begin
                        result <= 32'd0;
                        error <= 1'b1;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule