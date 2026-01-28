module ExpectedManhattanDistance (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] vertex_count,
    input wire [15:0] vertex_x [0:15],
    input wire [15:0] vertex_y [0:15],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LFSR_SETTLE   = 4'd1;
    localparam [3:0] GEN_POINT1    = 4'd2;
    localparam [3:0] CHECK_INSIDE1 = 4'd3;
    localparam [3:0] WAIT_POINT2   = 4'd4;
    localparam [3:0] GEN_POINT2    = 4'd5;
    localparam [3:0] CHECK_INSIDE2 = 4'd6;
    localparam [3:0] ACCUMULATE    = 4'd7;
    localparam [3:0] DIVIDE        = 4'd8;
    localparam [3:0] FINISH        = 4'd9;
    
    localparam [10:0] N_SAMPLES = 11'd1024;
    
    reg [3:0] state, next_state;
    reg [10:0] sample_count;
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2000; // Safe timeout
    
    // LFSR registers (16-bit Galois LFSR)
    reg [15:0] lfsr_x;
    reg [15:0] lfsr_y;
    
    // Point storage
    reg [15:0] px1, py1;
    reg [15:0] px2, py2;
    
    // Flags
    reg inside1;
    reg inside2;
    
    // Accumulator (48-bit to hold sum of distances)
    reg signed [47:0] distance_sum;
    
    // Ray casting intermediate values
    reg signed [31:0] ray_denom;
    reg signed [31:0] ray_num_t;
    reg signed [31:0] ray_num_u;
    reg signed [31:0] ray_t;
    reg signed [31:0] ray_u;
    reg ray_hit;
    
    // Vertex index for ray casting loop
    reg [3:0] v_idx;
    reg signed [15:0] x1, y1, x2, y2;
    
    // Combinational helper signals
    reg signed [31:0] denom_temp;
    reg signed [31:0] num_t_temp;
    reg signed [31:0] num_u_temp;
    
    // Fixed point constants
    localparam signed [31:0] RAY_X = 32'sd10000 * 32'sd65536; // Target X (scaled)
    localparam signed [31:0] EPSILON = 32'sd1; // Small value to avoid division by zero
    
    // --- LFSR Update Logic (Galois LFSR) ---
    wire lfsr_x_next_bit;
    wire lfsr_y_next_bit;
    
    // 16-bit LFSR polynomial: x^16 + x^14 + x^13 + x^11 + 1 (taps)
    assign lfsr_x_next_bit = lfsr_x[15] ^ lfsr_x[13] ^ lfsr_x[12] ^ lfsr_x[10];
    assign lfsr_y_next_bit = lfsr_y[15] ^ lfsr_y[13] ^ lfsr_y[12] ^ lfsr_y[10];
    
    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            sample_count <= 11'd0;
            cycle_count <= 11'd0;
            lfsr_x <= 16'hABCD; // Non-zero seed
            lfsr_y <= 16'h1234; // Non-zero seed
            px1 <= 16'd0;
            py1 <= 16'd0;
            px2 <= 16'd0;
            py2 <= 16'd0;
            inside1 <= 1'b0;
            inside2 <= 1'b0;
            distance_sum <= 48'd0;
            v_idx <= 4'd0;
            x1 <= 16'd0;
            y1 <= 16'd0;
            x2 <= 16'd0;
            y2 <= 16'd0;
            ray_denom <= 32'd0;
            ray_num_t <= 32'd0;
            ray_num_u <= 32'd0;
            ray_t <= 32'd0;
            ray_u <= 32'd0;
            ray_hit <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 11'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    sample_count <= 11'd0;
                    distance_sum <= 48'd0;
                    if (start) begin
                        // Reset LFSRs to ensure randomness
                        lfsr_x <= 16'hABCD;
                        lfsr_y <= 16'h1234;
                    end
                end
                
                LFSR_SETTLE: begin
                    // Update LFSRs to get random bits
                    lfsr_x <= {lfsr_x[14:0], lfsr_x_next_bit};
                    lfsr_y <= {lfsr_y[14:0], lfsr_y_next_bit};
                end
                
                GEN_POINT1: begin
                    // Generate random point 1
                    // We shift LFSR values to spread entropy (simple LCG mix)
                    lfsr_x <= {lfsr_x[14:0], lfsr_x_next_bit};
                    lfsr_y <= {lfsr_y[14:0], lfsr_y_next_bit};
                    px1 <= lfsr_x;
                    py1 <= lfsr_y;
                    inside1 <= 1'b0; // Reset flag
                    v_idx <= 4'd0; // Start vertex loop
                end
                
                CHECK_INSIDE1: begin
                    // Ray Casting Logic
                    if (v_idx < vertex_count) begin
                        // Get vertices
                        x1 <= vertex_x[v_idx];
                        y1 <= vertex_y[v_idx];
                        if (v_idx == vertex_count - 4'd1) begin
                            x2 <= vertex_x[0];
                            y2 <= vertex_y[0];
                        end else begin
                            x2 <= vertex_x[v_idx + 4'd1];
                            y2 <= vertex_y[v_idx + 4'd1];
                        end
                        
                        // Calculate denominator for intersection: (y2 - y1)
                        denom_temp <= (y2 - y1) * 32'sd65536;
                        
                        // If denominator is 0, line is horizontal, skip
                        if ((y2 - y1) == 16'sd0) begin
                            ray_hit <= 1'b0;
                        end else begin
                            // Calculate u: (py - y1) / (y2 - y1)
                            num_u_temp <= (py1 - y1) * 32'sd65536;
                            
                            // Check if u is within [0, 1] range (fixed point)
                            ray_u <= (py1 - y1) * 32'sd65536 / (y2 - y1);
                            
                            // Calculate t: (px + t*dx - x1) / dx
                            // Ray is to X=10000, so dx = 10000 - px
                            // x_intersect = x1 + u * (x2 - x1)
                            // We check if x_intersect > px1
                            
                            // To avoid overflow, calculate x_intersect directly
                            // x_intersect = x1 + ( (py1 - y1) * (x2 - x1) ) / (y2 - y1)
                            // We only need to know if intersection is to the right
                            
                            // Let's calculate the intersection X coordinate using long multiplication
                            // temp = (py1 - y1) * (x2 - x1)
                            // x_intersect = x1 + temp / (y2 - y1)
                            
                            // Optimization: Check if ((py1 - y1) < 0) != ((y2 - y1) < 0) -> u >= 0 is invalid
                            // Actually standard ray casting: 
                            // 1. Check if y is between y1 and y2 (strictly)
                            // 2. Check if ray (to +inf) intersects segment
                            
                            // Check intersection with ray to X = +infinity
                            // Condition: ((y1 > py) != (y2 > py)) && (px < (x2-x1)*(py-y1)/(y2-y1) + x1)
                            
                            // We calculate (x2-x1)*(py-y1)/(y2-y1) + x1
                            // Intermediate: (x2 - x1) * (py - y1) -> 32-bit result
                            // Divide by (y2 - y1) -> 32-bit result (scaled)
                            // Add x1 (scaled) -> 32-bit result
                            
                            // Since we are in always block, we trigger calculation
                            ray_num_t <= (x2 - x1) * (py1 - y1); // 32-bit signed product
                            ray_denom <= (y2 - y1); // 16-bit signed
                            
                            // The actual comparison check is done combinationally below
                            // to ensure timing. Here we just set a flag if valid.
                            
                            // For inside test: 
                            // Intersection exists if (y1 <= py && py < y2) || (y2 <= py && py < y1)
                            // We check if py is strictly between y1 and y2
                            // AND intersection X is strictly greater than px
                            
                            // Let's use a simpler logic for stability:
                            // If ((y1 > py1) != (y2 > py1)) then potential hit
                            // AND ((px1) < (x1 + (x2-x1)*(py1-y1)/(y2-y1)))
                        end
                    end else begin
                        // Loop finished
                    end
                end
                
                WAIT_POINT2: begin
                    // Continue LFSR
                    lfsr_x <= {lfsr_x[14:0], lfsr_x_next_bit};
                    lfsr_y <= {lfsr_y[14:0], lfsr_y_next_bit};
                end
                
                GEN_POINT2: begin
                    // Generate random point 2
                    lfsr_x <= {lfsr_x[14:0], lfsr_x_next_bit};
                    lfsr_y <= {lfsr_y[14:0], lfsr_y_next_bit};
                    px2 <= lfsr_x;
                    py2 <= lfsr_y;
                    inside2 <= 1'b0;
                    v_idx <= 4'd0;
                end
                
                CHECK_INSIDE2: begin
                    // Same logic as CHECK_INSIDE1
                    if (v_idx < vertex_count) begin
                        x1 <= vertex_x[v_idx];
                        y1 <= vertex_y[v_idx];
                        if (v_idx == vertex_count - 4'd1) begin
                            x2 <= vertex_x[0];
                            y2 <= vertex_y[0];
                        end else begin
                            x2 <= vertex_x[v_idx + 4'd1];
                            y2 <= vertex_y[v_idx + 4'd1];
                        end
                        ray_denom <= (y2 - y1) * 32'sd65536;
                        if ((y2 - y1) != 16'sd0) begin
                             ray_u <= (py2 - y1) * 32'sd65536 / (y2 - y1);
                             ray_num_t <= (x2 - x1) * (py2 - y1);
                             ray_denom <= (y2 - y1);
                        end
                    end
                end
                
                ACCUMULATE: begin
                    // Calculate Manhattan distance: |px1-px2| + |py1-py2|
                    // Since we only have 16-bit points, result fits in 17 bits.
                    // We accumulate into 48-bit sum.
                    if (inside1 && inside2) begin
                        distance_sum <= distance_sum + 
                                        ($signed({15'd0, (px1 > px2 ? px1 - px2 : px2 - px1)}) + 
                                         $signed({15'd0, (py1 > py2 ? py1 - py2 : py2 - py1)}));
                        sample_count <= sample_count + 11'd1;
                    end
                end
                
                DIVIDE: begin
                    // Divide sum by 1024 (right shift by 10)
                    // Q16.16 format: result is sum / 1024
                    // distance_sum is Q16.16 * 1024 (conceptually)
                    // Shift right 10 bits
                    result <= distance_sum[47:16]; // Keep top 32 bits (Q16.16)
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
            
            // Special handling for ray casting hit detection (combinational logic embedded)
            // We perform the actual check here to update inside flags
            if (state == CHECK_INSIDE1 && v_idx < vertex_count && (y2 - y1) != 16'sd0) begin
                // Check if py1 is strictly between y1 and y2
                // (y1 > py1) != (y2 > py1)
                if ((y1 > py1) != (y2 > py1)) begin
                    // Calculate intersection X
                    // x_intersect = x1 + ( (x2 - x1) * (py1 - y1) ) / (y2 - y1)
                    // We only need to compare x_intersect > px1
                    // i.e., (x1 * denom + num_t) > px1 * denom
                    // Use 48-bit intermediate to prevent overflow
                    if (($signed({{16{x1[15]}}, x1}) * $signed(ray_denom) + $signed(ray_num_t)) > ($signed({{16{px1[15]}}, px1}) * $signed(ray_denom))) begin
                        inside1 <= ~inside1; // Toggle
                    end
                end
            end
            
            if (state == CHECK_INSIDE2 && v_idx < vertex_count && (y2 - y1) != 16'sd0) begin
                if ((y1 > py2) != (y2 > py2)) begin
                    if (($signed({{16{x1[15]}}, x1}) * $signed(ray_denom) + $signed(ray_num_t)) > ($signed({{16{px2[15]}}, px2}) * $signed(ray_denom))) begin
                        inside2 <= ~inside2;
                    end
                end
            end
        end
    end
    
    // --- Next State Logic ---
    always @(*) begin
        next_state = state; // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) next_state = LFSR_SETTLE;
            end
            
            LFSR_SETTLE: begin
                next_state = GEN_POINT1;
            end
            
            GEN_POINT1: begin
                next_state = CHECK_INSIDE1;
            end
            
            CHECK_INSIDE1: begin
                // Loop through vertices
                if (v_idx < vertex_count - 4'd1) begin
                    // Continue loop
                end else begin
                    // Loop done, go to wait for point 2
                    next_state = WAIT_POINT2;
                end
            end
            
            WAIT_POINT2: begin
                next_state = GEN_POINT2;
            end
            
            GEN_POINT2: begin
                next_state = CHECK_INSIDE2;
            end
            
            CHECK_INSIDE2: begin
                 if (v_idx < vertex_count - 4'd1) begin
                    // Continue loop
                end else begin
                    next_state = ACCUMULATE;
                end
            end
            
            ACCUMULATE: begin
                if (sample_count >= N_SAMPLES) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = LFSR_SETTLE; // Loop back
                end
            end
            
            DIVIDE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Timeout safety
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end
    
    // --- Vertex Loop Increment Logic (Shared) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_idx <= 4'd0;
        end else begin
            if (state == CHECK_INSIDE1 && v_idx < vertex_count - 4'd1) begin
                v_idx <= v_idx + 4'd1;
            end else if (state == CHECK_INSIDE1) begin
                v_idx <= 4'd0; // Reset for next stage
            end
            
            if (state == CHECK_INSIDE2 && v_idx < vertex_count - 4'd1) begin
                v_idx <= v_idx + 4'd1;
            end else if (state == CHECK_INSIDE2) begin
                v_idx <= 4'd0;
            end
        end
    end

endmodule