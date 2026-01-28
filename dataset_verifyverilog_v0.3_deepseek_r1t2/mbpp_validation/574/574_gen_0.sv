module cylinder_surface_area(
    input clk,
    input rst_n,
    input start,
    input [15:0] radius,
    input [15:0] height,
    output reg [31:0] result,
    output reg done
);
    
    // Constants (Q8.8 format)
    localparam [15:0] PI_FIXED = 16'h0324;  // 804.25 = 3.14159265*256
    localparam [15:0] TWO = 16'h0200;       // 2 in Q8.8 format (512)
    
    // State machine declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CALC_R_SQ   = 3'd1;
    localparam [2:0] CALC_TERM1  = 3'd2;
    localparam [2:0] CALC_TERM2  = 3'd3;
    localparam [2:0] OUTPUT      = 3'd4;
    
    reg [2:0] state;
    reg [31:0] temp_reg;  // Q16.16 format
    reg [31:0] term1_reg; // Q16.16
    reg [31:0] term2_reg; // Q16.16
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            temp_reg <= 32'd0;
            term1_reg <= 32'd0;
            term2_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_reg <= radius * radius;  // Q16.16
                        state <= CALC_R_SQ;
                    end
                end
                
                CALC_R_SQ: begin
                    // Calculate term1 = 2 * π * r²
                    // temp_reg = r²
                    // term1_reg = (temp_reg * PI_FIXED * 2) >> 8
                    term1_reg <= ((temp_reg * PI_FIXED) << 1) >>> 8;  // Multiply by 2 and divide by 256 (Q16.16)
                    state <= CALC_TERM1;
                end
                
                CALC_TERM1: begin
                    // Calculate term2 = 2 * π * r * h
                    temp_reg <= radius * height;  // Q16.16
                    state <= CALC_TERM2;
                end
                
                CALC_TERM2: begin
                    // term2_reg = (temp_reg * PI_FIXED * 2) >> 8
                    term2_reg <= ((temp_reg * PI_FIXED) << 1) >>> 8;  // Q16.16
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    result <= term1_reg + term2_reg;  // Q16.16
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule