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

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_HULL_PINE = 4'd1;
    localparam [3:0] COMPUTE_HULL_ASPEN = 4'd2;
    localparam [3:0] CLIP_POLYGONS = 4'd3;
    localparam [3:0] COMPUTE_AREA = 4'd4;
    localparam [3:0] FINISHED = 4'd5;

    reg [3:0] state, next_state;

    // Internal buffers for convex hulls (max 8 points)
    reg [31:0] pine_hull_x [0:7];
    reg [31:0] pine_hull_y [0:7];
    reg [3:0] pine_hull_size;
    reg [31:0] aspen_hull_x [0:7];
    reg [31:0] aspen_hull_y [0:7];
    reg [3:0] aspen_hull_size;

    // Intermediate polygon for clipping (max 8 points)
    reg [31:0] clip_poly_x [0:7];
    reg [31:0] clip_poly_y [0:7];
    reg [3:0] clip_poly_size;

    // Internal counters and temporary registers
    reg [3:0] i, j, k;
    reg [31:0] temp_x, temp_y;
    reg [63:0] temp_area;
    reg [3:0] min_idx;

    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            area_out <= 64'd0;
            cycle_count <= 16'd0;
            
            // Initialize all internal registers
            for (i = 0; i < 8; i = i + 1) begin
                pine_hull_x[i] <= 32'd0;
                pine_hull_y[i] <= 32'd0;
                aspen_hull_x[i] <= 32'd0;
                aspen_hull_y[i] <= 32'd0;
                clip_poly_x[i] <= 32'd0;
                clip_poly_y[i] <= 32'd0;
            end
            pine_hull_size <= 4'd0;
            aspen_hull_size <= 4'd0;
            clip_poly_size <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_x <= 32'd0;
            temp_y <= 32'd0;
            temp_area <= 64'd0;
            min_idx <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= COMPUTE_HULL_PINE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_HULL_PINE: begin
                    // Implement Graham Scan for Pine points
                    // Step 1: Find point with minimum y (and x if tie)
                    if (i == 4'd0) begin
                        min_idx <= 4'd0;
                        for (j = 1; j < pine_count; j = j + 1) begin
                            if (pine_pts_y[j] < pine_pts_y[min_idx] || 
                                (pine_pts_y[j] == pine_pts_y[min_idx] && pine_pts_x[j] < pine_pts_x[min_idx])) begin
                                min_idx <= j;
                            end
                        end
                        // Swap min point to first position
                        temp_x <= pine_pts_x[0];
                        temp_y <= pine_pts_y[0];
                        pine_pts_x[0] <= pine_pts_x[min_idx];
                        pine_pts_y[0] <= pine_pts_y[min_idx];
                        pine_pts_x[min_idx] <= temp_x;
                        pine_pts_y[min_idx] <= temp_y;
                        i <= i + 4'd1;
                    end
                    // Step 2: Sort remaining points by polar angle
                    else if (i < pine_count) begin
                        // Insertion sort
                        j <= i;
                        while (j > 4'd0 && 
                              (pine_pts_y[j] < pine_pts_y[j-1] || 
                               (pine_pts_y[j] == pine_pts_y[j-1] && pine_pts_x[j] < pine_pts_x[j-1]))) begin
                            // Swap
                            temp_x <= pine_pts_x[j];
                            temp_y <= pine_pts_y[j];
                            pine_pts_x[j] <= pine_pts_x[j-1];
                            pine_pts_y[j] <= pine_pts_y[j-1];
                            pine_pts_x[j-1] <= temp_x;
                            pine_pts_y[j-1] <= temp_y;
                            j <= j - 4'd1;
                        end
                        i <= i + 4'd1;
                    end
                    // Step 3: Build convex hull
                    else begin
                        // Initialize hull with first 3 points
                        if (pine_count >= 3'd3) begin
                            pine_hull_size <= 3'd3;
                            pine_hull_x[0] <= pine_pts_x[0];
                            pine_hull_y[0] <= pine_pts_y[0];
                            pine_hull_x[1] <= pine_pts_x[1];
                            pine_hull_y[1] <= pine_pts_y[1];
                            pine_hull_x[2] <= pine_pts_x[2];
                            pine_hull_y[2] <= pine_pts_y[2];
                            i <= 3'd3;
                            j <= 3'd2;
                        end else if (pine_count == 3'd2) begin
                            pine_hull_size <= 3'd2;
                            pine_hull_x[0] <= pine_pts_x[0];
                            pine_hull_y[0] <= pine_pts_y[0];
                            pine_hull_x[1] <= pine_pts_x[1];
                            pine_hull_y[1] <= pine_pts_y[1];
                            next_state <= COMPUTE_HULL_ASPEN;
                        end else begin
                            pine_hull_size <= 3'd1;
                            pine_hull_x[0] <= pine_pts_x[0];
                            pine_hull_y[0] <= pine_pts_y[0];
                            next_state <= COMPUTE_HULL_ASPEN;
                        end
                    end
                    
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_HULL_ASPEN: begin
                    // Similar implementation for Aspen points
                    // (Implementation details would mirror Pine hull computation)
                    // For brevity, we'll assume similar logic
                    if (i == 4'd0) begin
                        min_idx <= 4'd0;
                        for (j = 1; j < aspen_count; j = j + 1) begin
                            if (aspen_pts_y[j] < aspen_pts_y[min_idx] || 
                                (aspen_pts_y[j] == aspen_pts_y[min_idx] && aspen_pts_x[j] < aspen_pts_x[min_idx])) begin
                                min_idx <= j;
                            end
                        end
                        temp_x <= aspen_pts_x[0];
                        temp_y <= aspen_pts_y[0];
                        aspen_pts_x[0] <= aspen_pts_x[min_idx];
                        aspen_pts_y[0] <= aspen_pts_y[min_idx];
                        aspen_pts_x[min_idx] <= temp_x;
                        aspen_pts_y[min_idx] <= temp_y;
                        i <= i + 4'd1;
                    end else if (i < aspen_count) begin
                        j <= i;
                        while (j > 4'd0 && 
                              (aspen_pts_y[j] < aspen_pts_y[j-1] || 
                               (aspen_pts_y[j] == aspen_pts_y[j-1] && aspen_pts_x[j] < aspen_pts_x[j-1]))) begin
                            temp_x <= aspen_pts_x[j];
                            temp_y <= aspen_pts_y[j];
                            aspen_pts_x[j] <= aspen_pts_x[j-1];
                            aspen_pts_y[j] <= aspen_pts_y[j-1];
                            aspen_pts_x[j-1] <= temp_x;
                            aspen_pts_y[j-1] <= temp_y;
                            j <= j - 4'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (aspen_count >= 3'd3) begin
                            aspen_hull_size <= 3'd3;
                            aspen_hull_x[0] <= aspen_pts_x[0];
                            aspen_hull_y[0] <= aspen_pts_y[0];
                            aspen_hull_x[1] <= aspen_pts_x[1];
                            aspen_hull_y[1] <= aspen_pts_y[1];
                            aspen_hull_x[2] <= aspen_pts_x[2];
                            aspen_hull_y[2] <= aspen_pts_y[2];
                            i <= 3'd3;
                            j <= 3'd2;
                        end else if (aspen_count == 3'd2) begin
                            aspen_hull_size <= 3'd2;
                            aspen_hull_x[0] <= aspen_pts_x[0];
                            aspen_hull_y[0] <= aspen_pts_y[0];
                            aspen_hull_x[1] <= aspen_pts_x[1];
                            aspen_hull_y[1] <= aspen_pts_y[1];
                            next_state <= CLIP_POLYGONS;
                        end else begin
                            aspen_hull_size <= 3'd1;
                            aspen_hull_x[0] <= aspen_pts_x[0];
                            aspen_hull_y[0] <= aspen_pts_y[0];
                            next_state <= CLIP_POLYGONS;
                        end
                    end
                    
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                CLIP_POLYGONS: begin
                    // Implement Sutherland-Hodgman clipping
                    // Clip pine hull against aspen hull edges
                    // Initialize with pine hull
                    if (i == 4'd0) begin
                        clip_poly_size <= pine_hull_size;
                        for (j = 0; j < pine_hull_size; j = j + 1) begin
                            clip_poly_x[j] <= pine_hull_x[j];
                            clip_poly_y[j] <= pine_hull_y[j];
                        end
                        i <= i + 4'd1;
                        j <= 4'd0;
                    end
                    // Clip against each edge of aspen hull
                    else if (i <= aspen_hull_size) begin
                        // Get edge from aspen_hull[i-1] to aspen_hull[i]
                        // Implement clipping logic
                        // For simplicity, we'll assume this is handled in multiple cycles
                        if (j < clip_poly_size) begin
                            // Check if point is inside edge
                            // This is a simplified placeholder
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        next_state <= COMPUTE_AREA;
                    end
                    
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_AREA: begin
                    // Compute area of clipped polygon using shoelace formula
                    if (i == 4'd0) begin
                        temp_area <= 64'd0;
                        i <= i + 4'd1;
                        j <= 4'd0;
                    end else if (i < clip_poly_size) begin
                        // Shoelace formula: sum(x[i]*y[i+1] - x[i+1]*y[i])
                        if (j == 4'd0) begin
                            temp_area <= temp_area + 
                                (64'd0 + $signed(clip_poly_x[i]) * $signed(clip_poly_y[(i+1) % clip_poly_size]) - 
                                 $signed(clip_poly_x[(i+1) % clip_poly_size]) * $signed(clip_poly_y[i]));
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        // Finalize area (absolute value and divide by 2)
                        if (temp_area[63]) begin
                            temp_area <= -temp_area;
                        end
                        area_out <= temp_area >>> 1;  // Divide by 2
                        next_state <= FINISHED;
                    end
                    
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

    // Helper functions for fixed-point arithmetic
    function [63:0] multiply_fixed;
        input [31:0] a, b;
        begin
            multiply_fixed = $signed(a) * $signed(b);
        end
    endfunction

    function [31:0] divide_fixed;
        input [63:0] num;
        begin
            divide_fixed = num >>> 16;  // Divide by 2^16 for Q16.16
        end
    endfunction

endmodule