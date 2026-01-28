module polar_to_rect(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] polar_mag,
    input wire [15:0] polar_phi,
    output reg [15:0] rect_x,
    output reg [15:0] rect_y,
    output reg done
);
    // Q16.16 fixed-point format: 16 integer bits, 16 fractional bits
    // Input polar_phi is 0 to 65536 representing 0 to 2π radians
    // Lookup table: 256 entries for sin(0..π/2) in Q16.16
    
    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] QUADRANT    = 3'd1;
    localparam [2:0] LOOKUP      = 3'd2;
    localparam [2:0] MULT        = 3'd3;
    localparam [2:0] FINISH      = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [1:0] quadrant_reg;
    reg sign_x_reg;
    reg sign_y_reg;
    reg [15:0] angle_reg;
    reg [15:0] mag_reg;
    reg [15:0] sin_val_reg;
    reg [15:0] cos_val_reg;
    reg [7:0] lookup_idx;
    reg [7:0] cycle_count;
    
    // 32-bit intermediates for multiplication
    reg [31:0] mult_x_temp;
    reg [31:0] mult_y_temp;
    
    // Lookup table storage (256 entries x 16 bits)
    reg [15:0] sin_table [0:255];
    
    // Initialize lookup table at compile time
    initial begin
        // Pre-calculated sin values for 0 to π/2 in Q16.16 format
        // These are approximate values for demonstration
        // sin(0) = 0, sin(π/2) = 1.0 = 65536
        sin_table[0] = 16'd0;
        sin_table[1] = 16'd257;
        sin_table[2] = 16'd514;
        sin_table[3] = 16'd771;
        sin_table[4] = 16'd1028;
        sin_table[5] = 16'd1285;
        sin_table[6] = 16'd1542;
        sin_table[7] = 16'd1799;
        sin_table[8] = 16'd2056;
        sin_table[9] = 16'd2313;
        sin_table[10] = 16'd2570;
        sin_table[11] = 16'd2827;
        sin_table[12] = 16'd3084;
        sin_table[13] = 16'd3341;
        sin_table[14] = 16'd3598;
        sin_table[15] = 16'd3855;
        // ... fill rest with interpolated values
        // For brevity, show pattern; in real implementation, all 256 values
        // would be pre-calculated and initialized
        sin_table[127] = 16'd46341; // sin(π/4) = √2/2
        sin_table[255] = 16'd65535; // sin(π/2) ≈ 1.0
        
        // Fill remaining entries with approximate values
        // In practice, these would be calculated offline
        for (integer i = 16; i < 255; i = i + 1) begin
            if (i < 127)
                sin_table[i] = (i * 256) >> 8;
            else
                sin_table[i] = 65535 - ((255 - i) * 256) >> 8;
        end
    end
    
    // Quadrant mapping logic
    wire [1:0] phi_quadrant;
    wire [15:0] phi_mapped;
    wire sign_x_calc;
    wire sign_y_calc;
    
    // Determine quadrant based on phi (0 to 65536)
    // Q1: 0-16384 (0 to π/2)
    // Q2: 16384-32768 (π/2 to π)
    // Q3: 32768-49152 (π to 3π/2)
    // Q4: 49152-65536 (3π/2 to 2π)
    assign phi_quadrant = (polar_phi < 16'd16384) ? 2'd0 :
                         (polar_phi < 16'd32768) ? 2'd1 :
                         (polar_phi < 16'd49152) ? 2'd2 : 2'd3;
    
    // Map angle to 0..π/2 for lookup
    assign phi_mapped = (phi_quadrant == 2'd0) ? polar_phi :
                       (phi_quadrant == 2'd1) ? (16'd32768 - polar_phi) :
                       (phi_quadrant == 2'd2) ? (polar_phi - 16'd32768) :
                       (16'd65536 - polar_phi);
    
    // Determine signs based on quadrant
    assign sign_x_calc = (phi_quadrant == 2'd1) ? 1'b1 :  // Q2: negative
                        (phi_quadrant == 2'd2) ? 1'b1 :  // Q3: negative
                        1'b0;                           // Q1, Q4: positive
    
    assign sign_y_calc = (phi_quadrant == 2'd2) ? 1'b1 :  // Q3: negative
                        (phi_quadrant == 2'd3) ? 1'b1 :  // Q4: negative
                        1'b0;                           // Q1, Q2: positive
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            quadrant_reg <= 2'd0;
            sign_x_reg <= 1'b0;
            sign_y_reg <= 1'b0;
            angle_reg <= 16'd0;
            mag_reg <= 16'd0;
            sin_val_reg <= 16'd0;
            cos_val_reg <= 16'd0;
            lookup_idx <= 8'd0;
            cycle_count <= 8'd0;
            mult_x_temp <= 32'd0;
            mult_y_temp <= 32'd0;
            rect_x <= 16'd0;
            rect_y <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load inputs
                        mag_reg <= polar_mag;
                        angle_reg <= polar_phi;
                        quadrant_reg <= phi_quadrant;
                        sign_x_reg <= sign_x_calc;
                        sign_y_reg <= sign_y_calc;
                        state <= QUADRANT;
                    end
                end
                
                QUADRANT: begin
                    // Already computed quadrant in IDLE
                    // Map angle to 0..π/2 range
                    angle_reg <= phi_mapped;
                    lookup_idx <= phi_mapped[15:8]; // Use upper 8 bits as index
                    state <= LOOKUP;
                end
                
                LOOKUP: begin
                    // Lookup sin and cos values
                    // sin(θ) from table
                    sin_val_reg <= sin_table[lookup_idx];
                    // cos(θ) = sin(π/2 - θ)
                    cos_val_reg <= sin_table[8'd255 - lookup_idx];
                    
                    if (cycle_count < 8'd7) begin
                        cycle_count <= cycle_count + 8'd1;
                        lookup_idx <= lookup_idx + 8'd1;
                        state <= LOOKUP;
                    end else begin
                        cycle_count <= 8'd0;
                        state <= MULT;
                    end
                end
                
                MULT: begin
                    // x = r * cos(φ) in Q16.16
                    // Use 32-bit intermediate (48-bit result, take upper 32 bits)
                    mult_x_temp <= mag_reg * cos_val_reg;
                    mult_y_temp <= mag_reg * sin_val_reg;
                    
                    if (cycle_count < 8'd3) begin
                        cycle_count <= cycle_count + 8'd1;
                        state <= MULT;
                    end else begin
                        cycle_count <= 8'd0;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Apply sign and truncate to 16 bits
                    // Take upper 16 bits (Q16.16 format)
                    if (sign_x_reg) begin
                        rect_x <= (~mult_x_temp[31:16]) + 16'd1;
                    end else begin
                        rect_x <= mult_x_temp[31:16];
                    end
                    
                    if (sign_y_reg) begin
                        rect_y <= (~mult_y_temp[31:16]) + 16'd1;
                    end else begin
                        rect_y <= mult_y_temp[31:16];
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule