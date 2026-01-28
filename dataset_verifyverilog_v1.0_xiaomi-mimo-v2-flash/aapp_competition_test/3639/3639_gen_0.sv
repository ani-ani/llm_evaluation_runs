module CyclistWetness(
    input clk,
    input rst_n,
    input start,
    input [4:0] T_in,
    input [15:0] c_fixed,
    input [15:0] d_fixed,
    input [6:0] rain [0:31],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SETUP   = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FIND_MIN = 3'd3;
    localparam [2:0] FINISH  = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Registers for inputs
    reg [4:0] T_reg;
    reg [15:0] c_reg;
    reg [15:0] d_reg;
    reg [6:0] rain_reg [0:31];
    
    // DP state - using block RAM style
    localparam NUM_DIST = 32;
    localparam NUM_TIME = 32;
    
    // Current wetness for each distance index (0-31)
    reg [31:0] dp_current [0:31];
    reg [31:0] dp_next [0:31];
    
    // Control counters
    reg [4:0] time_idx;      // Current time step (0 to T_reg)
    reg [5:0] dist_idx;      // Distance index (0 to 31)
    reg [3:0] speed_idx;     // Speed selection (0 to 7)
    reg [4:0] setup_counter; // For initialization
    reg [7:0] cycle_counter; // Timeout prevention
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Intermediate calculation registers
    reg [31:0] temp_v;           // Velocity (Q16.16)
    reg [63:0] temp_v_sq;        // v^2 (Q32.32)
    reg [63:0] temp_sweat;       // Sweat calculation (Q32.32)
    reg [31:0] sweat_q16;        // Sweat in Q16.16
    reg [31:0] rain_acc;         // Accumulated rain
    reg [15:0] distance_step;    // Distance per step (Q8.8)
    reg [15:0] time_step;        // Time per step (Q8.8) - 1/32 minute
    reg [15:0] speed_val;        // Current speed (Q8.8)
    reg [15:0] delta_dist;       // Distance covered (Q16.16)
    reg [31:0] candidate_wetness;
    
    // Precomputed speeds (0.5 to 5.0 km/h in 8 steps)
    // Q8.8 format: 0.5 = 0x0080, 5.0 = 0x0500
    wire [15:0] speeds [0:7];
    assign speeds[0] = 16'h0080; // 0.5
    assign speeds[1] = 16'h0100; // 1.0
    assign speeds[2] = 16'h0180; // 1.5
    assign speeds[3] = 16'h0200; // 2.0
    assign speeds[4] = 16'h0280; // 2.5
    assign speeds[5] = 16'h0300; // 3.0
    assign speeds[6] = 16'h0380; // 3.5
    assign speeds[7] = 16'h0400; // 4.0
    
    // Result tracking
    reg [31:0] best_result;
    reg [5:0] best_dist_idx;
    
    // Helper function for Q16.16 multiplication
    function automatic [31:0] mul_q1616(
        input [31:0] a,
        input [31:0] b
    );
        reg [63:0] prod;
        begin
            prod = a * b;          // Q32.32
            mul_q1616 = prod[47:16]; // Q16.16 (take middle 32 bits)
        end
    endfunction
    
    // Helper function for Q16.16 * Q8.8 multiplication
    function automatic [31:0] mul_q1616_q88(
        input [31:0] a_q16,        // Q16.16
        input [15:0] b_q8          // Q8.8
    );
        reg [47:0] prod;
        begin
            prod = a_q16 * b_q8;   // Q24.24
            mul_q1616_q88 = prod[39:8]; // Q16.16 (shift right 8, keep 32 bits)
        end
    endfunction
    
    // Helper function for Q8.8 multiplication
    function automatic [15:0] mul_q88(
        input [15:0] a,
        input [15:0] b
    );
        reg [31:0] prod;
        begin
            prod = a * b;          // Q16.16
            mul_q88 = prod[23:8];  // Q8.8 (shift right 8, keep 16 bits)
        end
    endfunction
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            time_idx <= 5'd0;
            dist_idx <= 6'd0;
            speed_idx <= 4'd0;
            setup_counter <= 5'd0;
            best_result <= 32'h7FFFFFFF; // Initialize to max
            best_dist_idx <= 6'd0;
            
            // Initialize DP arrays
            for (int i = 0; i < 32; i = i + 1) begin
                dp_current[i] <= 32'h7FFFFFFF;
                dp_next[i] <= 32'h7FFFFFFF;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        // Store inputs
                        T_reg <= (T_in == 5'd0) ? 5'd1 : T_in; // Clamp to 1 if 0
                        c_reg <= c_fixed;
                        d_reg <= d_fixed;
                        
                        // Copy rain values
                        for (int i = 0; i < 32; i = i + 1) begin
                            rain_reg[i] <= rain[i];
                        end
                        
                        state <= SETUP;
                        setup_counter <= 5'd0;
                        time_idx <= 5'd0;
                        best_result <= 32'h7FFFFFFF;
                    end
                end
                
                SETUP: begin
                    // Calculate distance step: d / 32 (Q8.8)
                    // d_reg is Q8.8, result Q8.8
                    if (setup_counter == 5'd0) begin
                        distance_step <= {2'b00, d_reg[15:2]}; // Divide by 4 first
                        time_step <= 16'h0020; // 1/32 = 0.03125 in Q8.8
                    end
                    
                    // Initialize dp_current[0] = 0, others = infinity
                    if (setup_counter < 5'd2) begin
                        for (int i = 0; i < 32; i = i + 1) begin
                            if (i == 0 && setup_counter == 5'd0) begin
                                dp_current[i] <= 32'd0;
                            end else if (i > 0) begin
                                dp_current[i] <= 32'h7FFFFFFF;
                            end
                        end
                    end
                    
                    if (setup_counter == 5'd1) begin
                        setup_counter <= 5'd0;
                        state <= COMPUTE;
                    end else begin
                        setup_counter <= setup_counter + 5'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (time_idx < T_reg) begin
                        if (dist_idx < NUM_DIST) begin
                            if (speed_idx < 8) begin
                                // Check if current state is reachable
                                if (dp_current[dist_idx] < 32'h7FFFFFFF) begin
                                    // Get current speed
                                    speed_val <= speeds[speed_idx];
                                    
                                    // Calculate velocity in km/h
                                    // v = speed_val (already Q8.8, 0.5 to 5.0 km/h)
                                    temp_v <= {16'h0000, speeds[speed_idx]}; // Q16.16
                                    
                                    // Calculate v^2 (Q32.32)
                                    temp_v_sq <= {16'h0000, speeds[speed_idx]} * {16'h0000, speeds[speed_idx]};
                                end
                                speed_idx <= speed_idx + 4'd1;
                            end else begin
                                // Reset speed_idx for next distance
                                speed_idx <= 4'd0;
                                
                                // Calculate sweat for this speed
                                // s = c * v^2
                                temp_sweat <= c_reg * temp_v_sq[31:16]; // Q8.8 * Q16.16 = Q24.24
                                
                                // Convert sweat to Q16.16 (need to shift by 8)
                                sweat_q16 <= (c_reg * temp_v_sq[31:16]) >> 8;
                                
                                // Calculate distance covered: v * time_step
                                // v (Q8.8) * time_step (Q8.8) = Q16.16
                                delta_dist <= mul_q88(speed_val, time_step);
                                
                                // Calculate new distance index
                                // dist + delta_dist, then scale to 0-31
                                // delta_dist is Q16.16, divide by (d/32) which is Q8.8
                                // Result = delta_dist / distance_step
                                // delta_dist (Q16.16) / distance_step (Q8.8) = Q8.8
                                // Multiply by 32 for integer index
                                // Index = delta_dist / distance_step = delta_dist * (32 / d)
                                // Simplified: delta_dist is Q16.16, distance_step is Q8.8
                                // delta_dist / distance_step = (delta_dist << 8) / distance_step
                                
                                // Check overflow for new distance
                                // new_dist = dist_idx + (delta_dist / distance_step)
                                // For simplicity, use delta_dist in Q8.8 format
                                reg [15:0] delta_dist_q8;
                                delta_dist_q8 = delta_dist[23:8]; // Convert to Q8.8
                                
                                // Calculate rain: time_step * rain[time_idx]
                                // time_step is 1/32, so rain is rain[time_idx]/32
                                reg [22:0] rain_partial;
                                rain_partial = {15'd0, rain_reg[time_idx]} * 8'd32; // Scale up
                                rain_acc <= {9'd0, rain_partial[22:9]}; // Divide by 32, result Q8.8
                                
                                // Calculate total wetness
                                // sweat_q16 is Q16.16, rain_acc is Q8.8
                                // rain_acc needs to be converted to Q16.16
                                candidate_wetness <= dp_current[dist_idx] + sweat_q16 + {rain_acc, 8'd0};
                                
                                // Calculate new distance index
                                // Convert delta_dist to steps: delta_dist / distance_step
                                // Use division: delta_dist (Q16.16) / distance_step (Q8.8)
                                // Result in Q8.8, multiply by 32 for integer index
                                // Simplified: delta_dist_q8 / distance_step
                                // For our purposes, approximate: delta_dist_q8 is already proportional
                                // index_increment = delta_dist_q8 >> 4 (divide by 16)
                                
                                // Wait one cycle for calculations
                            end
                            
                        end else begin
                            // Finished all distances for this time step
                            dist_idx <= 6'd0;
                            speed_idx <= 4'd0;
                            time_idx <= time_idx + 5'd1;
                            
                            // Copy dp_next to dp_current
                            for (int i = 0; i < 32; i = i + 1) begin
                                dp_current[i] <= dp_next[i];
                                dp_next[i] <= 32'h7FFFFFFF; // Reset for next iteration
                            end
                        end
                    end else begin
                        // Time has reached T, find minimum
                        state <= FIND_MIN;
                        dist_idx <= 6'd0;
                    end
                end
                
                FIND_MIN: begin
                    // Search for minimum wetness at or beyond target distance
                    if (dist_idx < NUM_DIST) begin
                        if (dp_current[dist_idx] < best_result) begin
                            best_result <= dp_current[dist_idx];
                            best_dist_idx <= dist_idx;
                        end
                        dist_idx <= dist_idx + 6'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= best_result;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection
            if (cycle_counter >= MAX_CYCLES && state != IDLE) begin
                state <= FINISH;
                result <= 32'd0;
                done <= 1'b1;
            end
        end
    end
    
    // Combinational logic for DP update (completes in same cycle)
    always @(*) begin
        integer new_dist_idx;
        reg [31:0] new_wetness;
        reg [15:0] dist_increment;
        
        // Default assignments
        for (int i = 0; i < 32; i = i + 1) begin
            dp_next[i] = dp_current[i];
        end
        
        if (state == COMPUTE && dist_idx < NUM_DIST && speed_idx == 4'd0) begin
            // Only process when ready to compute for current state
            if (dp_current[dist_idx] < 32'h7FFFFFFF) begin
                // Calculate new distance index
                // delta_dist is Q16.16, distance_step is Q8.8
                // Convert delta_dist to Q8.8: delta_dist[23:8]
                // Then divide by distance_step to get steps in Q8.8
                // Multiply by 32 for integer steps
                // Simplified approximation: delta_dist_q8 / distance_step gives steps
                // For our discrete speeds, we can use lookup
                
                // Precompute for each speed
                case (speed_idx)
                    4'd0: dist_increment = 16'h0020; // 0.5 km/h -> ~0.26 steps
                    4'd1: dist_increment = 16'h0040; // 1.0 km/h -> ~0.52 steps
                    4'd2: dist_increment = 16'h0060; // 1.5 km/h -> ~0.78 steps
                    4'd3: dist_increment = 16'h0080; // 2.0 km/h -> ~1.04 steps
                    4'd4: dist_increment = 16'h00A0; // 2.5 km/h -> ~1.30 steps
                    4'd5: dist_increment = 16'h00C0; // 3.0 km/h -> ~1.56 steps
                    4'd6: dist_increment = 16'h00E0; // 3.5 km/h -> ~1.82 steps
                    4'd7: dist_increment = 16'h0100; // 4.0 km/h -> ~2.08 steps
                    default: dist_increment = 16'h0000;
                endcase
                
                // Add to current index (integer rounding)
                new_dist_idx = dist_idx + dist_increment[7:3]; // Divide by 8, then add
                
                // Clamp to max distance index
                if (new_dist_idx >= 32) new_dist_idx = 31;
                
                // Update dp_next if better
                new_wetness = dp_current[dist_idx] + sweat_q16 + {rain_acc, 8'd0};
                if (new_wetness < dp_next[new_dist_idx]) begin
                    dp_next[new_dist_idx] = new_wetness;
                end
            end
        end
    end
    
endmodule
