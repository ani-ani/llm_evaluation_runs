module laser_shots(
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input signed [15:0] x_in,
    input signed [15:0] y_in,
    input load_done,
    output reg result,
    output reg done,
    output reg [2:0] state_debug
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] CHECK_SINGLE = 3'd2;
    localparam [2:0] CHECK_PAIRS = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] point_count;
    reg [15:0] x_coords [0:15];
    reg [15:0] y_coords [0:15];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Slope calculation registers
    reg signed [31:0] dx1, dy1, dx2, dy2;
    reg signed [31:0] cross_product;
    reg [3:0] i, j, k;
    reg [3:0] ref1, ref2;
    reg [3:0] outliers;
    reg single_line_success;
    reg two_line_success;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            point_count <= 4'd0;
            cycle_count <= 8'd0;
            state_debug <= 3'd0;
            
            // Initialize coordinate arrays
            for (i = 0; i < 16; i = i + 1) begin
                x_coords[i] <= 16'd0;
                y_coords[i] <= 16'd0;
            end
            
            // Initialize algorithm registers
            dx1 <= 32'd0;
            dy1 <= 32'd0;
            dx2 <= 32'd0;
            dy2 <= 32'd0;
            cross_product <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            ref1 <= 4'd0;
            ref2 <= 4'd0;
            outliers <= 4'd0;
            single_line_success <= 1'b0;
            two_line_success <= 1'b0;
        end else begin
            state <= next_state;
            state_debug <= state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                if (load_done) begin
                    next_state = CHECK_SINGLE;
                end
            end
            
            CHECK_SINGLE: begin
                if (single_line_success || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else if (!single_line_success) begin
                    next_state = CHECK_PAIRS;
                end
            end
            
            CHECK_PAIRS: begin
                if (two_line_success || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load phase: Store coordinates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            point_count <= 4'd0;
        end else if (state == LOAD && valid_in && point_count < 4'd16) begin
            x_coords[point_count] <= x_in;
            y_coords[point_count] <= y_in;
            point_count <= point_count + 4'd1;
        end
    end

    // Cycle counter for processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state == CHECK_SINGLE || state == CHECK_PAIRS) begin
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Check if all points are colinear (single line)
    always @(posedge clk) begin
        if (state == CHECK_SINGLE && point_count >= 4'd3) begin
            // Use first two points as reference
            dx1 <= x_coords[1] - x_coords[0];
            dy1 <= y_coords[1] - y_coords[0];
            
            // Check all other points
            single_line_success <= 1'b1;
            for (k = 2; k < point_count; k = k + 1) begin
                dx2 <= x_coords[k] - x_coords[0];
                dy2 <= y_coords[k] - y_coords[0];
                cross_product <= dx1 * dy2 - dy1 * dx2;
                
                // If cross product is not zero, points are not colinear
                if (cross_product != 32'd0) begin
                    single_line_success <= 1'b0;
                end
            end
        end
    end

    // Check if points can be covered by two lines
    always @(posedge clk) begin
        if (state == CHECK_PAIRS && point_count >= 4'd3) begin
            two_line_success <= 1'b0;
            
            // Try all possible pairs of points as reference for first line
            for (ref1 = 0; ref1 < point_count - 1; ref1 = ref1 + 1) begin
                for (ref2 = ref1 + 1; ref2 < point_count; ref2 = ref2 + 1) begin
                    // Skip if we don't have enough points left
                    if (point_count - 2 < 3) begin
                        two_line_success <= 1'b1;
                    end else begin
                        // Count outliers for this reference line
                        outliers <= 4'd0;
                        for (k = 0; k < point_count; k = k + 1) begin
                            if (k != ref1 && k != ref2) begin
                                dx1 <= x_coords[ref2] - x_coords[ref1];
                                dy1 <= y_coords[ref2] - y_coords[ref1];
                                dx2 <= x_coords[k] - x_coords[ref1];
                                dy2 <= y_coords[k] - y_coords[ref1];
                                cross_product <= dx1 * dy2 - dy1 * dx2;
                                
                                if (cross_product != 32'd0) begin
                                    outliers <= outliers + 4'd1;
                                end
                            end
                        end
                        
                        // If we have at most 2 outliers, check if they form a second line
                        if (outliers <= 4'd2) begin
                            // Find the two outliers
                            reg [3:0] outlier_indices [0:1];
                            reg [3:0] outlier_count;
                            outlier_count <= 4'd0;
                            
                            for (k = 0; k < point_count; k = k + 1) begin
                                if (k != ref1 && k != ref2) begin
                                    dx1 <= x_coords[ref2] - x_coords[ref1];
                                    dy1 <= y_coords[ref2] - y_coords[ref1];
                                    dx2 <= x_coords[k] - x_coords[ref1];
                                    dy2 <= y_coords[k] - y_coords[ref1];
                                    cross_product <= dx1 * dy2 - dy1 * dx2;
                                    
                                    if (cross_product != 32'd0 && outlier_count < 4'd2) begin
                                        outlier_indices[outlier_count] <= k;
                                        outlier_count <= outlier_count + 4'd1;
                                    end
                                end
                            end
                            
                            // If we have exactly 2 outliers, check if they form a line
                            if (outlier_count == 4'd2) begin
                                dx1 <= x_coords[outlier_indices[1]] - x_coords[outlier_indices[0]];
                                dy1 <= y_coords[outlier_indices[1]] - y_coords[outlier_indices[0]];
                                
                                // Check if all other points (excluding ref1, ref2) are on either line
                                reg all_on_lines;
                                all_on_lines <= 1'b1;
                                
                                for (k = 0; k < point_count; k = k + 1) begin
                                    if (k != ref1 && k != ref2 && k != outlier_indices[0] && k != outlier_indices[1]) begin
                                        // Check against first line
                                        dx2 <= x_coords[k] - x_coords[ref1];
                                        dy2 <= y_coords[k] - y_coords[ref1];
                                        cross_product <= dx1 * dy2 - dy1 * dx2;
                                        
                                        // Check against second line
                                        if (cross_product != 32'd0) begin
                                            dx2 <= x_coords[k] - x_coords[outlier_indices[0]];
                                            dy2 <= y_coords[k] - y_coords[outlier_indices[0]];
                                            cross_product <= dx1 * dy2 - dy1 * dx2;
                                            
                                            if (cross_product != 32'd0) begin
                                                all_on_lines <= 1'b0;
                                            end
                                        end
                                    end
                                end
                                
                                if (all_on_lines) begin
                                    two_line_success <= 1'b1;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    // Result and done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
                
                LOAD: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
                
                CHECK_SINGLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
                
                CHECK_PAIRS: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
                
                DONE_STATE: begin
                    // For N <= 2, always success
                    if (point_count <= 4'd2) begin
                        result <= 1'b1;
                    end else if (single_line_success || two_line_success) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule