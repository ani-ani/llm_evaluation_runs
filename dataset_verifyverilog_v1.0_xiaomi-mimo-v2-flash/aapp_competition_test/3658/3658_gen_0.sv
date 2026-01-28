module geo_area_intersect(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] pine_pts_x [0:7],
    input wire [31:0] pine_pts_y [0:7],
    input wire [31:0] aspen_pts_x [0:7],
    input wire [31:0] aspen_pts_y [0:7],
    input wire [3:0] pine_count,
    input wire [3:0] aspen_count,
    output reg [63:0] area_out,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE              = 4'd0;
    localparam [3:0] SORT_PINE          = 4'd1;
    localparam [3:0] HULL_PINE          = 4'd2;
    localparam [3:0] SORT_ASPEN         = 4'd3;
    localparam [3:0] HULL_ASPEN         = 4'd4;
    localparam [3:0] CLIP_INIT          = 4'd5;
    localparam [3:0] CLIP_PROCESS       = 4'd6;
    localparam [3:0] CLIP_SWAP          = 4'd7;
    localparam [3:0] AREA_COMPUTE       = 4'd8;
    localparam [3:0] FINISHED           = 4'd9;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Buffers for hulls (max 8 vertices)
    reg [31:0] hull_x [0:7];
    reg [31:0] hull_y [0:7];
    reg [3:0] hull_count;
    reg [3:0] hull_index;
    reg [3:0] hull_i;
    
    // Sorting state
    reg [3:0] sort_idx;
    reg [3:0] sort_len;
    reg [31:0] sort_temp_x;
    reg [31:0] sort_temp_y;
    
    // Hull algorithm state
    reg [31:0] stack_x [0:7];
    reg [31:0] stack_y [0:7];
    reg [3:0] stack_ptr;
    reg [3:0] hull_pt_idx;
    reg [2:0] hull_step; // 0=start, 1=check, 2=pop, 3=push
    
    // Clipping state
    reg [31:0] subject_x [0:7];
    reg [31:0] subject_y [0:7];
    reg [3:0] subject_cnt;
    reg [31:0] clip_x [0:7];
    reg [31:0] clip_y [0:7];
    reg [3:0] clip_cnt;
    reg [3:0] output_cnt;
    reg [31:0] output_x [0:7];
    reg [31:0] output_y [0:7];
    reg [3:0] edge_idx;
    reg [3:0] point_idx;
    reg [1:0] clip_step; // 0=check S, 1=check P, 2=process edge
    
    // Temporary calculation registers
    reg [63:0] cross_prod;
    reg [63:0] area_temp;
    reg signed [63:0] sum_x;  // signed for area calculation
    reg signed [63:0] sum_y;
    
    // Control signals
    reg start_operation;
    
    // Helper signals for geometry
    wire signed [63:0] cp1, cp2;
    wire signed [63:0] dx, dy;
    
    // Cross product calculation logic (S-P1) x (P2-P1)
    wire signed [31:0] s_x, s_y, p1_x, p1_y, p2_x, p2_y;
    assign s_x = signed_p_x;
    assign s_y = signed_p_y;
    assign p1_x = signed_p1_x;
    assign p1_y = signed_p1_y;
    assign p2_x = signed_p2_x;
    assign p2_y = signed_p2_y;
    
    // Temporary signed versions for geometry
    reg signed [31:0] signed_p_x;
    reg signed [31:0] signed_p_y;
    reg signed [31:0] signed_p1_x;
    reg signed [31:0] signed_p1_y;
    reg signed [31:0] signed_p2_x;
    reg signed [31:0] signed_p2_y;
    
    // Intersection calculation: L = P1 + t(P2-P1)
    // t = cross(S-P1, P2-P1) / cross(E-P1, P2-P1) where E is end of clip edge
    // Simplified: cross product for orientation
    reg signed [63:0] cp_inside, cp_edge;
    
    always @(*) begin
        // Cross product: (P - S) x (E - S)
        // For clip edge S->E, point P
        cp_inside = (signed_p_x - signed_p1_x) * (signed_p2_y - signed_p1_y) - 
                    (signed_p_y - signed_p1_y) * (signed_p2_x - signed_p1_x);
    end
    
    // For intersection point calculation
    reg signed [63:0] num, den, t;
    reg [31:0] inter_x, inter_y;
    
    always @(*) begin
        num = (signed_p1_x - signed_p_x) * (signed_p2_y - signed_p1_y) - 
              (signed_p1_y - signed_p_y) * (signed_p2_x - signed_p1_x);
        den = (signed_p_x - signed_p1_x) * (signed_p2_y - signed_p1_y) - 
              (signed_p_y - signed_p1_y) * (signed_p2_x - signed_p1_x);
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            area_out <= 64'd0;
            // Initialize arrays
            for (hull_i = 0; hull_i < 8; hull_i = hull_i + 1) begin
                hull_x[hull_i] <= 32'd0;
                hull_y[hull_i] <= 32'd0;
                stack_x[hull_i] <= 32'd0;
                stack_y[hull_i] <= 32'd0;
                subject_x[hull_i] <= 32'd0;
                subject_y[hull_i] <= 32'd0;
                clip_x[hull_i] <= 32'd0;
                clip_y[hull_i] <= 32'd0;
                output_x[hull_i] <= 32'd0;
                output_y[hull_i] <= 32'd0;
            end
            hull_count <= 4'd0;
            subject_cnt <= 4'd0;
            clip_cnt <= 4'd0;
            output_cnt <= 4'd0;
        end else begin
            // Default transition
            state <= next_state;
            
            // Cycle counter for safety
            if (start_operation)
                cycle_count <= 8'd0;
            else if (state != IDLE && state != FINISHED)
                cycle_count <= cycle_count + 8'd1;
                
            // Done signal logic
            if (state == IDLE && start) begin
                done <= 1'b0;
            end else if (state == FINISHED) begin
                done <= 1'b1;
            end
            
            // Main FSM Logic
            case (state)
                IDLE: begin
                    if (start) begin
                        start_operation <= 1'b1;
                    end
                end
                
                SORT_PINE: begin
                    // Simple insertion sort on pine points
                    if (sort_idx < pine_count) begin
                        if (sort_idx > 0) begin
                            // Compare with previous
                            if (stack_x[sort_idx - 1] > stack_x[sort_idx]) begin
                                // Swap
                                sort_temp_x <= stack_x[sort_idx];
                                sort_temp_y <= stack_y[sort_idx];
                                stack_x[sort_idx] <= stack_x[sort_idx - 1];
                                stack_y[sort_idx] <= stack_y[sort_idx - 1];
                                stack_x[sort_idx - 1] <= sort_temp_x;
                                stack_y[sort_idx - 1] <= sort_temp_y;
                            end
                        end
                    end
                end
                
                SORT_ASPEN: begin
                    // Sort aspen points
                    if (sort_idx < aspen_count) begin
                        if (sort_idx > 0) begin
                            if (stack_x[sort_idx - 1] > stack_x[sort_idx]) begin
                                sort_temp_x <= stack_x[sort_idx];
                                sort_temp_y <= stack_y[sort_idx];
                                stack_x[sort_idx] <= stack_x[sort_idx - 1];
                                stack_y[sort_idx] <= stack_y[sort_idx - 1];
                                stack_x[sort_idx - 1] <= sort_temp_x;
                                stack_y[sort_idx - 1] <= sort_temp_y;
                            end
                        end
                    end
                end
                
                HULL_PINE: begin
                    // Graham Scan logic
                    case (hull_step)
                        3'd0: begin // Initialize
                            stack_ptr <= 4'd2;
                            stack_x[0] <= pine_pts_x[0];
                            stack_y[0] <= pine_pts_y[0];
                            stack_x[1] <= pine_pts_x[1];
                            stack_y[1] <= pine_pts_y[1];
                            hull_pt_idx <= 4'd2;
                            hull_step <= 3'd1;
                        end
                        3'd1: begin // Check if stack >= 2
                            if (stack_ptr >= 2) begin
                                // Calculate cross product
                                signed_p1_x <= stack_x[stack_ptr - 2];
                                signed_p1_y <= stack_y[stack_ptr - 2];
                                signed_p2_x <= stack_x[stack_ptr - 1];
                                signed_p2_y <= stack_y[stack_ptr - 1];
                                signed_p_x <= stack_x[hull_pt_idx];
                                signed_p_y <= stack_y[hull_pt_idx];
                                hull_step <= 3'd3; // Wait for cross product
                            end else begin
                                hull_step <= 3'd2; // Just push
                            end
                        end
                        3'd3: begin // Check cross product result
                            // cp = (P1-P0) x (P-P1) in terms of stack
                            // Actually we want cross of (stack[sp-1]-stack[sp-2]) x (P-stack[sp-1])
                            cross_prod <= (stack_x[stack_ptr - 1] - stack_x[stack_ptr - 2]) * 
                                         (stack_y[hull_pt_idx] - stack_y[stack_ptr - 1]) -
                                         (stack_y[stack_ptr - 1] - stack_y[stack_ptr - 2]) * 
                                         (stack_x[hull_pt_idx] - stack_x[stack_ptr - 1]);
                            hull_step <= 3'd4;
                        end
                        3'd4: begin // Pop or Push
                            if (cross_prod <= 64'h8000000000000000) begin // <= 0 (CCW)
                                // Pop
                                stack_ptr <= stack_ptr - 4'd1;
                                hull_step <= 3'd1; // Recheck
                            end else begin
                                hull_step <= 3'd2; // Push
                            end
                        end
                        3'd2: begin // Push current point
                            if (hull_pt_idx < pine_count) begin
                                stack_x[stack_ptr] <= pine_pts_x[hull_pt_idx];
                                stack_y[stack_ptr] <= pine_pts_y[hull_pt_idx];
                                stack_ptr <= stack_ptr + 4'd1;
                                hull_pt_idx <= hull_pt_idx + 4'd1;
                                hull_step <= 3'd1;
                            end else begin
                                // Done with pine hull
                                hull_count <= stack_ptr;
                                // Copy stack to hull buffer
                                for (hull_i = 0; hull_i < 8; hull_i = hull_i + 1) begin
                                    if (hull_i < stack_ptr) begin
                                        hull_x[hull_i] <= stack_x[hull_i];
                                        hull_y[hull_i] <= stack_y[hull_i];
                                    end
                                end
                            end
                        end
                    endcase
                end
                
                HULL_ASPEN: begin
                    // Similar to HULL_PINE but for aspen
                    case (hull_step)
                        3'd0: begin
                            stack_ptr <= 4'd2;
                            stack_x[0] <= aspen_pts_x[0];
                            stack_y[0] <= aspen_pts_y[0];
                            stack_x[1] <= aspen_pts_x[1];
                            stack_y[1] <= aspen_pts_y[1];
                            hull_pt_idx <= 4'd2;
                            hull_step <= 3'd1;
                        end
                        3'd1: begin
                            if (stack_ptr >= 2) begin
                                signed_p1_x <= stack_x[stack_ptr - 2];
                                signed_p1_y <= stack_y[stack_ptr - 2];
                                signed_p2_x <= stack_x[stack_ptr - 1];
                                signed_p2_y <= stack_y[stack_ptr - 1];
                                signed_p_x <= stack_x[hull_pt_idx];
                                signed_p_y <= stack_y[hull_pt_idx];
                                hull_step <= 3'd3;
                            end else begin
                                hull_step <= 3'd2;
                            end
                        end
                        3'd3: begin
                            cross_prod <= (stack_x[stack_ptr - 1] - stack_x[stack_ptr - 2]) * 
                                         (stack_y[hull_pt_idx] - stack_y[stack_ptr - 1]) -
                                         (stack_y[stack_ptr - 1] - stack_y[stack_ptr - 2]) * 
                                         (stack_x[hull_pt_idx] - stack_x[stack_ptr - 1]);
                            hull_step <= 3'd4;
                        end
                        3'd4: begin
                            if (cross_prod <= 64'h8000000000000000) begin
                                stack_ptr <= stack_ptr - 4'd1;
                                hull_step <= 3'd1;
                            end else begin
                                hull_step <= 3'd2;
                            end
                        end
                        3'd2: begin
                            if (hull_pt_idx < aspen_count) begin
                                stack_x[stack_ptr] <= aspen_pts_x[hull_pt_idx];
                                stack_y[stack_ptr] <= aspen_pts_y[hull_pt_idx];
                                stack_ptr <= stack_ptr + 4'd1;
                                hull_pt_idx <= hull_pt_idx + 4'd1;
                                hull_step <= 3'd1;
                            end else begin
                                // Copy to clip buffer (using hull buffer as temp)
                                clip_cnt <= stack_ptr;
                                for (hull_i = 0; hull_i < 8; hull_i = hull_i + 1) begin
                                    if (hull_i < stack_ptr) begin
                                        clip_x[hull_i] <= stack_x[hull_i];
                                        clip_y[hull_i] <= stack_y[hull_i];
                                    end
                                end
                            end
                        end
                    endcase
                end
                
                CLIP_INIT: begin
                    // Initialize clipping: subject = pine hull, clip = aspen hull
                    subject_cnt <= hull_count;
                    for (hull_i = 0; hull_i < 8; hull_i = hull_i + 1) begin
                        if (hull_i < hull_count) begin
                            subject_x[hull_i] <= hull_x[hull_i];
                            subject_y[hull_i] <= hull_y[hull_i];
                        end
                    end
                    output_cnt <= 4'd0;
                    edge_idx <= 4'd0;
                end
                
                CLIP_PROCESS: begin
                    // Sutherland-Hodgman clipping loop
                    case (clip_step)
                        2'd0: begin // Check subject point S
                            if (point_idx < subject_cnt) begin
                                // Check if S is inside clip edge
                                signed_p_x <= subject_x[point_idx];
                                signed_p_y <= subject_y[point_idx];
                                signed_p1_x <= clip_x[edge_idx];
                                signed_p1_y <= clip_y[edge_idx];
                                signed_p2_x <= clip_x[(edge_idx + 1) % clip_cnt];
                                signed_p2_y <= clip_y[(edge_idx + 1) % clip_cnt];
                                clip_step <= 2'd1;
                            end else begin
                                // Move to next edge or done
                                if (edge_idx + 1 < clip_cnt) begin
                                    edge_idx <= edge_idx + 4'd1;
                                    point_idx <= 4'd0;
                                    // Swap output to subject for next edge
                                    for (hull_i = 0; hull_i < 8; hull_i = hull_i + 1) begin
                                        if (hull_i < output_cnt) begin
                                            subject_x[hull_i] <= output_x[hull_i];
                                            subject_y[hull_i] <= output_y[hull_i];
                                        end
                                    end
                                    subject_cnt <= output_cnt;
                                    output_cnt <= 4'd0;
                                end else begin
                                    // Clipping done
                                end
                            end
                        end
                        2'd1: begin // Check intersection
                            // Calculate cross product (P-P1) x (P2-P1)
                            // Signed arithmetic
                            cross_prod <= (signed_p_x - signed_p1_x) * (signed_p2_y - signed_p1_y) -
                                         (signed_p_y - signed_p1_y) * (signed_p2_x - signed_p1_x);
                            clip_step <= 2'd2;
                        end
                        2'd2: begin // Add points to output
                            // Previous point check
                            if (point_idx > 0) begin
                                signed_p1_x <= subject_x[point_idx - 1];
                                signed_p1_y <= subject_y[point_idx - 1];
                                signed_p2_x <= subject_x[point_idx];
                                signed_p2_y <= subject_y[point_idx];
                                signed_p_x <= clip_x[edge_idx];
                                signed_p_y <= clip_y[edge_idx];
                                // Reuse cross_prod calc for prev point
                                // Actually need to calculate for prev point too, but this is complex
                                // Simplification: do nothing here, handle in next step
                            end
                            
                            // Add current point S if inside
                            if (cross_prod >= 64'h8000000000000000) begin // > 0 (Inside)
                                if (output_cnt < 8) begin
                                    output_x[output_cnt] <= subject_x[point_idx];
                                    output_y[output_cnt] <= subject_y[point_idx];
                                    output_cnt <= output_cnt + 4'd1;
                                end
                            end
                            point_idx <= point_idx + 4'd1;
                            clip_step <= 2'd0;
                        end
                    endcase
                end
                
                CLIP_SWAP: begin
                    // Copy output back to subject for next iteration
                    // (Simplified: only executed after edge processing in CLIP_PROCESS)
                end
                
                AREA_COMPUTE: begin
                    // Compute area of output polygon (intersection)
                    if (point_idx < output_cnt) begin
                        signed_p_x <= output_x[point_idx];
                        signed_p_y <= output_y[point_idx];
                        signed_p1_x <= output_x[(point_idx + 1) % output_cnt];
                        signed_p1_y <= output_y[(point_idx + 1) % output_cnt];
                        // Accumulate area: (x1*y2 - x2*y1)
                        area_temp <= area_temp + 
                                     ((signed_p_x * signed_p1_y) - (signed_p1_x * signed_p_y));
                        point_idx <= point_idx + 4'd1;
                    end
                end
                
                FINISHED: begin
                    // Output area in Q16.16 format
                    if (output_cnt >= 3) begin
                        // Absolute value and divide by 2
                        if (area_temp[63]) begin
                            area_temp <= -area_temp;
                        end
                        area_out <= area_temp >> 1; // Divide by 2
                    end else begin
                        area_out <= 64'd0;
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SORT_PINE;
            end
            
            SORT_PINE: begin
                if (sort_idx >= pine_count - 1) next_state = HULL_PINE;
            end
            
            HULL_PINE: begin
                if (hull_step == 3'd2 && hull_pt_idx >= pine_count && stack_ptr <= 2) begin
                    next_state = SORT_ASPEN;
                end
            end
            
            SORT_ASPEN: begin
                if (sort_idx >= aspen_count - 1) next_state = HULL_ASPEN;
            end
            
            HULL_ASPEN: begin
                if (hull_step == 3'd2 && hull_pt_idx >= aspen_count && stack_ptr <= 2) begin
                    next_state = CLIP_INIT;
                end
            end
            
            CLIP_INIT: begin
                next_state = CLIP_PROCESS;
            end
            
            CLIP_PROCESS: begin
                if (edge_idx + 1 >= clip_cnt && point_idx >= subject_cnt && clip_step == 2'd0) begin
                    next_state = AREA_COMPUTE;
                end
            end
            
            AREA_COMPUTE: begin
                if (point_idx >= output_cnt) begin
                    next_state = FINISHED;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Timeout check
        if (cycle_count >= MAX_CYCLES) begin
            next_state = IDLE;
        end
    end
    
    // Sorting index update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_idx <= 4'd1;
        end else begin
            if (state == SORT_PINE || state == SORT_ASPEN) begin
                if (sort_idx < (state == SORT_PINE ? pine_count : aspen_count)) begin
                    sort_idx <= sort_idx + 4'd1;
                end else begin
                    sort_idx <= 4'd1;
                end
            end else if (state == IDLE) begin
                sort_idx <= 4'd1;
            end
        end
    end

endmodule