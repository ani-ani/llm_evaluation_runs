module cylinder_volume (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] r,
    input wire [7:0] h,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STAGE1 = 3'd1;  // r² computation
    localparam [2:0] STAGE2 = 3'd2;  // (r² × h) computation
    localparam [2:0] STAGE3 = 3'd3;  // (r² × h × π) computation
    localparam [2:0] STAGE4 = 3'd4;  // Complete
    
    // Constants (Q16.16 format)
    localparam [31:0] PI_Q16 = 32'h0003243F;  // π × 65536 = 205887
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] r_reg, h_reg;
    reg [15:0] r_squared;        // r × r (16-bit)
    reg [23:0] r_squared_h;      // r² × h (24-bit)
    reg [47:0] pi_mult_temp;     // 48-bit intermediate for π multiplication
    reg [31:0] result_reg;       // Final Q16.16 result
    reg done_reg;
    reg busy_reg;
    
    // Control signals
    reg stage1_en, stage2_en, stage3_en, stage4_en;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = STAGE1;
                else next_state = IDLE;
            end
            STAGE1: next_state = STAGE2;
            STAGE2: next_state = STAGE3;
            STAGE3: next_state = STAGE4;
            STAGE4: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential state register and computation pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r_reg <= 8'd0;
            h_reg <= 8'd0;
            r_squared <= 16'd0;
            r_squared_h <= 24'd0;
            pi_mult_temp <= 48'd0;
            result_reg <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            done_reg <= 1'b0;
            busy_reg <= 1'b0;
            stage1_en <= 1'b0;
            stage2_en <= 1'b0;
            stage3_en <= 1'b0;
            stage4_en <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default values
            done <= 1'b0;
            stage1_en <= 1'b0;
            stage2_en <= 1'b0;
            stage3_en <= 1'b0;
            stage4_en <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        r_reg <= r;
                        h_reg <= h;
                        busy <= 1'b1;
                    end
                end
                
                STAGE1: begin
                    // Stage 1: r² = r × r
                    r_squared <= r_reg * r_reg;
                    stage1_en <= 1'b1;
                end
                
                STAGE2: begin
                    // Stage 2: r² × h
                    r_squared_h <= r_squared * h_reg;
                    stage2_en <= 1'b1;
                end
                
                STAGE3: begin
                    // Stage 3: Multiply by π (Q16.16)
                    // r_squared_h is 24-bit unsigned
                    // Extend to 32-bit Q0.24 for multiplication
                    // r_squared_h << 8 = 32-bit Q0.24
                    pi_mult_temp <= {8'd0, r_squared_h, 16'd0} * PI_Q16;
                    stage3_en <= 1'b1;
                end
                
                STAGE4: begin
                    // Stage 4: Extract Q16.16 result
                    // π_mult_temp is 48-bit: Q16.40 × Q0.24 = Q16.40
                    // Take bits [47:16] for Q16.16 format
                    result_reg <= pi_mult_temp[47:16];
                    result <= pi_mult_temp[47:16];
                    done <= 1'b1;
                    busy <= 1'b0;
                    stage4_en <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule