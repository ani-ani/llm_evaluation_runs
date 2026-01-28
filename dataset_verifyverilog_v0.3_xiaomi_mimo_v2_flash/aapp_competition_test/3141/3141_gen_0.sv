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

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LOAD_POINTS   = 4'd1;
    localparam [3:0] SETUP_YZ      = 4'd2;
    localparam [3:0] COMPUTE_YZ    = 4'd3;
    localparam [3:0] SETUP_XZ      = 4'd4;
    localparam [3:0] COMPUTE_XZ    = 4'd5;
    localparam [3:0] SETUP_XY      = 4'd6;
    localparam [3:0] COMPUTE_XY    = 4'd7;
    localparam [3:0] SETUP_SQRT    = 4'd8;
    localparam [3:0] SQRT_WAIT     = 4'd9;
    localparam [3:0] FINALIZE      = 4'd10;
    localparam [3:0] DONE_STATE    = 4'd11;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Point storage (packed to avoid unpacked array issues)
    reg [31:0] pts_x [0:7];
    reg [31:0] pts_y [0:7];
    reg [31:0] pts_z [0:7];
    
    // Loop counters
    reg [3:0] i, j, k;
    reg [3:0] N_reg;
    
    // Projected coordinates for current pair
    reg [31:0] a1, a2, b1, b2;
    
    // Intermediate computation registers
    reg [63:0] diff1, diff2;
    reg [63:0] sq_dist;
    reg [63:0] max_sq_dist;
    
    // Diameter accumulators for each projection
    reg [63:0] diam_yz;
    reg [63:0] diam_xz;
    reg [63:0] diam_xy;
    reg [31:0] current_diam;
    
    // Square root signals
    reg sqrt_start;
    reg [63:0] sqrt_input;
    wire [31:0] sqrt_output;
    wire sqrt_done;
    reg sqrt_done_reg;
    
    // Cycle counter for timeout
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2000;

    // Square root module (non-restoring algorithm)
    sqrt_64bit sqrt_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(sqrt_start),
        .radicand(sqrt_input),
        .result(sqrt_output),
        .done(sqrt_done)
    );

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 12'd0;
        end else begin
            state <= next_state;
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 12'd1;
            end else begin
                cycle_count <= 12'd0;
            end
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            diameter <= 32'd0;
            N_reg <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            max_sq_dist <= 64'd0;
            diam_yz <= 64'd0;
            diam_xz <= 64'd0;
            diam_xy <= 64'd0;
            current_diam <= 32'd0;
            sqrt_start <= 1'b0;
            sqrt_done_reg <= 1'b0;
            // Initialize arrays
            pts_x[0] <= 32'd0; pts_x[1] <= 32'd0; pts_x[2] <= 32'd0; pts_x[3] <= 32'd0;
            pts_x[4] <= 32'd0; pts_x[5] <= 32'd0; pts_x[6] <= 32'd0; pts_x[7] <= 32'd0;
            pts_y[0] <= 32'd0; pts_y[1] <= 32'd0; pts_y[2] <= 32'd0; pts_y[3] <= 32'd0;
            pts_y[4] <= 32'd0; pts_y[5] <= 32'd0; pts_y[6] <= 32'd0; pts_y[7] <= 32'd0;
            pts_z[0] <= 32'd0; pts_z[1] <= 32'd0; pts_z[2] <= 32'd0; pts_z[3] <= 32'd0;
            pts_z[4] <= 32'd0; pts_z[5] <= 32'd0; pts_z[6] <= 32'd0; pts_z[7] <= 32'd0;
            next_state <= IDLE;
        end else begin
            sqrt_done_reg <= sqrt_done;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    diameter <= 32'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    cycle_count <= 12'd0;
                    if (start && N >= 4'd1 && N <= 4'd8) begin
                        N_reg <= N;
                        next_state <= LOAD_POINTS;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD_POINTS: begin
                    if (i < N_reg) begin
                        case (i)
                            4'd0: begin pts_x[0] <= x0; pts_y[0] <= y0; pts_z[0] <= z0; end
                            4'd1: begin pts_x[1] <= x1; pts_y[1] <= y1; pts_z[1] <= z1; end
                            4'd2: begin pts_x[2] <= x2; pts_y[2] <= y2; pts_z[2] <= z2; end
                            4'd3: begin pts_x[3] <= x3; pts_y[3] <= y3; pts_z[3] <= z3; end
                            4'd4: begin pts_x[4] <= x4; pts_y[4] <= y4; pts_z[4] <= z4; end
                            4'd5: begin pts_x[5] <= x5; pts_y[5] <= y5; pts_z[5] <= z5; end
                            4'd6: begin pts_x[6] <= x6; pts_y[6] <= y6; pts_z[6] <= z6; end
                            4'd7: begin pts_x[7] <= x7; pts_y[7] <= y7; pts_z[7] <= z7; end
                        endcase
                        i <= i + 4'd1;
                        next_state <= LOAD_POINTS;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd1;
                        max_sq_dist <= 64'd0;
                        next_state <= SETUP_YZ;
                    end
                end
                
                SETUP_YZ: begin
                    // YZ projection: use pts_y and pts_z
                    if (i < N_reg - 4'd1) begin
                        if (j < N_reg) begin
                            a1 <= pts_y[i]; a2 <= pts_y[j];
                            b1 <= pts_z[i]; b2 <= pts_z[j];
                            next_state <= COMPUTE_YZ;
                        end else begin
                            j <= 4'd1;
                            i <= i + 4'd1;
                            next_state <= SETUP_YZ;
                        end
                    end else begin
                        diam_yz <= max_sq_dist;
                        i <= 4'd0;
                        j <= 4'd1;
                        max_sq_dist <= 64'd0;
                        next_state <= SETUP_XZ;
                    end
                end
                
                COMPUTE_YZ: begin
                    // diff1 = (y[j] - y[i]) << 16
                    if (a2 >= a1) begin
                        diff1 <= {16'd0, (a2 - a1), 16'd0};
                    end else begin
                        diff1 <= {16'd0, (a1 - a2), 16'd0};
                    end
                    // diff2 = (z[j] - z[i]) << 16
                    if (b2 >= b1) begin
                        diff2 <= {16'd0, (b2 - b1), 16'd0};
                    end else begin
                        diff2 <= {16'd0, (b1 - b2), 16'd0};
                    end
                    next_state <= SETUP_YZ;
                    // Update max_sq_dist in next cycle
                    k <= 4'd0; // Dummy
                end
                
                SETUP_XZ: begin
                    // XZ projection: use pts_x and pts_z
                    if (i < N_reg - 4'd1) begin
                        if (j < N_reg) begin
                            a1 <= pts_x[i]; a2 <= pts_x[j];
                            b1 <= pts_z[i]; b2 <= pts_z[j];
                            next_state <= COMPUTE_XZ;
                        end else begin
                            j <= 4'd1;
                            i <= i + 4'd1;
                            next_state <= SETUP_XZ;
                        end
                    end else begin
                        diam_xz <= max_sq_dist;
                        i <= 4'd0;
                        j <= 4'd1;
                        max_sq_dist <= 64'd0;
                        next_state <= SETUP_XY;
                    end
                end
                
                COMPUTE_XZ: begin
                    if (a2 >= a1) begin
                        diff1 <= {16'd0, (a2 - a1), 16'd0};
                    end else begin
                        diff1 <= {16'd0, (a1 - a2), 16'd0};
                    end
                    if (b2 >= b1) begin
                        diff2 <= {16'd0, (b2 - b1), 16'd0};
                    end else begin
                        diff2 <= {16'd0, (b1 - b2), 16'd0};
                    end
                    next_state <= SETUP_XZ;
                end
                
                SETUP_XY: begin
                    // XY projection: use pts_x and pts_y
                    if (i < N_reg - 4'd1) begin
                        if (j < N_reg) begin
                            a1 <= pts_x[i]; a2 <= pts_x[j];
                            b1 <= pts_y[i]; b2 <= pts_y[j];
                            next_state <= COMPUTE_XY;
                        end else begin
                            j <= 4'd1;
                            i <= i + 4'd1;
                            next_state <= SETUP_XY;
                        end
                    end else begin
                        diam_xy <= max_sq_dist;
                        k <= 4'd0; // 0=YZ, 1=XZ, 2=XY
                        next_state <= SETUP_SQRT;
                    end
                end
                
                COMPUTE_XY: begin
                    if (a2 >= a1) begin
                        diff1 <= {16'd0, (a2 - a1), 16'd0};
                    end else begin
                        diff1 <= {16'd0, (a1 - a2), 16'd0};
                    end
                    if (b2 >= b1) begin
                        diff2 <= {16'd0, (b2 - b1), 16'd0};
                    end else begin
                        diff2 <= {16'd0, (b1 - b2), 16'd0};
                    end
                    next_state <= SETUP_XY;
                end
                
                SETUP_SQRT: begin
                    // Select which diameter to process
                    if (k == 4'd0) begin
                        sqrt_input <= diam_yz;
                    end else if (k == 4'd1) begin
                        sqrt_input <= diam_xz;
                    end else begin
                        sqrt_input <= diam_xy;
                    end
                    sqrt_start <= 1'b1;
                    next_state <= SQRT_WAIT;
                end
                
                SQRT_WAIT: begin
                    sqrt_start <= 1'b0;
                    if (sqrt_done_reg) begin
                        current_diam <= sqrt_output;
                        next_state <= FINALIZE;
                    end else begin
                        next_state <= SQRT_WAIT;
                    end
                end
                
                FINALIZE: begin
                    // Update diameter with min
                    if (k == 4'd0) begin
                        diameter <= current_diam;
                        k <= 4'd1;
                        next_state <= SETUP_SQRT;
                    end else if (k == 4'd1) begin
                        if (current_diam < diameter) begin
                            diameter <= current_diam;
                        end
                        k <= 4'd2;
                        next_state <= SETUP_SQRT;
                    end else begin
                        if (current_diam < diameter) begin
                            diameter <= current_diam;
                        end
                        next_state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Computation for diff1/diff2 (done in FINALIZE state for COMPUTE states)
            // Note: To avoid complexity, we compute sq_dist at the start of COMPUTE states
            // Re-ordered to compute sq_dist after diff calculations
        end
    end

    // Separate block for square distance calculation to avoid combinational loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sq_dist <= 64'd0;
        end else begin
            if (state == COMPUTE_YZ || state == COMPUTE_XZ || state == COMPUTE_XY) begin
                // sq_dist = diff1 * diff1 + diff2 * diff2
                // This is Q32.32 * Q32.32 = Q64.64, but we use middle 64 bits
                // For simplicity in Verilog, we assume multiplication fits in 128 bits
                // Use temporary variables for multiplication
                sq_dist <= (diff1 * diff1) + (diff2 * diff2);
            end
            
            if (state == COMPUTE_YZ && ((diff1 * diff1) + (diff2 * diff2) > max_sq_dist)) begin
                max_sq_dist <= (diff1 * diff1) + (diff2 * diff2);
            end else if (state == COMPUTE_XZ && ((diff1 * diff1) + (diff2 * diff2) > max_sq_dist)) begin
                max_sq_dist <= (diff1 * diff1) + (diff2 * diff2);
            end else if (state == COMPUTE_XY && ((diff1 * diff1) + (diff2 * diff2) > max_sq_dist)) begin
                max_sq_dist <= (diff1 * diff1) + (diff2 * diff2);
            end
        end
    end

endmodule

// 64-bit square root module using non-restoring algorithm
module sqrt_64bit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] radicand,
    output reg [31:0] result,
    output reg done
);

    reg [63:0] rem;
    reg [31:0] root;
    reg [5:0] bit_idx; // 0 to 63
    reg working;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
            working <= 1'b0;
            rem <= 64'd0;
            root <= 32'd0;
            bit_idx <= 6'd64; // Start at MSB
        end else begin
            if (start && !working) begin
                // Initialize
                rem <= radicand;
                root <= 32'd0;
                bit_idx <= 6'd31; // Start from bit 31
                working <= 1'b1;
                done <= 1'b0;
            end else if (working) begin
                if (bit_idx != 6'd31 || (bit_idx == 6'd31 && rem[63:32] >= (root << 1) + 1)) begin
                    // Remainder calculation
                    if (rem[63:32] >= ((root << 1) | 1)) begin
                        rem <= {rem[61:0], 2'b00}; // Shift left by 2
                        root <= (root << 1) | 1;
                        rem[63:32] <= rem[63:32] - ((root << 1) | 1);
                    end else begin
                        rem <= {rem[61:0], 2'b00}; // Shift left by 2
                        root <= root << 1;
                        rem[63:32] <= rem[63:32] - (root << 1);
                    end
                    
                    if (bit_idx == 6'd0) begin
                        result <= root;
                        done <= 1'b1;
                        working <= 1'b0;
                    end else begin
                        bit_idx <= bit_idx - 6'd1;
                    end
                end else begin
                    // Special case for first iteration
                    rem <= {rem[61:0], 2'b00};
                    root <= root << 1;
                    if (bit_idx == 6'd0) begin
                        result <= root;
                        done <= 1'b1;
                        working <= 1'b0;
                    end else begin
                        bit_idx <= bit_idx - 6'd1;
                    end
                end
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule