module MinimumDrillDiameter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [12:0] N,  // 5000 < 2^13
    input wire [31:0] points_x [0:4999],  // Q16.16 signed
    input wire [31:0] points_y [0:4999],
    input wire [31:0] points_z [0:4999],
    output reg [31:0] diameter,  // Q16.16
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] LOAD_POINTS = 4'd1;
    localparam [3:0] COMPUTE_X   = 4'd2;
    localparam [3:0] COMPUTE_Y   = 4'd3;
    localparam [3:0] COMPUTE_Z   = 4'd4;
    localparam [3:0] FIND_MIN    = 4'd5;
    localparam [3:0] CALC_DONE   = 4'd6;
    
    reg [3:0] state, next_state;
    
    // Fixed-point constants
    localparam [31:0] ZERO = 32'h0000_0000;
    localparam [31:0] ONE  = 32'h0001_0000;  // 1.0 in Q16.16
    localparam [31:0] TWO  = 32'h0002_0000;  // 2.0 in Q16.16
    
    // Iteration limits
    localparam [7:0] MAX_ITERATIONS = 8'd100;  // Bounded iteration
    localparam [7:0] MAX_SAMPLES = 8'd8;       // Sample points for MEC
    localparam [7:0] MAX_AXES = 8'd3;
    
    // Registers for processing
    reg [12:0] counter;          // Point index counter
    reg [7:0] axis_counter;      // X, Y, Z counter (0,1,2)
    reg [7:0] iter_counter;      // Iteration counter
    reg [7:0] sample_counter;    // Sample point counter
    
    // Result registers for each axis (radius in Q16.16)
    reg [31:0] radius_x;
    reg [31:0] radius_y;
    reg [31:0] radius_z;
    reg [31:0] current_min_radius;
    reg [31:0] current_diameter;
    
    // Temporary registers for MEC computation
    reg [31:0] center_x, center_y;  // Current candidate center
    reg [31:0] test_x, test_y;      // Test point coordinates
    reg [31:0] max_dist;            // Maximum distance from center
    reg [31:0] dist_sq;             // Squared distance
    reg [31:0] dist;                // Distance (approximate sqrt)
    reg [31:0] best_radius;         // Best radius for current axis
    reg [31:0] best_center_x, best_center_y;
    
    // Helper signals for distance calculation
    reg [63:0] diff_x, diff_y;      // 64-bit for subtraction
    reg [63:0] sum_sq;              // Sum of squares (64-bit)
    reg [31:0] sqrt_val;            // Approximate sqrt result
    
    // Sample point indices (store up to 8 samples)
    reg [12:0] sample_idx [0:7];
    
    // Computation state for each axis
    reg [2:0] comp_state;  // 0=init, 1=load_samples, 2=iterate
    
    integer i;  // For loop iterations
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            diameter <= 32'd0;
            counter <= 13'd0;
            axis_counter <= 8'd0;
            iter_counter <= 8'd0;
            sample_counter <= 8'd0;
            radius_x <= 32'h7FFF_FFFF;
            radius_y <= 32'h7FFF_FFFF;
            radius_z <= 32'h7FFF_FFFF;
            current_min_radius <= 32'h7FFF_FFFF;
            current_diameter <= 32'h7FFF_FFFF;
            best_radius <= 32'h7FFF_FFFF;
            center_x <= 32'd0;
            center_y <= 32'd0;
            best_center_x <= 32'd0;
            best_center_y <= 32'd0;
            test_x <= 32'd0;
            test_y <= 32'd0;
            max_dist <= 32'd0;
            dist_sq <= 32'd0;
            dist <= 32'd0;
            diff_x <= 64'd0;
            diff_y <= 64'd0;
            sum_sq <= 64'd0;
            sqrt_val <= 32'd0;
            comp_state <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                sample_idx[i] <= 13'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    diameter <= 32'd0;
                    counter <= 13'd0;
                    axis_counter <= 8'd0;
                    iter_counter <= 8'd0;
                    sample_counter <= 8'd0;
                    radius_x <= 32'h7FFF_FFFF;
                    radius_y <= 32'h7FFF_FFFF;
                    radius_z <= 32'h7FFF_FFFF;
                    current_min_radius <= 32'h7FFF_FFFF;
                    current_diameter <= 32'h7FFF_FFFF;
                    best_radius <= 32'h7FFF_FFFF;
                    comp_state <= 3'd0;
                end
                
                LOAD_POINTS: begin
                    // Load sample indices for MEC (8 random-ish samples)
                    if (counter < N && counter < 13'd5000) begin
                        if (sample_counter < MAX_SAMPLES) begin
                            sample_idx[sample_counter] <= counter;
                            sample_counter <= sample_counter + 8'd1;
                        end
                        counter <= counter + 13'd1;
                    end
                end
                
                COMPUTE_X, COMPUTE_Y, COMPUTE_Z: begin
                    // State machine for MEC computation
                    case (comp_state)
                        3'd0: begin  // Initialize
                            best_radius <= 32'h7FFF_FFFF;
                            iter_counter <= 8'd0;
                            sample_counter <= 8'd0;
                            comp_state <= 3'd1;
                        end
                        
                        3'd1: begin  // Load current sample point as center candidate
                            if (sample_counter < MAX_SAMPLES && sample_counter < N) begin
                                // Set candidate center from sample point
                                if (state == COMPUTE_X) begin
                                    center_x <= points_y[sample_idx[sample_counter]];
                                    center_y <= points_z[sample_idx[sample_counter]];
                                end else if (state == COMPUTE_Y) begin
                                    center_x <= points_x[sample_idx[sample_counter]];
                                    center_y <= points_z[sample_idx[sample_counter]];
                                end else begin  // COMPUTE_Z
                                    center_x <= points_x[sample_idx[sample_counter]];
                                    center_y <= points_y[sample_idx[sample_counter]];
                                end
                                sample_counter <= sample_counter + 8'd1;
                                max_dist <= 32'd0;
                                counter <= 13'd0;
                                comp_state <= 3'd2;
                            end else begin
                                comp_state <= 3'd0;
                                iter_counter <= iter_counter + 8'd1;
                            end
                        end
                        
                        3'd2: begin  // Test all points against current center
                            if (counter < N && counter < 13'd5000) begin
                                // Get point coordinates based on axis
                                if (state == COMPUTE_X) begin
                                    test_x <= points_y[counter];
                                    test_y <= points_z[counter];
                                end else if (state == COMPUTE_Y) begin
                                    test_x <= points_x[counter];
                                    test_y <= points_z[counter];
                                end else begin  // COMPUTE_Z
                                    test_x <= points_x[counter];
                                    test_y <= points_y[counter];
                                end
                                counter <= counter + 13'd1;
                            end else if (counter == N || counter >= 13'd5000) begin
                                // Check if this candidate is better
                                if (max_dist < best_radius) begin
                                    best_radius <= max_dist;
                                    best_center_x <= center_x;
                                    best_center_y <= center_y;
                                end
                                comp_state <= 3'd1;  // Next sample
                            end
                        end
                        
                        default: comp_state <= 3'd0;
                    endcase
                    
                    // Distance calculation pipeline (2-cycle delay)
                    if (comp_state == 3'd2 && counter > 13'd0) begin
                        // Cycle 1: Compute difference and square
                        if (center_x > test_x)
                            diff_x <= {16'd0, center_x} - {16'd0, test_x};
                        else
                            diff_x <= {16'd0, test_x} - {16'd0, center_x};
                        
                        if (center_y > test_y)
                            diff_y <= {16'd0, center_y} - {16'd0, test_y};
                        else
                            diff_y <= {16'd0, test_y} - {16'd0, center_y};
                    end
                    
                    if (comp_state == 3'd2 && counter > 13'd0) begin
                        // Cycle 2: Compute sum of squares and approximate sqrt
                        sum_sq <= (diff_x[47:16] * diff_x[47:16]) + (diff_y[47:16] * diff_y[47:16]);
                    end
                    
                    if (comp_state == 3'd2 && counter > 13'd0) begin
                        // Cycle 3: Approximate sqrt (linear approximation)
                        // For Q16.16: sqrt(x/65536) = sqrt(x)/256
                        // Use bit-shift approximation: sqrt(x) ≈ x >> (log2(x)/2)
                        if (sum_sq[63:32] != 0) begin
                            // Large values: use shift approximation
                            if (sum_sq[63:48] != 0)
                                sqrt_val <= sum_sq[57:26];  // >> 30 (approx sqrt for large)
                            else if (sum_sq[47:32] != 0)
                                sqrt_val <= sum_sq[39:8];   // >> 32 (approx sqrt for medium)
                            else
                                sqrt_val <= sum_sq[31:0];   // >> 32 for small
                        end else begin
                            sqrt_val <= sum_sq[31:0];  // Direct for very small
                        end
                    end
                    
                    if (comp_state == 3'd2 && counter > 13'd0) begin
                        // Cycle 4: Update max distance
                        if (sqrt_val > max_dist && sqrt_val != 32'd0) begin
                            max_dist <= sqrt_val;
                        end
                    end
                    
                    // Check completion
                    if (comp_state == 3'd0 && iter_counter >= MAX_ITERATIONS) begin
                        // Done with this axis
                        if (state == COMPUTE_X) begin
                            radius_x <= best_radius;
                        end else if (state == COMPUTE_Y) begin
                            radius_y <= best_radius;
                        end else begin  // COMPUTE_Z
                            radius_z <= best_radius;
                        end
                        comp_state <= 3'd0;
                    end
                end
                
                FIND_MIN: begin
                    // Find minimum radius and convert to diameter
                    if (radius_x < radius_y && radius_x < radius_z) begin
                        current_min_radius <= radius_x;
                    end else if (radius_y < radius_z) begin
                        current_min_radius <= radius_y;
                    end else begin
                        current_min_radius <= radius_z;
                    end
                    // Diameter = 2 * radius (Q16.16)
                    current_diameter <= {current_min_radius[30:0], 1'b0};
                end
                
                CALC_DONE: begin
                    diameter <= current_diameter;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && N > 13'd0) begin
                    next_state = LOAD_POINTS;
                end
            end
            
            LOAD_POINTS: begin
                if (counter >= N || counter >= 13'd5000) begin
                    next_state = COMPUTE_X;
                end
            end
            
            COMPUTE_X: begin
                if (comp_state == 3'd0 && iter_counter >= MAX_ITERATIONS) begin
                    next_state = COMPUTE_Y;
                end
            end
            
            COMPUTE_Y: begin
                if (comp_state == 3'd0 && iter_counter >= MAX_ITERATIONS) begin
                    next_state = COMPUTE_Z;
                end
            end
            
            COMPUTE_Z: begin
                if (comp_state == 3'd0 && iter_counter >= MAX_ITERATIONS) begin
                    next_state = FIND_MIN;
                end
            end
            
            FIND_MIN: begin
                next_state = CALC_DONE;
            end
            
            CALC_DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule