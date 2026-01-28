module surface_area_cylinder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] r,
    input wire [15:0] h,
    output reg [31:0] result,
    output reg done
);

    // Fixed-point constants
    localparam [31:0] PI_SCALED = 32'd205887;  // 3.1416 * 65536
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STAGE1 = 3'd1;  // r + h
    localparam [2:0] STAGE2 = 3'd2;  // pi * r
    localparam [2:0] STAGE3 = 3'd3;  // 2 * pi_r
    localparam [2:0] STAGE4 = 3'd4;  // (2*pi*r) * (r+h)
    localparam [2:0] FINISH = 3'd5;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    // Intermediate registers
    reg [15:0] r_reg;
    reg [15:0] h_reg;
    reg [31:0] r_plus_h;      // 16-bit result stored in 32-bit
    reg [31:0] pi_times_r;    // 32-bit result
    reg [31:0] two_pi_times_r; // 32-bit result
    
    // Combinational signals
    wire [31:0] r_plus_h_wire = r_reg + h_reg;
    wire [63:0] pi_r_mult = PI_SCALED * r_reg;
    wire [31:0] two_pi_r_wire = pi_times_r << 1;  // Multiply by 2
    wire [63:0] final_mult = two_pi_times_r * r_plus_h;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            r_reg <= 16'd0;
            h_reg <= 16'd0;
            r_plus_h <= 32'd0;
            pi_times_r <= 32'd0;
            two_pi_times_r <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        r_reg <= r;
                        h_reg <= h;
                        state <= STAGE1;
                    end
                end
                
                STAGE1: begin
                    // Compute r + h (16-bit addition)
                    r_plus_h <= r_plus_h_wire;
                    state <= STAGE2;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                STAGE2: begin
                    // Compute pi * r (32-bit multiplication)
                    // PI_SCALED is 32-bit, r_reg is 16-bit
                    // Result is 48-bit, take upper 32 bits for Q16.16
                    pi_times_r <= pi_r_mult[47:16];
                    state <= STAGE3;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                STAGE3: begin
                    // Compute 2 * pi_r (left shift by 1)
                    two_pi_times_r <= two_pi_r_wire;
                    state <= STAGE4;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                STAGE4: begin
                    // Compute final result: (2*pi*r) * (r+h)
                    // Both are Q16.16, result is Q32.32, take upper 32 bits
                    result <= final_mult[63:32];
                    state <= FINISH;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule