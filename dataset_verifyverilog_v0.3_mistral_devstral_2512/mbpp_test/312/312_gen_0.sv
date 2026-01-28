module cone_volume (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,      // 16-bit unsigned radius
    input wire [15:0] height,      // 16-bit unsigned height
    output reg [31:0] volume,      // 32-bit fixed-point Q16.16 result
    output reg done
);

    // Fixed-point constants (Q16.16 format)
    // pi = 3.14159265 * 65536 = 205887
    // one_third = 0.33333333 * 65536 = 21845
    localparam [31:0] PI_FIXED = 32'd205887;
    localparam [31:0] ONE_THIRD = 32'd21845;
    
    // State machine
    reg [2:0] state;
    reg [31:0] r_squared;
    reg [31:0] r_squared_h;
    reg [31:0] temp_result;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_R2 = 3'd1;
    localparam [2:0] CALC_R2H = 3'd2;
    localparam [2:0] CALC_PI = 3'd3;
    localparam [2:0] CALC_THIRD = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            volume <= 32'd0;
            r_squared <= 32'd0;
            r_squared_h <= 32'd0;
            temp_result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC_R2;
                    end
                end
                
                CALC_R2: begin
                    // r_squared = radius * radius (16-bit * 16-bit = 32-bit)
                    r_squared <= radius * radius;
                    state <= CALC_R2H;
                end
                
                CALC_R2H: begin
                    // r_squared_h = r_squared * height (32-bit * 16-bit = 48-bit, truncate to 32-bit)
                    r_squared_h <= r_squared * height;
                    state <= CALC_PI;
                end
                
                CALC_PI: begin
                    // Multiply by pi (21845 * 205887, then shift by 16 bits)
                    temp_result <= (r_squared_h * PI_FIXED) >>> 16;
                    state <= CALC_THIRD;
                end
                
                CALC_THIRD: begin
                    // Multiply by 1/3 (divide by 3 using multiplication by 21845, shift by 16)
                    volume <= (temp_result * ONE_THIRD) >>> 16;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule