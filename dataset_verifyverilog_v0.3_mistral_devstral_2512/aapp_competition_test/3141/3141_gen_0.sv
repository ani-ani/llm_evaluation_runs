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

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE_X = 3'd2;
    localparam [2:0] COMPUTE_Y = 3'd3;
    localparam [2:0] COMPUTE_Z = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;

    // Internal point storage (Q16.16)
    reg [31:0] x_reg [0:7];
    reg [31:0] y_reg [0:7];
    reg [31:0] z_reg [0:7];

    // Current point indices for pair comparison
    reg [2:0] i, j;

    // Maximum squared distances for each projection (Q32.32)
    reg [63:0] max_sq_dist_yz;
    reg [63:0] max_sq_dist_xz;
    reg [63:0] max_sq_dist_xy;

    // Current squared distance being computed (Q32.32)
    reg [63:0] current_sq_dist;

    // Diameter results for each projection (Q16.16)
    reg [31:0] diameter_yz;
    reg [31:0] diameter_xz;
    reg [31:0] diameter_xy;

    // Square root computation registers
    reg [63:0] sqrt_input;
    reg [31:0] sqrt_result;
    reg [5:0] sqrt_cycle;
    reg [63:0] sqrt_remainder;
    reg [31:0] sqrt_root;

    // Cycle counter to prevent infinite loops
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd1900;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            diameter <= 32'd0;
            cycle_count <= 11'd0;

            // Initialize all point registers
            x_reg[0] <= 32'd0; y_reg[0] <= 32'd0; z_reg[0] <= 32'd0;
            x_reg[1] <= 32'd0; y_reg[1] <= 32'd0; z_reg[1] <= 32'd0;
            x_reg[2] <= 32'd0; y_reg[2] <= 32'd0; z_reg[2] <= 32'd0;
            x_reg[3] <= 32'd0; y_reg[3] <= 32'd0; z_reg[3] <= 32'd0;
            x_reg[4] <= 32'd0; y_reg[4] <= 32'd0; z_reg[4] <= 32'd0;
            x_reg[5] <= 32'd0; y_reg[5] <= 32'd0; z_reg[5] <= 32'd0;
            x_reg[6] <= 32'd0; y_reg[6] <= 32'd0; z_reg[6] <= 32'd0;
            x_reg[7] <= 32'd0; y_reg[7] <= 32'd0; z_reg[7] <= 32'd0;

            // Initialize max distances
            max_sq_dist_yz <= 64'd0;
            max_sq_dist_xz <= 64'd0;
            max_sq_dist_xy <= 64'd0;

            // Initialize indices
            i <= 3'd0;
            j <= 3'd0;

            // Initialize diameter results
            diameter_yz <= 32'd0;
            diameter_xz <= 32'd0;
            diameter_xy <= 32'd0;

            // Initialize sqrt computation
            sqrt_input <= 64'd0;
            sqrt_result <= 32'd0;
            sqrt_cycle <= 6'd0;
            sqrt_remainder <= 64'd0;
            sqrt_root <= 32'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 11'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load input points
                    x_reg[0] <= x0; y_reg[0] <= y0; z_reg[0] <= z0;
                    x_reg[1] <= x1; y_reg[1] <= y1; z_reg[1] <= z1;
                    x_reg[2] <= x2; y_reg[2] <= y2; z_reg[2] <= z2;
                    x_reg[3] <= x3; y_reg[3] <= y3; z_reg[3] <= z3;
                    x_reg[4] <= x4; y_reg[4] <= y4; z_reg[4] <= z4;
                    x_reg[5] <= x5; y_reg[5] <= y5; z_reg[5] <= z5;
                    x_reg[6] <= x6; y_reg[6] <= y6; z_reg[6] <= z6;
                    x_reg[7] <= x7; y_reg[7] <= y7; z_reg[7] <= z7;

                    // Initialize max distances
                    max_sq_dist_yz <= 64'd0;
                    max_sq_dist_xz <= 64'd0;
                    max_sq_dist_xy <= 64'd0;

                    // Initialize indices
                    i <= 3'd0;
                    j <= 3'd1;

                    next_state <= COMPUTE_X;
                end

                COMPUTE_X: begin
                    // Compute squared distance in YZ plane (ignore x)
                    if (i < N && j < N && i != j) begin
                        // Compute (y[i] - y[j])^2 + (z[i] - z[j])^2
                        reg [31:0] dy, dz;
                        dy = y_reg[i] - y_reg[j];
                        dz = z_reg[i] - z_reg[j];
                        current_sq_dist = ({dy, 32'd0} * {dy, 32'd0})[63:32] + 
                                        ({dz, 32'd0} * {dz, 32'd0})[63:32];

                        if (current_sq_dist > max_sq_dist_yz) begin
                            max_sq_dist_yz <= current_sq_dist;
                        end

                        // Move to next pair
                        j <= j + 3'd1;
                        if (j >= N) begin
                            i <= i + 3'd1;
                            j <= 3'd0;
                            if (j >= i) begin
                                j <= i + 3'd1;
                            end
                        end
                    end

                    // Check if all pairs processed
                    if (i >= N - 1 && j >= N - 1) begin
                        // Start square root computation for YZ
                        sqrt_input <= max_sq_dist_yz;
                        sqrt_cycle <= 6'd0;
                        sqrt_remainder <= 64'd0;
                        sqrt_root <= 32'd0;
                        next_state <= COMPUTE_Y;
                    end else begin
                        next_state <= COMPUTE_X;
                    end
                end

                COMPUTE_Y: begin
                    // Compute squared distance in XZ plane (ignore y)
                    if (i < N && j < N && i != j) begin
                        // Compute (x[i] - x[j])^2 + (z[i] - z[j])^2
                        reg [31:0] dx, dz;
                        dx = x_reg[i] - x_reg[j];
                        dz = z_reg[i] - z_reg[j];
                        current_sq_dist = ({dx, 32'd0} * {dx, 32'd0})[63:32] + 
                                        ({dz, 32'd0} * {dz, 32'd0})[63:32];

                        if (current_sq_dist > max_sq_dist_xz) begin
                            max_sq_dist_xz <= current_sq_dist;
                        end

                        // Move to next pair
                        j <= j + 3'd1;
                        if (j >= N) begin
                            i <= i + 3'd1;
                            j <= 3'd0;
                            if (j >= i) begin
                                j <= i + 3'd1;
                            end
                        end
                    end

                    // Check if all pairs processed
                    if (i >= N - 1 && j >= N - 1) begin
                        // Start square root computation for XZ
                        sqrt_input <= max_sq_dist_xz;
                        sqrt_cycle <= 6'd0;
                        sqrt_remainder <= 64'd0;
                        sqrt_root <= 32'd0;
                        next_state <= COMPUTE_Z;
                    end else begin
                        next_state <= COMPUTE_Y;
                    end
                end

                COMPUTE_Z: begin
                    // Compute squared distance in XY plane (ignore z)
                    if (i < N && j < N && i != j) begin
                        // Compute (x[i] - x[j])^2 + (y[i] - y[j])^2
                        reg [31:0] dx, dy;
                        dx = x_reg[i] - x_reg[j];
                        dy = y_reg[i] - y_reg[j];
                        current_sq_dist = ({dx, 32'd0} * {dx, 32'd0})[63:32] + 
                                        ({dy, 32'd0} * {dy, 32'd0})[63:32];

                        if (current_sq_dist > max_sq_dist_xy) begin
                            max_sq_dist_xy <= current_sq_dist;
                        end

                        // Move to next pair
                        j <= j + 3'd1;
                        if (j >= N) begin
                            i <= i + 3'd1;
                            j <= 3'd0;
                            if (j >= i) begin
                                j <= i + 3'd1;
                            end
                        end
                    end

                    // Check if all pairs processed
                    if (i >= N - 1 && j >= N - 1) begin
                        // Start square root computation for XY
                        sqrt_input <= max_sq_dist_xy;
                        sqrt_cycle <= 6'd0;
                        sqrt_remainder <= 64'd0;
                        sqrt_root <= 32'd0;
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE_Z;
                    end
                end

                FINISH: begin
                    // Compute square roots for all three projections
                    // YZ projection
                    if (sqrt_cycle < 6'd32) begin
                        sqrt_remainder <= {sqrt_remainder[61:0], 2'b00};
                        sqrt_root <= {sqrt_root[30:0], 2'b00};
                        
                        reg [63:0] temp_remainder;
                        reg [31:0] temp_root;
                        
                        temp_root = sqrt_root + 32'd1;
                        temp_remainder = sqrt_remainder - (temp_root * temp_root);
                        
                        if (temp_remainder[63]) begin
                            sqrt_root <= sqrt_root + 32'd1;
                            sqrt_remainder <= temp_remainder;
                        end
                        
                        sqrt_cycle <= sqrt_cycle + 6'd1;
                        next_state <= FINISH;
                    end else begin
                        diameter_yz <= sqrt_root;
                        
                        // XZ projection
                        sqrt_input <= max_sq_dist_xz;
                        sqrt_cycle <= 6'd0;
                        sqrt_remainder <= 64'd0;
                        sqrt_root <= 32'd0;
                        next_state <= FINISH;
                    end
                    
                    // XZ projection sqrt
                    if (sqrt_cycle < 6'd32 && sqrt_cycle > 6'd0) begin
                        sqrt_remainder <= {sqrt_remainder[61:0], 2'b00};
                        sqrt_root <= {sqrt_root[30:0], 2'b00};
                        
                        reg [63:0] temp_remainder;
                        reg [31:0] temp_root;
                        
                        temp_root = sqrt_root + 32'd1;
                        temp_remainder = sqrt_remainder - (temp_root * temp_root);
                        
                        if (temp_remainder[63]) begin
                            sqrt_root <= sqrt_root + 32'd1;
                            sqrt_remainder <= temp_remainder;
                        end
                        
                        sqrt_cycle <= sqrt_cycle + 6'd1;
                        next_state <= FINISH;
                    end else if (sqrt_cycle == 6'd64) begin
                        diameter_xz <= sqrt_root;
                        
                        // XY projection
                        sqrt_input <= max_sq_dist_xy;
                        sqrt_cycle <= 6'd0;
                        sqrt_remainder <= 64'd0;
                        sqrt_root <= 32'd0;
                        next_state <= FINISH;
                    end
                    
                    // XY projection sqrt
                    if (sqrt_cycle < 6'd32 && sqrt_cycle > 6'd64) begin
                        sqrt_remainder <= {sqrt_remainder[61:0], 2'b00};
                        sqrt_root <= {sqrt_root[30:0], 2'b00};
                        
                        reg [63:0] temp_remainder;
                        reg [31:0] temp_root;
                        
                        temp_root = sqrt_root + 32'd1;
                        temp_remainder = sqrt_remainder - (temp_root * temp_root);
                        
                        if (temp_remainder[63]) begin
                            sqrt_root <= sqrt_root + 32'd1;
                            sqrt_remainder <= temp_remainder;
                        end
                        
                        sqrt_cycle <= sqrt_cycle + 6'd1;
                        next_state <= FINISH;
                    end else if (sqrt_cycle == 6'd96) begin
                        diameter_xy <= sqrt_root;
                        
                        // Find minimum diameter
                        if (diameter_yz < diameter_xz) begin
                            if (diameter_yz < diameter_xy) begin
                                diameter <= diameter_yz;
                            end else begin
                                diameter <= diameter_xy;
                            end
                        end else begin
                            if (diameter_xz < diameter_xy) begin
                                diameter <= diameter_xz;
                            end else begin
                                diameter <= diameter_xy;
                            end
                        end
                        
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end
endmodule