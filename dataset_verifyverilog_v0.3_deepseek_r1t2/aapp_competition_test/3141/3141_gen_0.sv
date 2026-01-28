module drill_bit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [31:0] x0, y0, z0,
    input wire [31:0] x1, y1, z1,
    input wire [31:0] x2, y2, z2,
    input wire [31:0] x3, y3, z3,
    input wire [31:0] x4, y4, z4,
    input wire [31:0] x5, y5, z5,
    input wire [31:0] x6, y6, z6,
    input wire [31:0] x7, y7, z7,
    output reg [31:0] diameter,
    output reg done
);
    
    // State machine declarations
    localparam [4:0] 
        IDLE       = 5'd0,
        LOAD       = 5'd1,
        INIT_PAIR  = 5'd2,
        CALC_PAIR  = 5'd3,
        NEXT_PAIR  = 5'd4,
        STORE_PROJ = 5'd5,
        INIT_SQRT  = 5'd6,
        ITER_SQRT  = 5'd7,
        STORE_SQRT = 5'd8,
        COMPARE    = 5'd9,
        FINISH     = 5'd10;
    
    // Projection types
    localparam [1:0] 
        YZ = 2'd0,
        XZ = 2'd1,
        XY = 2'd2;
    
    reg [4:0] state, next_state;
    reg [1:0] proj_sel;
    
    // Datapath registers
    reg [31:0] x_reg [0:7];
    reg [31:0] y_reg [0:7];
    reg [31:0] z_reg [0:7];
    reg [3:0] N_reg;
    reg [4:0] i, j;
    
    reg signed [63:0] dx_sq, dy_sq, sq_dist;
    reg [63:0] max_sq_dist_yz, max_sq_dist_xz, max_sq_dist_xy;
    reg [63:0] current_max;
    
    // Square root variables
    reg [63:0] sqrt_input;
    reg [31:0] sqrt_value;
    reg [63:0] sqrt_remainder;
    reg [5:0] bit_counter;
    
    reg [31:0] diameter_yz, diameter_xz, diameter_xy;
    integer k;
    
    // Cycle counter to prevent infinite loops
    reg [10:0] cycle_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done <= 1'b0;
            diameter <= 32'd0;
            proj_sel <= YZ;
            current_max <= 64'd0;
            max_sq_dist_yz <= 64'd0;
            max_sq_dist_xz <= 64'd0;
            max_sq_dist_xy <= 64'd0;
            diameter_yz <= 32'd0;
            diameter_xz <= 32'd0;
            diameter_xy <= 32'd0;
            i <= 5'd0;
            j <= 5'd0;
            sqrt_value <= 32'd0;
            sqrt_remainder <= 64'd0;
            sqrt_input <= 64'd0;
            bit_counter <= 6'd0;
            cycle_count <= 11'd0;
            
            // Initialize arrays
            for (k=0; k<8; k=k+1) begin
                x_reg[k] <= 32'd0;
                y_reg[k] <= 32'd0;
                z_reg[k] <= 32'd0;
            end
            N_reg <= 4'd0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        cycle_count <= 11'd0;
                    end
                end
                
                LOAD: begin
                    // Load input points into arrays
                    x_reg[0] <= x0; y_reg[0] <= y0; z_reg[0] <= z0;
                    x_reg[1] <= x1; y_reg[1] <= y1; z_reg[1] <= z1;
                    x_reg[2] <= x2; y_reg[2] <= y2; z_reg[2] <= z2;
                    x_reg[3] <= x3; y_reg[3] <= y3; z_reg[3] <= z3;
                    x_reg[4] <= x4; y_reg[4] <= y4; z_reg[4] <= z4;
                    x_reg[5] <= x5; y_reg[5] <= y5; z_reg[5] <= z5;
                    x_reg[6] <= x6; y_reg[6] <= y6; z_reg[6] <= z6;
                    x_reg[7] <= x7; y_reg[7] <= y7; z_reg[7] <= z7;
                    N_reg <= N;
                    proj_sel <= YZ;
                    
                    // Prevent invalid N
                    if (N > 4'd0) state <= INIT_PAIR;
                    else state <= FINISH;
                end
                
                INIT_PAIR: begin
                    i <= 5'd0;
                    j <= 5'd1;
                    current_max <= 64'd0;
                    state <= CALC_PAIR;
                end
                
                CALC_PAIR: begin
                    if ((i < (N_reg - 1)) && (j < N_reg)) begin
                        // Compute dy/dz based on projection
                        reg signed [31:0] dx, dy;
                        case(proj_sel)
                            YZ: begin
                                dx = y_reg[i] - y_reg[j];
                                dy = z_reg[i] - z_reg[j];
                            end
                            XZ: begin
                                dx = x_reg[i] - x_reg[j];
                                dy = z_reg[i] - z_reg[j];
                            end
                            XY: begin
                                dx = x_reg[i] - x_reg[j];
                                dy = y_reg[i] - y_reg[j];
                            end
                            default: begin // Shouldn't occur
                                dx = 32'd0;
                                dy = 32'd0;
                            end
                        endcase
                        
                        // Squared distance calculation (Q32.32)
                        dx_sq = dx * dx;
                        dy_sq = dy * dy;
                        sq_dist = dx_sq + dy_sq;
                        
                        // Update max squared distance
                        if (sq_dist > current_max) current_max <= sq_dist;
                        
                        state <= NEXT_PAIR;
                    end else begin
                        state <= STORE_PROJ;
                    end
                end
                
                NEXT_PAIR: begin
                    if (j < (N_reg - 1)) begin
                        j <= j + 1;
                        state <= CALC_PAIR;
                    end else if (i < (N_reg - 2)) begin
                        i <= i + 1;
                        j <= i + 2;
                        state <= CALC_PAIR;
                    end else begin
                        state <= STORE_PROJ;
                    end
                end
                
                STORE_PROJ: begin
                    // Store current_max after all pairs
                    case(proj_sel)
                        YZ: max_sq_dist_yz <= current_max;
                        XZ: max_sq_dist_xz <= current_max;
                        XY: max_sq_dist_xy <= current_max;
                    endcase
                    
                    if (proj_sel < XY) begin
                        proj_sel <= proj_sel + 1'b1;
                        state <= INIT_PAIR;
                    end else begin
                        proj_sel <= YZ;  // Start sqrt with YZ
                        state <= INIT_SQRT;
                    end
                end
                
                INIT_SQRT: begin
                    // Set sqrt input based on proj_sel
                    case(proj_sel)
                        YZ: sqrt_input <= max_sq_dist_yz;
                        XZ: sqrt_input <= max_sq_dist_xz;
                        XY: sqrt_input <= max_sq_dist_xy;
                    endcase
                    
                    sqrt_remainder <= 64'd0;
                    sqrt_value <= 32'd0;
                    bit_counter <= 6'd63; // 64-bit input
                    state <= ITER_SQRT;
                end
                
                ITER_SQRT: begin
                    if (bit_counter[5] == 1'b0) begin
                        // Non-restoring square root implementation
                        reg [63:0] tmp_rem;
                        reg [31:0] test_val;
                        
                        tmp_rem = sqrt_remainder << 2;
                        tmp_rem[1:0] = sqrt_input >> bit_counter[4:0] & 2'b11;
                        
                        test_val = (sqrt_value << 2) | 3'b001;
                        
                        if (tmp_rem >= test_val) begin
                            sqrt_remainder = tmp_rem - test_val;
                            sqrt_value = (sqrt_value << 1) | 1'b1;
                        end else begin
                            sqrt_remainder = tmp_rem;
                            sqrt_value = sqrt_value << 1;
                        end
                        
                        if (bit_counter == 6'd0) state <= STORE_SQRT;
                        else bit_counter <= bit_counter - 6'd1;
                    end
                end
                
                STORE_SQRT: begin
                    // Store result based on proj_sel
                    case(proj_sel)
                        YZ: diameter_yz <= sqrt_value;
                        XZ: diameter_xz <= sqrt_value;
                        XY: diameter_xy <= sqrt_value;
                    endcase
                    
                    if (proj_sel < XY) begin
                        proj_sel <= proj_sel + 1'b1;
                        state <= INIT_SQRT;
                    end else begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    // Find minimum diameter
                    if ((diameter_yz <= diameter_xz) && (diameter_yz <= diameter_xy)) 
                        diameter <= diameter_yz;
                    else if (diameter_xz <= diameter_xy)
                        diameter <= diameter_xz;
                    else 
                        diameter <= diameter_xy;
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycle_count > 2000) state <= FINISH;
        end
    end

endmodule