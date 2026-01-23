module courtyard_coverage(
    input clk,
    input rst_n,
    input start,
    input [31:0] angle_br,
    input [31:0] angle_tr,
    input [31:0] angle_tl,
    input [31:0] angle_bl,
    output reg [31:0] proportion,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam CALCULATE_COVERAGE = 3'b010;
    localparam COMPUTE_RESULT = 3'b100;
    
    // Registers for state machine
    reg [2:0] state;
    reg [5:0] grid_counter; // 0-63 for 8x8 grid
    reg [5:0] covered_count;
    
    // Intermediate signals for angle comparison
    reg [31:0] tan_br;
    reg [31:0] tan_tr;
    reg [31:0] tan_tl;
    reg [31:0] tan_bl;
    
    // Grid coordinates
    wire [31:0] x_pos;
    wire [31:0] y_pos;
    
    // Computed values for current point
    wire [31:0] x_minus_1;
    wire [31:0] y_minus_1;
    
    // Comparison results
    wire br_covered;
    wire tr_covered;
    wire tl_covered;
    wire bl_covered;
    wire point_covered;
    
    // Fixed-point constants
    localparam [31:0] ONE = 32'h00010000;      // 1.0 in Q16.16
    localparam [31:0] INV_EIGHT = 32'h00002000; // 0.125 in Q16.16 (1/8)
    localparam [31:0] DEG_45 = 32'h002C0000;    // 45 degrees * 65536 = 2949120
    localparam [31:0] DEG_90 = 32'h005A0000;    // 90 degrees * 65536 = 5898240
    
    // LUT for tan values (0-90 degrees) - simplified 16-entry LUT for efficiency
    // Values stored as Q16.16
    reg [31:0] tan_lut [0:15];
    
    // Initialize LUT (tan values for 0, 5.625, 11.25, ... 84.375 degrees)
    initial begin
        tan_lut[0]  = 32'h00000000; // tan(0) = 0
        tan_lut[1]  = 32'h0000F63D; // tan(5.625) ~ 0.098
        tan_lut[2]  = 32'h0001F246; // tan(11.25) ~ 0.198
        tan_lut[3]  = 32'h0002FA20; // tan(16.875) ~ 0.304
        tan_lut[4]  = 32'h00041421; // tan(22.5) ~ 0.414
        tan_lut[5]  = 32'h00055477; // tan(28.125) ~ 0.544
        tan_lut[6]  = 32'h0006D8A3; // tan(33.75) ~ 0.698
        tan_lut[7]  = 32'h0008B95B; // tan(39.375) ~ 0.885
        tan_lut[8]  = 32'h000B1CAC; // tan(45) = 1.0
        tan_lut[9]  = 32'h000E3931; // tan(50.625) ~ 1.219
        tan_lut[10] = 32'h0012762A; // tan(56.25) ~ 1.498
        tan_lut[11] = 32'h00188D51; // tan(61.875) ~ 1.888
        tan_lut[12] = 32'h0021E82A; // tan(67.5) ~ 2.414
        tan_lut[13] = 32'h00312FC3; // tan(73.125) ~ 3.122
        tan_lut[14] = 32'h004F28BC; // tan(78.75) ~ 4.828
        tan_lut[15] = 32'h00A6A6A6; // tan(84.375) ~ 10.268
    end
    
    // Calculate which LUT index to use based on angle (each entry covers ~5.625 degrees)
    wire [5:0] lut_index_br = angle_br[21:16] - 4; // Shift to get rough index (angle/5.625)
    wire [5:0] lut_index_tr = angle_tr[21:16] - 4;
    wire [5:0] lut_index_tl = angle_tl[21:16] - 4;
    wire [5:0] lut_index_bl = angle_bl[21:16] - 4;
    
    // Lookup tan values (handle boundary conditions)
    always @(*) begin
        if (angle_br < 16'h00040000) tan_br = 32'h00000000; // < 4 degrees, treat as 0
        else if (angle_br > 32'h00570000) tan_br = 32'h0A6A6A6A; // > 86 degrees, large value
        else tan_br = tan_lut[lut_index_br[3:0]];
        
        if (angle_tr < 16'h00040000) tan_tr = 32'h00000000;
        else if (angle_tr > 32'h00570000) tan_tr = 32'h0A6A6A6A;
        else tan_tr = tan_lut[lut_index_tr[3:0]];
        
        if (angle_tl < 16'h00040000) tan_tl = 32'h00000000;
        else if (angle_tl > 32'h00570000) tan_tl = 32'h0A6A6A6A;
        else tan_tl = tan_lut[lut_index_tl[3:0]];
        
        if (angle_bl < 16'h00040000) tan_bl = 32'h00000000;
        else if (angle_bl > 32'h00570000) tan_bl = 32'h0A6A6A6A;
        else tan_bl = tan_lut[lut_index_bl[3:0]];
    end
    
    // Calculate current grid point
    // x = (grid_counter[5:3]) * INV_EIGHT
    // y = (grid_counter[2:0]) * INV_EIGHT
    wire [2:0] x_idx = grid_counter[5:3];
    wire [2:0] y_idx = grid_counter[2:0];
    
    assign x_pos = {29'b0, x_idx, 3'b0} << 13; // x_idx * 8192 (INV_EIGHT shifted)
    assign y_pos = {29'b0, y_idx, 3'b0} << 13;
    
    // Calculate differences
    assign x_minus_1 = x_pos - ONE;
    assign y_minus_1 = y_pos - ONE;
    
    // Coverage checking logic
    // Bottom-right at (1,0): covers area from negative x-axis going CCW by angle_br
    // Condition: point must be in quadrant where x <= 1, y >= 0
    // And angle from negative x-axis is <= angle_br
    // Equivalent to: y <= -tan(angle) * (x-1)
    // Since (x-1) is negative, we multiply tan by (1-x) and check y <= tan * (1-x)
    wire [63:0] br_mult = {32'b0, tan_br} * {32'b0, ONE - x_pos};
    wire [31:0] br_threshold = br_mult[47:16]; // Q16.16 result
    assign br_covered = (x_pos <= ONE) && (y_pos >= 0) && (y_pos <= br_threshold);
    
    // Top-right at (1,1): covers area from negative y-axis (down) going CCW by angle_tr
    // Vector: (x-1, y-1), check if angle from negative y-axis <= angle_tr
    // Condition: (x-1) <= -tan(angle) * (y-1)  =>  (1-x) >= tan(angle) * (1-y)
    wire [63:0] tr_mult = {32'b0, tan_tr} * {32'b0, ONE - y_pos};
    wire [31:0] tr_threshold = tr_mult[47:16];
    assign tr_covered = (x_pos <= ONE) && (y_pos <= ONE) && (ONE - x_pos >= tr_threshold);
    
    // Top-left at (0,1): covers area from positive x-axis going CCW by angle_tl
    // Vector: (x, y-1), check if angle from positive x-axis <= angle_tl
    // Condition: (y-1) <= tan(angle) * x
    wire [63:0] tl_mult = {32'b0, tan_tl} * {32'b0, x_pos};
    wire [31:0] tl_threshold = tl_mult[47:16];
    assign tl_covered = (x_pos >= 0) && (y_pos <= ONE) && (y_pos - ONE <= tl_threshold);
    
    // Bottom-left at (0,0): covers area from positive y-axis (up) going clockwise by angle_bl
    // For clockwise, we check negative angle direction
    // Vector: (x, y), check if angle from positive y-axis <= angle_bl (clockwise)
    // Equivalent to: x <= tan(angle) * y
    wire [63:0] bl_mult = {32'b0, tan_bl} * {32'b0, y_pos};
    wire [31:0] bl_threshold = bl_mult[47:16];
    assign bl_covered = (x_pos >= 0) && (y_pos >= 0) && (x_pos <= bl_threshold);
    
    // Point is covered if any sprinkler covers it
    assign point_covered = br_covered | tr_covered | tl_covered | bl_covered;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            grid_counter <= 6'b0;
            covered_count <= 6'b0;
            proportion <= 32'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALCULATE_COVERAGE;
                        grid_counter <= 6'b0;
                        covered_count <= 6'b0;
                    end
                end
                
                CALCULATE_COVERAGE: begin
                    // Check coverage for current point and accumulate
                    if (point_covered) begin
                        covered_count <= covered_count + 1;
                    end
                    
                    if (grid_counter == 6'd63) begin
                        state <= COMPUTE_RESULT;
                    end
                    grid_counter <= grid_counter + 1;
                end
                
                COMPUTE_RESULT: begin
                    // proportion = (covered_points * 65536) / 64 = covered_points * 1024
                    // covered_points is 0-64, multiply by 1024 (1024 = 2^10 = shift left 10)
                    proportion <= {22'b0, covered_count, 10'b0};
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Restart if start is still high
                        state <= CALCULATE_COVERAGE;
                        grid_counter <= 6'b0;
                        covered_count <= 6'b0;
                        done <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule