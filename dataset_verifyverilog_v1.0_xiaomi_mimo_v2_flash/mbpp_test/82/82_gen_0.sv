module sphere_volume(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,
    output reg [31:0] volume,
    output reg done
);

    // Fixed-point constants for Q16.16 format
    // PI = 3.141592653589793 * 65536 = 205887
    localparam [31:0] PI_FIXED = 32'd205887;
    // 4/3 = 1.333333333333333 * 65536 = 87381
    localparam [31:0] FOUR_THIRDS = 32'd87381;
    
    // State machine states
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] COMPUTE_R2   = 4'd1;
    localparam [3:0] COMPUTE_R3   = 4'd2;
    localparam [3:0] COMPUTE_R3_PI = 4'd3;
    localparam [3:0] COMPUTE_FINAL = 4'd4;
    localparam [3:0] DONE_STATE   = 4'd5;
    
    reg [3:0] state;
    reg [31:0] r2;      // r^2 (scaled)
    reg [31:0] r3;      // r^3 (scaled)
    reg [47:0] temp;    // 48-bit intermediate
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            volume <= 32'd0;
            done <= 1'b0;
            r2 <= 32'd0;
            r3 <= 32'd0;
            temp <= 48'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_R2;
                        // Scale radius: radius is provided as value * 256
                        // r2 = (radius * radius) / 256 = radius * radius >> 8
                        r2 <= (radius * radius) >> 8;
                    end
                end
                
                COMPUTE_R2: begin
                    // r3 = (r2 * radius) / 256
                    // r2 is already scaled, multiply then shift
                    r3 <= (r2 * radius) >> 8;
                    state <= COMPUTE_R3;
                end
                
                COMPUTE_R3: begin
                    // Multiply r3 by PI, result scaled by 256 (from r3) * 65536 = 16777216
                    // temp = r3 * PI_FIXED
                    temp <= r3 * PI_FIXED;
                    state <= COMPUTE_R3_PI;
                end
                
                COMPUTE_R3_PI: begin
                    // Shift right by 16 to get Q16.16 format (remove extra scaling)
                    // temp is now r3 * PI, we need to divide by 256 (from radius scaling)
                    // temp >> 16 gives r3 * PI in Q16.16, but r3 still needs division by 256
                    // So: temp >> (16 + 8) = temp >> 24
                    temp <= temp >> 8;  // First shift 8 to divide by 256
                    state <= COMPUTE_FINAL;
                end
                
                COMPUTE_FINAL: begin
                    // Multiply by 4/3 and scale to Q16.16
                    // temp is now r3 * PI / 256 (value in Q16.16)
                    // Multiply by FOUR_THIRDS (1.3333... in Q16.16)
                    // temp * FOUR_THIRDS, then shift right 16 to maintain Q16.16
                    volume <= (temp[31:0] * FOUR_THIRDS) >> 16;
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