module cylinder_volume(
    input clk,
    input rst_n,
    input start,
    input [7:0] r,
    input [7:0] h,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] STAGE1  = 3'd1;
    localparam [2:0] STAGE2  = 3'd2;
    localparam [2:0] STAGE3  = 3'd3;
    localparam [2:0] FINISH  = 3'd4;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Pipeline registers
    reg [15:0] r_squared;
    reg [23:0] r_squared_h;
    reg [7:0] r_latched;
    reg [7:0] h_latched;

    // Constants
    localparam [31:0] PI_Q16_16 = 32'h3243F;  // 3.14159265 in Q16.16

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 8'd0;
            r_squared <= 16'd0;
            r_squared_h <= 24'd0;
            r_latched <= 8'd0;
            h_latched <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= STAGE1;
                        busy <= 1'b1;
                        r_latched <= r;
                        h_latched <= h;
                    end
                end
                
                STAGE1: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute r^2 (8-bit * 8-bit = 16-bit)
                    r_squared <= r_latched * r_latched;
                    state <= STAGE2;
                end
                
                STAGE2: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute r^2 * h (16-bit * 8-bit = 24-bit)
                    r_squared_h <= r_squared * h_latched;
                    state <= STAGE3;
                end
                
                STAGE3: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Multiply by PI (24-bit * 32-bit = 56-bit, take middle 32 bits for Q16.16)
                    // Shift left by 16 to align fractional parts
                    reg [55:0] temp;
                    temp = r_squared_h * PI_Q16_16;
                    result <= temp[47:16];  // Take bits 47-16 for Q16.16 result
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
        end
    end

endmodule